import SwiftUI

public struct AppTheme {
    // Primary Vibrant Colors
    public static let pickleballLime = Color(red: 0.52, green: 0.82, blue: 0.08) // #84CC16
    public static let pickleballGreen = Color(red: 0.08, green: 0.68, blue: 0.38) // #15AD61
    public static let burlingameBlue = Color(red: 0.00, green: 0.48, blue: 1.00) // #007AFF
    public static let burlingameSky = Color(red: 0.01, green: 0.52, blue: 0.88) // #0284C7
    
    // Light Canvas Colors
    public static let canvasBackground = Color(red: 0.96, green: 0.97, blue: 0.98) // #F6F8FA
    public static let cardBackground = Color.white
    public static let cardBorder = Color(red: 0.90, green: 0.92, blue: 0.94) // #E5E7EB
    
    // Text Colors
    public static let textPrimary = Color(red: 0.06, green: 0.09, blue: 0.14) // #0F172A
    public static let textSecondary = Color(red: 0.40, green: 0.45, blue: 0.55) // #64748B
    
    // Badges
    public static let reservedRed = Color(red: 0.94, green: 0.27, blue: 0.27) // #EF4444
    public static let availableGreen = Color(red: 0.06, green: 0.72, blue: 0.50) // #10B981
    public static let dropInBlue = Color(red: 0.00, green: 0.48, blue: 1.00) // #007AFF
    
    // Radii
    public static let cornerRadiusLarge: CGFloat = 18
    public static let cornerRadiusMedium: CGFloat = 14
    public static let cornerRadiusSmall: CGFloat = 10
}

public struct CleanCardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

public extension View {
    func cleanCardStyle() -> some View {
        self.modifier(CleanCardModifier())
    }
    
    func glassCardStyle() -> some View {
        self.modifier(CleanCardModifier())
    }
}

public struct HapticFeedback {
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
