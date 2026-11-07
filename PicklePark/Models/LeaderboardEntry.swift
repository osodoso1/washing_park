import Foundation

public enum LeaderboardScope: String, CaseIterable, Identifiable {
    case thisMonth = "This Month"
    case allTime = "All-Time"
    
    public var id: String { self.rawValue }
}

public struct LeaderboardUser: Identifiable, Codable, Hashable {
    public let id: String
    public var name: String
    public var monthlyPoints: Int
    public var allTimePoints: Int
    public var monthlyReports: Int
    public var allTimeReports: Int
    public var isCurrentUser: Bool
    public var favoriteSnack: String
    public var avatarEmoji: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        monthlyPoints: Int,
        allTimePoints: Int,
        monthlyReports: Int,
        allTimeReports: Int,
        isCurrentUser: Bool = false,
        favoriteSnack: String = "Cold Coconut Water & RXBar",
        avatarEmoji: String = "🎾"
    ) {
        self.id = id
        self.name = name
        self.monthlyPoints = monthlyPoints
        self.allTimePoints = allTimePoints
        self.monthlyReports = monthlyReports
        self.allTimeReports = allTimeReports
        self.isCurrentUser = isCurrentUser
        self.favoriteSnack = favoriteSnack
        self.avatarEmoji = avatarEmoji
    }
    
    /// Older builds saved this placeholder as the player's own name, so it read as "me" on everyone's phone
    public static let legacyPlaceholderName = "Player (You)"

    /// Stable default for players who never set a name, e.g. "Player 3553" (the server uses the same rule)
    public static func defaultName(forId id: String) -> String {
        let raw = id.hasPrefix("player_") ? String(id.dropFirst("player_".count)) : id
        let suffix = raw.prefix(4).uppercased()
        return suffix.isEmpty ? "Player" : "Player \(suffix)"
    }

    /// Name shown on the leaderboard to everyone
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == Self.legacyPlaceholderName {
            return Self.defaultName(forId: id)
        }
        return trimmed
    }

    public func points(for scope: LeaderboardScope) -> Int {
        switch scope {
        case .thisMonth: return monthlyPoints
        case .allTime: return allTimePoints
        }
    }
    
    public func reports(for scope: LeaderboardScope) -> Int {
        switch scope {
        case .thisMonth: return monthlyReports
        case .allTime: return allTimeReports
        }
    }
    
    public var rankBadge: String {
        switch allTimePoints {
        case 120...: return "👑 Snack MVP"
        case 90..<120: return "🥇 Gold Scout"
        case 50..<90: return "🥈 Silver Scout"
        default: return "🥉 Bronze Helper"
        }
    }
}

/// One points award. It is uploaded with a unique id so the server adds it exactly once,
/// even when the phone retries or two devices share the same player.
public struct LeaderboardAward: Codable, Equatable {
    public let id: String
    public let allTimePoints: Int
    public let allTimeReports: Int
    public let monthlyPoints: Int
    public let monthlyReports: Int
}

/// What this phone uploads for its own player
public struct LeaderboardUpload: Encodable {
    public let id: String
    public let name: String
    public let monthlyPoints: Int
    public let allTimePoints: Int
    public let monthlyReports: Int
    public let allTimeReports: Int
    public let isCurrentUser: Bool
    public let favoriteSnack: String
    public let avatarEmoji: String
    public let monthKey: String
    public let awards: [LeaderboardAward]
    /// Previous player id on this phone whose points were folded into `id`
    public let mergedFrom: String?
}
