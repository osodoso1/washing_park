import SwiftUI

public struct BracketTheme {
    // Primary Electric Palette
    public static let pickleballLime = Color(red: 0.78, green: 0.95, blue: 0.31) // #C6F24F
    public static let pickleballGreen = Color(red: 0.08, green: 0.68, blue: 0.38)
    public static let deepNavy = Color(red: 0.03, green: 0.11, blue: 0.22) // #081C38
    public static let cardNavy = Color(red: 0.05, green: 0.16, blue: 0.32) // #0D2952
    public static let lightCardNavy = Color(red: 0.08, green: 0.22, blue: 0.42)
    public static let accentGold = Color(red: 0.98, green: 0.75, blue: 0.18) // #FBBF24
    public static let accentSilver = Color(red: 0.80, green: 0.84, blue: 0.90)
    public static let accentBronze = Color(red: 0.85, green: 0.55, blue: 0.30)
    
    // Gradients
    public static let heroGradient = LinearGradient(
        colors: [Color(red: 0.03, green: 0.11, blue: 0.22), Color(red: 0.06, green: 0.18, blue: 0.36)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let limeGradient = LinearGradient(
        colors: [Color(red: 0.78, green: 0.95, blue: 0.31), Color(red: 0.65, green: 0.90, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Radii
    public static let cornerRadiusLarge: CGFloat = 20
    public static let cornerRadiusMedium: CGFloat = 14
    public static let cornerRadiusSmall: CGFloat = 10
}

public struct BracketCardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(BracketTheme.cardNavy)
            .clipShape(RoundedRectangle(cornerRadius: BracketTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BracketTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func bracketCardStyle() -> some View {
        self.modifier(BracketCardModifier())
    }
}

public struct BracketHaptics {
    public static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    public static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
