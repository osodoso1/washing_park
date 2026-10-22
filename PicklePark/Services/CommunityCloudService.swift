import Foundation
import Combine
import SwiftUI

/// Prior update item serialized with Unix Epoch seconds for cross-platform JSON compatibility
public struct CloudPriorUpdate: Codable {
    public var id: String
    public var courts: Int
    public var extra: Int
    public var queue: Int
    public var authorName: String?
    public var extraNotes: String?
    public var timestamp: Double
    
    public init(
        id: String = UUID().uuidString,
        courts: Int,
        extra: Int,
        queue: Int,
        authorName: String? = nil,
        extraNotes: String? = nil,
        timestamp: Double
    ) {
        self.id = id
        self.courts = courts
        self.extra = extra
        self.queue = queue
        self.authorName = authorName
        self.extraNotes = extraNotes
        self.timestamp = timestamp
    }
}

/// Payload for live Washington Park crowdsourced activity synced across all players' devices
public struct ParkCloudSyncPayload: Codable {
    public var courtsInUse: Int
    public var extraCourts: Int
    public var inQueue: Int
    public var lastAuthor: String?
    public var extraNotes: String?
    public var reportTimestamp: Double // Unix Epoch seconds
    
    // Walk-On Sides Status (Courts 2 & 3)
    public var court2State: String
    public var court3State: String
    public var priorUpdates: [CloudPriorUpdate]?
    
    public init(
        courtsInUse: Int,
        extraCourts: Int,
        inQueue: Int,
        lastAuthor: String? = nil,
        extraNotes: String? = nil,
        reportTimestamp: Double = Date().timeIntervalSince1970,
        court2State: String = "Free",
        court3State: String = "Free",
        priorUpdates: [CloudPriorUpdate]? = nil
    ) {
        self.courtsInUse = courtsInUse
        self.extraCourts = extraCourts
        self.inQueue = inQueue
        self.lastAuthor = lastAuthor
        self.extraNotes = extraNotes
        self.reportTimestamp = reportTimestamp
        self.court2State = court2State
        self.court3State = court3State
        self.priorUpdates = priorUpdates
    }
}

public final class CommunityCloudService: ObservableObject {
    public static let shared = CommunityCloudService()
    
    // Shared Washington Park Community Cloud Endpoint (Cloudflare Workers + KV)
    public static let baseWorkerURL = "https://picklepark-sync.cf-watcher.workers.dev"
    private let cloudEndpointURL = "https://picklepark-sync.cf-watcher.workers.dev/wp_live_feed_v1"
    
