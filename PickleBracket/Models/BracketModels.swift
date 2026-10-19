import Foundation
import SwiftData
import SwiftUI

// MARK: - Tournament Enums

public enum TournamentFormat: String, Codable, CaseIterable, Identifiable {
    case singleElimination = "Single Elimination"
    case doubleElimination = "Double Elimination"
    case roundRobinPool = "Round Robin + Playoffs"
    case kingOfTheCourt = "King of the Court (Rotating)"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .singleElimination: return "point.topleft.down.curvedto.point.filled.bottomright.up"
        case .doubleElimination: return "arrow.triangle.branch"
        case .roundRobinPool: return "tablecells.fill"
        case .kingOfTheCourt: return "crown.fill"
        }
    }
    
    public var description: String {
        switch self {
        case .singleElimination: return "Standard knockout tree bracket. Win and advance to the championship!"
        case .doubleElimination: return "Winners and consolation bracket. Teams must lose twice to be eliminated."
        case .roundRobinPool: return "All teams play in pool play, then top seeds advance to single elimination."
        case .kingOfTheCourt: return "Individual rotating doubles with live leaderboard advancing top 4 to gold."
        }
    }
}

public enum TournamentScoring: String, Codable, CaseIterable, Identifiable {
    case sideOut = "Side-Out (Traditional)"
    case rally = "Rally Scoring (MLP)"
    case dreamBreaker = "DreamBreaker (4v4 Singles)"
    
    public var id: String { self.rawValue }
    
    public var shortName: String {
        switch self {
        case .sideOut: return "Side-Out"
        case .rally: return "Rally (MLP)"
        case .dreamBreaker: return "DreamBreaker"
        }
    }
    
    public var defaultTargetScore: Int {
        switch self {
        case .sideOut: return 11
        case .rally: return 15
        case .dreamBreaker: return 21
        }
    }
    
    public var description: String {
        switch self {
        case .sideOut: return "Traditional pickleball rules: only the serving team scores points. Play to 11 or 15, win by 2."
        case .rally: return "Point scored on every single rally. Fast-paced modern MLP format to 15 or 21, win by 2."
        case .dreamBreaker: return "Official 4v4 team tiebreaker: 1v1 singles rotation every 4 rallies up to 21 points!"
        }
    }
}

public enum TournamentStage: String, Codable {
    case setup = "Setup"
    case inProgress = "In Progress"
    case completed = "Completed"
    case podium = "Podium"
}

// MARK: - SwiftData Models

@Model
public final class PlayerModel {
    public var id: String
    public var name: String
    public var duprId: String
    public var duprRating: Double
    public var duprReliability: Double // e.g. 0.85 half-life
    public var avatarEmoji: String
    public var wins: Int
    public var losses: Int
    public var pointsWon: Int
    public var pointsLost: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        duprId: String = "",
        duprRating: Double = 3.5,
        duprReliability: Double = 0.80,
        avatarEmoji: String = "🎾",
        wins: Int = 0,
        losses: Int = 0,
        pointsWon: Int = 0,
        pointsLost: Int = 0
    ) {
        self.id = id
        self.name = name
        self.duprId = duprId
        self.duprRating = duprRating
        self.duprReliability = duprReliability
        self.avatarEmoji = avatarEmoji
        self.wins = wins
        self.losses = losses
        self.pointsWon = pointsWon
        self.pointsLost = pointsLost
    }
    
    public var pointDifferential: Int {
        return pointsWon - pointsLost
    }
}

