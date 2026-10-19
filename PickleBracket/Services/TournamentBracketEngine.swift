import Foundation
import SwiftData
import SwiftUI

public final class TournamentBracketEngine: ObservableObject {
    public static let shared = TournamentBracketEngine()
    
    public init() {}
    
    // MARK: - Single Elimination Bracket Generation
    
    /// Generates full binary tree bracket matches for 4, 8, 16, or 32 teams
    public func generateSingleEliminationMatches(tournamentId: String, seededTeams: [TeamModel]) -> [BracketMatchModel] {
        let teamCount = seededTeams.count
        guard teamCount >= 2 else { return [] }
        
        // Power of 2 bracket size (4, 8, 16, 32)
        let bracketSize: Int = {
            if teamCount <= 4 { return 4 }
            if teamCount <= 8 { return 8 }
            if teamCount <= 16 { return 16 }
            return 32
        }()
        
        var teamsPadded = seededTeams
        // Add BYE teams if needed
        while teamsPadded.count < bracketSize {
            let byeTeam = TeamModel(name: "BYE", p1Name: "BYE", p1DUPR: 0, seedIndex: teamsPadded.count + 1)
            teamsPadded.append(byeTeam)
        }
        
        // Standard tournament bracket seeding pairings
        let pairings = standardBracketPairings(for: bracketSize)
        let totalRounds = Int(log2(Double(bracketSize)))
        
        var matches: [BracketMatchModel] = []
        var roundMatchesMap: [Int: [BracketMatchModel]] = [:]
        
        // 1. Create Round 0 (First Round) matches
        var round0Matches: [BracketMatchModel] = []
        for matchIdx in 0..<(bracketSize / 2) {
            let pair = pairings[matchIdx]
            let teamA = teamsPadded[pair.0 - 1]
            let teamB = teamsPadded[pair.1 - 1]
            
            let roundTitle: String = {
                if totalRounds == 2 { return "Semi-Final \(matchIdx + 1)" }
                if totalRounds == 3 { return "Quarterfinal \(matchIdx + 1)" }
                if totalRounds == 4 { return "Round of 16 (\(matchIdx + 1))" }
                return "Round 1 (\(matchIdx + 1))"
            }()
            
            let isByeMatch = teamB.name == "BYE"
            
            let match = BracketMatchModel(
                tournamentId: tournamentId,
                roundIndex: 0,
                matchIndex: matchIdx,
                title: roundTitle,
                teamAId: teamA.id,
                teamAName: teamA.name,
                teamAMembers: teamA.displayMembers,
                teamADUPR: teamA.combinedDUPR,
                teamBId: isByeMatch ? nil : teamB.id,
                teamBName: teamB.name,
                teamBMembers: teamB.displayMembers,
                teamBDUPR: teamB.combinedDUPR,
                scoreA: isByeMatch ? 11 : 0,
                scoreB: 0,
                isFinished: isByeMatch,
                winnerId: isByeMatch ? teamA.id : nil,
                winnerName: isByeMatch ? teamA.name : nil,
                courtNumber: (matchIdx % 4) + 1
            )
            round0Matches.append(match)
            matches.append(match)
        }
        roundMatchesMap[0] = round0Matches
        
        // 2. Create subsequent rounds up to Championship Final
        for r in 1..<totalRounds {
            let matchCountInRound = bracketSize / (1 << (r + 1))
            var roundMatches: [BracketMatchModel] = []
            
            for mIdx in 0..<matchCountInRound {
                let roundTitle: String = {
                    if r == totalRounds - 1 { return "🥇 GOLD CHAMPIONSHIP" }
                    if r == totalRounds - 2 { return "Semi-Final \(mIdx + 1)" }
                    if r == totalRounds - 3 { return "Quarterfinal \(mIdx + 1)" }
                    return "Round \(r + 1) (\(mIdx + 1))"
                }()
                
                let match = BracketMatchModel(
                    tournamentId: tournamentId,
                    roundIndex: r,
                    matchIndex: mIdx,
                    title: roundTitle,
                    teamAId: nil,
                    teamAName: "Winner R\(r) M\(mIdx * 2 + 1)",
                    teamAMembers: "TBD",
                    teamADUPR: 3.5,
                    teamBId: nil,
                    teamBName: "Winner R\(r) M\(mIdx * 2 + 2)",
                    teamBMembers: "TBD",
                    teamBDUPR: 3.5,
                    scoreA: 0,
                    scoreB: 0,
                    isFinished: false,
                    courtNumber: (mIdx % 2) + 1
                )
                roundMatches.append(match)
                matches.append(match)
            }
            roundMatchesMap[r] = roundMatches
        }
        
        // 3. Link parent nextMatchId pointers so winning a match automatically advances to parent node
        for r in 0..<(totalRounds - 1) {
            guard let currentRound = roundMatchesMap[r], let nextRound = roundMatchesMap[r + 1] else { continue }
            for (idx, match) in currentRound.enumerated() {
                let parentMatch = nextRound[idx / 2]
                match.nextMatchId = parentMatch.id
                match.nextMatchSlot = (idx % 2 == 0) ? "A" : "B"
                
                // If this match was a BYE, advance immediately!
                if match.isFinished, let winnerId = match.winnerId, let winnerName = match.winnerName {
                    if match.nextMatchSlot == "A" {
                        parentMatch.teamAId = winnerId
                        parentMatch.teamAName = winnerName
                        parentMatch.teamAMembers = match.teamAMembers
                        parentMatch.teamADUPR = match.teamADUPR
                    } else {
                        parentMatch.teamBId = winnerId
                        parentMatch.teamBName = winnerName
                        parentMatch.teamBMembers = match.teamBMembers
                        parentMatch.teamBDUPR = match.teamBDUPR
                    }
                }
            }
        }
        
        // 4. Create Bronze Medal Match (3rd place)
        let bronzeMatch = BracketMatchModel(
            tournamentId: tournamentId,
            roundIndex: totalRounds - 1,
            matchIndex: 1, // Bronze match
            title: "🥉 BRONZE MEDAL (3RD PLACE)",
            teamAName: "Semi-Final 1 Runner-Up",
            teamAMembers: "TBD",
            teamBName: "Semi-Final 2 Runner-Up",
            teamBMembers: "TBD",
            courtNumber: 2
        )
        matches.append(bronzeMatch)
        
        return matches
    }
    
