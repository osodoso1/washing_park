import SwiftUI
import SwiftData

public struct CreateLeagueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var leagueTitle = "Burlingame Pickleball League"
    @State private var seasonName = "Fall 2026"
    @State private var totalWeeks = 6
    @State private var registeredTeams: [TeamModel] = []
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("📅 NEW LEAGUE SEASON")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(BracketTheme.pickleballLime)
                            Text("Setup Season & Fixtures")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        
                        // Title & Season
                        VStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("LEAGUE NAME")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("League Name", text: $leagueTitle, prompt: Text("e.g. Washington Park Doubles League").foregroundColor(Color.white.opacity(0.6)))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(12)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SEASON / DIVISION")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                TextField("Season Name", text: $seasonName, prompt: Text("e.g. Fall 2026 - DUPR 4.0+").foregroundColor(Color.white.opacity(0.6)))
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(12)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Total Weeks
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SEASON LENGTH (WEEKS)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 8) {
                                ForEach([4, 6, 8, 10], id: \.self) { weeks in
                                    Button(action: {
                                        BracketHaptics.light()
                                        totalWeeks = weeks
                                    }) {
                                        Text("\(weeks) Wks")
                                            .font(.system(size: 13, weight: .black))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(totalWeeks == weeks ? BracketTheme.pickleballLime : Color.white.opacity(0.1))
                                            .foregroundColor(totalWeeks == weeks ? .black : .white)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Teams
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("REGISTERED LEAGUE TEAMS (\(registeredTeams.count))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Button("Load 6 Teams") { loadDefaultTeams() }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(BracketTheme.pickleballLime)
                            }
                            
                            ForEach(registeredTeams) { team in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(team.name).font(.system(size: 13, weight: .bold)).foregroundColor(BracketTheme.pickleballLime)
                                        Text(team.displayMembers).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                    Text("\(String(format: "%.2f", team.combinedDUPR)) DUPR")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Submit Button
                        Button(action: createLeagueAction) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Generate Full League Season ➔")
                                    .font(.system(size: 15, weight: .black))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BracketTheme.pickleballLime)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("New League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
            .onAppear {
                if registeredTeams.isEmpty { loadDefaultTeams() }
            }
        }
    }
    
    private func loadDefaultTeams() {
        let presets = [
            ("Dink Dynamos", "Dominic Soriano", 4.25, "Alex Rivera", 4.40),
            ("Kitchen Kings", "Sarah Chen", 4.15, "Mike Johnson", 3.85),
            ("Bay Smashers", "Lisa Wang", 4.65, "Kevin Zhang", 3.90),
            ("Spin Wizards", "Ernie Davis", 4.50, "Arthur Dent", 3.60),
            ("Lob Masters", "Andrew Smith", 4.30, "Ian Malcolm", 4.05),
            ("Court Cutters", "Robert Paulson", 4.70, "Monica Geller", 3.75)
        ]
        
        registeredTeams = presets.map {
            TeamModel(name: $0.0, p1Name: $0.1, p1DUPR: $0.2, p2Name: $0.3, p2DUPR: $0.4)
        }
    }
    
    private func createLeagueAction() {
        BracketHaptics.success()
        let league = LeagueModel(
            title: leagueTitle,
            seasonName: seasonName,
            totalWeeks: totalWeeks,
            currentWeek: 1
        )
        
        league.teams = registeredTeams
        let fixtures = LeagueEngine.shared.generateLeagueSchedule(
            leagueId: league.id,
            teams: registeredTeams,
            totalWeeks: totalWeeks
        )
        league.matches = fixtures
        
        modelContext.insert(league)
        for t in registeredTeams { modelContext.insert(t) }
        for f in fixtures { modelContext.insert(f) }
        try? modelContext.save()
        
        dismiss()
    }
}