    @Published public var isSyncing: Bool = false
    @Published public var lastCloudSyncDate: Date? = nil
    @Published public var syncBannerMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        Task {
            await pullLatestFromCloud()
        }
    }
    
    /// Pulls latest crowdsourced court activity & walk-on status from the cloud
    public func pullLatestFromCloud() async {
        guard let url = URL(string: cloudEndpointURL) else { return }
        
        await MainActor.run { self.isSyncing = true }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let payload = try? JSONDecoder.pickleParkCloudDecoder.decode(ParkCloudSyncPayload.self, from: data) {
                    await MainActor.run {
                        self.applyCloudPayload(payload)
                        self.lastCloudSyncDate = Date()
                        self.isSyncing = false
                    }
                    return
                }
            }
        } catch {
            // Silently fallback to local state if offline
        }
        
        await MainActor.run {
            self.isSyncing = false
        }
    }
    
    /// Broadcasts local court activity & walk-on update to the community cloud
    public func broadcastToCloud() {
        guard let url = URL(string: cloudEndpointURL) else { return }
        
        let qStatus = PickleQueueManager.shared.queueStatus
        let walkOn = WalkOnCourtManager.shared.status
        let priorCloud = qStatus.priorUpdates.prefix(2).map {
            CloudPriorUpdate(
                id: $0.id,
                courts: $0.courts,
                extra: $0.extra,
                queue: $0.queue,
                authorName: $0.authorName,
                extraNotes: $0.extraNotes,
                timestamp: $0.timestamp.timeIntervalSince1970
            )
        }
        
        let payload = ParkCloudSyncPayload(
            courtsInUse: qStatus.courtsInUse,
            extraCourts: qStatus.extraCourts,
            inQueue: qStatus.inQueue,
            lastAuthor: qStatus.lastAuthor,
            extraNotes: qStatus.priorUpdates.first?.extraNotes,
            reportTimestamp: qStatus.pickleQueReportDate.timeIntervalSince1970,
            court2State: walkOn.court2State.rawValue,
            court3State: walkOn.court3State.rawValue,
            priorUpdates: priorCloud
        )
        
        guard let jsonData = try? JSONEncoder().encode(payload) else { return }
        
        Task {
            for attempt in 1...3 {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 12.0)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                   let returnedPayload = try? JSONDecoder.pickleParkCloudDecoder.decode(ParkCloudSyncPayload.self, from: data) {
                    await MainActor.run {
                        self.applyCloudPayload(returnedPayload)
                        self.lastCloudSyncDate = Date()
                    }
                    return
                }
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                }
            }
        }
    }
    
    private func applyCloudPayload(_ payload: ParkCloudSyncPayload) {
        let qManager = PickleQueueManager.shared
        let cloudDate = Date(timeIntervalSince1970: payload.reportTimestamp)
        guard payload.reportTimestamp > 1000 else { return }
        
        // Check if this is a brand-new remote queue update to notify the user
        ParkNotificationManager.shared.evaluateIncomingQueuePayload(payload)
        
        // Apply whenever cloud update is newer than or equal to local report (or local is uninitialized)
        if qManager.queueStatus.pickleQueReportDate.timeIntervalSince1970 < 1000 ||
            cloudDate >= qManager.queueStatus.pickleQueReportDate {
            qManager.queueStatus.courtsInUse = payload.courtsInUse
            qManager.queueStatus.extraCourts = payload.extraCourts
            qManager.queueStatus.inQueue = payload.inQueue
            qManager.queueStatus.lastAuthor = payload.lastAuthor
            qManager.queueStatus.pickleQueReportDate = cloudDate
            qManager.queueStatus.lastAppSyncDate = Date()
            
            if let cloudPriors = payload.priorUpdates, !cloudPriors.isEmpty {
                qManager.queueStatus.priorUpdates = cloudPriors.prefix(2).map {
                    PickleQueUpdate(
                        id: $0.id,
                        courts: $0.courts,
                        extra: $0.extra,
                        queue: $0.queue,
                        authorName: $0.authorName,
                        extraNotes: $0.extraNotes,
                        timestamp: Date(timeIntervalSince1970: $0.timestamp)
                    )
                }
            }
            qManager.saveLocalState()
            
            let deterministicId = "cf_live_\(Int(payload.reportTimestamp))"
            CourtUsageAnalyticsService.shared.recordUsageSnapshot(
                id: deterministicId,
                timestamp: cloudDate,
                courtsInUse: payload.courtsInUse,
                peopleInQueue: payload.inQueue,
                walkOnCourtsOpen: payload.extraCourts,
                court2State: payload.court2State,
                court3State: payload.court3State,
                reporter: payload.lastAuthor,
                pushToCloud: false
            )
        }
        
        // Apply walk-on states if valid
        let walkOnManager = WalkOnCourtManager.shared
        if WalkOnCourtStatus.isDateExpired(cloudDate) {
            walkOnManager.status.court2State = .free
            walkOnManager.status.court3State = .free
            walkOnManager.save()
        } else if walkOnManager.status.lastReportDate.timeIntervalSince1970 < 1000 ||
                    cloudDate >= walkOnManager.status.lastReportDate {
            if let c2 = CourtSideOccupancy(rawValue: payload.court2State) {
                walkOnManager.status.court2State = c2
            }
            if let c3 = CourtSideOccupancy(rawValue: payload.court3State) {
                walkOnManager.status.court3State = c3
            }
            walkOnManager.status.lastReportDate = cloudDate
            walkOnManager.status.lastReporterName = payload.lastAuthor
            walkOnManager.save()
        }
    }
    
    // MARK: - Auto-Clipboard Ingestion Bridge
    
    /// Checks system pasteboard for PickleQue / Court activity text and auto-ingests it
    @MainActor
    public func checkAndIngestClipboard() -> Bool {
        guard let clipboardText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            return false
        }
        
        // Check if clipboard contains PickleQue or court patterns
        // E.g., "Courts: 4, Extra: 2, Queue: 12", "4 courts in use, 14 waiting", "4/0/14", etc.
        if let parsed = parseCourtText(clipboardText) {
            let lastStored = PickleQueueManager.shared.queueStatus
            
            // Avoid duplicate ingestion if exact same numbers and ingested within last 10 mins
            if parsed.courts == lastStored.courtsInUse &&
                parsed.extra == lastStored.extraCourts &&
                parsed.queue == lastStored.inQueue &&
                Date().timeIntervalSince(lastStored.pickleQueReportDate) < 300 {
                return false
            }
            
            PickleQueueManager.shared.submitActivity(
                courts: parsed.courts,
                extra: parsed.extra,
                queue: parsed.queue,
                author: parsed.author ?? "Auto-Sync",
                extraNotes: "Auto-synced from Clipboard"
            )
            
            broadcastToCloud()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                syncBannerMessage = "🟢 Auto-synced from PickleQue clipboard!"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.syncBannerMessage = nil
                }
            }
            
            return true
        }
        
        return false
    }
    
    private struct ParsedCourtInfo {
        let courts: Int
        let extra: Int
        let queue: Int
        let author: String?
    }
    
    private func parseCourtText(_ text: String) -> ParsedCourtInfo? {
        let lower = text.lowercased()
        
        // 1. Pattern: "Courts: X, Extra: Y, Queue: Z" or "X courts in use, Y extra, Z in queue"
        var courts: Int? = nil
        var extra: Int? = 0
        var queue: Int? = nil
        
        // Regex search for courts in use
        if let courtsMatch = regexMatch(pattern: #"(\d+)\s*(?:courts?|perm|in use)"#, in: lower) {
            courts = Int(courtsMatch)
        } else if let cMatch = regexMatch(pattern: #"courts?:\s*(\d+)"#, in: lower) {
            courts = Int(cMatch)
        }
        
        // Regex search for extra courts
        if let extraMatch = regexMatch(pattern: #"(\d+)\s*(?:extra|unreserved)"#, in: lower) {
            extra = Int(extraMatch)
        } else if let eMatch = regexMatch(pattern: #"extra:\s*(\d+)"#, in: lower) {
            extra = Int(eMatch)
        }
        
        // Regex search for queue / waiting
        if let queueMatch = regexMatch(pattern: #"(\d+)\s*(?:in queue|waiting|in line|queue)"#, in: lower) {
            queue = Int(queueMatch)
        } else if let qMatch = regexMatch(pattern: #"queue:\s*(\d+)"#, in: lower) {
            queue = Int(qMatch)
        }
        
        // Format fallback: "4 / 2 / 14"
        if courts == nil && queue == nil {
            let parts = lower.components(separatedBy: CharacterSet(charactersIn: ",/-| \n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .compactMap { Int($0) }
            
            if parts.count >= 2 {
                courts = parts[0]
                queue = parts.count >= 3 ? parts[2] : parts[1]
                if parts.count >= 3 { extra = parts[1] }
            }
        }
        
        if let c = courts, let q = queue {
            return ParsedCourtInfo(
                courts: min(4, max(0, c)),
                extra: min(2, max(0, extra ?? 0)),
                queue: max(0, q),
                author: "PickleQue Sync"
            )
        }
        
        return nil
    }
    
    private func regexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
            if let targetRange = Range(match.range(at: 1), in: text) {
                return String(text[targetRange])
            }
        }
        return nil
    }
}