    /// Standard tournament seeding seed-pairings for bracket trees
    private func standardBracketPairings(for size: Int) -> [(Int, Int)] {
        switch size {
        case 4:
            return [(1, 4), (2, 3)]
        case 8:
            return [(1, 8), (4, 5), (2, 7), (3, 6)]
        case 16:
            return [
                (1, 16), (8, 9), (4, 13), (5, 12),
                (2, 15), (7, 10), (3, 14), (6, 11)
            ]
        case 32:
            return [
                (1, 32), (16, 17), (8, 25), (9, 24),
                (4, 29), (13, 20), (5, 28), (12, 21),
                (2, 31), (15, 18), (7, 26), (10, 23),
                (3, 30), (14, 19), (6, 27), (11, 22)
            ]
        default:
            return [(1, 4), (2, 3)]
        }
    }
    
    // MARK: - Advance Winner in Tree
    
    /// Updates match score and advances winner to the connected next round bracket match
    public func updateMatchScore(
        match: BracketMatchModel,
        tournament: TournamentModel,
        allMatches: [BracketMatchModel],
        scoreA: Int,
        scoreB: Int
    ) {
        match.scoreA = scoreA
        match.scoreB = scoreB
        
        let target = tournament.targetScore
        let diff = abs(scoreA - scoreB)
        
        if (scoreA >= target || scoreB >= target) && diff >= 2 {
            match.isFinished = true
            let isWinnerA = scoreA > scoreB
            match.winnerId = isWinnerA ? match.teamAId : match.teamBId
            match.winnerName = isWinnerA ? match.teamAName : match.teamBName
            
            let winnerMembers = isWinnerA ? match.teamAMembers : match.teamBMembers
            let winnerDUPR = isWinnerA ? match.teamADUPR : match.teamBDUPR
            
            let loserName = isWinnerA ? match.teamBName : match.teamAName
            let loserMembers = isWinnerA ? match.teamBMembers : match.teamAMembers
            let loserDUPR = isWinnerA ? match.teamBDUPR : match.teamADUPR
            
            // 1. Advance to Next Round Match if present
            if let nextId = match.nextMatchId, let nextMatch = allMatches.first(where: { $0.id == nextId }) {
                if match.nextMatchSlot == "A" {
                    nextMatch.teamAId = match.winnerId
                    nextMatch.teamAName = match.winnerName ?? "Winner"
                    nextMatch.teamAMembers = winnerMembers
                    nextMatch.teamADUPR = winnerDUPR
                } else {
                    nextMatch.teamBId = match.winnerId
                    nextMatch.teamBName = match.winnerName ?? "Winner"
                    nextMatch.teamBMembers = winnerMembers
                    nextMatch.teamBDUPR = winnerDUPR
                }
            }
            
            // 2. If this was a Semi-Final match, feed the loser to the Bronze Match
            let totalRounds = Int(log2(Double(tournament.teamCount)))
            if match.roundIndex == totalRounds - 2 {
                if let bronzeMatch = allMatches.first(where: { $0.title.contains("BRONZE") }) {
                    if match.matchIndex == 0 {
                        bronzeMatch.teamAName = loserName
                        bronzeMatch.teamAMembers = loserMembers
                        bronzeMatch.teamADUPR = loserDUPR
                    } else {
                        bronzeMatch.teamBName = loserName
                        bronzeMatch.teamBMembers = loserMembers
                        bronzeMatch.teamBDUPR = loserDUPR
                    }
                }
            }
            
            // 3. Check if Gold Championship finished
            if match.title.contains("GOLD") {
                tournament.goldWinnerName = match.winnerName
                tournament.silverWinnerName = loserName
                tournament.stage = .podium
            }
            
            // 4. Check if Bronze Medal finished
            if match.title.contains("BRONZE") {
                tournament.bronzeWinnerName = match.winnerName
            }
        } else {
            match.isFinished = false
            match.winnerId = nil
            match.winnerName = nil
        }
    }
}
