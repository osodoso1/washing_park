import SwiftUI

public struct LeaderboardCard: View {
    @ObservedObject private var leaderboard = LeaderboardManager.shared
    
    @State private var isShowingFullLeaderboard: Bool = false
    @State private var isShowingEditProfile: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.95, green: 0.70, blue: 0.10))
                    
                    Text("COMMUNITY LEADERBOARD")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.05))
                }
                
                Spacer()
                
                Button(action: {
                    HapticFeedback.light()
                    isShowingFullLeaderboard = true
                }) {
                    HStack(spacing: 3) {
                        Text("View Rankings")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            
            // Snack MVP Spotlight Banner (Top contributor)
            if let mvp = leaderboard.snackMVP(for: leaderboard.selectedScope) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.98, green: 0.93, blue: 0.82))
                            .frame(width: 44, height: 44)
                        Text(mvp.avatarEmoji.isEmpty ? "👑" : mvp.avatarEmoji)
                            .font(.system(size: 22))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(mvp.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("\(mvp.points(for: leaderboard.selectedScope)) pts")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.05))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.98, green: 0.92, blue: 0.80))
                                .clipShape(Capsule())
                        }
                        
                        Text("🍪 Bring them: \(mvp.favoriteSnack)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(10)
                .background(Color(red: 0.99, green: 0.98, blue: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.95, green: 0.88, blue: 0.70), lineWidth: 1)
                )
            }
            
            // Your Points & Edit Profile Action
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.pickleballGreen)
                    
                    Text("Your Score: \(leaderboard.currentUser.monthlyPoints) pts this month (\(leaderboard.currentUser.allTimePoints) all-time)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                Button(action: {
                    HapticFeedback.light()
                    isShowingEditProfile = true
                }) {
                    Text("Edit Snack")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.burlingameBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.burlingameBlue.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .cleanCardStyle()
        .sheet(isPresented: $isShowingFullLeaderboard) {
            LeaderboardSheet()
        }
        .sheet(isPresented: $isShowingEditProfile) {
            EditProfileSheet()
        }
    }
}

// MARK: - Full Leaderboard Sheet with Dual Scopes

private struct LeaderboardSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var leaderboard = LeaderboardManager.shared
    
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    
                    // Scope Switcher: [ This Month (August) | All-Time ]
                    HStack(spacing: 4) {
                        ForEach(LeaderboardScope.allCases) { scope in
                            let isSelected = leaderboard.selectedScope == scope
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    leaderboard.selectedScope = scope
                                }
                                HapticFeedback.light()
                            }) {
                                Text(scope == .thisMonth ? "This Month (\(leaderboard.currentMonthName))" : scope.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(isSelected ? AppTheme.pickleballLime : Color.clear)
                                    )
                                    .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color(red: 0.90, green: 0.92, blue: 0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Header Banner explaining the snack sponsorship
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("🍪 🥤 🥪")
                                .font(.system(size: 24))
                            Text("Community Snack Rewards")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        
                        Text("Help our Washington Park community stay informed! The top contributor each month earns the **Snack MVP** crown — players are encouraged to bring them their favorite snack or drink at the courts!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineSpacing(2)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppTheme.availableGreen)
                                Text("+10 pts Activity")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppTheme.burlingameBlue)
                                Text("+5 pts Walk-On")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.85))
                                Text("Resets 1st of month")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.75))
                            }
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(Color(red: 0.98, green: 0.96, blue: 0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 0.94, green: 0.88, blue: 0.75), lineWidth: 1)
                    )
                    
                    // User's own card with Edit Snack button
                    HStack(spacing: 12) {
                        Text(leaderboard.currentUser.avatarEmoji)
                            .font(.system(size: 24))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(leaderboard.currentUser.name)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Your Snack: \(leaderboard.currentUser.favoriteSnack)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.burlingameBlue)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            showingEditProfile = true
                        }) {
                            Text("Change")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.burlingameBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.burlingameBlue.opacity(0.10))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.burlingameBlue.opacity(0.25), lineWidth: 1))
                    
                    // Rankings List
                    VStack(alignment: .leading, spacing: 8) {
                        Text(leaderboard.selectedScope == .thisMonth ? "THIS MONTH'S TOP SCOUTS" : "ALL-TIME COMMUNITY RANKINGS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        let rankedUsers = leaderboard.users(for: leaderboard.selectedScope)
                        ForEach(Array(rankedUsers.enumerated()), id: \.element.id) { index, user in
                            HStack(spacing: 12) {
                                // Rank Number or Trophy
                                Text(rankIcon(for: index))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(user.name)
                                            .font(.system(size: 14, weight: user.isCurrentUser ? .black : .bold, design: .rounded))
                                            .foregroundColor(user.isCurrentUser ? AppTheme.burlingameBlue : AppTheme.textPrimary)
                                        
                                        if user.isCurrentUser {
                                            Text("YOU")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.burlingameBlue)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    Text("🍪 Fav Snack: \(user.favoriteSnack)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(user.points(for: leaderboard.selectedScope)) pts")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    
                                    Text("\(user.reports(for: leaderboard.selectedScope)) reports")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(user.isCurrentUser ? AppTheme.burlingameBlue.opacity(0.06) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(user.isCurrentUser ? AppTheme.burlingameBlue.opacity(0.3) : Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Community Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                        .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet()
            }
        }
    }
    
    private func rankIcon(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "#\(index + 1)"
        }
    }
}

// MARK: - Edit Profile & Favorite Snack Sheet (with Content Moderation Governance)

private struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var leaderboard = LeaderboardManager.shared
    
    @State private var userName: String = ""
    @State private var favoriteSnack: String = ""
    @State private var avatarEmoji: String = "🎾"
    @State private var errorMessage: String? = nil
    
    let emojiOptions = ["🎾", "🏓", "⚡️", "👑", "🔥", "🌟", "🍪", "🥤", "🍉"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YOUR COMMUNITY PROFILE")) {
                    TextField("Name (e.g. Dominic)", text: $userName)
                        .font(.system(size: 15))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Avatar Icon")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button(action: {
                                    avatarEmoji = emoji
                                    HapticFeedback.light()
                                }) {
                                    Text(emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 34, height: 34)
                                        .background(avatarEmoji == emoji ? AppTheme.burlingameBlue.opacity(0.15) : Color.clear)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle().stroke(avatarEmoji == emoji ? AppTheme.burlingameBlue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(
                    header: Text("FAVORITE SNACK OR DRINK"),
                    footer: Text("When you earn Snack MVP, fellow Washington Park players will see your favorite drink or snack to bring you!")
                ) {
                    TextField("e.g. Cold Coconut Water & RXBar", text: $favoriteSnack)
                        .font(.system(size: 15))
                }
                
                if let error = errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(AppTheme.reservedRed)
                            Text(error)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.reservedRed)
                        }
                    }
                }
            }
            .navigationTitle("Edit Snack & Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.burlingameBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .bold()
                    .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            .onAppear {
                let user = leaderboard.currentUser
                self.userName = user.name
                self.favoriteSnack = user.favoriteSnack
                self.avatarEmoji = user.avatarEmoji.isEmpty ? "🎾" : user.avatarEmoji
            }
        }
    }
    
    private func saveProfile() {
        let result = leaderboard.updateUserProfile(name: userName, favoriteSnack: favoriteSnack, avatarEmoji: avatarEmoji)
        if result.success {
            errorMessage = nil
            dismiss()
        } else {
            errorMessage = result.message ?? "Please enter appropriate text."
            HapticFeedback.light()
        }
    }
}
