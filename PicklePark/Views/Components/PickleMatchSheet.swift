import SwiftUI

public struct PickleMatchSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var rotationEngine = MatchRotationEngine.shared
    @StateObject private var tourneyEngine = TournamentEngine.shared
    
    @State private var selectedGameFormat: GameFormat = .rotatingDoubles
    
    // Rotating Doubles State
    @State private var newPlayerName: String = ""
    @State private var newPlayerSkill: SkillTier = .intermediate
    @State private var showingResetAlert: Bool = false
    
    // Tournament Setup State
    @State private var newTeamName: String = ""
    @State private var newTeamP1: String = ""
    @State private var newTeamP2: String = ""
    @State private var newTeamP1Skill: SkillTier = .intermediate
    @State private var newTeamP2Skill: SkillTier = .intermediate
    
    // Individual Tourney Player
    @State private var newIndivPlayerName: String = ""
    @State private var newIndivPlayerSkill: SkillTier = .intermediate
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.03, green: 0.16, blue: 0.32)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Game Format Segmented Switcher
                        gameFormatSwitcher
                        
                        if selectedGameFormat == .rotatingDoubles {
                            if !rotationEngine.isSessionActive || rotationEngine.currentRound == nil {
                                rotationSetupView
                            } else {
                                rotationActiveRoundView
                            }
                        } else {
                            tournamentContainerView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(selectedGameFormat == .tournament ? "Park Tournament 🏆" : "PickleMatch 🎾")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppTheme.pickleballLime)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if (selectedGameFormat == .rotatingDoubles && rotationEngine.isSessionActive) ||
                       (selectedGameFormat == .tournament && tourneyEngine.isTournamentActive) {
                        Button("Reset") {
                            showingResetAlert = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .alert("Reset Match Session?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    HapticFeedback.light()
                    if selectedGameFormat == .rotatingDoubles {
                        rotationEngine.resetSession()
                    } else {
                        tourneyEngine.resetTournament()
                    }
                }
            } message: {
                Text("This will clear active scores and return to the configuration screen.")
            }
            .toolbarBackground(Color(red: 0.03, green: 0.16, blue: 0.32), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Game Format Switcher
    
    private var gameFormatSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(GameFormat.allCases) { format in
                Button(action: {
                    HapticFeedback.light()
                    selectedGameFormat = format
                }) {
                    Text(format.rawValue)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedGameFormat == format ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                        .foregroundColor(selectedGameFormat == format ? Color.black : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - ==========================================
    // MARK: - ROTATING DOUBLES
    // MARK: - ==========================================
    
    private var rotationSetupView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("How many courts?")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Pick court count, scoring rules, and player lineup.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            // Court Count Selector
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SELECT ACTIVE COURTS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("\(rotationEngine.activeCourtsForSession * 4) players on court")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.pickleballLime)
                }
                
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { c in
                        Button(action: {
                            HapticFeedback.light()
                            rotationEngine.courtCount = c
                        }) {
                            VStack(spacing: 2) {
                                Text("\(c)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                if rotationEngine.courtCount == c {
                                    Text("✓").font(.system(size: 11, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(rotationEngine.courtCount == c ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                            .foregroundColor(rotationEngine.courtCount == c ? Color.black : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Scoring Format Selector (Side-Out, Rally, DreamBreaker)
            VStack(alignment: .leading, spacing: 8) {
                Text("SCORING FORMAT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 6) {
                    ForEach(ScoringFormat.allCases) { format in
                        Button(action: {
                            HapticFeedback.light()
                            rotationEngine.scoringFormat = format
                            rotationEngine.targetScore = format.defaultTargetScore
                        }) {
                            Text(format.shortName)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(rotationEngine.scoringFormat == format ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                                .foregroundColor(rotationEngine.scoringFormat == format ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                
                Text(rotationEngine.scoringFormat.description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Matchmaking Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("SKILL MATCHMAKING MODE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 6) {
                    ForEach(MatchmakingMode.allCases) { mode in
                        Button(action: {
                            HapticFeedback.light()
                            rotationEngine.matchmakingMode = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(rotationEngine.matchmakingMode == mode ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                                .foregroundColor(rotationEngine.matchmakingMode == mode ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Target Score
            HStack {
                Text("Play To").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                Spacer()
                HStack(spacing: 6) {
                    ForEach([11, 15, 21], id: \.self) { pts in
                        Button(action: { rotationEngine.targetScore = pts; HapticFeedback.light() }) {
                            Text("\(pts) Pts").font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(rotationEngine.targetScore == pts ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                                .foregroundColor(rotationEngine.targetScore == pts ? Color.black : Color.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Players List with Clear All button
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(rotationEngine.matchmakingMode == .social ? "PLAYERS (\(rotationEngine.players.count))" : "PLAYERS (\(rotationEngine.players.count)) · TAP BADGE TO CHANGE SKILL")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    if !rotationEngine.players.isEmpty {
                        Button(action: {
                            HapticFeedback.light()
                            rotationEngine.clearAllPlayers()
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "trash").font(.system(size: 10))
                                Text("Clear All").font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    TextField("Player Name", text: $newPlayerName, prompt: Text("Enter player name...").foregroundColor(Color.white.opacity(0.65)))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.white.opacity(0.15)).foregroundColor(.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onSubmit { addPlayerAction() }
                    
                    if rotationEngine.matchmakingMode != .social {
                        Menu {
                            ForEach(SkillTier.allCases) { tier in
                                Button(tier.label) { newPlayerSkill = tier }
                            }
                        } label: {
                            Text(newPlayerSkill.badge)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 10)
                                .background(skillBadgeColor(newPlayerSkill).opacity(0.25))
                                .foregroundColor(skillBadgeColor(newPlayerSkill))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    
                    Button(action: addPlayerAction) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(AppTheme.pickleballLime)
                    }
                }
                
                if rotationEngine.players.isEmpty {
                    Text("No players added yet. Add at least 4 players to start.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 6) {
                        ForEach(rotationEngine.players) { p in
                            HStack {
                                Text(p.name).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                if rotationEngine.matchmakingMode != .social {
                                    Button(action: {
                                        HapticFeedback.light()
                                        rotationEngine.cyclePlayerSkill(id: p.id)
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(p.skillTier.rawValue).font(.system(size: 10, weight: .heavy))
                                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 8))
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(skillBadgeColor(p.skillTier).opacity(0.2))
                                        .foregroundColor(skillBadgeColor(p.skillTier))
                                        .clipShape(Capsule())
                                    }
                                }
                                Button(action: {
                                    HapticFeedback.light()
                                    rotationEngine.removePlayer(id: p.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Button(action: {
                HapticFeedback.success()
                rotationEngine.startNewSession()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("START MATCH ROTATIONS")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(rotationEngine.players.count >= 4 ? AppTheme.pickleballLime : Color.gray.opacity(0.3))
                .foregroundColor(rotationEngine.players.count >= 4 ? Color.black : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: rotationEngine.players.count >= 4 ? AppTheme.pickleballLime.opacity(0.3) : Color.clear, radius: 8, y: 3)
            }
            .disabled(rotationEngine.players.count < 4)
        }
    }
    
    private var rotationActiveRoundView: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.emerald600).frame(width: 8, height: 8)
                    Text("ROUND \(rotationEngine.currentRoundNumber)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.pickleballLime)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(AppTheme.pickleballLime.opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                Text("\(rotationEngine.scoringFormat.shortName) · First to \(rotationEngine.targetScore)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if let round = rotationEngine.currentRound {
                ForEach(round.matches) { match in
                    rotationMatchCard(match: match)
                }
                
                if !round.sittingPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("🛋️")
                            Text("NEXT UP (SITTING THIS ROUND · \(round.sittingPlayers.count))")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.20))
                        }
                        HStack(spacing: 6) {
                            ForEach(round.sittingPlayers) { sitter in
                                HStack(spacing: 4) {
                                    Text(sitter.name).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                    if rotationEngine.matchmakingMode != .social {
                                        Text(sitter.skillTier.badge)
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(skillBadgeColor(sitter.skillTier))
                                    }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(red: 0.15, green: 0.12, blue: 0.05).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            
            Button(action: {
                HapticFeedback.success()
                rotationEngine.generateNextRound()
            }) {
                HStack(spacing: 8) {
                    Text("NEXT ROUND")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 16))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppTheme.pickleballLime).foregroundColor(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
    
    private func rotationMatchCard(match: CourtMatch) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("COURT \(match.courtNumber)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.pickleballLime)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(AppTheme.pickleballLime.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                if rotationEngine.scoringFormat == .dreamBreaker {
                    let totalPts = match.scoreA + match.scoreB
                    let rotationNum = (totalPts / 4) % 2
                    Text("⚡️ 1v1 Rot \(rotationNum + 1) (Pt #\((totalPts % 4) + 1)/4)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color.amber)
                }
                
                Spacer()
                Text(match.isFinished ? "GAME COMPLETE ✓" : "LIVE")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(match.isFinished ? AppTheme.pickleballLime : .emerald600)
            }
            
            // Team A
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if match.winnerSide == .teamA { Text("👑") }
                        Text(match.teamA.displayNames)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(match.winnerSide == .teamA ? AppTheme.pickleballLime : .white)
                    }
                    HStack(spacing: 4) {
                        Text("Team A").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                        if rotationEngine.matchmakingMode != .social {
                            Text("(\(String(format: "%.1f", match.teamA.combinedRating)) DUPR)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.pickleballLime)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: {
                        HapticFeedback.light()
                        rotationEngine.updateScore(matchId: match.id, team: .teamA, delta: -1)
                    }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.4))
                    }
                    Text("\(match.scoreA)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(match.winnerSide == .teamA ? AppTheme.pickleballLime : .white)
                        .frame(minWidth: 36)
                    Button(action: {
                        HapticFeedback.light()
                        rotationEngine.updateScore(matchId: match.id, team: .teamA, delta: 1)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(AppTheme.pickleballLime)
                    }
                }
            }
            .padding(10)
            .background(match.winnerSide == .teamA ? AppTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text("vs").font(.system(size: 11, weight: .black)).foregroundColor(.white.opacity(0.4))
            
            // Team B
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if match.winnerSide == .teamB { Text("👑") }
                        Text(match.teamB.displayNames)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(match.winnerSide == .teamB ? AppTheme.pickleballLime : .white)
                    }
                    HStack(spacing: 4) {
                        Text("Team B").font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
                        if rotationEngine.matchmakingMode != .social {
                            Text("(\(String(format: "%.1f", match.teamB.combinedRating)) DUPR)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppTheme.pickleballLime)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: {
                        HapticFeedback.light()
                        rotationEngine.updateScore(matchId: match.id, team: .teamB, delta: -1)
                    }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 20)).foregroundColor(.white.opacity(0.4))
                    }
                    Text("\(match.scoreB)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(match.winnerSide == .teamB ? AppTheme.pickleballLime : .white)
                        .frame(minWidth: 36)
                    Button(action: {
                        HapticFeedback.light()
                        rotationEngine.updateScore(matchId: match.id, team: .teamB, delta: 1)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(AppTheme.pickleballLime)
                    }
                }
            }
            .padding(10)
            .background(match.winnerSide == .teamB ? AppTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(Color(red: 0.05, green: 0.20, blue: 0.38))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    // MARK: - ==========================================
    // MARK: - 🏆 PARK TOURNAMENT MODE
    // MARK: - ==========================================
    
    @ViewBuilder
    private var tournamentContainerView: some View {
        switch tourneyEngine.stage {
        case .setup:
            tournamentSetupView
        case .roundRobin:
            tournamentRoundRobinView
        case .playoffs:
            tournamentPlayoffsView
        case .championship:
            tournamentChampionshipView
        case .podium:
            tournamentPodiumView
        }
    }
    
    // 1. Tournament Setup
    private var tournamentSetupView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text("PARK TOURNAMENT MODE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color.amber)
                }
                Text("Pick Tournament Type & Scoring")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Tournament Type Selector (Fixed Teams vs Rotating King of Court)
            VStack(alignment: .leading, spacing: 6) {
                Text("TOURNAMENT FORMAT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 6) {
                    ForEach(TournamentType.allCases) { type in
                        Button(action: {
                            HapticFeedback.light()
                            tourneyEngine.tournamentType = type
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(tourneyEngine.tournamentType == type ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                                .foregroundColor(tourneyEngine.tournamentType == type ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                Text(tourneyEngine.tournamentType.description)
                    .font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
            }
            .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Scoring Format Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("SCORING FORMAT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                HStack(spacing: 6) {
                    ForEach(ScoringFormat.allCases) { format in
                        Button(action: {
                            HapticFeedback.light()
                            tourneyEngine.scoringFormat = format
                            tourneyEngine.targetScore = format.defaultTargetScore
                        }) {
                            Text(format.shortName)
                                .font(.system(size: 11, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(tourneyEngine.scoringFormat == format ? AppTheme.pickleballLime : Color.white.opacity(0.1))
                                .foregroundColor(tourneyEngine.scoringFormat == format ? Color.black : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
            
            if tourneyEngine.tournamentType == .fixedTeams {
                // Fixed Teams Registration
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("REGISTERED TEAMS (\(tourneyEngine.tournamentTeams.count))")
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        if !tourneyEngine.tournamentTeams.isEmpty {
                            Button(action: {
                                HapticFeedback.light()
                                tourneyEngine.clearAllTeams()
                            }) {
                                Text("Clear All").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        TextField("Team Name", text: $newTeamName, prompt: Text("Team Name (e.g. Dink Masters)").foregroundColor(Color.white.opacity(0.65)))
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.white.opacity(0.15)).foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        HStack(spacing: 6) {
                            TextField("Player 1", text: $newTeamP1, prompt: Text("Player 1 Name").foregroundColor(Color.white.opacity(0.65)))
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 10)
                                .background(Color.white.opacity(0.15)).foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            TextField("Player 2", text: $newTeamP2, prompt: Text("Player 2 Name").foregroundColor(Color.white.opacity(0.65)))
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 10)
                                .background(Color.white.opacity(0.15)).foregroundColor(.white)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button(action: addTeamAction) {
                                Text("+ Add")
                                    .font(.system(size: 13, weight: .black))
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(AppTheme.pickleballLime).foregroundColor(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(tourneyEngine.tournamentTeams) { team in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.name).font(.system(size: 13, weight: .bold)).foregroundColor(AppTheme.pickleballLime)
                                    Text(team.displayMembers).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                Button(action: {
                                    HapticFeedback.light()
                                    tourneyEngine.removeTeam(id: team.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(10).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                // Individual Rotating Tournament Player List
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("INDIVIDUAL PLAYERS (\(tourneyEngine.individualPlayers.count))")
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        if !tourneyEngine.individualPlayers.isEmpty {
                            Button(action: {
                                HapticFeedback.light()
                                tourneyEngine.clearAllPlayers()
                            }) {
                                Text("Clear All").font(.system(size: 10, weight: .bold)).foregroundColor(.orange)
                            }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        TextField("Player Name", text: $newIndivPlayerName, prompt: Text("Player Name (e.g. Alex)...").foregroundColor(Color.white.opacity(0.65)))
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.white.opacity(0.15)).foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.25), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onSubmit { addIndivPlayerAction() }
                        
                        Button(action: addIndivPlayerAction) {
                            Text("+ Add")
                                .font(.system(size: 13, weight: .black))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(AppTheme.pickleballLime).foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(tourneyEngine.individualPlayers) { player in
                            HStack {
                                Text(player.name).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                Button(action: {
                                    HapticFeedback.light()
                                    tourneyEngine.removeIndividualPlayer(id: player.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(10).background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(14).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // Start Tournament Button
            let canStart = tourneyEngine.tournamentType == .fixedTeams ? (tourneyEngine.tournamentTeams.count >= 4) : (tourneyEngine.individualPlayers.count >= 4)
            Button(action: {
                HapticFeedback.success()
                tourneyEngine.startTournament()
            }) {
                HStack(spacing: 8) {
                    Text("🏆")
                    Text("KICKOFF TOURNAMENT ROUND ROBIN")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(canStart ? AppTheme.pickleballLime : Color.gray.opacity(0.3))
                .foregroundColor(canStart ? Color.black : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!canStart)
        }
    }
    
    // 2. Stage 1: Round Robin Pool Play View
    private var tournamentRoundRobinView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tourneyEngine.tournamentType == .fixedTeams ? "STAGE 1: TEAM ROUND ROBIN" : "STAGE 1: INDIVIDUAL KING OF COURT")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.pickleballLime)
                    Text("Top 4 advance to Championship")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            
            // Standings Leaderboard Table
            if tourneyEngine.tournamentType == .fixedTeams {
                tournamentStandingsTable
            } else {
                individualStandingsTable
            }
            
            // Round Robin Match Scorecards
            VStack(alignment: .leading, spacing: 10) {
                Text("MATCHES (\(tourneyEngine.roundRobinMatches.filter { $0.isFinished }.count)/\(tourneyEngine.roundRobinMatches.count) Finished)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                ForEach(tourneyEngine.roundRobinMatches) { match in
                    tournamentMatchCard(match: match)
                }
            }
            
            Button(action: {
                HapticFeedback.success()
                tourneyEngine.advanceToPlayoffs()
            }) {
                HStack(spacing: 8) {
                    Text(tourneyEngine.tournamentType == .fixedTeams ? "ADVANCE TOP 4 TO PLAYOFFS" : "🥇 ADVANCE TOP 4 TO GOLD CHAMPIONSHIP")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(tourneyEngine.isRoundRobinComplete ? AppTheme.pickleballLime : Color.gray.opacity(0.4))
                .foregroundColor(tourneyEngine.isRoundRobinComplete ? Color.black : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!tourneyEngine.isRoundRobinComplete)
        }
    }
    
    // Fixed Standings Table
    private var tournamentStandingsTable: some View {
        VStack(spacing: 6) {
            HStack {
                Text("RANK & TEAM").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading)
                Text("W-L").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .center)
                Text("+/-").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .center)
                Text("PTS").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.bottom, 2)
            
            ForEach(Array(tourneyEngine.rankedStandings.enumerated()), id: \.element.id) { index, team in
                HStack {
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(index < 4 ? AppTheme.pickleballLime : .white.opacity(0.4))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(team.name).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                            Text(team.displayMembers).font(.system(size: 9)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(team.wins)-\(team.losses)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(team.wins > team.losses ? AppTheme.pickleballLime : .white)
                        .frame(width: 45, alignment: .center)
                    
                    Text("\(team.pointDifferential >= 0 ? "+" : "")\(team.pointDifferential)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(team.pointDifferential >= 0 ? .emerald600 : .orange)
                        .frame(width: 45, alignment: .center)
                    
                    Text("\(team.pointsWon)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(8)
                .background(index < 4 ? AppTheme.pickleballLime.opacity(0.08) : Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color(red: 0.05, green: 0.20, blue: 0.38))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // Individual Standings Table
    private var individualStandingsTable: some View {
        VStack(spacing: 6) {
            HStack {
                Text("RANK & PLAYER").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading)
                Text("W-L").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .center)
                Text("+/-").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .center)
                Text("PTS").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 45, alignment: .trailing)
            }
            .padding(.horizontal, 10).padding(.bottom, 2)
            
            ForEach(Array(tourneyEngine.rankedIndividualStandings.enumerated()), id: \.element.id) { index, item in
                HStack {
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(index < 4 ? AppTheme.pickleballLime : .white.opacity(0.4))
                            .frame(width: 16)
                        Text(item.player.name).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(item.wins)-\(item.losses)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(item.wins > item.losses ? AppTheme.pickleballLime : .white)
                        .frame(width: 45, alignment: .center)
                    
                    Text("\(item.pointDifferential >= 0 ? "+" : "")\(item.pointDifferential)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(item.pointDifferential >= 0 ? .emerald600 : .orange)
                        .frame(width: 45, alignment: .center)
                    
                    Text("\(item.pointsWon)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(8)
                .background(index < 4 ? AppTheme.pickleballLime.opacity(0.08) : Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color(red: 0.05, green: 0.20, blue: 0.38))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // 3. Stage 2: Playoffs View
    private var tournamentPlayoffsView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STAGE 2: PLAYOFFS SEMI-FINALS")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.pickleballLime)
                Text("Winners advance to the Gold Medal Championship!")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(tourneyEngine.playoffMatches) { match in
                tournamentMatchCard(match: match)
            }
            
            Button(action: {
                HapticFeedback.success()
                tourneyEngine.advanceToChampionship()
            }) {
                HStack(spacing: 8) {
                    Text("🥇 ADVANCE TO CHAMPIONSHIP")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(tourneyEngine.isPlayoffsComplete ? AppTheme.pickleballLime : Color.gray.opacity(0.4))
                .foregroundColor(tourneyEngine.isPlayoffsComplete ? Color.black : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!tourneyEngine.isPlayoffsComplete)
        }
    }
    
    // 4. Stage 3: Championship View
    private var tournamentChampionshipView: some View {
        VStack(spacing: 16) {
            Text("STAGE 3: MEDAL ROUNDS")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(Color.amber)
            
            if let gold = tourneyEngine.championshipMatch {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🥇 GOLD MEDAL CHAMPIONSHIP")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color.amber)
                    tournamentMatchCard(match: gold)
                }
            }
            
            if let bronze = tourneyEngine.bronzeMatch {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🥉 BRONZE MEDAL (3RD PLACE)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Color.orange)
                    tournamentMatchCard(match: bronze)
                }
            }
            
            Button(action: {
                HapticFeedback.success()
                tourneyEngine.finalizePodium()
            }) {
                HStack(spacing: 8) {
                    Text("🏆")
                    Text("FINALIZE & CROWN CHAMPIONS")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(tourneyEngine.isChampionshipComplete ? AppTheme.pickleballLime : Color.gray.opacity(0.4))
                .foregroundColor(tourneyEngine.isChampionshipComplete ? Color.black : Color.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!tourneyEngine.isChampionshipComplete)
        }
    }
    
    // 5. Stage 4: Podium View
    private var tournamentPodiumView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🏆")
                    .font(.system(size: 50))
                Text("TOURNAMENT CHAMPIONS")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.pickleballLime)
                Text("Congratulations to all teams at Washington Park!")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if let gold = tourneyEngine.goldWinner {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text("🥇")
                        Text("1ST PLACE · GOLD CHAMPIONS")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(Color.amber)
                    }
                    Text(gold.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(gold.displayMembers)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.pickleballLime)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color(red: 0.18, green: 0.14, blue: 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.amber, lineWidth: 2))
            }
            
            HStack(spacing: 10) {
                if let silver = tourneyEngine.silverWinner {
                    VStack(spacing: 4) {
                        Text("🥈 2nd Place")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text(silver.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(silver.displayMembers)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                if let bronze = tourneyEngine.bronzeWinner {
                    VStack(spacing: 4) {
                        Text("🥉 3rd Place")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text(bronze.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(bronze.displayMembers)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Button(action: {
                HapticFeedback.light()
                tourneyEngine.resetTournament()
            }) {
                Text("Start New Tournament")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.pickleballLime)
                    .padding(.vertical, 8)
            }
        }
    }
    
    // Tournament Match Card
    private func tournamentMatchCard(match: TournamentMatch) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(match.title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.pickleballLime)
                
                if tourneyEngine.scoringFormat == .dreamBreaker {
                    let pts = match.scoreA + match.scoreB
                    Text("⚡️ 1v1 Rot \((pts / 4) + 1)")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color.amber)
                }
                
                Spacer()
                Text(match.isFinished ? "FINISHED ✓" : "LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(match.isFinished ? AppTheme.pickleballLime : .emerald600)
            }
            
            // Team A
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if match.winnerTeamId == match.teamA.id { Text("👑") }
                        Text(match.teamA.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(match.winnerTeamId == match.teamA.id ? AppTheme.pickleballLime : .white)
                    }
                    Text(match.teamA.displayMembers).font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: {
                        HapticFeedback.light()
                        tourneyEngine.updateMatchScore(matchId: match.id, team: .teamA, delta: -1)
                    }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.4))
                    }
                    Text("\(match.scoreA)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(match.winnerTeamId == match.teamA.id ? AppTheme.pickleballLime : .white)
                        .frame(minWidth: 28)
                    Button(action: {
                        HapticFeedback.light()
                        tourneyEngine.updateMatchScore(matchId: match.id, team: .teamA, delta: 1)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppTheme.pickleballLime)
                    }
                }
            }
            .padding(8)
            .background(match.winnerTeamId == match.teamA.id ? AppTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Team B
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        if match.winnerTeamId == match.teamB.id { Text("👑") }
                        Text(match.teamB.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(match.winnerTeamId == match.teamB.id ? AppTheme.pickleballLime : .white)
                    }
                    Text(match.teamB.displayMembers).font(.system(size: 10)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(action: {
                        HapticFeedback.light()
                        tourneyEngine.updateMatchScore(matchId: match.id, team: .teamB, delta: -1)
                    }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.4))
                    }
                    Text("\(match.scoreB)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(match.winnerTeamId == match.teamB.id ? AppTheme.pickleballLime : .white)
                        .frame(minWidth: 28)
                    Button(action: {
                        HapticFeedback.light()
                        tourneyEngine.updateMatchScore(matchId: match.id, team: .teamB, delta: 1)
                    }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(AppTheme.pickleballLime)
                    }
                }
            }
            .padding(8)
            .background(match.winnerTeamId == match.teamB.id ? AppTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(12)
        .background(Color(red: 0.05, green: 0.20, blue: 0.38))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func addPlayerAction() {
        guard !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        HapticFeedback.light()
        rotationEngine.addPlayer(name: newPlayerName, skill: newPlayerSkill)
        newPlayerName = ""
    }
    
    private func addTeamAction() {
        guard !newTeamName.isEmpty, !newTeamP1.isEmpty, !newTeamP2.isEmpty else { return }
        HapticFeedback.light()
        tourneyEngine.addTeam(name: newTeamName, p1Name: newTeamP1, p2Name: newTeamP2, skill1: newTeamP1Skill, skill2: newTeamP2Skill)
        newTeamName = ""
        newTeamP1 = ""
        newTeamP2 = ""
    }
    
    private func addIndivPlayerAction() {
        guard !newIndivPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        HapticFeedback.light()
        tourneyEngine.addIndividualPlayer(name: newIndivPlayerName, skill: newIndivPlayerSkill)
        newIndivPlayerName = ""
    }
    
    private func skillBadgeColor(_ tier: SkillTier) -> Color {
        switch tier {
        case .beginner: return Color.emerald600
        case .intermediate: return Color(red: 0.95, green: 0.70, blue: 0.15)
        case .advanced: return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .pro: return Color(red: 0.70, green: 0.40, blue: 0.95)
        }
    }
}

private extension Color {
    static let emerald600 = Color(red: 0.02, green: 0.75, blue: 0.45)
    static let amber = Color(red: 0.95, green: 0.75, blue: 0.15)
}
