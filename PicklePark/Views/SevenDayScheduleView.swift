import SwiftUI

public struct SevenDayScheduleView: View {
    @ObservedObject var scheduleStore = CourtScheduleStore.shared
    var onReserveSlot: (ReservationSlot) -> Void
    
    @State private var activeDayOffset: Int = 0
    private let calendar = Calendar.current
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Horizontal 7-Day Selector Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date())) ?? Date()
                        DayTab(
                            date: date,
                            isSelected: activeDayOffset == offset,
                            isToday: offset == 0
                        ) {
                            activeDayOffset = offset
                            scheduleStore.selectedDate = date
                            HapticFeedback.light()
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            let selectedDate = calendar.date(byAdding: .day, value: activeDayOffset, to: calendar.startOfDay(for: Date())) ?? Date()
            let slotsForDay = scheduleStore.slotsForDate(selectedDate)
            
            // Courts 2 and 3 for Selected Day
            ForEach(Court.reservableCourts) { court in
                let courtSlots = slotsForDay.filter { $0.courtId == court.id }
                CourtCardView(court: court, slots: courtSlots) { slot in
                    onReserveSlot(slot)
                }
            }
        }
    }
}

private struct DayTab: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(dayOfWeekAbbrev(date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .secondary)
                
                Text(dayNumberString(date))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .black : .primary)
            }
            .frame(width: 46, height: 56)
            .background(isSelected ? AppTheme.pickleballLime : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isToday && !isSelected ? AppTheme.pickleballLime : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func dayOfWeekAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private func dayNumberString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
