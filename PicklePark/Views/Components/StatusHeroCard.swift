import SwiftUI

public struct StatusHeroCard: View {
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var lostAndFoundManager = LostAndFoundManager.shared
    var onReserveTap: () -> Void
    var onClubhouseHoursTap: () -> Void
    var onLostAndFoundTap: () -> Void
    
    public init(
        onReserveTap: @escaping () -> Void,
        onClubhouseHoursTap: @escaping () -> Void,
        onLostAndFoundTap: @escaping () -> Void = {}
    ) {
        self.onReserveTap = onReserveTap
        self.onClubhouseHoursTap = onClubhouseHoursTap
        self.onLostAndFoundTap = onLostAndFoundTap
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Washington Park")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Burlingame, CA · Courts 1, 2 & 3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Spacer()
                
                // Live Calendar Pill
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.availableGreen)
                        .frame(width: 7, height: 7)
                    Text("Live City Feed")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.availableGreen)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(AppTheme.availableGreen.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // Live Weather & Air Quality Strip (AQI on left + weather, Court Weather on right)
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Text(weatherService.currentWeather.formattedAqiSummary)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Text(weatherService.currentWeather.formattedWeatherSummary)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                
                Spacer()
                
                Text("Court Weather")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(red: 0.94, green: 0.96, blue: 0.98))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Clubhouse Info & Lost and Found Side-by-Side Row
            HStack(spacing: 8) {
                // Club Info Button
                Button(action: {
                    HapticFeedback.light()
                    onClubhouseHoursTap()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.burlingameBlue)
                        
                        Text("Clubhouse: 8a–7p · Lights: 10p")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: 2)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppTheme.burlingameBlue)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(AppTheme.burlingameBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Lost & Found Button with Red Notification Badge
                Button(action: {
                    HapticFeedback.light()
                    onLostAndFoundTap()
                }) {
                    HStack(spacing: 5) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.burlingameBlue)
                            
                            if lostAndFoundManager.shouldShowRedNotificationBadge {
                                Circle()
                                    .fill(AppTheme.reservedRed)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 3, y: -3)
                            }
                        }
                        
                        Text("Lost & Found")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.burlingameBlue)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.burlingameBlue.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                lostAndFoundManager.shouldShowRedNotificationBadge
                                    ? AppTheme.reservedRed.opacity(0.45)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Court Type Tags
            HStack(spacing: 8) {
                CourtTypeTag(
                    title: "Court 1",
                    subtitle: "Open Play (4 PB)",
                    icon: "figure.pickleball",
                    accentColor: AppTheme.pickleballGreen
                )
                
                CourtTypeTag(
                    title: "Courts 2 & 3",
                    subtitle: "Reservable",
                    icon: "calendar",
                    accentColor: AppTheme.burlingameBlue
                )
            }
            
            // 1-Tap Reserve on WebTrac Action
            Button(action: {
                HapticFeedback.medium()
                onReserveTap()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Reserve Courts 2 & 3 on WebTrac")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.pickleballLime)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .shadow(color: AppTheme.pickleballLime.opacity(0.35), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cleanCardStyle()
    }
}

private struct CourtTypeTag: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(accentColor)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .stroke(Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
        )
    }
}
