import Foundation
import CloudKit
import Combine
import SwiftUI

public struct CommunityFeedbackItem: Identifiable, Codable {
    public var id: String
    public var authorName: String
    public var topic: String
    public var message: String
    public var timestamp: Date
}

public final class CloudKitManager: ObservableObject {
    public static let shared = CloudKitManager()
    
    // CloudKit Public Database (accessible by all players)
    private let container: CKContainer
    private let publicDB: CKDatabase
    
    @Published public var isCloudKitAvailable: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var cloudStatusMessage: String? = nil
    @Published public var communityFeedbackList: [CommunityFeedbackItem] = []
    
    private let leaderboardEndpointURL = "https://picklepark-sync.cf-watcher.workers.dev/wp_leaderboard_v1"
    private let feedbackEndpointURL = "https://picklepark-sync.cf-watcher.workers.dev/wp_feedback_v1"
    
    public init() {
        self.container = CKContainer(identifier: "iCloud.com.dominicsoriano.washingpark")
        self.publicDB = container.publicCloudDatabase
        
        Task {
            await checkAccountStatus()
            await fetchLatestCourtActivity()
            await fetchLeaderboardFromCloud()
            await fetchCommunityFeedback()
        }
    }
    
    /// Verifies iCloud account readiness
    public func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.isCloudKitAvailable = (status == .available)
            }
        } catch {
            await MainActor.run {
                self.isCloudKitAvailable = false
            }
        }
    }
    
    // MARK: - Court Activity CloudKit Sync
    
    public func pushCourtActivityToCloud(
        courts: Int,
        extra: Int,
        queue: Int,
        author: String?,
        notes: String?,
        c2State: String,
        c3State: String
    ) {
        let record = CKRecord(recordType: "CourtActivityRecord", recordID: CKRecord.ID(recordName: "washington_park_latest_status"))
        record["courtsInUse"] = courts as NSNumber
        record["extraCourts"] = extra as NSNumber
        record["inQueue"] = queue as NSNumber
        record["authorName"] = (author ?? "Community Player") as NSString
        record["extraNotes"] = (notes ?? "") as NSString
        record["court2State"] = c2State as NSString
        record["court3State"] = c3State as NSString
        record["timestamp"] = Date() as NSDate
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .allKeys
        modifyOp.modifyRecordsResultBlock = { [weak self] result in
            if case .success = result {
                DispatchQueue.main.async {
                    self?.cloudStatusMessage = "☁️ Synced to Apple CloudKit!"
                }
            }
        }
        publicDB.add(modifyOp)
    }
    
    public func fetchLatestCourtActivity() async {
        let recordID = CKRecord.ID(recordName: "washington_park_latest_status")
        do {
            let record = try await publicDB.record(for: recordID)
            await MainActor.run {
                self.applyActivityRecord(record)
            }
        } catch {
            // Silently fallback to local state
        }
    }
    
    private func applyActivityRecord(_ record: CKRecord) {
        guard let timestamp = record["timestamp"] as? Date else { return }
        let qManager = PickleQueueManager.shared
        let walkOn = WalkOnCourtManager.shared
        
        if qManager.queueStatus.pickleQueReportDate.timeIntervalSince1970 < 1000 ||
            timestamp > qManager.queueStatus.pickleQueReportDate {
            if let courts = record["courtsInUse"] as? Int { qManager.queueStatus.courtsInUse = courts }
            if let extra = record["extraCourts"] as? Int { qManager.queueStatus.extraCourts = extra }
            if let queue = record["inQueue"] as? Int { qManager.queueStatus.inQueue = queue }
            if let author = record["authorName"] as? String { qManager.queueStatus.lastAuthor = author }
            qManager.queueStatus.pickleQueReportDate = timestamp
            qManager.queueStatus.lastAppSyncDate = Date()
            qManager.saveLocalState()
        }
        
        // Check if the cloud record's timestamp is expired (from a prior day or past 11 PM)
        if WalkOnCourtStatus.isDateExpired(timestamp) {
            walkOn.status.court2State = .free
            walkOn.status.court3State = .free
            walkOn.save()
        } else if walkOn.status.lastReportDate.timeIntervalSince1970 < 1000 ||
                    timestamp >= walkOn.status.lastReportDate {
            // Cloud record is from today and not expired
            if let c2Str = record["court2State"] as? String, let c2 = CourtSideOccupancy(rawValue: c2Str) {
                walkOn.status.court2State = c2
            }
            if let c3Str = record["court3State"] as? String, let c3 = CourtSideOccupancy(rawValue: c3Str) {
                walkOn.status.court3State = c3
            }
            walkOn.status.lastReportDate = timestamp
            walkOn.save()
        }
        
        // Record real player report from CloudKit into usage & wait-time telemetry
        let deterministicId = "ck_live_\(Int(timestamp.timeIntervalSince1970))"
        CourtUsageAnalyticsService.shared.recordUsageSnapshot(
            id: deterministicId,
            timestamp: timestamp,
            courtsInUse: qManager.queueStatus.courtsInUse,
            peopleInQueue: qManager.queueStatus.inQueue,
            walkOnCourtsOpen: qManager.queueStatus.extraCourts,
            court2State: walkOn.status.court2State.rawValue,
            court3State: walkOn.status.court3State.rawValue,
            reporter: qManager.queueStatus.lastAuthor,
            pushToCloud: false
        )
    }
    
    // MARK: - Community Leaderboard CloudKit Sync
    
    public func pushUserToLeaderboard(user: LeaderboardUser) {
        let recordID = CKRecord.ID(recordName: "user_\(user.id)")
        let record = CKRecord(recordType: "LeaderboardUserRecord", recordID: recordID)
        record["userId"] = user.id as NSString
        record["name"] = user.name as NSString
        record["monthlyPoints"] = user.monthlyPoints as NSNumber
        record["allTimePoints"] = user.allTimePoints as NSNumber
        record["monthlyReports"] = user.monthlyReports as NSNumber
        record["allTimeReports"] = user.allTimeReports as NSNumber
        record["favoriteSnack"] = user.favoriteSnack as NSString
        record["avatarEmoji"] = user.avatarEmoji as NSString
        record["lastUpdated"] = Date() as NSDate
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .allKeys
        publicDB.add(modifyOp)
        
        // Also push to Cloudflare Worker KV so leaderboard syncs across all devices
        if let url = URL(string: leaderboardEndpointURL),
           let data = try? JSONEncoder().encode([user]) {
            Task {
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6.0)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = data
                if let (respData, resp) = try? await URLSession.shared.data(for: req),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let remoteUsers = try? JSONDecoder().decode([LeaderboardUser].self, from: respData) {
                    await MainActor.run {
                        LeaderboardManager.shared.mergeCloudUsers(remoteUsers)
                    }
                }
            }
        }
    }
    
    public func fetchLeaderboardFromCloud() async {
        // 1. Fetch from Cloudflare Worker KV
        if let url = URL(string: leaderboardEndpointURL) {
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6.0)
            req.httpMethod = "GET"
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
               let workerUsers = try? JSONDecoder().decode([LeaderboardUser].self, from: data),
               !workerUsers.isEmpty {
                await MainActor.run {
                    LeaderboardManager.shared.mergeCloudUsers(workerUsers)
                }
            }
        }
        
        // 2. Fetch from CloudKit
        let query = CKQuery(recordType: "LeaderboardUserRecord", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "monthlyPoints", ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query)
            var cloudUsers: [LeaderboardUser] = []
            
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    if let u = self.parseUser(from: record) {
                        cloudUsers.append(u)
                    }
                }
            }
            
            if !cloudUsers.isEmpty {
                await MainActor.run {
                    LeaderboardManager.shared.mergeCloudUsers(cloudUsers)
                }
            }
        } catch {
            // Fallback to local store
        }
    }
    
    private func parseUser(from record: CKRecord) -> LeaderboardUser? {
        guard let name = record["name"] as? String else { return nil }
        let userId = record["userId"] as? String ?? record.recordID.recordName
        let mPoints = record["monthlyPoints"] as? Int ?? 0
        let aPoints = record["allTimePoints"] as? Int ?? 0
        let mReports = record["monthlyReports"] as? Int ?? 0
        let aReports = record["allTimeReports"] as? Int ?? 0
        let snack = record["favoriteSnack"] as? String ?? "Cold Coconut Water & RXBar"
        let emoji = record["avatarEmoji"] as? String ?? "🎾"
        
        let isCurrent = userId == LeaderboardManager.shared.currentUser.id
        
        return LeaderboardUser(
            id: userId,
            name: name,
            monthlyPoints: mPoints,
            allTimePoints: aPoints,
            monthlyReports: mReports,
            allTimeReports: aReports,
            isCurrentUser: isCurrent,
            favoriteSnack: snack,
            avatarEmoji: emoji
        )
    }
    
    // MARK: - Community Feedback & Dev Board Sync
    
    public func submitFeedback(topic: String, message: String, author: String) async -> Bool {
        let cleanMessage = ContentModerator.shared.cleanse(message)
        let cleanAuthor = ContentModerator.shared.cleanse(author)
        let recordID = CKRecord.ID(recordName: "feedback_\(UUID().uuidString)")
        let record = CKRecord(recordType: "DevFeedbackRecord", recordID: recordID)
        record["topic"] = topic as NSString
        record["message"] = cleanMessage as NSString
        record["authorName"] = cleanAuthor as NSString
        record["timestamp"] = Date() as NSDate
        record["appVersion"] = "1.0.0" as NSString
        
        let newItem = CommunityFeedbackItem(
            id: recordID.recordName,
            authorName: cleanAuthor,
            topic: topic,
            message: cleanMessage,
            timestamp: Date()
        )
        
        // Push to Cloudflare Worker KV
        if let url = URL(string: feedbackEndpointURL) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode([newItem]) {
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6.0)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = data
                _ = try? await URLSession.shared.data(for: req)
            }
        }
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .allKeys
        publicDB.add(modifyOp)
        
        await MainActor.run {
            self.communityFeedbackList.insert(newItem, at: 0)
        }
        return true
    }
    
    public func fetchCommunityFeedback() async {
        var mergedById: [String: CommunityFeedbackItem] = [:]
        
        // 1. Pull from Cloudflare Worker KV
        if let url = URL(string: feedbackEndpointURL) {
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 6.0)
            req.httpMethod = "GET"
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
               let workerItems = try? decoder.decode([CommunityFeedbackItem].self, from: data) {
                for item in workerItems {
                    mergedById[item.id] = item
                }
            }
        }
        
        // 2. Pull from CloudKit
        let query = CKQuery(recordType: "DevFeedbackRecord", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query)
            for (_, result) in matchResults {
                if case .success(let record) = result {
                    if let message = record["message"] as? String,
                       let author = record["authorName"] as? String {
                        let topic = record["topic"] as? String ?? "General"
                        let timestamp = record["timestamp"] as? Date ?? Date()
                        let item = CommunityFeedbackItem(
                            id: record.recordID.recordName,
                            authorName: author,
                            topic: topic,
                            message: message,
                            timestamp: timestamp
                        )
                        mergedById[item.id] = item
                    }
                }
            }
        } catch {}
        
        let sorted = mergedById.values.sorted { $0.timestamp > $1.timestamp }
        if !sorted.isEmpty {
            await MainActor.run {
                self.communityFeedbackList = sorted
            }
        }
    }
}
