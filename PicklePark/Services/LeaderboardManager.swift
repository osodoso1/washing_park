import Foundation
import Combine
import Security
import SwiftUI

/// The player's id lives in iCloud Keychain so points follow their Apple ID to a new phone
/// and survive deleting the app. UserDefaults keeps a copy for older code paths.
enum PlayerIdentity {
    private static let keychainService = "com.dominicsoriano.washingpark.player"
    private static let keychainAccount = "player_id"
    static let defaultsKey = "picklepark_unique_device_user_id_v1"

    static func resolvePlayerId() -> String {
        if let synced = readKeychain() {
            UserDefaults.standard.set(synced, forKey: defaultsKey)
            return synced
        }
        // First launch of this build: keep the id this phone already had so its points carry over
        let existing = UserDefaults.standard.string(forKey: defaultsKey).flatMap { $0.isEmpty ? nil : $0 }
        let id = existing ?? "player_\(UUID().uuidString.prefix(12))"
        writeKeychain(id)
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
    }

    private static func readKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8),
              !id.isEmpty else {
            return nil
        }
        return id
    }

    private static func writeKeychain(_ id: String) {
        let match: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny
        ]
        SecItemDelete(match as CFDictionary)

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: Data(id.utf8)
        ]
        SecItemAdd(item as CFDictionary, nil)
    }
}

public final class LeaderboardManager: ObservableObject {
    public static let shared = LeaderboardManager()

    private let storageKey = "community_leaderboard_fresh_v3"
    private let monthKey = "leaderboard_active_month_key_v3"
    private let pendingAwardsKey = "leaderboard_pending_awards_v1"
    private let pendingMergeKey = "leaderboard_pending_merge_from_v1"

    @Published public var users: [LeaderboardUser]
    @Published public var selectedScope: LeaderboardScope = .thisMonth
    @Published public var currentMonthName: String = ""

    private let playerId: String
    /// Awards the server hasn't confirmed yet (no signal, app closed mid-upload); resent on the next sync
    private var pendingAwards: [LeaderboardAward]
    private var pendingMergeFrom: String?

    public init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        self.currentMonthName = formatter.string(from: Date())

        let playerId = PlayerIdentity.resolvePlayerId()
        
        var pendingAwards: [LeaderboardAward] = []
        if let data = UserDefaults.standard.data(forKey: pendingAwardsKey),
           let decoded = try? JSONDecoder().decode([LeaderboardAward].self, from: data) {
            pendingAwards = decoded
        }
        var pendingMergeFrom = UserDefaults.standard.string(forKey: pendingMergeKey)
        
        var loaded: [LeaderboardUser] = []
        if let savedData = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([LeaderboardUser].self, from: savedData) {
            loaded = decoded
        }
        
        if var me = loaded.first(where: { $0.isCurrentUser }) {
            if me.id != playerId {
                // This phone played under another id (an older build, or before iCloud Keychain synced
                // this player's id here). Fold those points into the synced player once.
                let oldId = me.id
                if me.allTimePoints > 0 || me.monthlyPoints > 0 {
                    pendingAwards.append(LeaderboardAward(
                        id: "merge_\(oldId)",
                        allTimePoints: me.allTimePoints,
                        allTimeReports: me.allTimeReports,
                        monthlyPoints: me.monthlyPoints,
                        monthlyReports: me.monthlyReports
                    ))
                    pendingMergeFrom = oldId
                }
                me = LeaderboardUser(
                    id: playerId,
                    name: me.name,
                    monthlyPoints: me.monthlyPoints,
                    allTimePoints: me.allTimePoints,
                    monthlyReports: me.monthlyReports,
                    allTimeReports: me.allTimeReports,
                    isCurrentUser: true,
                    favoriteSnack: me.favoriteSnack,
                    avatarEmoji: me.avatarEmoji
                )
            }
            if me.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || me.name == LeaderboardUser.legacyPlaceholderName {
                me.name = LeaderboardUser.defaultName(forId: playerId)
            }
            loaded.removeAll { $0.isCurrentUser || $0.id == playerId }
            loaded.insert(me, at: 0)
        } else {
            // Fresh clean start
            loaded.removeAll { $0.id == playerId }
            loaded.insert(
                LeaderboardUser(
                    id: playerId,
                    name: LeaderboardUser.defaultName(forId: playerId),
                    monthlyPoints: 0,
                    allTimePoints: 0,
                    monthlyReports: 0,
                    allTimeReports: 0,
                    isCurrentUser: true,
                    favoriteSnack: "Cold Coconut Water & RXBar",
                    avatarEmoji: "🎾"
                ),
                at: 0
            )
        }
        
        self.playerId = playerId
        self.pendingAwards = pendingAwards
        self.pendingMergeFrom = pendingMergeFrom
        self.users = loaded
        
