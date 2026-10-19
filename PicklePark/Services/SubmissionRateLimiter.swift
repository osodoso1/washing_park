import Foundation
import Combine
import SwiftUI

public final class SubmissionRateLimiter: ObservableObject {
    public static let shared = SubmissionRateLimiter()
    
    private let lastPointsAwardedKey = "picklepark_last_points_awarded_timestamp"
    
    /// Points cooldown window: 4 hours (14,400 seconds)
    public let pointsCooldownInterval: TimeInterval = 4 * 3600
    
    @Published public var lastPointsAwardedDate: Date?
    
    public init() {
        if let timestamp = UserDefaults.standard.object(forKey: lastPointsAwardedKey) as? Date {
            self.lastPointsAwardedDate = timestamp
        }
    }
    
    /// Checks if the user is eligible to earn points on this submission (Allowed once every 4 hours)
    public func shouldAwardPoints() -> (eligible: Bool, remainingSeconds: TimeInterval, message: String?) {
        if let lastDate = lastPointsAwardedDate {
            let elapsed = Date().timeIntervalSince(lastDate)
            if elapsed < pointsCooldownInterval {
                let remaining = pointsCooldownInterval - elapsed
                let formattedTime = formatRemainingTime(remaining)
                return (
                    eligible: false,
                    remainingSeconds: remaining,
                    message: "Points cooldown: Next +10 pts available in \(formattedTime)."
                )
            }
        }
        return (eligible: true, remainingSeconds: 0, message: "Earn +10 Leaderboard Points!")
    }
    
    /// Records points awarded timestamp
    public func recordPointsAwarded() {
        let now = Date()
        lastPointsAwardedDate = now
        UserDefaults.standard.set(now, forKey: lastPointsAwardedKey)
    }
    
    /// Formats remaining cooldown time (e.g. "2h 45m" or "32m")
    public func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(ceil(seconds / 60.0))
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(max(1, totalMinutes))m"
        }
    }
}