@Model
public final class TeamModel {
    public var id: String
    public var name: String
    public var p1Name: String
    public var p1DUPR: Double
    public var p2Name: String
    public var p2DUPR: Double
    public var seedIndex: Int
    public var wins: Int
    public var losses: Int
    public var pointsWon: Int
    public var pointsLost: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        p1Name: String,
        p1DUPR: Double = 3.5,
        p2Name: String = "",
        p2DUPR: Double = 3.5,
        seedIndex: Int = 1,
        wins: Int = 0,
        losses: Int = 0,
        pointsWon: Int = 0,
        pointsLost: Int = 0
    ) {
        self.id = id
        self.name = name
        self.p1Name = p1Name
        self.p1DUPR = p1DUPR
        self.p2Name = p2Name
        self.p2DUPR = p2DUPR
        self.seedIndex = seedIndex
        self.wins = wins
        self.losses = losses
        self.pointsWon = pointsWon
        self.pointsLost = pointsLost
    }
    
    public var combinedDUPR: Double {
        if p2Name.isEmpty { return p1DUPR }
        return (p1DUPR + p2DUPR) / 2.0
    }
    
    public var displayMembers: String {
        if p2Name.isEmpty { return p1Name }
        return "\(p1Name) & \(p2Name)"
    }
    
    public var pointDifferential: Int {
        return pointsWon - pointsLost
    }
}

@Model
public final class BracketMatchModel {
    public var id: String
    public var tournamentId: String
    public var roundIndex: Int // 0: Round of 16/Quarters, 1: Semis, 2: Finals
    public var matchIndex: Int // Position in that round column
    public var title: String
    public var teamAId: String?
    public var teamAName: String
    public var teamAMembers: String
    public var teamADUPR: Double
    public var teamBId: String?
    public var teamBName: String
    public var teamBMembers: String
    public var teamBDUPR: Double
    public var scoreA: Int
    public var scoreB: Int
    public var isFinished: Bool
    public var winnerId: String?
    public var winnerName: String?
    public var nextMatchId: String?
    public var nextMatchSlot: String? // "A" or "B"
    public var courtNumber: Int
    public var isLosersBracket: Bool
    
    public init(
        id: String = UUID().uuidString,
        tournamentId: String,
        roundIndex: Int,
        matchIndex: Int,
        title: String,
        teamAId: String? = nil,
        teamAName: String = "TBD",
        teamAMembers: String = "",
        teamADUPR: Double = 3.5,
        teamBId: String? = nil,
        teamBName: String = "TBD",
        teamBMembers: String = "",
        teamBDUPR: Double = 3.5,
        scoreA: Int = 0,
        scoreB: Int = 0,
        isFinished: Bool = false,
        winnerId: String? = nil,
        winnerName: String? = nil,
        nextMatchId: String? = nil,
        nextMatchSlot: String? = nil,
        courtNumber: Int = 1,
        isLosersBracket: Bool = false
    ) {
        self.id = id
        self.tournamentId = tournamentId
        self.roundIndex = roundIndex
        self.matchIndex = matchIndex
        self.title = title
        self.teamAId = teamAId
        self.teamAName = teamAName
        self.teamAMembers = teamAMembers
        self.teamADUPR = teamADUPR
        self.teamBId = teamBId
        self.teamBName = teamBName
        self.teamBMembers = teamBMembers
        self.teamBDUPR = teamBDUPR
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.isFinished = isFinished
        self.winnerId = winnerId
        self.winnerName = winnerName
        self.nextMatchId = nextMatchId
        self.nextMatchSlot = nextMatchSlot
        self.courtNumber = courtNumber
        self.isLosersBracket = isLosersBracket
    }
}

@Model
public final class TournamentModel {
    public var id: String
    public var title: String
    public var formatRaw: String
    public var scoringRaw: String
    public var targetScore: Int
    public var teamCount: Int
    public var stageRaw: String
    public var createdAt: Date
    public var goldWinnerName: String?
    public var silverWinnerName: String?
    public var bronzeWinnerName: String?
    
