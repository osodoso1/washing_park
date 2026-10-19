import Foundation
import SwiftUI
import Combine

public final class MatchRotationEngine: ObservableObject {
    public static let shared = MatchRotationEngine()
    
    @Published public var players: [MatchPlayer] = []
    @Published public var courtCount: Int = 2 // 1, 2, 3, 4, 5, 6+
    @Published public var targetScore: Int = 11
    @Published public var scoringFormat: ScoringFormat = .sideOut
    @Published public var matchmakingMode: MatchmakingMode = .balanced
    @Published public var currentRoundNumber: Int = 0
    @Published public var currentRound: MatchRound? = nil
    @Published public var pastRounds: [MatchRound] = []
    @Published public var isSessionActive: Bool = false
    
    // Partner history to prevent recent teammate duplicates
    private var partnerHistory: [String: Set<String>] = [:]
    
    public init() {
        loadDefaultPlayers()
    }
    
    public func loadDefaultPlayers() {
        if players.isEmpty {
            players = [
                MatchPlayer(name: "You", skillTier: .advanced),
                MatchPlayer(name: "Alex", skillTier: .intermediate),
                MatchPlayer(name: "Sarah", skillTier: .pro),
                MatchPlayer(name: "Mike", skillTier: .intermediate),
                MatchPlayer(name: "Jordan", skillTier: .beginner),
                MatchPlayer(name: "Taylor", skillTier: .advanced),
                MatchPlayer(name: "Sam", skillTier: .intermediate),
                MatchPlayer(name: "Elena", skillTier: .beginner)
            ]
        }
    }
    
    public func clearAllPlayers() {
        players.removeAll()
    }
    
    public func addPlayer(name: String, skill: SkillTier = .intermediate) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let cleansed = ContentModerator.shared.cleanse(String(trimmed.prefix(20)))
        guard !players.contains(where: { $0.name.lowercased() == cleansed.lowercased() }) else { return }
        
