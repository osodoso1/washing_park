import Foundation

public final class WebTracScraper: NSObject, ObservableObject {
    public static let shared = WebTracScraper()
    
    public static let webTracSearchURL = "https://caburlingameweb.myvscloud.com/webtrac/web/search.html?display=detail&frclass=Tennis%20Court&location=washington&module=FR"
    public static let civicPlusCalendarURL = "https://ca-burlingame.civicplus.com/1138/Field-Availability-Calendar"
    
    @Published public var isScraping: Bool = false
    @Published public var lastScrapeDate: Date? = nil
    
    public override init() {
        super.init()
    }
    
    /// Synthesizes schedule for a target date combining live CivicPlus ReachCM events for Reservable Courts 2 & 3
    public func generateSchedule(for targetDate: Date, liveEvents: [CivicPlusEvent]) -> [ReservationSlot] {
        var slots: [ReservationSlot] = []
        let calendar = Calendar.current
        
        let currentHour = calendar.component(.hour, from: Date())
        let isCurrentDay = calendar.isDateInToday(targetDate)
        
        let targetDay = calendar.component(.day, from: targetDate)
        let targetMonth = calendar.component(.month, from: targetDate)
        let targetYear = calendar.component(.year, from: targetDate)
        
        // Filter events matching targetDate (day/month/year)
        let eventsForDay = liveEvents.filter { ev in
            guard let sDate = ev.startDate else { return false }
            let sDay = calendar.component(.day, from: sDate)
            let sMonth = calendar.component(.month, from: sDate)
            let sYear = calendar.component(.year, from: sDate)
            return sDay == targetDay && sMonth == targetMonth && sYear == targetYear
        }
        
        // ONLY Reservable Courts: Court 2 and Court 3
        for court in Court.reservableCourts {
            for hour in 7...21 {
                let startFormatted = formatHour(hour)
                let endFormatted = formatHour(hour + 1)
                
                var status: SlotStatus = .available
                var booker: String? = nil
                var eventTitle: String? = nil
                
                // Match against live events for this specific court
                let matchingEvent = eventsForDay.first { ev in
                    let loc = ev.location.lowercased()
                    let isMatchCourt: Bool
                    if court.id == "wp_tennis_2" {
                        isMatchCourt = loc.contains("court 2") || loc.contains("tc02")
                    } else if court.id == "wp_tennis_3" {
                        isMatchCourt = loc.contains("court 3") || loc.contains("tc03")
                    } else {
                        isMatchCourt = false
                    }
                    
                    if isMatchCourt, let sDate = ev.startDate, let eDate = ev.endDate {
                        let sHour = calendar.component(.hour, from: sDate)
                        let eHour = calendar.component(.hour, from: eDate)
                        return hour >= sHour && hour < eHour
                    }
                    return false
                }
                
                if let ev = matchingEvent {
                    status = .reserved
                    booker = ev.bookerName.isEmpty ? "Reserved" : ev.bookerName
                    eventTitle = ev.eventName.isEmpty ? "Court Reservation" : ev.eventName
                } else if isCurrentDay && hour < currentHour {
                    status = .past
                } else {
                    status = .available
                    eventTitle = "Available"
                }
                
                let slot = ReservationSlot(
                    id: "\(court.id)_\(targetYear)_\(targetMonth)_\(targetDay)_\(hour)",
                    courtId: court.id,
                    courtName: court.displayName,
                    date: targetDate,
                    startTimeString: startFormatted,
                    endTimeString: endFormatted,
                    startHour: hour,
                    endHour: hour + 1,
                    status: status,
                    bookerName: booker,
                    eventName: eventTitle,
                    isReservableCourt: true,
                    reserveWebTracUrl: WebTracScraper.webTracSearchURL
                )
                slots.append(slot)
            }
        }
        
        return slots
    }
    
    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return String(format: "%d:00 %@", displayHour, period)
    }
}
