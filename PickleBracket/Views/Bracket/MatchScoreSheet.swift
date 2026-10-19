import SwiftUI
import SwiftData

public struct MatchScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    let match: BracketMatchModel
    @Bindable var tournament: TournamentModel
    let allMatches: [BracketMatchModel]
    
    @State private var currentScoreA: Int
    @State private var currentScoreB: Int
    
    public init(match: BracketMatchModel, tournament: TournamentModel, allMatches: [BracketMatchModel]) {
        self.match = match
        self.tournament = tournament
        self.allMatches = allMatches
        _currentScoreA = State(initialValue: match.scoreA)
        _currentScoreB = State(initialValue: match.scoreB)
    }
    
    private var isMatchWon: Bool {
        let target = tournament.targetScore
        let diff = abs(currentScoreA - currentScoreB)
        return (currentScoreA >= target || currentScoreB >= target) && diff >= 2
    }
    
    private var projectedDUPRDelta: (deltaA: Double, deltaB: Double) {
        DUPRService.shared.calculateEstimatedDUPRDelta(
            ratingA: match.teamADUPR,
            ratingB: match.teamBDUPR,
            scoreA: currentScoreA,
            scoreB: currentScoreB
        )
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Match Header
                    VStack(spacing: 6) {
                        Text(match.title.uppercased())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(BracketTheme.pickleballLime)
                        
                        Text("Target: First to \(tournament.targetScore) (Win by 2)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 10)
                    
                    // Score Entry Board
                    HStack(spacing: 16) {
                        // Team A
                        VStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(match.teamAName)
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if !match.teamAMembers.isEmpty {
                                    Text(match.teamAMembers)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                Text("DUPR \(String(format: "%.2f", match.teamADUPR))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(BracketTheme.pickleballLime)
                            }
                            .frame(height: 55)
                            
                            Text("\(currentScoreA)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundColor(currentScoreA > currentScoreB ? BracketTheme.pickleballLime : .white)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    if currentScoreA > 0 {
                                        BracketHaptics.light()
                                        currentScoreA -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                Button(action: {
                                    BracketHaptics.light()
                                    currentScoreA += 1
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                }
                            }
                            
                            // DUPR Projection
                            Text("\(projectedDUPRDelta.deltaA >= 0 ? "+" : "")\(String(format: "%.2f", projectedDUPRDelta.deltaA)) DUPR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(projectedDUPRDelta.deltaA >= 0 ? .green : .red)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        Text("VS")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        
                        // Team B
                        VStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(match.teamBName)
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if !match.teamBMembers.isEmpty {
                                    Text(match.teamBMembers)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                Text("DUPR \(String(format: "%.2f", match.teamBDUPR))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(BracketTheme.pickleballLime)
                            }
                            .frame(height: 55)
                            
                            Text("\(currentScoreB)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundColor(currentScoreB > currentScoreA ? BracketTheme.pickleballLime : .white)
                            
                            HStack(spacing: 10) {
                                Button(action: {
                                    if currentScoreB > 0 {
                                        BracketHaptics.light()
                                        currentScoreB -= 1
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                
                                Button(action: {
                                    BracketHaptics.light()
                                    currentScoreB += 1
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                }
                            }
                            
                            // DUPR Projection
                            Text("\(projectedDUPRDelta.deltaB >= 0 ? "+" : "")\(String(format: "%.2f", projectedDUPRDelta.deltaB)) DUPR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(projectedDUPRDelta.deltaB >= 0 ? .green : .red)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)
                    
                    // Quick Score Buttons
                    HStack(spacing: 8) {
                        Button("11 - 9") { setQuickScore(11, 9) }
                        Button("11 - 4") { setQuickScore(11, 4) }
                        Button("15 - 13") { setQuickScore(15, 13) }
                        Button("21 - 18") { setQuickScore(21, 18) }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BracketTheme.pickleballLime)
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    // Save / Advance Button
                    Button(action: {
                        BracketHaptics.success()
                        TournamentBracketEngine.shared.updateMatchScore(
                            match: match,
                            tournament: tournament,
                            allMatches: allMatches,
                            scoreA: currentScoreA,
                            scoreB: currentScoreB
                        )
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: isMatchWon ? "crown.fill" : "checkmark.circle.fill")
                            Text(isMatchWon ? "Confirm & Advance Winner ➔" : "Save Partial Score")
                                .font(.system(size: 15, weight: .black))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isMatchWon ? BracketTheme.pickleballLime : Color.white.opacity(0.2))
                        .foregroundColor(isMatchWon ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Scorekeeper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func setQuickScore(_ a: Int, _ b: Int) {
        BracketHaptics.light()
        currentScoreA = a
        currentScoreB = b
    }
}
