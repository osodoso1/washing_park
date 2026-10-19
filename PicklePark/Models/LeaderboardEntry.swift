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
