import Foundation

public enum GameFormat: String, Codable, CaseIterable, Identifiable {
    case rotatingDoubles = "Rotating Doubles"
    case tournament = "🏆 Park Tournament"
    
    public var id: String { rawValue }
    public var description: String {
        switch self {
        case .rotatingDoubles: return "Auto partner rotations, sitting queue & live scoring"
        case .tournament: return "Round Robin pool play ➔ Playoffs bracket ➔ Championship"
        }
    }
}

public enum ScoringFormat: String, Codable, CaseIterable, Identifiable {
    case sideOut = "Side-Out (Traditional)"
    case rally = "Rally Scoring (MLP)"
    case dreamBreaker = "DreamBreaker (4v4 Singles)"
    
    public var id: String { rawValue }
    
    public var shortName: String {
        switch self {
        case .sideOut: return "Side-Out"
        case .rally: return "Rally"
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
        case .sideOut: return "Traditional scoring (only serving side scores points to 11/15)"
        case .rally: return "Every rally scores a point (MLP style, freeze point at game point)"
        case .dreamBreaker: return "4v4 team singles showdown to 21 pts (rotates 1v1 player every 4 rallies)"
        }
    }
}

public enum TournamentType: String, Codable, CaseIterable, Identifiable {
    case fixedTeams = "Fixed Teams"
    case rotatingIndividual = "Rotating King of Court"
    
    public var id: String { rawValue }
    public var description: String {
        switch self {
        case .fixedTeams: return "Stay with your chosen partner for pool play & playoffs"
        case .rotatingIndividual: return "Rotate partners every match · Individual player standings"
        }
    }
}

public enum SkillTier: String, Codable, CaseIterable, Identifiable {
    case beginner = "2.5 Beg"
    case intermediate = "3.5 Int"
    case advanced = "4.5 Adv"
    case pro = "5.0 Pro"
    
    public var id: String { rawValue }
    
    public var rating: Double {
        switch self {
        case .beginner: return 2.5
        case .intermediate: return 3.5
        case .advanced: return 4.5
        case .pro: return 5.0
        }
    }
    
    public var label: String {
        switch self {
        case .beginner: return "Beginner (2.5)"
        case .intermediate: return "Intermediate (3.5)"
        case .advanced: return "Advanced (4.5)"
        case .pro: return "Pro / DUPR 5.0+"
        }
    }
    
    public var badge: String {
        switch self {
        case .beginner: return "2.5"
        case .intermediate: return "3.5"
        case .advanced: return "4.5"
        case .pro: return "5.0"
        }
    }
    
    public var nextTier: SkillTier {
        switch self {
        case .beginner: return .intermediate
        case .intermediate: return .advanced
        case .advanced: return .pro
        case .pro: return .beginner
        }
    }
}

public enum MatchmakingMode: String, Codable, CaseIterable, Identifiable {
    case balanced = "Balanced Teams"
    case tiered = "Tiered Courts"
    case social = "Random Social"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .balanced: return "Pairs high + low skill to create even match games"
        case .tiered: return "Groups similar ratings on Court 1 (Adv) vs Court 2 (Int)"
        case .social: return "Random rotation with zero repeated partner pairings"
        }
    }
}

public struct MatchPlayer: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var skillTier: SkillTier
    public var gamesPlayed: Int
    public var gamesSat: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        skillTier: SkillTier = .intermediate,
        gamesPlayed: Int = 0,
        gamesSat: Int = 0
    ) {
        self.id = id
        self.name = name
        self.skillTier = skillTier
        self.gamesPlayed = gamesPlayed
        self.gamesSat = gamesSat
    }
}

public struct MatchTeam: Identifiable, Codable, Equatable {
    public var id: String { "\(player1.id)_\(player2.id)" }
    public var player1: MatchPlayer
    public var player2: MatchPlayer
    
    public init(player1: MatchPlayer, player2: MatchPlayer) {
        self.player1 = player1
        self.player2 = player2
    }
    
    public var displayNames: String {
        "\(player1.name) + \(player2.name)"
    }
    
    public var combinedRating: Double {
        player1.skillTier.rating + player2.skillTier.rating
    }
}

