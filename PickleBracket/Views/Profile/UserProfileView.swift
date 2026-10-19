import SwiftUI
import SwiftData

public struct UserProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfileModel]
    
    @State private var isShowingDUPRConnect = false
    @State private var searchDUPRQuery = ""
    
    private var currentUser: UserProfileModel {
        if let existing = userProfiles.first {
            return existing
        }
        let fresh = UserProfileModel()
        modelContext.insert(fresh)
        return fresh
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Card
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BracketTheme.pickleballLime.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Text(currentUser.avatarEmoji)
                                    .font(.system(size: 40))
                            }
                            
                            VStack(spacing: 4) {
                                Text(currentUser.name)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(BracketTheme.pickleballLime)
                                    Text(currentUser.duprId)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 10)
                        
                        // Official DUPR Ratings Grid
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("OFFICIAL DUPR RATINGS")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Button("Sync DUPR") {
                                    isShowingDUPRConnect = true
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(BracketTheme.pickleballLime)
                            }
                            
                            HStack(spacing: 12) {
                                // Doubles DUPR
                                VStack(spacing: 4) {
                                    Text("DOUBLES")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(String(format: "%.2f", currentUser.duprDoublesRating))
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                    Text("Reliability: \(Int(currentUser.duprHalfLife * 100))%")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                // Singles DUPR
                                VStack(spacing: 4) {
                                    Text("SINGLES")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(String(format: "%.2f", currentUser.duprSinglesRating))
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Reliability: \(Int(currentUser.duprHalfLife * 100))%")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(16)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Trophy Case & Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CAREER TROPHY CASE")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            HStack(spacing: 12) {
                                VStack(spacing: 4) {
                                    Text("🥇").font(.system(size: 24))
                                    Text("\(currentUser.tournamentsWon)")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(BracketTheme.accentGold)
                                    Text("Tourneys Won")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(spacing: 4) {
                                    Text("🏆").font(.system(size: 24))
                                    Text("\(currentUser.leaguesWon)")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(BracketTheme.pickleballLime)
                                    Text("Leagues Won")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                VStack(spacing: 4) {
                                    Text("⚡️").font(.system(size: 24))
                                    Text("\(currentUser.winRatePercentage)%")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundColor(.white)
                                    Text("Win Rate")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(16)
                        .background(BracketTheme.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding()
                }
            }
            .navigationTitle("👤 Profile & DUPR")
            .sheet(isPresented: $isShowingDUPRConnect) {
                DUPRConnectSheet(currentUser: currentUser)
            }
        }
    }
}

public struct DUPRConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var currentUser: UserProfileModel
    @State private var query = ""
    @State private var searchResults: [DUPRPlayerResult] = []
    
    public var body: some View {
        NavigationStack {
            ZStack {
                BracketTheme.deepNavy.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search by Player Name or DUPR ID")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        TextField("Search Player", text: $query, prompt: Text("e.g. Dominic Soriano or DUPR-882194").foregroundColor(Color.white.opacity(0.6)))
                            .font(.system(size: 14, weight: .semibold))
                            .padding(12)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onChange(of: query) { _, newQuery in
                                searchResults = DUPRService.shared.searchPlayers(query: newQuery)
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(searchResults) { result in
                                Button(action: {
                                    BracketHaptics.success()
                                    currentUser.name = result.fullName
                                    currentUser.duprId = result.duprId
                                    currentUser.duprDoublesRating = result.doublesRating
                                    currentUser.duprSinglesRating = result.singlesRating
                                    currentUser.duprHalfLife = result.halfLife
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(result.fullName)
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("\(result.duprId) • \(result.location)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(String(format: "%.2f", result.doublesRating)) DUPR")
                                                .font(.system(size: 13, weight: .black))
                                                .foregroundColor(BracketTheme.pickleballLime)
                                            Text("Connect ➔")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(BracketTheme.pickleballLime)
                                        }
                                    }
                                    .padding(14)
                                    .background(BracketTheme.cardNavy)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Connect DUPR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.white)
                }
            }
            .onAppear {
                searchResults = DUPRService.shared.searchPlayers(query: "")
            }
        }
    }
}
