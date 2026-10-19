import Foundation
import Combine
import SwiftUI

public final class PickleQueueManager: ObservableObject {
    public static let shared = PickleQueueManager()
    
    private let queueStorageKey = "pickleque_live_status_v8"
    
    @Published public var queueStatus: QueueStatus
    
    public init() {
        if let savedData = UserDefaults.standard.data(forKey: queueStorageKey),
           let decoded = try? JSONDecoder().decode(QueueStatus.self, from: savedData) {
            var status = decoded
            status.priorUpdates = Array(status.priorUpdates.prefix(2))
            self.queueStatus = status
        } else {
            self.queueStatus = QueueStatus(
                courtsInUse: 4,
                extraCourts: 0,
                inQueue: 0,
                lastAuthor: "Dominic",
                pickleQueReportDate: Date(),
                lastAppSyncDate: Date(),
                priorUpdates: []
            )
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(queueStatus) {
            UserDefaults.standard.set(encoded, forKey: queueStorageKey)
        }
    }
    
    public func submitActivity(courts: Int, extra: Int, queue: Int, author: String? = nil, extraNotes: String? = nil) {
        let moderator = ContentModerator.shared
        
        let cleanedAuthor: String? = {
            if let a = author?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
                return moderator.cleanse(a)
            }
            return nil
        }()
        
        let cleanedNotes: String? = {
            if let n = extraNotes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return moderator.cleanse(n)
            }
            return nil
        }()
        
        let normalizedCourts = min(4, max(0, courts))
        let normalizedExtra = min(4, max(0, extra))
        // Wait time & queue only apply once all 4 courts are filled
        let normalizedQueue = normalizedCourts < 4 ? 0 : max(0, queue)
        
        let newUpdate = PickleQueUpdate(
            courts: normalizedCourts,
            extra: normalizedExtra,
            queue: normalizedQueue,
            authorName: cleanedAuthor,
            extraNotes: cleanedNotes,
            timestamp: Date()
        )
        
        queueStatus.priorUpdates.insert(newUpdate, at: 0)
        // Keep ONLY the last 2 prior updates
        queueStatus.priorUpdates = Array(queueStatus.priorUpdates.prefix(2))
        
        queueStatus.courtsInUse = normalizedCourts
        queueStatus.extraCourts = normalizedExtra
        queueStatus.inQueue = normalizedQueue
        queueStatus.lastAuthor = cleanedAuthor
        queueStatus.pickleQueReportDate = Date()
        queueStatus.lastAppSyncDate = Date()
        
        save()
        
        // Sync Walk-On Court Manager states with submitted extra count
        WalkOnCourtManager.shared.syncFromExtraCount(queueStatus.extraCourts, reporter: cleanedAuthor)
        
        // Broadcast to Apple CloudKit & Community Cloud
        let walkOn = WalkOnCourtManager.shared.status
        CloudKitManager.shared.pushCourtActivityToCloud(
            courts: queueStatus.courtsInUse,
            extra: queueStatus.extraCourts,
            queue: queueStatus.inQueue,
            author: cleanedAuthor,
            notes: cleanedNotes,
            c2State: walkOn.court2State.rawValue,
            c3State: walkOn.court3State.rawValue
        )
        CommunityCloudService.shared.broadcastToCloud()
        
        // Record Usage & Wait Time Telemetry for City of Burlingame Analytics
        CourtUsageAnalyticsService.shared.recordUsageSnapshot(
            courtsInUse: queueStatus.courtsInUse,
            peopleInQueue: queueStatus.inQueue,
            walkOnCourtsOpen: queueStatus.extraCourts,
            court2State: walkOn.court2State.rawValue,
            court3State: walkOn.court3State.rawValue,
            reporter: cleanedAuthor
        )
        
        // Award points on leaderboard once every 4 hours
        let pointsCheck = SubmissionRateLimiter.shared.shouldAwardPoints()
        if pointsCheck.eligible {
            SubmissionRateLimiter.shared.recordPointsAwarded()
            LeaderboardManager.shared.addPoints(amount: 10, reason: "Court Status Report")
        }
        HapticFeedback.success()
    }
    
    public func refreshActivity() {
        queueStatus.lastAppSyncDate = Date()
        save()
        Task {
            await CloudKitManager.shared.fetchLatestCourtActivity()
            await CommunityCloudService.shared.pullLatestFromCloud()
            await CourtUsageAnalyticsService.shared.fetchCloudTelemetryLogs()
        }
        HapticFeedback.light()
    }
}
