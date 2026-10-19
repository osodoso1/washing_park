import Foundation
import SwiftUI
import Combine

public final class TournamentEngine: ObservableObject {
    public static let shared = TournamentEngine()
    
    @Published public var tournamentType: TournamentType = .fixedTeams
    @Published public var scoringFormat: ScoringFormat = .sideOut
    @Published public var stage: TournamentStage = .setup
    
    // Fixed Teams Mode
    @Published public var tournamentTeams: [TournamentTeam] = []
    
    // Rotating Individual Tournament Mode
    @Published public var individualPlayers: [MatchPlayer] = []
    @Published public var individualStandings: [IndividualPlayerStanding] = []
    
    // Matches
    @Published public var roundRobinMatches: [TournamentMatch] = []
    @Published public var playoffMatches: [TournamentMatch] = []
    @Published public var championshipMatch: TournamentMatch? = nil
    @Published public var bronzeMatch: TournamentMatch? = nil
    
    // Winners
    @Published public var goldWinner: TournamentTeam? = nil
    @Published public var silverWinner: TournamentTeam? = nil
    @Published public var bronzeWinner: TournamentTeam? = nil
    
    @Published public var targetScore: Int = 11
    @Published public var courtCount: Int = 2
    @Published public var isTournamentActive: Bool = false
    
    public init() {
        loadDefaultData()
    }
    
