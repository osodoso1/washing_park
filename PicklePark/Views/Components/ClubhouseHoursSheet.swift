import SwiftUI

// MARK: - Clubhouse Schedule (single source of truth for every hours label in the app)

/// Washington Park clubhouse (Burlingame Community Center, 850 Burlingame Ave) front-desk hours,
/// as posted by the City of Burlingame (burlingame.org → Department Hours & Locations →
/// Recreation Center Office Hours). Everything is evaluated in Pacific time so "today"
/// always matches the park, whatever time zone the phone is set to.
public enum ClubhouseSchedule {
    public struct Hours: Equatable {
        /// Minutes after local midnight.
        public let openMinute: Int
        public let closeMinute: Int

        public func contains(minuteOfDay: Int) -> Bool {
            minuteOfDay >= openMinute && minuteOfDay < closeMinute
        }
    }

    public enum Status: Equatable {
        case open(closesAt: Int)
        case opensLaterToday(at: Int)
        case closed(nextWeekday: Int, opensAt: Int)
    }

    public struct DisplayRow: Identifiable {
        public let label: String
        /// `Calendar` weekday numbers (1 = Sunday … 7 = Saturday).
        public let weekdays: Set<Int>
        public var id: String { label }
    }

    public static let parkTimeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current
    public static let courtLightsOffMinute = 22 * 60
    public static let phoneNumber = "(650) 558-7300"

    private static let monThuHours = Hours(openMinute: 8 * 60, closeMinute: 20 * 60 + 30) // 8:00 AM – 8:30 PM
    private static let fridayHours = Hours(openMinute: 8 * 60, closeMinute: 17 * 60)      // 8:00 AM – 5:00 PM
    private static let weekendHours = Hours(openMinute: 9 * 60, closeMinute: 14 * 60)     // 9:00 AM – 2:00 PM

    /// Hours by `Calendar` weekday number (1 = Sunday … 7 = Saturday); nil means closed all day.
    public static func hours(forWeekday weekday: Int) -> Hours? {
        switch weekday {
        case 2...5: return monThuHours
        case 6: return fridayHours
        case 1, 7: return weekendHours
        default: return nil
        }
    }

    /// Rows for the hours sheet, in display order.
    public static let displayRows: [DisplayRow] = [
        DisplayRow(label: "Monday – Thursday", weekdays: [2, 3, 4, 5]),
        DisplayRow(label: "Friday", weekdays: [6]),
        DisplayRow(label: "Saturday", weekdays: [7]),
        DisplayRow(label: "Sunday", weekdays: [1]),
    ]

    public static var parkCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = parkTimeZone
        return calendar
    }

    public static func weekday(at date: Date) -> Int {
        parkCalendar.component(.weekday, from: date)
    }

    public static func minuteOfDay(at date: Date) -> Int {
        let parts = parkCalendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    public static func todaysHours(at date: Date) -> Hours? {
        hours(forWeekday: weekday(at: date))
    }

    public static func status(at date: Date) -> Status {
        let today = weekday(at: date)
        let minute = minuteOfDay(at: date)
        if let todays = hours(forWeekday: today) {
            if todays.contains(minuteOfDay: minute) { return .open(closesAt: todays.closeMinute) }
            if minute < todays.openMinute { return .opensLaterToday(at: todays.openMinute) }
        }
        for offset in 1...7 {
            let next = (today - 1 + offset) % 7 + 1
            if let nextHours = hours(forWeekday: next) {
                return .closed(nextWeekday: next, opensAt: nextHours.openMinute)
            }
        }
        return .closed(nextWeekday: today, opensAt: 0)
    }

    public static func isOpen(at date: Date) -> Bool {
        if case .open = status(at: date) { return true }
        return false
    }

    // MARK: Formatting

    private static func clock(_ minute: Int) -> (hour: Int, minute: Int, isPM: Bool) {
        let hour24 = (minute / 60) % 24
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return (hour12, minute % 60, hour24 >= 12)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    /// "8a", "8:30p", "12p"
    public static func compactTime(_ minute: Int) -> String {
        let c = clock(minute)
        let suffix = c.isPM ? "p" : "a"
        return c.minute == 0 ? "\(c.hour)\(suffix)" : "\(c.hour):\(twoDigits(c.minute))\(suffix)"
    }

    /// "5 PM", "8:30 PM"
    public static func shortTime(_ minute: Int) -> String {
        let c = clock(minute)
        let suffix = c.isPM ? "PM" : "AM"
        return c.minute == 0 ? "\(c.hour) \(suffix)" : "\(c.hour):\(twoDigits(c.minute)) \(suffix)"
    }

    /// "8:00 AM", "8:30 PM"
    public static func fullTime(_ minute: Int) -> String {
        let c = clock(minute)
        return "\(c.hour):\(twoDigits(c.minute)) \(c.isPM ? "PM" : "AM")"
    }

    public static func shortWeekdayName(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][((weekday - 1) % 7 + 7) % 7]
    }

    public static func weekdayName(_ weekday: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][((weekday - 1) % 7 + 7) % 7]
    }

    public static func rangeLabel(_ hours: Hours?) -> String {
        guard let hours else { return "Closed" }
        return "\(fullTime(hours.openMinute)) – \(fullTime(hours.closeMinute))"
    }

    /// Dashboard strip, e.g. "Clubhouse Fri 8a–5p · Lights 10p".
    public static func stripLabel(at date: Date) -> String {
        let day = weekday(at: date)
        let lights = compactTime(courtLightsOffMinute)
        guard let todays = hours(forWeekday: day) else {
            return "Clubhouse closed \(shortWeekdayName(day)) · Lights \(lights)"
        }
        return "Clubhouse \(shortWeekdayName(day)) \(compactTime(todays.openMinute))–\(compactTime(todays.closeMinute)) · Lights \(lights)"
    }

    /// Status badge, e.g. "Open · Closes 5 PM" or "Closed · Opens Sat 9 AM".
    public static func statusLabel(at date: Date) -> String {
        switch status(at: date) {
        case .open(let closesAt):
            return "Open · Closes \(shortTime(closesAt))"
        case .opensLaterToday(let opensAt):
            return "Closed · Opens \(shortTime(opensAt))"
        case .closed(let nextWeekday, let opensAt):
            return "Closed · Opens \(shortWeekdayName(nextWeekday)) \(shortTime(opensAt))"
        }
    }

    /// VoiceOver description for the dashboard strip.
    public static func accessibilityLabel(at date: Date) -> String {
        let day = weekday(at: date)
        return "Clubhouse hours \(weekdayName(day)): \(rangeLabel(hours(forWeekday: day))). \(statusLabel(at: date)). Court lights until \(shortTime(courtLightsOffMinute))."
    }
}

