import SwiftUI

public struct PodiumView: View {
    let goldWinner: String
    let silverWinner: String
    let bronzeWinner: String
    let tournamentTitle: String
    let onDismiss: () -> Void
    
    @State private var appearAnimation = false
    
    public var body: some View {
        ZStack {
            BracketTheme.deepNavy.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 6) {
                    Text("🏆 TOURNAMENT CHAMPIONS")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(BracketTheme.pickleballLime)
                    
                    Text(tournamentTitle)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                
                // 3D-Style Podium
                HStack(alignment: .bottom, spacing: 12) {
                    // Silver (2nd Place)
                    VStack(spacing: 8) {
                        Text("🥈").font(.system(size: 32))
                        Text(silverWinner.isEmpty ? "2nd Place" : silverWinner)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [BracketTheme.accentSilver, Color.gray], startPoint: .top, endPoint: .bottom))
                            .frame(height: 120)
                            .overlay(Text("2ND").font(.system(size: 18, weight: .black)).foregroundColor(.black.opacity(0.7)))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Gold (1st Place)
                    VStack(spacing: 8) {
                        Text("👑").font(.system(size: 44))
                        Text(goldWinner.isEmpty ? "CHAMPION" : goldWinner)
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(BracketTheme.pickleballLime)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [BracketTheme.accentGold, Color.orange], startPoint: .top, endPoint: .bottom))
                            .frame(height: 170)
                            .overlay(Text("1ST").font(.system(size: 24, weight: .black)).foregroundColor(.black))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Bronze (3rd Place)
                    VStack(spacing: 8) {
                        Text("🥉").font(.system(size: 30))
                        Text(bronzeWinner.isEmpty ? "3rd Place" : bronzeWinner)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [BracketTheme.accentBronze, Color.brown], startPoint: .top, endPoint: .bottom))
                            .frame(height: 90)
                            .overlay(Text("3RD").font(.system(size: 16, weight: .black)).foregroundColor(.white.opacity(0.8)))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .opacity(appearAnimation ? 1.0 : 0.0)
                
                Spacer()
                
                Button(action: {
                    BracketHaptics.light()
                    onDismiss()
                }) {
                    Text("Back to Tournament")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BracketTheme.pickleballLime)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearAnimation = true
            }
        }
    }
}
