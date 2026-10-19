import SwiftUI
import SwiftData

public struct LeagueStandingsView: View {
    let standings: [LeagueStandingItem]
    
    public var body: some View {
        VStack(spacing: 8) {
            // Table Header
            HStack {
                Text("RANK").frame(width: 35, alignment: .leading)
                Text("TEAM").frame(minWidth: 100, alignment: .leading)
                Spacer()
                Text("W-L").frame(width: 40, alignment: .center)
                Text("+/-").frame(width: 40, alignment: .center)
                Text("PTS").frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            
            // Standings Rows
            ForEach(standings) { item in
                HStack {
                    HStack(spacing: 4) {
                        if item.rank == 1 {
                            Text("🥇").font(.system(size: 11))
                        } else if item.rank == 2 {
                            Text("🥈").font(.system(size: 11))
                        } else if item.rank == 3 {
                            Text("🥉").font(.system(size: 11))
                        } else {
                            Text("#\(item.rank)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 35, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.teamName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(item.rank <= 4 ? BracketTheme.pickleballLime : .white)
                            .lineLimit(1)
                        Text(item.members)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 100, alignment: .leading)
                    
                    Spacer()
                    
                    Text("\(item.wins)-\(item.losses)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, alignment: .center)
                    
                    Text("\(item.pointDiff >= 0 ? "+" : "")\(item.pointDiff)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.pointDiff >= 0 ? .green : .red)
                        .frame(width: 40, alignment: .center)
                    
                    Text("\(item.leaguePoints)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(BracketTheme.pickleballLime)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(item.rank <= 4 ? BracketTheme.cardNavy : Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(item.rank == 1 ? BracketTheme.accentGold.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal)
    }
}

public struct LeagueDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LeagueModel.createdAt, order: .reverse) private var leagues: [LeagueModel]
    @Query private var allMatches: [BracketMatchModel]
    
    @State private var isShowingCreate = false
    @State private var selectedLeague: LeagueModel?
    @State private var selectedWeek: Int = 1
    @State private var selectedTab: Int = 0 // 0: Standings, 1: Weekly Fixtures, 2: Playoffs
    @State private var scoringMatch: BracketMatchModel?
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                if leagues.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 54))
                            .foregroundColor(BracketTheme.pickleballLime.opacity(0.8))
                        
                        Text("No Active Leagues")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Organize multi-week seasons, schedule weekly matchups, track live standings, and seed playoff brackets!")
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
                                Text("Create League")
                                    .font(.system(size: 15, weight: .black))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(BracketTheme.pickleballLime)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                        }
                    }
                } else {
                    let activeLeague = selectedLeague ?? leagues.first!
                    let leagueMatches = allMatches.filter { $0.tournamentId == activeLeague.id }
                    let standings = LeagueEngine.shared.calculateStandings(teams: activeLeague.teams, matches: leagueMatches)
                    
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(activeLeague.title)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("\(activeLeague.seasonName) • \(activeLeague.totalWeeks) Weeks Season")
                                        .font(.system(size: 11))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                }
                                Spacer()
                                
                                Button(action: {
                                    BracketHaptics.light()
                                    isShowingCreate = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                }
                            }
                            
                            Picker("Tab", selection: $selectedTab) {
                                Text("📊 Standings").tag(0)
                                Text("📅 Fixtures").tag(1)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(BracketTheme.cardNavy)
                        
                        ScrollView {
                            if selectedTab == 0 {
                                // Standings Table
                                VStack(spacing: 16) {
                                    LeagueStandingsView(standings: standings)
                                        .padding(.top, 10)
                                    
                                    // Playoff Generation Button
                                    Button(action: {
                                        generatePlayoffsFromStandings(league: activeLeague, standings: standings)
                                    }) {
                                        HStack {
                                            Image(systemName: "crown.fill")
                                            Text("Generate Top-4 Playoff Bracket ➔")
                                                .font(.system(size: 14, weight: .black))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(BracketTheme.accentGold)
                                        .foregroundColor(.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                // Weekly Fixtures
                                VStack(spacing: 14) {
                                    // Week selector pills
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(1...activeLeague.totalWeeks, id: \.self) { week in
                                                Button(action: {
                                                    BracketHaptics.light()
                                                    selectedWeek = week
                                                }) {
                                                    Text("Week \(week)")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 8)
                                                        .background(selectedWeek == week ? BracketTheme.pickleballLime : Color.white.opacity(0.1))
                                                        .foregroundColor(selectedWeek == week ? .black : .white)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding(.top, 10)
                                    
                                    // Fixture cards for selected week
                                    let weekMatches = leagueMatches.filter { $0.roundIndex == selectedWeek }
                                    ForEach(weekMatches) { match in
                                        Button(action: {
                                            BracketHaptics.light()
                                            scoringMatch = match
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("COURT \(match.courtNumber)")
                                                        .font(.system(size: 9, weight: .black))
                                                        .foregroundColor(BracketTheme.pickleballLime)
                                                    
                                                    HStack {
                                                        Text(match.teamAName)
                                                            .font(.system(size: 13, weight: match.scoreA > match.scoreB ? .black : .bold))
                                                            .foregroundColor(match.scoreA > match.scoreB ? BracketTheme.pickleballLime : .white)
                                                        Spacer()
                                                        Text("\(match.scoreA)")
                                                            .font(.system(size: 15, weight: .black))
                                                            .foregroundColor(match.scoreA > match.scoreB ? BracketTheme.pickleballLime : .white)
                                                    }
                                                    
                                                    HStack {
                                                        Text(match.teamBName)
                                                            .font(.system(size: 13, weight: match.scoreB > match.scoreA ? .black : .bold))
                                                            .foregroundColor(match.scoreB > match.scoreA ? BracketTheme.pickleballLime : .white)
                                                        Spacer()
                                                        Text("\(match.scoreB)")
                                                            .font(.system(size: 15, weight: .black))
                                                            .foregroundColor(match.scoreB > match.scoreA ? BracketTheme.pickleballLime : .white)
                                                    }
                                                }
                                                
                                                Image(systemName: "pencil.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(match.isFinished ? BracketTheme.pickleballLime : .white.opacity(0.4))
                                            }
                                            .padding(14)
                                            .background(BracketTheme.cardNavy)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("📅 Leagues")
            .sheet(isPresented: $isShowingCreate) {
                CreateLeagueView()
            }
            .sheet(item: $scoringMatch) { match in
                LeagueScoreSheet(match: match)
            }
        }
    }
    
    private func generatePlayoffsFromStandings(league: LeagueModel, standings: [LeagueStandingItem]) {
        BracketHaptics.success()
        let topTeams = standings.prefix(4).map { item in
            TeamModel(name: item.teamName, p1Name: item.members, p1DUPR: item.combinedDUPR)
        }
        
        let playoffTourney = TournamentModel(
            title: "\(league.title) - Championship Playoffs",
            format: .singleElimination,
            scoring: .sideOut,
            targetScore: 11,
            teamCount: 4,
            stage: .inProgress
        )
        
        let playoffMatches = TournamentBracketEngine.shared.generateSingleEliminationMatches(
            tournamentId: playoffTourney.id,
            seededTeams: Array(topTeams)
        )
        playoffTourney.teams = Array(topTeams)
        playoffTourney.matches = playoffMatches
        
        modelContext.insert(playoffTourney)
        for t in topTeams { modelContext.insert(t) }
        for m in playoffMatches { modelContext.insert(m) }
        try? modelContext.save()
    }
}

public struct LeagueScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    let match: BracketMatchModel
    @State private var scoreA: Int
    @State private var scoreB: Int
    
    public init(match: BracketMatchModel) {
        self.match = match
        _scoreA = State(initialValue: match.scoreA)
        _scoreB = State(initialValue: match.scoreB)
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text(match.title.uppercased())
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(BracketTheme.pickleballLime)
                        .padding(.top, 20)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text(match.teamAName).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                            Text("\(scoreA)").font(.system(size: 40, weight: .black)).foregroundColor(.white)
                            HStack {
                                Button("-") { if scoreA > 0 { scoreA -= 1 } }.buttonStyle(.bordered)
                                Button("+") { scoreA += 1 }.buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        VStack(spacing: 8) {
                            Text(match.teamBName).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                            Text("\(scoreB)").font(.system(size: 40, weight: .black)).foregroundColor(.white)
                            HStack {
                                Button("-") { if scoreB > 0 { scoreB -= 1 } }.buttonStyle(.bordered)
                                Button("+") { scoreB += 1 }.buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: {
                        BracketHaptics.success()
                        match.scoreA = scoreA
                        match.scoreB = scoreB
                        match.isFinished = (scoreA > 0 || scoreB > 0) && abs(scoreA - scoreB) >= 2
                        dismiss()
                    }) {
                        Text("Save Match Result")
                            .font(.system(size: 15, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(BracketTheme.pickleballLime)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
            .navigationTitle("Score Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }
}