public struct ClubhouseHoursSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.canvasBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Hero Header
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.burlingameBlue.opacity(0.12))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "building.2.crop.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.burlingameBlue)
                            }
                            .padding(.top, 8)
                            
                            Text("Washington Park Clubhouse")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("850 Burlingame Ave, Burlingame, CA 94010")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 6)
                        
                        // Clubhouse Hours Card (re-evaluated every minute so "today" and open/closed stay current)
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            let now = context.date
                            let today = ClubhouseSchedule.weekday(at: now)
                            let isOpen = ClubhouseSchedule.isOpen(at: now)
                            let badgeColor = isOpen ? AppTheme.availableGreen : AppTheme.reservedRed

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(AppTheme.burlingameBlue)
                                    Text("CLUBHOUSE & DESK HOURS")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                    Spacer(minLength: 6)
                                    Text(ClubhouseSchedule.statusLabel(at: now))
                                        .font(.system(size: 10, weight: .bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                        .background(badgeColor.opacity(0.12))
                                        .foregroundColor(badgeColor)
                                        .clipShape(Capsule())
                                }

                                VStack(spacing: 8) {
                                    ForEach(ClubhouseSchedule.displayRows) { row in
                                        let isToday = row.weekdays.contains(today)
                                        HoursRow(
                                            day: isToday ? "\(row.label) (Today)" : row.label,
                                            hours: ClubhouseSchedule.rangeLabel(
                                                row.weekdays.min().flatMap { ClubhouseSchedule.hours(forWeekday: $0) }
                                            ),
                                            isHighlight: isToday
                                        )
                                    }
                                }

                                Text("City of Burlingame posted hours. Holiday hours may differ — call \(ClubhouseSchedule.phoneNumber).")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(14)
                            .cleanCardStyle()
                        }
                        
                        // Court & Lights Schedule Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(AppTheme.pickleballLime)
                                Text("COURTS & LIGHTS SCHEDULE")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            VStack(spacing: 8) {
                                HoursRow(day: "Park & Courts Open", hours: "6:00 AM – 10:00 PM", isHighlight: true)
                                HoursRow(day: "Court Lights Active", hours: "Dusk – 10:00 PM (Auto Shutoff)")
                                HoursRow(day: "Court 1 Drop-In", hours: "8:00 AM – 10:00 PM Daily")
                                HoursRow(day: "Courts 2 & 3 WebTrac", hours: "Reservations or Walk-On")
                            }
                        }
                        .padding(14)
                        .cleanCardStyle()
                        
                        // Park Amenities & Amenities Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("FACILITIES & AMENITIES")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            VStack(spacing: 8) {
                                AmenityRow(icon: "figure.walk", title: "Restrooms", desc: "Located inside Clubhouse and adjacent to Court 1")
                                AmenityRow(icon: "drop.fill", title: "Water Refill Station", desc: "Next to Clubhouse front entrance")
                                AmenityRow(icon: "car.fill", title: "Free Parking", desc: "Washington Park lot on Burlingame Ave & Carolan Ave")
                                AmenityRow(icon: "phone.fill", title: "Parks & Rec Desk", desc: "(650) 558-7300 · parksrec@burlingame.org")
                            }
                        }
                        .padding(14)
                        .cleanCardStyle()
                        
                        // Open in Apple Maps Button
                        Button(action: {
                            if let url = URL(string: "http://maps.apple.com/?daddr=850+Burlingame+Ave,+Burlingame,+CA+94010") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Get Directions in Maps")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.burlingameBlue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Clubhouse & Park Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.burlingameBlue)
                    .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}

private struct HoursRow: View {
    let day: String
    let hours: String
    var isHighlight: Bool = false
    
    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 12, weight: isHighlight ? .bold : .medium))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            Text(hours)
                .font(.system(size: 12, weight: isHighlight ? .bold : .semibold))
                .foregroundColor(isHighlight ? AppTheme.burlingameBlue : AppTheme.textSecondary)
        }
        .padding(.vertical, 3)
    }
}

private struct AmenityRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.burlingameBlue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
