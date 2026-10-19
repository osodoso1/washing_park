import SwiftUI

public struct TodayScheduleView: View {
    @ObservedObject var scheduleStore = CourtScheduleStore.shared
    var onReserveSlot: (ReservationSlot) -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header for Reservable Courts
            HStack {
                Text("Reservable Courts Schedule (WebTrac)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // Only Reservable Courts: Court 2 & Court 3
            ForEach(Court.reservableCourts) { court in
                let slots = scheduleStore.todaySlots.filter { $0.courtId == court.id }
                CourtCardView(court: court, slots: slots) { slot in
                    onReserveSlot(slot)
                }
            }
        }
    }
}
