import SwiftUI

public struct MonthScheduleView: View {
    @ObservedObject var scheduleStore = CourtScheduleStore.shared
    var onReserveSlot: (ReservationSlot) -> Void
    
    @State private var selectedCalendarDate: Date = Calendar.current.startOfDay(for: Date())
    private let calendar = Calendar.current
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month Header
            Text(currentMonthString(for: selectedCalendarDate))
                .font(.system(size: 16, weight: .bold, design: .rounded))
            
            // Days Grid
            let days = generateMonthDays()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedCalendarDate)
                    let isToday = calendar.isDateInToday(date)
                    
                    Button(action: {
                        selectedCalendarDate = date
                        scheduleStore.selectedDate = date
                        HapticFeedback.light()
                    }) {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 12, weight: isSelected || isToday ? .bold : .regular))
                                .foregroundColor(isSelected ? .black : .primary)
                        }
                        .frame(height: 36)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? AppTheme.pickleballLime : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isToday && !isSelected ? AppTheme.pickleballLime : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Selected Day Breakdown for Reservable Courts 2 & 3
            let slotsForDay = scheduleStore.slotsForDate(selectedCalendarDate)
            
            ForEach(Court.reservableCourts) { court in
                let courtSlots = slotsForDay.filter { $0.courtId == court.id }
                CourtCardView(court: court, slots: courtSlots) { slot in
                    onReserveSlot(slot)
                }
            }
        }
        .padding(12)
        .glassCardStyle()
    }
    
    private func generateMonthDays() -> [Date] {
        let start = calendar.startOfDay(for: Date())
        var dates: [Date] = []
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: i, to: start) {
                dates.append(date)
            }
        }
        return dates
    }
    
    private func currentMonthString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