    @Relationship(deleteRule: .cascade) public var teams: [TeamModel] = []
    @Relationship(deleteRule: .cascade) public var matches: [BracketMatchModel] = []
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        format: TournamentFormat = .singleElimination,
        scoring: TournamentScoring = .sideOut,
        targetScore: Int = 11,
        teamCount: Int = 8,
        stage: TournamentStage = .setup,
        createdAt: Date = Date(),
        goldWinnerName: String? = nil,
        silverWinnerName: String? = nil,
        bronzeWinnerName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.formatRaw = format.rawValue
        self.scoringRaw = scoring.rawValue
        self.targetScore = targetScore
        self.teamCount = teamCount
        self.stageRaw = stage.rawValue
        self.createdAt = createdAt
        self.goldWinnerName = goldWinnerName
        self.silverWinnerName = silverWinnerName
        self.bronzeWinnerName = bronzeWinnerName
    }
    
    public var format: TournamentFormat {
        get { TournamentFormat(rawValue: formatRaw) ?? .singleElimination }
        set { formatRaw = newValue.rawValue }
    }
    
    public var scoring: TournamentScoring {
        get { TournamentScoring(rawValue: scoringRaw) ?? .sideOut }
        set { scoringRaw = newValue.rawValue }
    }
    
    public var stage: TournamentStage {
        get { TournamentStage(rawValue: stageRaw) ?? .setup }
        set { stageRaw = newValue.rawValue }
    }
}

@Model
public final class LeagueModel {
    public var id: String
    public var title: String
    public var seasonName: String
    public var totalWeeks: Int
    public var currentWeek: Int
    public var createdAt: Date
    public var isCompleted: Bool
    public var playoffTournamentId: String?
    
    @Relationship(deleteRule: .cascade) public var teams: [TeamModel] = []
    @Relationship(deleteRule: .cascade) public var matches: [BracketMatchModel] = []
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        seasonName: String = "Spring 2026",
        totalWeeks: Int = 6,
        currentWeek: Int = 1,
        createdAt: Date = Date(),
        isCompleted: Bool = false,
        playoffTournamentId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.seasonName = seasonName
        self.totalWeeks = totalWeeks
        self.currentWeek = currentWeek
        self.createdAt = createdAt
        self.isCompleted = isCompleted
        self.playoffTournamentId = playoffTournamentId
    }
}

@Model
public final class UserProfileModel {
    public var id: String
    public var name: String
    public var duprId: String
    public var duprDoublesRating: Double
    public var duprSinglesRating: Double
    public var duprHalfLife: Double
    public var avatarEmoji: String
    public var favoriteSnack: String
    public var tournamentsPlayed: Int
    public var tournamentsWon: Int
    public var leaguesWon: Int
    public var totalMatchesPlayed: Int
    public var totalMatchesWon: Int
    
    public init(
        id: String = "current_user",
        name: String = "Dominic",
        duprId: String = "DUPR-882194",
        duprDoublesRating: Double = 4.25,
        duprSinglesRating: Double = 4.10,
        duprHalfLife: Double = 0.90,
        avatarEmoji: String = "👑",
        favoriteSnack: String = "Cold Coconut Water",
        tournamentsPlayed: Int = 3,
        tournamentsWon: Int = 2,
        leaguesWon: Int = 1,
        totalMatchesPlayed: Int = 18,
        totalMatchesWon: Int = 14
    ) {
        self.id = id
        self.name = name
        self.duprId = duprId
        self.duprDoublesRating = duprDoublesRating
        self.duprSinglesRating = duprSinglesRating
        self.duprHalfLife = duprHalfLife
        self.avatarEmoji = avatarEmoji
        self.favoriteSnack = favoriteSnack
        self.tournamentsPlayed = tournamentsPlayed
        self.tournamentsWon = tournamentsWon
        self.leaguesWon = leaguesWon
        self.totalMatchesPlayed = totalMatchesPlayed
        self.totalMatchesWon = totalMatchesWon
    }
    
    public var winRatePercentage: Int {
        guard totalMatchesPlayed > 0 else { return 0 }
        return Int((Double(totalMatchesWon) / Double(totalMatchesPlayed)) * 100)
    }
}
