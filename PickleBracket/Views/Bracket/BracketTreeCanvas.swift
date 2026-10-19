import SwiftUI
import SwiftData

public struct BracketTreeCanvas: View {
    @Bindable var tournament: TournamentModel
    let matches: [BracketMatchModel]
    let onSelectMatch: (BracketMatchModel) -> Void
    
    // Layout Constants
    private let cardWidth: CGFloat = 190
    private let cardHeight: CGFloat = 82
    private let horizontalGap: CGFloat = 70
    private let baseVerticalGap: CGFloat = 20
    
    private var totalRounds: Int {
        let maxRound = matches.map { $0.roundIndex }.max() ?? 0
        return maxRound + 1
    }
    
    public init(
        tournament: TournamentModel,
        matches: [BracketMatchModel],
        onSelectMatch: @escaping (BracketMatchModel) -> Void
    ) {
        self.tournament = tournament
        self.matches = matches
        self.onSelectMatch = onSelectMatch
    }
    
    public var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                // 1. Bracket Connecting Lines
                BracketLinesShape(
                    matches: matches,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    horizontalGap: horizontalGap,
                    baseVerticalGap: baseVerticalGap
                )
                .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // 2. Interactive Match Nodes
                ForEach(matches.filter { !$0.title.contains("BRONZE") }) { match in
                    let pos = positionForMatch(match: match)
                    
                    BracketMatchNodeView(
                        match: match,
                        targetScore: tournament.targetScore,
                        isChampionship: match.roundIndex == totalRounds - 1
                    ) {
                        onSelectMatch(match)
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .position(x: pos.x + cardWidth / 2, y: pos.y + cardHeight / 2)
                }
            }
            .padding(30)
            .frame(width: totalCanvasWidth, height: totalCanvasHeight)
        }
        .background(Color(red: 0.02, green: 0.08, blue: 0.16))
    }
    
    // MARK: - Position Computations
    
    private var totalCanvasWidth: CGFloat {
        let cols = CGFloat(totalRounds)
        return (cols * cardWidth) + ((cols - 1) * horizontalGap) + 80
    }
    
    private var totalCanvasHeight: CGFloat {
        let round0Count = CGFloat(matches.filter { $0.roundIndex == 0 }.count)
        return max(600, (round0Count * cardHeight) + (round0Count * baseVerticalGap) + 80)
    }
    
    private func positionForMatch(match: BracketMatchModel) -> CGPoint {
        let col = CGFloat(match.roundIndex)
        let x = col * (cardWidth + horizontalGap)
        
        let round0Count = CGFloat(matches.filter { $0.roundIndex == 0 }.count)
        let totalSlotHeight = cardHeight + baseVerticalGap
        let multiplier = pow(2.0, col)
        
        // Center each node vertically relative to its two child nodes
        let yOffset = (multiplier - 1) * (totalSlotHeight / 2)
        let y = yOffset + (CGFloat(match.matchIndex) * multiplier * totalSlotHeight)
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Bracket Connecting Lines Shape

private struct BracketLinesShape: Shape {
    let matches: [BracketMatchModel]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let horizontalGap: CGFloat
    let baseVerticalGap: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        for match in matches {
            guard let nextId = match.nextMatchId,
                  let nextMatch = matches.first(where: { $0.id == nextId }) else { continue }
            
            let fromPos = calculatePos(match: match)
            let toPos = calculatePos(match: nextMatch)
            
            let startX = fromPos.x + cardWidth
            let startY = fromPos.y + (cardHeight / 2)
            
            let endX = toPos.x
            let endY = toPos.y + (match.nextMatchSlot == "A" ? (cardHeight * 0.3) : (cardHeight * 0.7))
            
            let midX = startX + (horizontalGap / 2)
            
            // Draw Orthogonal Bracket lines: [ — | — ]
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: midX, y: startY))
            path.addLine(to: CGPoint(x: midX, y: endY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        
        return path
    }
    
    private func calculatePos(match: BracketMatchModel) -> CGPoint {
        let col = CGFloat(match.roundIndex)
        let x = col * (cardWidth + horizontalGap)
        let totalSlotHeight = cardHeight + baseVerticalGap
        let multiplier = pow(2.0, col)
        let yOffset = (multiplier - 1) * (totalSlotHeight / 2)
        let y = yOffset + (CGFloat(match.matchIndex) * multiplier * totalSlotHeight)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Match Node View Component

public struct BracketMatchNodeView: View {
    let match: BracketMatchModel
    let targetScore: Int
    let isChampionship: Bool
    let onTap: () -> Void
    
    public var body: some View {
        Button(action: {
            BracketHaptics.light()
            onTap()
        }) {
            VStack(spacing: 0) {
                // Header (Match title & Court)
                HStack {
                    Text(match.title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(isChampionship ? BracketTheme.accentGold : BracketTheme.pickleballLime)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if match.isFinished {
                        Text("FINAL ✓")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(BracketTheme.pickleballLime)
                    } else {
                        Text("CT \(match.courtNumber)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.35))
                
                // Team A Slot
                HStack(spacing: 4) {
                    let isWinnerA = match.isFinished && match.winnerId == match.teamAId
                    if isWinnerA {
                        Text("👑").font(.system(size: 9))
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(match.teamAName)
                            .font(.system(size: 11, weight: isWinnerA ? .black : .bold))
                            .foregroundColor(isWinnerA ? BracketTheme.pickleballLime : .white)
                            .lineLimit(1)
                        if !match.teamAMembers.isEmpty && match.teamAMembers != "TBD" {
                            Text(match.teamAMembers)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if match.teamADUPR > 0 {
                        Text(String(format: "%.1f", match.teamADUPR))
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(BracketTheme.pickleballLime)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(match.scoreA)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(isWinnerA ? BracketTheme.pickleballLime : .white)
                        .frame(minWidth: 20, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(match.isFinished && match.winnerId == match.teamAId ? BracketTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.04))
                
                Divider().background(Color.white.opacity(0.15))
                
                // Team B Slot
                HStack(spacing: 4) {
                    let isWinnerB = match.isFinished && match.winnerId == match.teamBId
                    if isWinnerB {
                        Text("👑").font(.system(size: 9))
                    }
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(match.teamBName)
                            .font(.system(size: 11, weight: isWinnerB ? .black : .bold))
                            .foregroundColor(isWinnerB ? BracketTheme.pickleballLime : .white)
                            .lineLimit(1)
                        if !match.teamBMembers.isEmpty && match.teamBMembers != "TBD" {
                            Text(match.teamBMembers)
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    if match.teamBDUPR > 0 {
                        Text(String(format: "%.1f", match.teamBDUPR))
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(BracketTheme.pickleballLime)
                            .clipShape(Capsule())
                    }
                    
                    Text("\(match.scoreB)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(isWinnerB ? BracketTheme.pickleballLime : .white)
                        .frame(minWidth: 20, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(match.isFinished && match.winnerId == match.teamBId ? BracketTheme.pickleballLime.opacity(0.12) : Color.white.opacity(0.04))
            }
            .background(BracketTheme.cardNavy)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isChampionship
                        ? BracketTheme.accentGold.opacity(0.8)
                        : (match.isFinished ? BracketTheme.pickleballLime.opacity(0.6) : Color.white.opacity(0.2)),
                        lineWidth: isChampionship ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
