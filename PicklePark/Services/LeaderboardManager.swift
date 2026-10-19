import Foundation
import Combine
import SwiftUI

public final class LeaderboardManager: ObservableObject {
    public static let shared = LeaderboardManager()
    
    private let storageKey = "community_leaderboard_fresh_v3"
    private let monthKey = "leaderboard_active_month_key_v3"
    private let deviceUserIdKey = "picklepark_unique_device_user_id_v1"
    
    @Published public var users: [LeaderboardUser]
    @Published public var selectedScope: LeaderboardScope = .thisMonth
    @Published public var currentMonthName: String = ""
    
    public init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        self.currentMonthName = formatter.string(from: Date())
        
        let uniqueDeviceId: String = {
            if let existing = UserDefaults.standard.string(forKey: "picklepark_unique_device_user_id_v1"), !existing.isEmpty {
                return existing
            }
            let generated = "player_\(UUID().uuidString.prefix(12))"
            UserDefaults.standard.set(generated, forKey: "picklepark_unique_device_user_id_v1")
            return generated
        }()
        
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LeaderboardUser].self, from: savedData) {
            var loaded = decoded
            for i in 0..<loaded.count {
                if loaded[i].isCurrentUser && loaded[i].id == "local_user_player" {
                    loaded[i] = LeaderboardUser(
                        id: uniqueDeviceId,
                        name: loaded[i].name,
                        monthlyPoints: loaded[i].monthlyPoints,
                        allTimePoints: loaded[i].allTimePoints,
                        monthlyReports: loaded[i].monthlyReports,
                        allTimeReports: loaded[i].allTimeReports,
                        isCurrentUser: true,
                        favoriteSnack: loaded[i].favoriteSnack,
                        avatarEmoji: loaded[i].avatarEmoji
                    )
                }
            }
            self.users = loaded
        } else {
            // Fresh clean start with unique per-device ID
            self.users = [
                LeaderboardUser(
                    id: uniqueDeviceId,
                    name: "Player (You)",
                    monthlyPoints: 0,
                    allTimePoints: 0,
                    monthlyReports: 0,
                    allTimeReports: 0,
                    isCurrentUser: true,
                    favoriteSnack: "Cold Coconut Water & RXBar",
                    avatarEmoji: "🎾"
                )
            ]
        }
        
        checkMonthlyReset()
    }
    
    public var currentUser: LeaderboardUser {
        users.first(where: { $0.isCurrentUser }) ?? LeaderboardUser(name: "Player (You)", monthlyPoints: 0, allTimePoints: 0, monthlyReports: 0, allTimeReports: 0, isCurrentUser: true)
    }
    
    public func users(for scope: LeaderboardScope) -> [LeaderboardUser] {
        users.sorted { (u1, u2) -> Bool in
            let p1 = u1.points(for: scope)
            let p2 = u2.points(for: scope)
            if p1 == p2 {
                return u1.reports(for: scope) > u2.reports(for: scope)
            }
            return p1 > p2
        }
    }
    
    public func snackMVP(for scope: LeaderboardScope) -> LeaderboardUser? {
        users(for: scope).first
    }
    
    /// Checks if a new calendar month has started and resets monthly points while preserving all-time
    public func checkMonthlyReset() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let year = components.year, let month = components.month else { return }
        let currentMonthKey = "\(year)-\(month)"
        
        let savedMonthKey = UserDefaults.standard.string(forKey: monthKey)
        
        if savedMonthKey != nil && savedMonthKey != currentMonthKey {
            // Reset monthly scores
            for i in 0..<users.count {
                users[i].monthlyPoints = 0
                users[i].monthlyReports = 0
            }
            save()
        }
        
        UserDefaults.standard.set(currentMonthKey, forKey: monthKey)
    }
    
    public func addPoints(amount: Int, reason: String = "Court Report") {
        checkMonthlyReset()
        if let index = users.firstIndex(where: { $0.isCurrentUser }) {
            users[index].monthlyPoints += amount
            users[index].allTimePoints += amount
            users[index].monthlyReports += 1
            users[index].allTimeReports += 1
            save()
            
            // Push to CloudKit
            CloudKitManager.shared.pushUserToLeaderboard(user: users[index])
            HapticFeedback.success()
        }
    }
    
    public func updateUserProfile(name: String, favoriteSnack: String, avatarEmoji: String = "🎾") -> (success: Bool, message: String?) {
        let moderator = ContentModerator.shared
        
        let nameValidation = moderator.validateInput(name, fieldName: "Name")
        if !nameValidation.isValid {
            return (false, nameValidation.errorMessage)
        }
        
        let snackValidation = moderator.validateInput(favoriteSnack, fieldName: "Favorite Snack")
        if !snackValidation.isValid {
            return (false, snackValidation.errorMessage)
        }
        
        if let index = users.firstIndex(where: { $0.isCurrentUser }) {
            let cleanName = nameValidation.cleanedText.isEmpty ? "Player (You)" : nameValidation.cleanedText
            let cleanSnack = snackValidation.cleanedText.isEmpty ? "Cold Coconut Water & RXBar" : snackValidation.cleanedText
            
            users[index].name = cleanName
            users[index].favoriteSnack = cleanSnack
            users[index].avatarEmoji = avatarEmoji
            save()
            
            // Push to CloudKit
            CloudKitManager.shared.pushUserToLeaderboard(user: users[index])
            HapticFeedback.success()
            return (true, nil)
        }
        
        return (false, "Could not update user profile.")
    }
    
    public func mergeCloudUsers(_ cloudUsers: [LeaderboardUser]) {
        for cloudUser in cloudUsers {
            if let index = users.firstIndex(where: { $0.id == cloudUser.id || $0.name.lowercased() == cloudUser.name.lowercased() }) {
                if !users[index].isCurrentUser {
                    users[index] = cloudUser
                }
            } else {
                users.append(cloudUser)
            }
        }
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
