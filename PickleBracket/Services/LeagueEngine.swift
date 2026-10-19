import Foundation
import SwiftData
import SwiftUI

public struct LeagueStandingItem: Identifiable {
    public var id: String
    public var rank: Int
    public var teamName: String
    public var members: String
    public var combinedDUPR: Double
    public var wins: Int
    public var losses: Int
    public var pointDiff: Int
    public var pointsWon: Int
    public var leaguePoints: Int
}

public final class LeagueEngine: ObservableObject {
    public static let shared = LeagueEngine()
    
    public init() {}
    
    /// Generates weekly fixtures for a league with n teams over totalWeeks
    public func generateLeagueSchedule(leagueId: String, teams: [TeamModel], totalWeeks: Int) -> [BracketMatchModel] {
        guard teams.count >= 2 else { return [] }
        
        var matches: [BracketMatchModel] = []
        var teamList = teams
        if teamList.count % 2 != 0 {
            let byeTeam = TeamModel(name: "BYE", p1Name: "BYE", p1DUPR: 0)
            teamList.append(byeTeam)
        }
        
        let n = teamList.count
        let rounds = totalWeeks
        var matchId = 1
        
        for week in 1...rounds {
            let weekOffset = (week - 1) % (n - 1)
            var currentRotation = teamList
            
            // Standard circle method for round robin fixtures
            for i in 1..<n {
                let newIndex = (i - 1 + weekOffset) % (n - 1) + 1
                currentRotation[newIndex] = teamList[i]
            }
            
            for j in 0..<(n / 2) {
                let teamA = currentRotation[j]
                let teamB = currentRotation[n - 1 - j]
                
                if teamA.name == "BYE" || teamB.name == "BYE" { continue }
                
                let match = BracketMatchModel(
                    tournamentId: leagueId,
                    roundIndex: week, // Week number
                    matchIndex: j,
                    title: "Week \(week) Match \(j + 1)",
                    teamAId: teamA.id,
                    teamAName: teamA.name,
                    teamAMembers: teamA.displayMembers,
                    teamADUPR: teamA.combinedDUPR,
                    teamBId: teamB.id,
                    teamBName: teamB.name,
                    teamBMembers: teamB.displayMembers,
                    teamBDUPR: teamB.combinedDUPR,
                    courtNumber: (j % 4) + 1
                )
                matches.append(match)
                matchId += 1
            }
        }
        
        return matches
    }
    
    /// Computes live ranked league standings from finished league matches
    public func calculateStandings(teams: [TeamModel], matches: [BracketMatchModel]) -> [LeagueStandingItem] {
        var teamStats: [String: (wins: Int, losses: Int, ptsWon: Int, ptsLost: Int)] = [:]
        
        for team in teams {
            teamStats[team.name] = (0, 0, 0, 0)
        }
        
        for m in matches where m.isFinished {
            if var a = teamStats[m.teamAName], var b = teamStats[m.teamBName] {
                a.ptsWon += m.scoreA
                a.ptsLost += m.scoreB
                b.ptsWon += m.scoreB
                b.ptsLost += m.scoreA
                
                if m.scoreA > m.scoreB {
                    a.wins += 1
                    b.losses += 1
                } else {
                    b.wins += 1
                    a.losses += 1
                }
                
                teamStats[m.teamAName] = a
                teamStats[m.teamBName] = b
            }
        }
        
        var standings: [LeagueStandingItem] = []
        for team in teams {
            let stats = teamStats[team.name] ?? (0, 0, 0, 0)
            let diff = stats.ptsWon - stats.ptsLost
            let leaguePts = (stats.wins * 3) + stats.ptsWon
            
            standings.append(LeagueStandingItem(
                id: team.id,
                rank: 1,
                teamName: team.name,
                members: team.displayMembers,
                combinedDUPR: team.combinedDUPR,
                wins: stats.wins,
                losses: stats.losses,
                pointDiff: diff,
                pointsWon: stats.ptsWon,
                leaguePoints: leaguePts
            ))
        }
        
        // Sort by Wins -> Point Diff -> Total Points
        standings.sort {
            if $0.wins != $1.wins { return $0.wins > $1.wins }
            if $0.pointDiff != $1.pointDiff { return $0.pointDiff > $1.pointDiff }
            return $0.pointsWon > $1.pointsWon
        }
        
        for i in 0..<standings.count {
            standings[i].rank = i + 1
        }
        
        return standings
    }
}