    public func loadDefaultData() {
        if tournamentTeams.isEmpty {
            tournamentTeams = [
                TournamentTeam(name: "Dink Dynamos", player1: MatchPlayer(name: "You", skillTier: .advanced), player2: MatchPlayer(name: "Alex", skillTier: .intermediate)),
                TournamentTeam(name: "Kitchen Kings", player1: MatchPlayer(name: "Sarah", skillTier: .pro), player2: MatchPlayer(name: "Mike", skillTier: .intermediate)),
                TournamentTeam(name: "Erne Express", player1: MatchPlayer(name: "Jordan", skillTier: .beginner), player2: MatchPlayer(name: "Taylor", skillTier: .advanced)),
                TournamentTeam(name: "Lob Stars", player1: MatchPlayer(name: "Sam", skillTier: .intermediate), player2: MatchPlayer(name: "Elena", skillTier: .intermediate))
            ]
        }
        
        if individualPlayers.isEmpty {
            individualPlayers = [
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
    
    public func clearAllTeams() {
        tournamentTeams.removeAll()
    }
    
    public func clearAllPlayers() {
        individualPlayers.removeAll()
    }
    
    public func addTeam(name: String, p1Name: String, p2Name: String, skill1: SkillTier = .intermediate, skill2: SkillTier = .intermediate) {
        let cleanName = ContentModerator.shared.cleanse(name.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanP1 = ContentModerator.shared.cleanse(p1Name.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanP2 = ContentModerator.shared.cleanse(p2Name.trimmingCharacters(in: .whitespacesAndNewlines))
        
        guard !cleanName.isEmpty, !cleanP1.isEmpty, !cleanP2.isEmpty else { return }
        
        let team = TournamentTeam(
            name: cleanName,
            player1: MatchPlayer(name: cleanP1, skillTier: skill1),
            player2: MatchPlayer(name: cleanP2, skillTier: skill2)
        )
        tournamentTeams.append(team)
    }
    
    public func removeTeam(id: UUID) {
        tournamentTeams.removeAll { $0.id == id }
    }
    
    public func addIndividualPlayer(name: String, skill: SkillTier = .intermediate) {
        let clean = ContentModerator.shared.cleanse(name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !clean.isEmpty else { return }
        guard !individualPlayers.contains(where: { $0.name.lowercased() == clean.lowercased() }) else { return }
        individualPlayers.append(MatchPlayer(name: clean, skillTier: skill))
    }
    
    public func removeIndividualPlayer(id: String) {
        individualPlayers.removeAll { $0.id == id }
    }
    
    // MARK: - Tournament Lifecycle
    
    public func startTournament() {
        if tournamentType == .fixedTeams {
            guard tournamentTeams.count >= 4 else { return }
            for i in 0..<tournamentTeams.count {
                tournamentTeams[i].wins = 0
                tournamentTeams[i].losses = 0
                tournamentTeams[i].pointsWon = 0
                tournamentTeams[i].pointsLost = 0
                tournamentTeams[i].seed = 0
            }
            generateFixedRoundRobinSchedule()
        } else {
            guard individualPlayers.count >= 4 else { return }
            individualStandings = individualPlayers.map { IndividualPlayerStanding(player: $0) }
            generateRotatingIndividualSchedule()
        }
        
        playoffMatches = []
        championshipMatch = nil
        bronzeMatch = nil
        goldWinner = nil
        silverWinner = nil
        bronzeWinner = nil
        
        stage = .roundRobin
        isTournamentActive = true
    }
    
    private func generateFixedRoundRobinSchedule() {
        roundRobinMatches = []
        let count = tournamentTeams.count
        var matchIndex = 1
        
        for i in 0..<count {
            for j in (i + 1)..<count {
                let teamA = tournamentTeams[i]
                let teamB = tournamentTeams[j]
                let court = ((matchIndex - 1) % courtCount) + 1
                
                roundRobinMatches.append(TournamentMatch(
                    title: "Pool Match \(matchIndex)",
                    stage: .roundRobin,
                    courtNumber: court,
                    teamA: teamA,
                    teamB: teamB
                ))
                matchIndex += 1
            }
        }
    }
    
    private func generateRotatingIndividualSchedule() {
        roundRobinMatches = []
        var pool = individualPlayers.shuffled()
        if pool.count % 4 != 0 {
            // Trim to multiple of 4 or pad
            let validCount = (pool.count / 4) * 4
            pool = Array(pool.prefix(validCount))
        }
        
        var matchIndex = 1
        // Generate 3 rounds of rotating pairings
        for round in 1...3 {
            pool.shuffle()
            for i in stride(from: 0, to: pool.count, by: 4) {
                guard i + 3 < pool.count else { break }
                let p1 = pool[i]
                let p2 = pool[i+1]
                let p3 = pool[i+2]
                let p4 = pool[i+3]
                
                let teamA = TournamentTeam(name: "\(p1.name) + \(p2.name)", player1: p1, player2: p2)
                let teamB = TournamentTeam(name: "\(p3.name) + \(p4.name)", player1: p3, player2: p4)
                let court = ((matchIndex - 1) % courtCount) + 1
                
                roundRobinMatches.append(TournamentMatch(
                    title: "Round \(round) · Match \(matchIndex)",
                    stage: .roundRobin,
                    courtNumber: court,
                    teamA: teamA,
                    teamB: teamB
                ))
                matchIndex += 1
            }
        }
    }
    
    // Standings sorted by wins DESC, point differential DESC, points won DESC
    public var rankedStandings: [TournamentTeam] {
        tournamentTeams.sorted {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            if $0.pointDifferential != $1.pointDifferential { return $0.pointDifferential > $1.pointDifferential }
            return $0.pointsWon > $1.pointsWon
        }
    }
    
    public var rankedIndividualStandings: [IndividualPlayerStanding] {
        individualStandings.sorted {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            if $0.pointDifferential != $1.pointDifferential { return $0.pointDifferential > $1.pointDifferential }
            return $0.pointsWon > $1.pointsWon
        }
    }
    
    public var isRoundRobinComplete: Bool {
        !roundRobinMatches.isEmpty && roundRobinMatches.allSatisfy { $0.isFinished }
    }
    
    public func advanceToPlayoffs() {
        if tournamentType == .fixedTeams {
            let standings = rankedStandings
            guard standings.count >= 4 else { return }
            
            playoffMatches = [
                TournamentMatch(
                    title: "Semi-Final 1 (#1 vs #4)",
                    stage: .playoffs,
                    courtNumber: 1,
                    teamA: standings[0],
                    teamB: standings[3]
                ),
                TournamentMatch(
                    title: "Semi-Final 2 (#2 vs #3)",
                    stage: .playoffs,
                    courtNumber: min(2, courtCount),
                    teamA: standings[1],
                    teamB: standings[2]
                )
            ]
        } else {
            // Rotating Individual: Top 4 individual players make the Championship Gold match!
            let topIndiv = rankedIndividualStandings
            guard topIndiv.count >= 4 else { return }
            
            let p1 = topIndiv[0].player
            let p2 = topIndiv[1].player
            let p3 = topIndiv[2].player
            let p4 = topIndiv[3].player
            
            // #1 + #4 vs #2 + #3
            let teamA = TournamentTeam(name: "👑 \(p1.name) + \(p4.name)", player1: p1, player2: p4)
            let teamB = TournamentTeam(name: "👑 \(p2.name) + \(p3.name)", player1: p2, player2: p3)
            
            championshipMatch = TournamentMatch(
                title: "🥇 GOLD CHAMPIONSHIP (TOP 4 ROTATION)",
                stage: .championship,
                courtNumber: 1,
                teamA: teamA,
                teamB: teamB
            )
            stage = .championship
            return
        }
        
        stage = .playoffs
    }
    
    public var isPlayoffsComplete: Bool {
        playoffMatches.count == 2 && playoffMatches.allSatisfy { $0.isFinished }
    }
    
    public func advanceToChampionship() {
        guard isPlayoffsComplete else { return }
        
        let semi1 = playoffMatches[0]
        let semi2 = playoffMatches[1]
        
        guard let semi1WinnerId = semi1.winnerTeamId,
              let semi2WinnerId = semi2.winnerTeamId else { return }
        
        let semi1Winner = (semi1WinnerId == semi1.teamA.id) ? semi1.teamA : semi1.teamB
        let semi1Loser = (semi1WinnerId == semi1.teamA.id) ? semi1.teamB : semi1.teamA
        
        let semi2Winner = (semi2WinnerId == semi2.teamA.id) ? semi2.teamA : semi2.teamB
        let semi2Loser = (semi2WinnerId == semi2.teamA.id) ? semi2.teamB : semi2.teamA
        
        championshipMatch = TournamentMatch(
            title: "🥇 GOLD MEDAL CHAMPIONSHIP",
            stage: .championship,
            courtNumber: 1,
            teamA: semi1Winner,
            teamB: semi2Winner
        )
        
        bronzeMatch = TournamentMatch(
            title: "🥉 BRONZE MEDAL (3RD PLACE)",
            stage: .championship,
            courtNumber: min(2, courtCount),
            teamA: semi1Loser,
            teamB: semi2Loser
        )
        
        stage = .championship
    }
    
    public var isChampionshipComplete: Bool {
        championshipMatch?.isFinished == true
    }
    
    public func finalizePodium() {
        guard let champ = championshipMatch, champ.isFinished, let champWinnerId = champ.winnerTeamId else { return }
        
        goldWinner = (champWinnerId == champ.teamA.id) ? champ.teamA : champ.teamB
        silverWinner = (champWinnerId == champ.teamA.id) ? champ.teamB : champ.teamA
        
        if let bronze = bronzeMatch, bronze.isFinished, let bronzeWinnerId = bronze.winnerTeamId {
            bronzeWinner = (bronzeWinnerId == bronze.teamA.id) ? bronze.teamA : bronze.teamB
        } else {
            bronzeWinner = bronzeMatch?.teamA
        }
        
        stage = .podium
    }
    
    // MARK: - Score Updates
    
    public func updateMatchScore(matchId: UUID, team: TeamSide, delta: Int) {
        if let idx = roundRobinMatches.firstIndex(where: { $0.id == matchId }) {
            updateScoreInMatch(&roundRobinMatches[idx], team: team, delta: delta)
            if tournamentType == .fixedTeams {
                recalculateRoundRobinStats()
            } else {
                recalculateIndividualStats()
            }
            return
        }
        
        if let idx = playoffMatches.firstIndex(where: { $0.id == matchId }) {
            updateScoreInMatch(&playoffMatches[idx], team: team, delta: delta)
            return
        }
        
        if championshipMatch?.id == matchId {
            var m = championshipMatch!
            updateScoreInMatch(&m, team: team, delta: delta)
            championshipMatch = m
            return
        }
        
        if bronzeMatch?.id == matchId {
            var m = bronzeMatch!
            updateScoreInMatch(&m, team: team, delta: delta)
            bronzeMatch = m
            return
        }
    }
    
    private func updateScoreInMatch(_ match: inout TournamentMatch, team: TeamSide, delta: Int) {
        if team == .teamA {
            match.scoreA = max(0, match.scoreA + delta)
        } else {
            match.scoreB = max(0, match.scoreB + delta)
        }
        
        if match.scoreA >= targetScore && (match.scoreA - match.scoreB) >= 2 {
            match.isFinished = true
            match.winnerTeamId = match.teamA.id
        } else if match.scoreB >= targetScore && (match.scoreB - match.scoreA) >= 2 {
            match.isFinished = true
            match.winnerTeamId = match.teamB.id
        } else {
            match.isFinished = false
            match.winnerTeamId = nil
        }
    }
    
    private func recalculateRoundRobinStats() {
        for i in 0..<tournamentTeams.count {
            tournamentTeams[i].wins = 0
            tournamentTeams[i].losses = 0
            tournamentTeams[i].pointsWon = 0
            tournamentTeams[i].pointsLost = 0
        }
        
        for m in roundRobinMatches where m.isFinished {
            guard let teamAIdx = tournamentTeams.firstIndex(where: { $0.id == m.teamA.id }),
                  let teamBIdx = tournamentTeams.firstIndex(where: { $0.id == m.teamB.id }) else { continue }
            
            tournamentTeams[teamAIdx].pointsWon += m.scoreA
            tournamentTeams[teamAIdx].pointsLost += m.scoreB
            tournamentTeams[teamBIdx].pointsWon += m.scoreB
            tournamentTeams[teamBIdx].pointsLost += m.scoreA
            
            if m.winnerTeamId == m.teamA.id {
                tournamentTeams[teamAIdx].wins += 1
                tournamentTeams[teamBIdx].losses += 1
            } else if m.winnerTeamId == m.teamB.id {
                tournamentTeams[teamBIdx].wins += 1
                tournamentTeams[teamAIdx].losses += 1
            }
        }
    }
    
    private func recalculateIndividualStats() {
        for i in 0..<individualStandings.count {
            individualStandings[i].wins = 0
            individualStandings[i].losses = 0
            individualStandings[i].pointsWon = 0
            individualStandings[i].pointsLost = 0
        }
        
        for m in roundRobinMatches where m.isFinished {
            let pA1 = m.teamA.player1.id
            let pA2 = m.teamA.player2.id
            let pB1 = m.teamB.player1.id
            let pB2 = m.teamB.player2.id
            
            for id in [pA1, pA2] {
                if let idx = individualStandings.firstIndex(where: { $0.player.id == id }) {
                    individualStandings[idx].pointsWon += m.scoreA
                    individualStandings[idx].pointsLost += m.scoreB
                    if m.winnerTeamId == m.teamA.id { individualStandings[idx].wins += 1 }
                    else { individualStandings[idx].losses += 1 }
                }
            }
            
            for id in [pB1, pB2] {
                if let idx = individualStandings.firstIndex(where: { $0.player.id == id }) {
                    individualStandings[idx].pointsWon += m.scoreB
                    individualStandings[idx].pointsLost += m.scoreA
                    if m.winnerTeamId == m.teamB.id { individualStandings[idx].wins += 1 }
                    else { individualStandings[idx].losses += 1 }
                }
            }
        }
    }
    
    public func resetTournament() {
        stage = .setup
        isTournamentActive = false
        roundRobinMatches = []
        playoffMatches = []
        championshipMatch = nil
        bronzeMatch = nil
        goldWinner = nil
        silverWinner = nil
        bronzeWinner = nil
    }
}
