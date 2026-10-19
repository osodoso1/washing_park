import SwiftUI
import SwiftData

public struct TournamentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TournamentModel.createdAt, order: .reverse) private var tournaments: [TournamentModel]
    
    @State private var isShowingCreate = false
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                if tournaments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 54))
                            .foregroundColor(BracketTheme.pickleballLime.opacity(0.8))
                        
                        Text("No Tournaments Yet")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Create your first knockout bracket, seed teams with DUPR ratings, and track live scores!")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button(action: {
                            BracketHaptics.light()
                            isShowingCreate = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create Tournament")
                                    .font(.system(size: 15, weight: .black))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(BracketTheme.pickleballLime)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 10)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(tournaments) { tourney in
                                NavigationLink(destination: TournamentDetailView(tournament: tourney)) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(tourney.title)
                                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                                    .foregroundColor(.white)
                                                
                                                HStack(spacing: 6) {
                                                    Text(tourney.format.rawValue)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(BracketTheme.pickleballLime)
                                                    Text("•")
                                                        .foregroundColor(.white.opacity(0.4))
                                                    Text("\(tourney.teamCount) Teams")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                            }
                                            Spacer()
                                            
                                            if let gold = tourney.goldWinnerName {
                                                HStack(spacing: 4) {
                                                    Text("👑")
                                                    Text(gold)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(BracketTheme.accentGold)
                                                }
                                                .padding(.horizontal, 8).padding(.vertical, 4)
                                                .background(BracketTheme.accentGold.opacity(0.15))
                                                .clipShape(Capsule())
                                            } else {
                                                Text("IN PROGRESS")
                                                    .font(.system(size: 9, weight: .black))
                                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                                    .background(BracketTheme.pickleballLime.opacity(0.2))
                                                    .foregroundColor(BracketTheme.pickleballLime)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        
                                        Divider().background(Color.white.opacity(0.1))
                                        
                                        HStack {
                                            HStack(spacing: 4) {
                                                Image(systemName: "sportscourt.fill")
                                                    .font(.system(size: 11))
                                                Text(tourney.scoring.shortName)
                                                    .font(.system(size: 11, weight: .semibold))
                                            }
                                            .foregroundColor(.white.opacity(0.7))
                                            
                                            Spacer()
                                            
                                            Text("View Bracket ➔")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(BracketTheme.pickleballLime)
                                        }
                                    }
                                    .padding(16)
                                    .background(BracketTheme.cardNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("🏆 Tournaments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        BracketHaptics.light()
                        isShowingCreate = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BracketTheme.pickleballLime)
                    }
                }
            }
            .sheet(isPresented: $isShowingCreate) {
                CreateTournamentView()
            }
        }
    }
}
