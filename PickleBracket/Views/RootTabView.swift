import SwiftUI
import SwiftData

public struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tournaments: [TournamentModel]
    @Query private var leagues: [LeagueModel]
    
    public init() {}
    
    public var body: some View {
        TabView {
            TournamentListView()
                .tabItem {
                    Label("Tournaments", systemImage: "trophy.fill")
                }
            
            LeagueDashboardView()
                .tabItem {
                    Label("Leagues", systemImage: "calendar.badge.clock")
                }
            
            UserProfileView()
                .tabItem {
                    Label("Profile & DUPR", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(BracketTheme.pickleballLime)
        .onAppear {
            seedSampleDataIfNeeded()
        }
    }
    
    private func seedSampleDataIfNeeded() {
        guard tournaments.isEmpty else { return }
        
        // 1. Create Showcase Tournament
        let tourney = TournamentModel(
            title: "Washington Park Championship 2026",
            format: .singleElimination,
            scoring: .sideOut,
            targetScore: 11,
            teamCount: 8,
            stage: .inProgress
        )
        
        let sampleTeams = [
            TeamModel(name: "Dink Dynamos", p1Name: "Dominic Soriano", p1DUPR: 4.25, p2Name: "Alex Rivera", p2DUPR: 4.40, seedIndex: 1),
            TeamModel(name: "Kitchen Kings", p1Name: "Sarah Chen", p1DUPR: 4.15, p2Name: "Mike Johnson", p2DUPR: 3.85, seedIndex: 2),
            TeamModel(name: "Bay Smashers", p1Name: "Lisa Wang", p1DUPR: 4.65, p2Name: "Kevin Zhang", p2DUPR: 3.90, seedIndex: 3),
            TeamModel(name: "Spin Wizards", p1Name: "Ernie Davis", p1DUPR: 4.50, p2Name: "Arthur Dent", p2DUPR: 3.60, seedIndex: 4),
            TeamModel(name: "Lob Masters", p1Name: "Andrew Smith", p1DUPR: 4.30, p2Name: "Ian Malcolm", p2DUPR: 4.05, seedIndex: 5),
            TeamModel(name: "Court Cutters", p1Name: "Robert Paulson", p1DUPR: 4.70, p2Name: "Monica Geller", p2DUPR: 3.75, seedIndex: 6),
            TeamModel(name: "Paddle Pros", p1Name: "Johan Cruyff", p1DUPR: 4.10, p2Name: "Steve Rogers", p2DUPR: 3.80, seedIndex: 7),
            TeamModel(name: "Net Ninjas", p1Name: "Red Bryant", p1DUPR: 4.35, p2Name: "Michelle Kwan", p2DUPR: 3.95, seedIndex: 8)
        ]
        
        let seeded = DUPRService.shared.seedTeamsByDUPR(teams: sampleTeams)
        tourney.teams = seeded
        
        let matches = TournamentBracketEngine.shared.generateSingleEliminationMatches(
            tournamentId: tourney.id,
            seededTeams: seeded
        )
        tourney.matches = matches
        
        modelContext.insert(tourney)
        for t in seeded { modelContext.insert(t) }
        for m in matches { modelContext.insert(m) }
        
        // 2. Create Showcase League
        if leagues.isEmpty {
            let league = LeagueModel(
                title: "Burlingame Doubles League",
                seasonName: "Fall 2026",
                totalWeeks: 6,
                currentWeek: 1
            )
            league.teams = seeded
            let fixtures = LeagueEngine.shared.generateLeagueSchedule(
                leagueId: league.id,
                teams: seeded,
                totalWeeks: 6
            )
            league.matches = fixtures
            modelContext.insert(league)
            for f in fixtures { modelContext.insert(f) }
        }
        
        try? modelContext.save()
    }
}
