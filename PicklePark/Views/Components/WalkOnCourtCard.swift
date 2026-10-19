import SwiftUI

public struct WalkOnCourtCard: View {
    @ObservedObject private var walkOnManager = WalkOnCourtManager.shared
    @ObservedObject private var scheduleStore = CourtScheduleStore.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COURTS 2 & 3: LIVE CAPACITY & SIDES")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.burlingameBlue)
                    
                    Text("Extra Pickleball Courts (4 Max)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                }
                
                Spacer()
                
                // Status Pill showing Exact Live PB Availability
                extraPBCourtsBadge
            }
            
            // SECTION A: COURT 2 (2 PB SIDES)
            CourtSideSelectorView(
                courtNumber: 2,
                slot: scheduleStore.currentHourSlot(for: 2),
                currentState: walkOnManager.status.court2State
            ) { newState in
                walkOnManager.setCourt2State(newState)
            }
            
            // SECTION B: COURT 3 (2 PB SIDES)
            CourtSideSelectorView(
                courtNumber: 3,
                slot: scheduleStore.currentHourSlot(for: 3),
                currentState: walkOnManager.status.court3State
            ) { newState in
                walkOnManager.setCourt3State(newState)
            }
            
            // Dynamic Overall Capacity Explanation
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.burlingameSky)
                
                Text(capacityExplanation)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            
            // Footer: Timestamp & 11 PM Daily Reset notice
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                    Text("Updated: \(formattedTime(from: walkOnManager.status.lastReportDate))")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.55, green: 0.45, blue: 0.85))
                    Text("Auto-resets at 11:00 PM")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.75))
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .cleanCardStyle()
    }
    
    // MARK: - Live Extra PB Courts Badge
    
    @ViewBuilder
    private var extraPBCourtsBadge: some View {
        let totalOpen = calculateTotalOpenPBCourts()
        let isAllOpen = totalOpen == 4
        let isFull = totalOpen == 0
        
        let badgeColor: Color = {
            if isAllOpen { return AppTheme.availableGreen }
            if isFull { return AppTheme.reservedRed }
            return Color(red: 0.96, green: 0.55, blue: 0.15)
        }()
        
        HStack(spacing: 5) {
            Circle()
                .fill(badgeColor)
                .frame(width: 7, height: 7)
            
            Text("\(totalOpen) / 4 PB Open")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
    }
    
    private func calculateTotalOpenPBCourts() -> Int {
        var openCount = 0
        
        // Court 2 check
        let c2Slot = scheduleStore.currentHourSlot(for: 2)
        if c2Slot?.status == .reserved {
            openCount += 0
        } else {
            openCount += walkOnManager.status.court2State.pickleballCourtsOpen
        }
        
        // Court 3 check
        let c3Slot = scheduleStore.currentHourSlot(for: 3)
        if c3Slot?.status == .reserved {
            openCount += 0
        } else {
            openCount += walkOnManager.status.court3State.pickleballCourtsOpen
        }
        
        return openCount
    }
    
    private var capacityExplanation: String {
        let total = calculateTotalOpenPBCourts()
        if total == 4 {
            return "Both courts free — all 4 extra pickleball courts available right now!"
        } else if total == 0 {
            return "All taken / full — 0 extra pickleball courts available right now."
        } else {
            return "\(total) of 4 extra pickleball courts open across Courts 2 & 3."
        }
    }
    
    private func formattedTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        let mins = seconds / 60
        if mins < 60 { return "\(mins)m ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Court Side Selector View (Court 2 & Court 3 Sub-Buttons)

private struct CourtSideSelectorView: View {
    let courtNumber: Int
    let slot: ReservationSlot?
    let currentState: CourtSideOccupancy
    let onSelectState: (CourtSideOccupancy) -> Void
    
    var body: some View {
        let isReserved = slot?.status == .reserved
        
        VStack(alignment: .leading, spacing: 6) {
            // Court Header & City Reservation Tag
            HStack {
                Text("Court \(courtNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text("(2 PB Courts)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                
                Spacer()
                
                if isReserved, let name = slot?.bookerName, !name.isEmpty {
                    HStack(spacing: 4) {
                        Circle().fill(AppTheme.reservedRed).frame(width: 6, height: 6)
                        Text("Booked by \(name)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.reservedRed)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.reservedRed.opacity(0.08))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(AppTheme.availableGreen).frame(width: 6, height: 6)
                        Text("Unreserved")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.availableGreen)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.availableGreen.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            
            // Sub-Buttons: [ Free (2 PB) ] [ 1 Side (1 PB Open) ] [ Both Sides (Full) ]
            HStack(spacing: 6) {
                // Sub-button 1: Free
                SideButton(
                    title: "Free",
                    subtitle: "2 PB Open",
                    isSelected: currentState == .free && !isReserved,
                    activeColor: AppTheme.availableGreen,
                    isDisabled: isReserved
                ) {
                    onSelectState(.free)
                }
                
                // Sub-button 2: 1 Side Taken
                SideButton(
                    title: "1 Side Taken",
                    subtitle: "1 PB Open",
                    isSelected: currentState == .oneSideTaken && !isReserved,
                    activeColor: Color(red: 0.96, green: 0.55, blue: 0.15),
                    isDisabled: isReserved
                ) {
                    onSelectState(.oneSideTaken)
                }
                
                // Sub-button 3: Both Sides Taken
                SideButton(
                    title: isReserved ? "Reserved" : "Both Sides",
                    subtitle: "Full (0 PB)",
                    isSelected: currentState == .bothSidesTaken || isReserved,
                    activeColor: AppTheme.reservedRed,
                    isDisabled: isReserved
                ) {
                    onSelectState(.bothSidesTaken)
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isReserved ? AppTheme.reservedRed.opacity(0.25) : Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 1)
        )
    }
}

private struct SideButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let activeColor: Color
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    action()
                }
            }
        }) {
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? activeColor : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? activeColor : Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.6 : 1.0)
    }
}
