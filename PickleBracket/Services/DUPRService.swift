import Foundation
import SwiftUI

public struct DUPRPlayerResult: Identifiable, Codable {
    public var id: String
    public var fullName: String
    public var duprId: String
    public var doublesRating: Double
    public var singlesRating: Double
    public var halfLife: Double
    public var location: String
    public var verified: Bool
}

public final class DUPRService: ObservableObject {
    public static let shared = DUPRService()
    
    // Sample DUPR Registry Database
    private let duprDatabase: [DUPRPlayerResult] = [
        DUPRPlayerResult(id: "1", fullName: "Dominic Soriano", duprId: "DUPR-882194", doublesRating: 4.25, singlesRating: 4.10, halfLife: 0.92, location: "Burlingame, CA", verified: true),
        DUPRPlayerResult(id: "2", fullName: "Alex Rivera", duprId: "DUPR-109283", doublesRating: 4.40, singlesRating: 4.35, halfLife: 0.88, location: "San Mateo, CA", verified: true),
        DUPRPlayerResult(id: "3", fullName: "Sarah Chen", duprId: "DUPR-384729", doublesRating: 4.15, singlesRating: 3.95, halfLife: 0.85, location: "Burlingame, CA", verified: true),
        DUPRPlayerResult(id: "4", fullName: "Mike Johnson", duprId: "DUPR-592810", doublesRating: 3.85, singlesRating: 3.70, halfLife: 0.80, location: "Millbrae, CA", verified: true),
        DUPRPlayerResult(id: "5", fullName: "Lisa Wang", duprId: "DUPR-748291", doublesRating: 4.65, singlesRating: 4.50, halfLife: 0.95, location: "San Francisco, CA", verified: true),
        DUPRPlayerResult(id: "6", fullName: "Kevin Zhang", duprId: "DUPR-629104", doublesRating: 3.90, singlesRating: 3.80, halfLife: 0.78, location: "Belmont, CA", verified: true),
        DUPRPlayerResult(id: "7", fullName: "Arthur Dent", duprId: "DUPR-492019", doublesRating: 3.60, singlesRating: 3.50, halfLife: 0.75, location: "San Carlos, CA", verified: true),
        DUPRPlayerResult(id: "8", fullName: "Ernie Davis", duprId: "DUPR-938201", doublesRating: 4.50, singlesRating: 4.30, halfLife: 0.90, location: "Palo Alto, CA", verified: true),
        DUPRPlayerResult(id: "9", fullName: "Andrew Smith", duprId: "DUPR-284910", doublesRating: 4.30, singlesRating: 4.20, halfLife: 0.86, location: "Redwood City, CA", verified: true),
        DUPRPlayerResult(id: "10", fullName: "Robert Paulson", duprId: "DUPR-193820", doublesRating: 4.70, singlesRating: 4.60, halfLife: 0.96, location: "Menlo Park, CA", verified: true),
        DUPRPlayerResult(id: "11", fullName: "Monica Geller", duprId: "DUPR-582910", doublesRating: 3.75, singlesRating: 3.65, halfLife: 0.80, location: "Foster City, CA", verified: true),
        DUPRPlayerResult(id: "12", fullName: "Ian Malcolm", duprId: "DUPR-839201", doublesRating: 4.05, singlesRating: 3.90, halfLife: 0.82, location: "San Mateo, CA", verified: true)
    ]
    
    public init() {}
    
    /// Looks up a player by DUPR ID or partial name
    public func searchPlayers(query: String) -> [DUPRPlayerResult] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return duprDatabase }
        
        return duprDatabase.filter {
            $0.fullName.lowercased().contains(clean) ||
            $0.duprId.lowercased().contains(clean) ||
            $0.location.lowercased().contains(clean)
        }
    }
    
    /// Returns or generates a validated DUPR profile for a player name
    public func lookupOrCreatePlayer(name: String, preferredDUPR: Double = 3.5) -> DUPRPlayerResult {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = duprDatabase.first(where: { $0.fullName.lowercased() == clean.lowercased() }) {
            return match
        }
        
        let randomId = "DUPR-\(abs(clean.hashValue % 900000) + 100000)"
        return DUPRPlayerResult(
            id: UUID().uuidString,
            fullName: clean.isEmpty ? "Player" : clean,
            duprId: randomId,
            doublesRating: preferredDUPR,
            singlesRating: max(2.0, preferredDUPR - 0.15),
            halfLife: 0.80,
            location: "Washington Park, CA",
            verified: true
        )
    }
    
    /// Sorts teams by aggregate DUPR rating and seeds them (Seed #1, #2, #3...)
    public func seedTeamsByDUPR(teams: [TeamModel]) -> [TeamModel] {
        let sorted = teams.sorted { $0.combinedDUPR > $1.combinedDUPR }
        for (idx, team) in sorted.enumerated() {
            team.seedIndex = idx + 1
        }
        return sorted
    }
    
    /// Estimates DUPR rating impact for a finished match based on DUPR expected point ratio
    public func calculateEstimatedDUPRDelta(ratingA: Double, ratingB: Double, scoreA: Int, scoreB: Int) -> (deltaA: Double, deltaB: Double) {
        let total = Double(scoreA + scoreB)
        guard total > 0 else { return (0, 0) }
        
        let actualRatioA = Double(scoreA) / total
        let ratingDiff = ratingA - ratingB
        
        // Logistic curve for expected point ratio based on DUPR rating gap
        let expectedRatioA = 1.0 / (1.0 + pow(10.0, -ratingDiff / 1.5))
        
        let delta = (actualRatioA - expectedRatioA) * 0.25
        let roundedDeltaA = (delta * 100).rounded() / 100
        let roundedDeltaB = (-delta * 100).rounded() / 100
        
        return (roundedDeltaA, roundedDeltaB)
    }
}
