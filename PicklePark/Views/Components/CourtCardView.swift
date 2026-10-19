import SwiftUI

public struct CourtCardView: View {
    let court: Court
    let slots: [ReservationSlot]
    var onReserveSlot: (ReservationSlot) -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Court Header
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.burlingameBlue)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(court.displayName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text(court.surfaceType)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                let reservedCount = slots.filter { $0.status == .reserved }.count
                let availableCount = slots.filter { $0.status == .available }.count
                
                HStack(spacing: 6) {
                    if reservedCount > 0 {
                        Text("\(reservedCount) Booked")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.reservedRed)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppTheme.reservedRed.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text("\(availableCount) Open")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.availableGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.availableGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            
            // All Slots for Today / Selected Date
            VStack(spacing: 6) {
                ForEach(slots) { slot in
                    SlotRow(slot: slot) {
                        onReserveSlot(slot)
                    }
                }
            }
        }
        .padding(14)
        .cleanCardStyle()
    }
}

private struct SlotRow: View {
    let slot: ReservationSlot
    var onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light()
            onTap()
        }) {
            HStack(spacing: 8) {
                // Time Range
                Text(slot.startTimeString)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(slot.status == .past ? AppTheme.textSecondary.opacity(0.6) : AppTheme.textPrimary)
                    .frame(width: 60, alignment: .leading)
                
                // Status Indicator
                Circle()
                    .fill(slot.status == .reserved ? AppTheme.reservedRed : (slot.status == .available ? AppTheme.availableGreen : AppTheme.textSecondary.opacity(0.4)))
                    .frame(width: 7, height: 7)
                
                // Booker Name / Event Title or Available text
                VStack(alignment: .leading, spacing: 1) {
                    if slot.status == .reserved {
                        if let booker = slot.bookerName, !booker.isEmpty {
                            Text(slot.displaySubtitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.reservedRed)
                                .lineLimit(1)
                        } else {
                            Text("Reserved via WebTrac")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.reservedRed)
                        }
                    } else if slot.status == .available {
                        Text("Available · Open on WebTrac")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.availableGreen)
                    } else {
                        Text("Past")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if slot.status == .available {
                    Text("Book")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(AppTheme.pickleballLime)
                        .clipShape(Capsule())
                } else if slot.status == .reserved {
                    Text("Booked")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.reservedRed)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                slot.status == .reserved
                ? AppTheme.reservedRed.opacity(0.06)
                : (slot.status == .available ? Color(red: 0.97, green: 0.98, blue: 0.99) : Color.black.opacity(0.02))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(slot.status == .reserved ? AppTheme.reservedRed.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
