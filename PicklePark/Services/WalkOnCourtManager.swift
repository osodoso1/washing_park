import Foundation
import Combine
import SwiftUI

public final class WalkOnCourtManager: ObservableObject {
    public static let shared = WalkOnCourtManager()
    
    private let storageKey = "walk_on_courts_sides_status_v4"
    
    @Published public var status: WalkOnCourtStatus
    
    public init() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(WalkOnCourtStatus.self, from: savedData) {
            var current = decoded
            if current.lastReportDate.timeIntervalSince1970 > 1000 && current.isExpiredBy11PM {
                current = WalkOnCourtStatus(court2State: .free, court3State: .free, lastReportDate: Date(timeIntervalSince1970: 0), lastReporterName: nil)
            }
            self.status = current
        } else {
            self.status = WalkOnCourtStatus(court2State: .free, court3State: .free, lastReportDate: Date(timeIntervalSince1970: 0), lastReporterName: nil)
        }
        check11PMReset()
    }
    
    public func check11PMReset() {
        if status.lastReportDate.timeIntervalSince1970 > 1000 && status.isExpiredBy11PM {
            status = WalkOnCourtStatus(court2State: .free, court3State: .free, lastReportDate: Date(timeIntervalSince1970: 0), lastReporterName: nil)
            save()
        }
    }
    
    public func resetToFree() {
        status = WalkOnCourtStatus(court2State: .free, court3State: .free, lastReportDate: Date(), lastReporterName: nil)
        save()
    }
    
    public func save() {
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    public func syncFromExtraCount(_ extra: Int, reporter: String? = nil) {
        let clamped = min(4, max(0, extra))
        switch clamped {
        case 4:
            status.court2State = .free
            status.court3State = .free
        case 3:
            status.court2State = .free
            status.court3State = .oneSideTaken
        case 2:
            status.court2State = .free
            status.court3State = .bothSidesTaken
        case 1:
            status.court2State = .oneSideTaken
            status.court3State = .bothSidesTaken
        default:
            status.court2State = .bothSidesTaken
            status.court3State = .bothSidesTaken
        }
        status.lastReportDate = Date()
        if let r = reporter { status.lastReporterName = r }
        save()
    }
    
    public func setCourt2State(_ state: CourtSideOccupancy, reporter: String? = nil) {
        status.court2State = state
        status.lastReportDate = Date()
        if let r = reporter { status.lastReporterName = r }
        save()
        
        let qStatus = PickleQueueManager.shared.queueStatus
        let openExtra = status.court2State.pickleballCourtsOpen + status.court3State.pickleballCourtsOpen
        PickleQueueManager.shared.queueStatus.extraCourts = openExtra
        PickleQueueManager.shared.queueStatus.pickleQueReportDate = Date()
        PickleQueueManager.shared.saveLocalState()
        ParkNotificationManager.shared.markLocalQueueSubmission(
            timestamp: PickleQueueManager.shared.queueStatus.pickleQueReportDate.timeIntervalSince1970
        )
        
        CloudKitManager.shared.pushCourtActivityToCloud(
            courts: qStatus.courtsInUse,
            extra: openExtra,
            queue: qStatus.inQueue,
            author: reporter,
            notes: nil,
            c2State: status.court2State.rawValue,
            c3State: status.court3State.rawValue
        )
        CommunityCloudService.shared.broadcastToCloud()
        
        CourtUsageAnalyticsService.shared.recordUsageSnapshot(
            courtsInUse: qStatus.courtsInUse,
            peopleInQueue: qStatus.inQueue,
            walkOnCourtsOpen: openExtra,
            court2State: status.court2State.rawValue,
            court3State: status.court3State.rawValue,
            reporter: reporter
        )
        
        let pointsCheck = SubmissionRateLimiter.shared.shouldAwardPoints()
        if pointsCheck.eligible {
            SubmissionRateLimiter.shared.recordPointsAwarded()
            LeaderboardManager.shared.addPoints(amount: 5, reason: "Court 2 Report")
        }
        HapticFeedback.success()
    }
    
    public func setCourt3State(_ state: CourtSideOccupancy, reporter: String? = nil) {
        status.court3State = state
        status.lastReportDate = Date()
        if let r = reporter { status.lastReporterName = r }
        save()
        
        let qStatus = PickleQueueManager.shared.queueStatus
        let openExtra = status.court2State.pickleballCourtsOpen + status.court3State.pickleballCourtsOpen
        PickleQueueManager.shared.queueStatus.extraCourts = openExtra
        PickleQueueManager.shared.queueStatus.pickleQueReportDate = Date()
        PickleQueueManager.shared.saveLocalState()
        ParkNotificationManager.shared.markLocalQueueSubmission(
            timestamp: PickleQueueManager.shared.queueStatus.pickleQueReportDate.timeIntervalSince1970
        )
        
        CloudKitManager.shared.pushCourtActivityToCloud(
            courts: qStatus.courtsInUse,
            extra: openExtra,
            queue: qStatus.inQueue,
            author: reporter,
            notes: nil,
            c2State: status.court2State.rawValue,
            c3State: status.court3State.rawValue
        )
        CommunityCloudService.shared.broadcastToCloud()
        
        CourtUsageAnalyticsService.shared.recordUsageSnapshot(
            courtsInUse: qStatus.courtsInUse,
            peopleInQueue: qStatus.inQueue,
            walkOnCourtsOpen: openExtra,
            court2State: status.court2State.rawValue,
            court3State: status.court3State.rawValue,
            reporter: reporter
        )
        
        let pointsCheck = SubmissionRateLimiter.shared.shouldAwardPoints()
        if pointsCheck.eligible {
            SubmissionRateLimiter.shared.recordPointsAwarded()
            LeaderboardManager.shared.addPoints(amount: 5, reason: "Court 3 Report")
        }
        HapticFeedback.success()
    }
}