public enum TeamSide: String, Codable {
    case teamA
    case teamB
}

public struct CourtMatch: Identifiable, Codable, Equatable {
    public let id: UUID
    public var courtNumber: Int
    public var teamA: MatchTeam
    public var teamB: MatchTeam
    public var scoreA: Int
    public var scoreB: Int
    public var isFinished: Bool
    public var winnerSide: TeamSide?
    
    public init(
        id: UUID = UUID(),
        courtNumber: Int,
        teamA: MatchTeam,
        teamB: MatchTeam,
        scoreA: Int = 0,
        scoreB: Int = 0,
        isFinished: Bool = false,
        winnerSide: TeamSide? = nil
    ) {
        self.id = id
        self.courtNumber = courtNumber
        self.teamA = teamA
        self.teamB = teamB
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.isFinished = isFinished
        self.winnerSide = winnerSide
    }
}

public struct MatchRound: Identifiable, Codable, Equatable {
    public let id: UUID
    public var roundNumber: Int
    public var matches: [CourtMatch]
    public var sittingPlayers: [MatchPlayer]
    
    public init(id: UUID = UUID(), roundNumber: Int, matches: [CourtMatch], sittingPlayers: [MatchPlayer]) {
        self.id = id
        self.roundNumber = roundNumber
        self.matches = matches
        self.sittingPlayers = sittingPlayers
    }
}

// MARK: - Tournament Mode Models

public enum TournamentStage: String, Codable, CaseIterable, Identifiable {
    case setup = "Setup"
    case roundRobin = "Round Robin Pool"
    case playoffs = "Playoffs"
    case championship = "Championship"
    case podium = "🏆 Podium"
    
    public var id: String { rawValue }
}

public struct TournamentTeam: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var player1: MatchPlayer
    public var player2: MatchPlayer
    public var wins: Int
    public var losses: Int
    public var pointsWon: Int
    public var pointsLost: Int
    public var seed: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        player1: MatchPlayer,
        player2: MatchPlayer,
        wins: Int = 0,
        losses: Int = 0,
        pointsWon: Int = 0,
        pointsLost: Int = 0,
        seed: Int = 0
    ) {
        self.id = id
        self.name = name
        self.player1 = player1
        self.player2 = player2
        self.wins = wins
        self.losses = losses
        self.pointsWon = pointsWon
        self.pointsLost = pointsLost
        self.seed = seed
    }
    
    public var pointDifferential: Int {
        pointsWon - pointsLost
    }
    
    public var combinedRating: Double {
        player1.skillTier.rating + player2.skillTier.rating
    }
    
    public var displayMembers: String {
        "\(player1.name) & \(player2.name)"
    }
}

public struct IndividualPlayerStanding: Identifiable, Codable, Equatable {
    public var id: String { player.id }
    public var player: MatchPlayer
    public var wins: Int
    public var losses: Int
    public var pointsWon: Int
    public var pointsLost: Int
    
    public init(player: MatchPlayer, wins: Int = 0, losses: Int = 0, pointsWon: Int = 0, pointsLost: Int = 0) {
        self.player = player
        self.wins = wins
        self.losses = losses
        self.pointsWon = pointsWon
        self.pointsLost = pointsLost
    }
    
    public var pointDifferential: Int {
        pointsWon - pointsLost
    }
}

public struct TournamentMatch: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var stage: TournamentStage
    public var courtNumber: Int
    public var teamA: TournamentTeam
    public var teamB: TournamentTeam
    public var scoreA: Int
    public var scoreB: Int
    public var isFinished: Bool
    public var winnerTeamId: UUID?
    
    public init(
        id: UUID = UUID(),
        title: String,
        stage: TournamentStage,
        courtNumber: Int = 1,
        teamA: TournamentTeam,
        teamB: TournamentTeam,
        scoreA: Int = 0,
        scoreB: Int = 0,
        isFinished: Bool = false,
        winnerTeamId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.stage = stage
        self.courtNumber = courtNumber
        self.teamA = teamA
        self.teamB = teamB
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.isFinished = isFinished
        self.winnerTeamId = winnerTeamId
    }
}
