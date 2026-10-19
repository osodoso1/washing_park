import SwiftUI
import SwiftData

public struct CreateTournamentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var tournamentTitle = "Washington Park Open 2026"
    @State private var selectedFormat: TournamentFormat = .singleElimination
    @State private var selectedScoring: TournamentScoring = .sideOut
    @State private var targetScore = 11
    @State private var bracketSize = 8
    
    // Team registration inputs
    @State private var newTeamName = ""
    @State private var newP1Name = ""
    @State private var newP1DUPR = 3.5
    @State private var newP2Name = ""
    @State private var newP2DUPR = 3.5
    
    @State private var registeredTeams: [TeamModel] = []
    @State private var navigateToDetail: TournamentModel?
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 4) {
                            Text("⚡️ NEW TOURNAMENT")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(BracketTheme.pickleballLime)
                            Text("Create Bracket & Seed DUPRs")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        
                        // Tournament Title
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TOURNAMENT NAME")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            TextField("Tournament Name", text: $tournamentTitle, prompt: Text("e.g. Bay Area Dink Championship").foregroundColor(Color.white.opacity(0.6)))
                                .font(.system(size: 15, weight: .semibold))
                                .padding(12)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Format Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TOURNAMENT FORMAT")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            ForEach(TournamentFormat.allCases) { format in
                                Button(action: {
                                    BracketHaptics.light()
                                    selectedFormat = format
                                }) {
                                    HStack {
                                        Image(systemName: format.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(selectedFormat == format ? .black : BracketTheme.pickleballLime)
                                            .frame(width: 26)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(format.rawValue)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(selectedFormat == format ? .black : .white)
                                            Text(format.description)
                                                .font(.system(size: 10))
                                                .foregroundColor(selectedFormat == format ? .black.opacity(0.7) : .white.opacity(0.6))
                                        }
                                        Spacer()
                                        if selectedFormat == format {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .padding(12)
                                    .background(selectedFormat == format ? BracketTheme.pickleballLime : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Scoring & Bracket Size
                        HStack(spacing: 12) {
                            // Bracket Size
                            VStack(alignment: .leading, spacing: 6) {
                                Text("BRACKET SIZE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                HStack(spacing: 6) {
                                    ForEach([4, 8, 16], id: \.self) { size in
                                        Button(action: {
                                            BracketHaptics.light()
                                            bracketSize = size
                                        }) {
                                            Text("\(size)")
                                                .font(.system(size: 13, weight: .black))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(bracketSize == size ? BracketTheme.pickleballLime : Color.white.opacity(0.1))
                                                .foregroundColor(bracketSize == size ? .black : .white)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(BracketTheme.cardNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            // Target Score
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PLAY TO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                HStack(spacing: 6) {
                                    ForEach([11, 15, 21], id: \.self) { pts in
                                        Button(action: {
                                            BracketHaptics.light()
                                            targetScore = pts
                                        }) {
                                            Text("\(pts)")
                                                .font(.system(size: 13, weight: .black))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(targetScore == pts ? BracketTheme.pickleballLime : Color.white.opacity(0.1))
                                                .foregroundColor(targetScore == pts ? .black : .white)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(BracketTheme.cardNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Team Registration & Presets
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TEAMS & DUPR SEEDING (\(registeredTeams.count)/\(bracketSize))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Button("Auto-Fill 8 DUPR Teams") {
                                    loadPresetDUPRTeams(count: bracketSize)
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(BracketTheme.pickleballLime)
                            }
                            
                            // Input fields
                            VStack(spacing: 8) {
                                TextField("Team Name", text: $newTeamName, prompt: Text("Team Name (e.g. Dink Dynamos)").foregroundColor(Color.white.opacity(0.65)))
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(10)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                HStack(spacing: 6) {
                                    TextField("Player 1", text: $newP1Name, prompt: Text("Player 1").foregroundColor(Color.white.opacity(0.65)))
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(8)
                                        .background(Color.white.opacity(0.12))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    TextField("Player 2", text: $newP2Name, prompt: Text("Player 2").foregroundColor(Color.white.opacity(0.65)))
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(8)
                                        .background(Color.white.opacity(0.12))
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button(action: addTeamManual) {
                                        Text("+ Add")
                                            .font(.system(size: 12, weight: .black))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(BracketTheme.pickleballLime)
                                            .foregroundColor(.black)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            
                            // Registered Team Chips
                            VStack(spacing: 6) {
                                ForEach(registeredTeams) { team in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(team.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(BracketTheme.pickleballLime)
                                            Text(team.displayMembers)
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Text("\(String(format: "%.2f", team.combinedDUPR)) DUPR")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Button(action: {
                                            registeredTeams.removeAll { $0.id == team.id }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(14)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Create Bracket Button
                        Button(action: createTournamentAndGenerateTree) {
                            HStack {
                                Image(systemName: "point.topleft.down.curvedto.point.filled.bottomright.up")
                                Text("Generate DUPR Bracket Tree ➔")
                                    .font(.system(size: 16, weight: .black))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(BracketTheme.pickleballLime)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("New Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                if registeredTeams.isEmpty {
                    loadPresetDUPRTeams(count: 8)
                }
            }
        }
    }
    
    private func addTeamManual() {
        guard !newTeamName.isEmpty, !newP1Name.isEmpty else { return }
        BracketHaptics.light()
        
        let p1Lookup = DUPRService.shared.lookupOrCreatePlayer(name: newP1Name)
        let p2Lookup = newP2Name.isEmpty ? nil : DUPRService.shared.lookupOrCreatePlayer(name: newP2Name)
        
        let team = TeamModel(
            name: newTeamName,
            p1Name: newP1Name,
            p1DUPR: p1Lookup.doublesRating,
            p2Name: newP2Name,
            p2DUPR: p2Lookup?.doublesRating ?? 3.5
        )
        registeredTeams.append(team)
        newTeamName = ""
        newP1Name = ""
        newP2Name = ""
    }
    
    private func loadPresetDUPRTeams(count: Int) {
        BracketHaptics.light()
        let presets = [
            ("Dink Dynamos", "Dominic Soriano", 4.25, "Alex Rivera", 4.40),
            ("Kitchen Kings", "Sarah Chen", 4.15, "Mike Johnson", 3.85),
            ("Bay Smashers", "Lisa Wang", 4.65, "Kevin Zhang", 3.90),
            ("Spin Wizards", "Ernie Davis", 4.50, "Arthur Dent", 3.60),
            ("Lob Masters", "Andrew Smith", 4.30, "Ian Malcolm", 4.05),
            ("Court Cutters", "Robert Paulson", 4.70, "Monica Geller", 3.75),
            ("Paddle Pros", "Johan Cruyff", 4.10, "Steve Rogers", 3.80),
            ("Net Ninjas", "Red Bryant", 4.35, "Michelle Kwan", 3.95),
            ("Ace Attackers", "Drew Barry", 3.70, "Bert Cooper", 3.65),
            ("Speedy Dinkers", "Adrian Paul", 4.20, "Scott Pilgrim", 3.90),
            ("Drop Shot Divas", "Rachel Green", 4.00, "Phoebe Buffay", 3.80),
            ("Power Hitters", "Tony Stark", 4.80, "Bruce Banner", 4.50),
            ("Baseline Beasts", "Clark Kent", 4.60, "Lois Lane", 4.10),
            ("Erne Experts", "Peter Parker", 4.30, "Miles Morales", 4.25),
            ("Fire Dinkers", "Diana Prince", 4.75, "Steve Trevor", 4.00),
            ("Volley Vipers", "Wally West", 4.15, "Barry Allen", 4.20)
        ]
        
        registeredTeams = presets.prefix(count).map { item in
            TeamModel(
                name: item.0,
                p1Name: item.1,
                p1DUPR: item.2,
                p2Name: item.3,
                p2DUPR: item.4
            )
        }
    }
    
    private func createTournamentAndGenerateTree() {
        BracketHaptics.success()
        
        let tournament = TournamentModel(
            title: tournamentTitle,
            format: selectedFormat,
            scoring: selectedScoring,
            targetScore: targetScore,
            teamCount: registeredTeams.count,
            stage: .inProgress
        )
        
        // Seed teams by DUPR
        let seeded = DUPRService.shared.seedTeamsByDUPR(teams: registeredTeams)
        tournament.teams = seeded
        
        // Generate matches for the tree
        let generatedMatches = TournamentBracketEngine.shared.generateSingleEliminationMatches(
            tournamentId: tournament.id,
            seededTeams: seeded
        )
        tournament.matches = generatedMatches
        
        modelContext.insert(tournament)
        for t in seeded { modelContext.insert(t) }
        for m in generatedMatches { modelContext.insert(m) }
        try? modelContext.save()
        
        dismiss()
    }
}