        save()
        savePending()
        checkMonthlyReset()
    }
    
    public var currentUser: LeaderboardUser {
        users.first(where: { $0.isCurrentUser }) ?? LeaderboardUser(
            id: playerId,
            name: LeaderboardUser.defaultName(forId: playerId),
            monthlyPoints: 0,
            allTimePoints: 0,
            monthlyReports: 0,
            allTimeReports: 0,
            isCurrentUser: true
        )
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

    private var currentMonthKey: String {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    /// Checks if a new calendar month has started and resets monthly points while preserving all-time
    public func checkMonthlyReset() {
        let currentMonthKey = self.currentMonthKey
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
            pendingAwards.append(LeaderboardAward(
                id: "aw_\(UUID().uuidString)",
                allTimePoints: amount,
                allTimeReports: 1,
                monthlyPoints: amount,
                monthlyReports: 1
            ))
            savePending()
            save()

            // Push to the shared leaderboard
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
            let cleanName = nameValidation.cleanedText.isEmpty ? LeaderboardUser.defaultName(forId: users[index].id) : nameValidation.cleanedText
            let cleanSnack = snackValidation.cleanedText.isEmpty ? "Cold Coconut Water & RXBar" : snackValidation.cleanedText

            users[index].name = cleanName
            users[index].favoriteSnack = cleanSnack
            users[index].avatarEmoji = avatarEmoji
            save()

            // Push to the shared leaderboard
            CloudKitManager.shared.pushUserToLeaderboard(user: users[index])
            HapticFeedback.success()
            return (true, nil)
        }

        return (false, "Could not update user profile.")
    }

    // MARK: - Shared Leaderboard Sync

    /// This phone's player as uploaded to the shared leaderboard. Call on the main thread.
    func makeUpload() -> LeaderboardUpload {
        let me = currentUser
        return LeaderboardUpload(
            id: me.id,
            name: me.displayName,
            monthlyPoints: me.monthlyPoints,
            allTimePoints: me.allTimePoints,
            monthlyReports: me.monthlyReports,
            allTimeReports: me.allTimeReports,
            isCurrentUser: true,
            favoriteSnack: me.favoriteSnack,
            avatarEmoji: me.avatarEmoji,
            monthKey: currentMonthKey,
            awards: pendingAwards,
            mergedFrom: pendingMergeFrom
        )
    }

    /// The server stored this upload: its awards no longer need resending. Call on the main thread.
    func confirmUpload(_ upload: LeaderboardUpload) {
        let sentIds = Set(upload.awards.map(\.id))
        pendingAwards.removeAll { sentIds.contains($0.id) }
        if upload.mergedFrom == pendingMergeFrom {
            pendingMergeFrom = nil
        }
        savePending()
    }

    /// Applies the shared leaderboard. Other players are matched by id only (names aren't unique).
    /// Returns true when the server is missing or behind on this phone's player and it should upload.
    /// Call on the main thread.
    @discardableResult
    public func applyServerUsers(_ serverUsers: [LeaderboardUser]) -> Bool {
        let me = currentUser
        var needsUpload = !pendingAwards.isEmpty || pendingMergeFrom != nil

        if let serverMe = serverUsers.first(where: { $0.id == me.id }) {
            if serverMe.allTimePoints < me.allTimePoints ||
                serverMe.monthlyPoints < me.monthlyPoints ||
                serverMe.name != String(me.displayName.prefix(60)) ||
                serverMe.favoriteSnack != me.favoriteSnack ||
                serverMe.avatarEmoji != me.avatarEmoji {
                needsUpload = true
            }
            // Another device on the same Apple ID may have earned points: take the server's totals
            // plus anything this phone hasn't delivered yet, never going below what's shown here
            if let index = users.firstIndex(where: { $0.isCurrentUser }) {
                users[index].allTimePoints = max(users[index].allTimePoints, serverMe.allTimePoints + pendingAwards.reduce(0) { $0 + $1.allTimePoints })
                users[index].allTimeReports = max(users[index].allTimeReports, serverMe.allTimeReports + pendingAwards.reduce(0) { $0 + $1.allTimeReports })
                users[index].monthlyPoints = max(users[index].monthlyPoints, serverMe.monthlyPoints + pendingAwards.reduce(0) { $0 + $1.monthlyPoints })
                users[index].monthlyReports = max(users[index].monthlyReports, serverMe.monthlyReports + pendingAwards.reduce(0) { $0 + $1.monthlyReports })
            }
        } else if me.allTimePoints > 0 || me.name != LeaderboardUser.defaultName(forId: me.id) {
            needsUpload = true
        }

        for serverUser in serverUsers where serverUser.id != me.id {
            var remote = serverUser
            remote.isCurrentUser = false
            if let index = users.firstIndex(where: { $0.id == remote.id }) {
                users[index] = remote
            } else {
                users.append(remote)
            }
        }
        save()
        return needsUpload
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func savePending() {
        if let encoded = try? JSONEncoder().encode(pendingAwards) {
            UserDefaults.standard.set(encoded, forKey: pendingAwardsKey)
        }
        UserDefaults.standard.set(pendingMergeFrom, forKey: pendingMergeKey)
    }
}