        players.append(MatchPlayer(name: cleansed, skillTier: skill))
    }
    
    public func removePlayer(id: String) {
        players.removeAll { $0.id == id }
    }
    
    public func cyclePlayerSkill(id: String) {
        if let idx = players.firstIndex(where: { $0.id == id }) {
            players[idx].skillTier = players[idx].skillTier.nextTier
        }
    }
    
    public var maxPossibleCourts: Int {
        max(1, players.count / 4)
    }
    
    public var activeCourtsForSession: Int {
        min(courtCount, maxPossibleCourts)
    }
    
    // MARK: - Session Control
    
    public func startNewSession() {
        guard players.count >= 4 else { return }
        
        // Reset counters
        for i in 0..<players.count {
            players[i].gamesPlayed = 0
            players[i].gamesSat = 0
        }
        partnerHistory.removeAll()
        pastRounds.removeAll()
        currentRoundNumber = 0
        isSessionActive = true
        
        generateNextRound()
    }
    
    public func resetSession() {
        isSessionActive = false
        currentRoundNumber = 0
        currentRound = nil
        pastRounds.removeAll()
    }
    
    // MARK: - Next Round Generator
    
    public func generateNextRound() {
        guard players.count >= 4 else { return }
        
        if let current = currentRound {
            pastRounds.append(current)
        }
        
        currentRoundNumber += 1
        let activeCourts = activeCourtsForSession
        let playingSlots = activeCourts * 4
        
        // 1. Sitter Selection: Prioritize least games played, then most sat
        let pool = players.shuffled().sorted {
            if $0.gamesPlayed != $1.gamesPlayed {
                return $0.gamesPlayed < $1.gamesPlayed
            }
            return $0.gamesSat > $1.gamesSat
        }
        
        let selectedForPlay = Array(pool.prefix(playingSlots))
        let sitting = Array(pool.dropFirst(playingSlots))
        
        // Update stats
        for p in selectedForPlay {
            if let idx = players.firstIndex(where: { $0.id == p.id }) {
                players[idx].gamesPlayed += 1
            }
        }
        for s in sitting {
            if let idx = players.firstIndex(where: { $0.id == s.id }) {
                players[idx].gamesSat += 1
            }
        }
        
        // 2. Form Matches based on MatchmakingMode
        let courtMatches = createCourtPairings(players: selectedForPlay, courts: activeCourts)
        
        currentRound = MatchRound(
            roundNumber: currentRoundNumber,
            matches: courtMatches,
            sittingPlayers: sitting
        )
    }
    
    private func createCourtPairings(players: [MatchPlayer], courts: Int) -> [CourtMatch] {
        var matches: [CourtMatch] = []
        
        switch matchmakingMode {
        case .balanced:
            // High + Low pairing to make even teams
            let sorted = players.sorted { $0.skillTier.rating > $1.skillTier.rating }
            let total = sorted.count
            
            for c in 0..<courts {
                let startIdx = c * 4
                guard startIdx + 3 < total else { break }
                
                let p1 = sorted[startIdx]     // highest
                let p2 = sorted[startIdx + 1] // 2nd highest
                let p3 = sorted[startIdx + 2] // 2nd lowest
                let p4 = sorted[startIdx + 3] // lowest
                
                // Pair: (1 + 4) vs (2 + 3) for balanced match
                let teamA = MatchTeam(player1: p1, player2: p4)
                let teamB = MatchTeam(player1: p2, player2: p3)
                
                recordPartnership(p1.id, p4.id)
                recordPartnership(p2.id, p3.id)
                
                matches.append(CourtMatch(
                    courtNumber: c + 1,
                    teamA: teamA,
                    teamB: teamB
                ))
            }
            
        case .tiered:
            // Groups similar players on Court 1 (Adv), Court 2 (Int), etc.
            let sorted = players.sorted { $0.skillTier.rating > $1.skillTier.rating }
            for c in 0..<courts {
                let startIdx = c * 4
                guard startIdx + 3 < sorted.count else { break }
                
                let courtGroup = Array(sorted[startIdx..<(startIdx + 4)]).shuffled()
                let teamA = MatchTeam(player1: courtGroup[0], player2: courtGroup[1])
                let teamB = MatchTeam(player1: courtGroup[2], player2: courtGroup[3])
                
                recordPartnership(courtGroup[0].id, courtGroup[1].id)
                recordPartnership(courtGroup[2].id, courtGroup[3].id)
                
                matches.append(CourtMatch(
                    courtNumber: c + 1,
                    teamA: teamA,
                    teamB: teamB
                ))
            }
            
        case .social:
            // Random shuffle with partner deduplication
            var available = players.shuffled()
            for c in 0..<courts {
                guard available.count >= 4 else { break }
                
                let p1 = available.removeFirst()
                // Find least frequent partner for p1
                let p2Idx = findBestPartnerIndex(for: p1, in: available)
                let p2 = available.remove(at: p2Idx)
                
                let p3 = available.removeFirst()
                let p4Idx = findBestPartnerIndex(for: p3, in: available)
                let p4 = available.remove(at: p4Idx)
                
                let teamA = MatchTeam(player1: p1, player2: p2)
                let teamB = MatchTeam(player1: p3, player2: p4)
                
                recordPartnership(p1.id, p2.id)
                recordPartnership(p3.id, p4.id)
                
                matches.append(CourtMatch(
                    courtNumber: c + 1,
                    teamA: teamA,
                    teamB: teamB
                ))
            }
        }
        
        return matches
    }
    
    private func findBestPartnerIndex(for player: MatchPlayer, in pool: [MatchPlayer]) -> Int {
        guard let history = partnerHistory[player.id] else { return 0 }
        
        // Find first player not in history
        for (i, candidate) in pool.enumerated() {
            if !history.contains(candidate.id) {
                return i
            }
        }
        return 0
    }
    
    private func recordPartnership(_ id1: String, _ id2: String) {
        partnerHistory[id1, default: []].insert(id2)
        partnerHistory[id2, default: []].insert(id1)
    }
    
    // MARK: - Live Score Updates
    
    public func updateScore(matchId: UUID, team: TeamSide, delta: Int) {
        guard let round = currentRound,
              let matchIdx = round.matches.firstIndex(where: { $0.id == matchId }) else { return }
        
        var match = round.matches[matchIdx]
        
        if team == .teamA {
            match.scoreA = max(0, match.scoreA + delta)
        } else {
            match.scoreB = max(0, match.scoreB + delta)
        }
        
        // Check game completion (e.g. target score 11, 15, or 21 with win-by-2)
        if match.scoreA >= targetScore && (match.scoreA - match.scoreB) >= 2 {
            match.isFinished = true
            match.winnerSide = .teamA
        } else if match.scoreB >= targetScore && (match.scoreB - match.scoreA) >= 2 {
            match.isFinished = true
            match.winnerSide = .teamB
        } else {
            match.isFinished = false
            match.winnerSide = nil
        }
        
        currentRound?.matches[matchIdx] = match
    }
}
