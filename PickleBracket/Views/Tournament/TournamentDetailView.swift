import SwiftUI
import SwiftData

public struct TournamentDetailView: View {
    @Bindable var tournament: TournamentModel
    @Query private var allMatches: [BracketMatchModel]
    
    @State private var selectedTab: Int = 0 // 0: Bracket Tree, 1: Matches, 2: Teams
    @State private var selectedMatchForScoring: BracketMatchModel?
    @State private var isShowingPodium = false
    
    private var tournamentMatches: [BracketMatchModel] {
        allMatches.filter { $0.tournamentId == tournament.id }
    }
    
    public var body: some View {
        ZStack {
            BracketTheme.deepNavy.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Info Bar
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tournament.title)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 6) {
                                Text(tournament.format.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BracketTheme.pickleballLime)
                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))
                                Text(tournament.scoring.shortName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.4))
                                Text("Play to \(tournament.targetScore)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        if tournament.stage == .podium || tournament.goldWinnerName != nil {
                            Button(action: {
                                BracketHaptics.light()
                                isShowingPodium = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("👑")
                                    Text("Podium").font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(BracketTheme.accentGold)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Segmented View Selector
                    Picker("View", selection: $selectedTab) {
                        Text("🌳 Bracket Tree").tag(0)
                        Text("📋 Match List").tag(1)
                        Text("👥 Teams & DUPR").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(BracketTheme.cardNavy)
                
                // Tab Content
                if selectedTab == 0 {
                    // Tree View Canvas (Image 2)
                    BracketTreeCanvas(
                        tournament: tournament,
                        matches: tournamentMatches
                    ) { match in
                        selectedMatchForScoring = match
                    }
                } else if selectedTab == 1 {
                    // Match List View
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(tournamentMatches) { match in
                                Button(action: {
                                    BracketHaptics.light()
                                    selectedMatchForScoring = match
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(match.title.uppercased())
                                                .font(.system(size: 10, weight: .black, design: .rounded))
                                                .foregroundColor(BracketTheme.pickleballLime)
                                            
                                            HStack {
                                                Text(match.teamAName)
                                                    .font(.system(size: 14, weight: match.winnerId == match.teamAId ? .black : .bold))
                                                    .foregroundColor(match.winnerId == match.teamAId ? BracketTheme.pickleballLime : .white)
                                                Spacer()
                                                Text("\(match.scoreA)")
                                                    .font(.system(size: 16, weight: .black))
                                                    .foregroundColor(match.winnerId == match.teamAId ? BracketTheme.pickleballLime : .white)
                                            }
                                            
                                            HStack {
                                                Text(match.teamBName)
                                                    .font(.system(size: 14, weight: match.winnerId == match.teamBId ? .black : .bold))
                                                    .foregroundColor(match.winnerId == match.teamBId ? BracketTheme.pickleballLime : .white)
                                                Spacer()
                                                Text("\(match.scoreB)")
                                                    .font(.system(size: 16, weight: .black))
                                                    .foregroundColor(match.winnerId == match.teamBId ? BracketTheme.pickleballLime : .white)
                                            }
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                    .padding(14)
                                    .background(BracketTheme.cardNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(match.isFinished ? BracketTheme.pickleballLime.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                } else {
                    // Teams & DUPR Seeding List
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(tournament.teams.sorted { $0.seedIndex < $1.seedIndex }) { team in
                                HStack {
                                    Text("#\(team.seedIndex)")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                        .frame(width: 35, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(team.name)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                        Text(team.displayMembers)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(String(format: "%.2f", team.combinedDUPR)) DUPR")
                                            .font(.system(size: 11, weight: .black))
                                            .foregroundColor(BracketTheme.pickleballLime)
                                        Text("Combined")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                .padding(14)
                                .background(BracketTheme.cardNavy)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMatchForScoring) { match in
            MatchScoreSheet(
                match: match,
                tournament: tournament,
                allMatches: tournamentMatches
            )
        }
        .sheet(isPresented: $isShowingPodium) {
            PodiumView(
                goldWinner: tournament.goldWinnerName ?? "Gold Winner",
                silverWinner: tournament.silverWinnerName ?? "Silver Runner-Up",
                bronzeWinner: tournament.bronzeWinnerName ?? "Bronze 3rd Place",
                tournamentTitle: tournament.title
            ) {
                isShowingPodium = false
            }
        }
    }
}
