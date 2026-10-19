import Foundation

public enum CourtSideOccupancy: String, Codable, CaseIterable {
    case free = "Free"
    case oneSideTaken = "1 Side Taken"
    case bothSidesTaken = "Both Sides Taken"
    
    public var pickleballCourtsOpen: Int {
        switch self {
        case .free: return 2
        case .oneSideTaken: return 1
        case .bothSidesTaken: return 0
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .free: return "Free (2 PB)"
        case .oneSideTaken: return "1 Side (1 PB Open)"
        case .bothSidesTaken: return "Both Sides (Full)"
        }
    }
}

public struct WalkOnCourtStatus: Codable {
    public var court2State: CourtSideOccupancy
    public var court3State: CourtSideOccupancy
    public var lastReportDate: Date
    public var lastReporterName: String?
    
    public init(
        court2State: CourtSideOccupancy = .free,
        court3State: CourtSideOccupancy = .free,
        lastReportDate: Date = Date(),
        lastReporterName: String? = nil
    ) {
        self.court2State = court2State
        self.court3State = court3State
        self.lastReportDate = lastReportDate
        self.lastReporterName = lastReporterName
    }
    
    /// Total pickleball courts open on walk-on unreserved courts (0 to 4)
    public var totalPickleballCourtsOpen: Int {
        return court2State.pickleballCourtsOpen + court3State.pickleballCourtsOpen
    }
    
    /// Checks if a given report timestamp has expired past the 11:00 PM daily reset or prior day threshold
    public static func isDateExpired(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // If not from today, it is expired
        if !calendar.isDate(date, inSameDayAs: now) {
            return true
        }
        
        // If report was created before today's 11 PM and current time is past 11 PM
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 23
        components.minute = 0
        components.second = 0
        
        if let today11PM = calendar.date(from: components) {
            if now >= today11PM && date < today11PM {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if this report has expired past the 11:00 PM daily reset threshold
    public var isExpiredBy11PM: Bool {
        return Self.isDateExpired(lastReportDate)
    }
}
