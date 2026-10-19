import Foundation
import SwiftUI

public enum SlotStatus: String, Codable, CaseIterable {
    case available = "Available"
    case reserved = "Reserved"
    case dropInOpenPlay = "Drop-In Open Play"
    case lessonsProgram = "Lessons / Clinic"
    case past = "Past"
    
    public var title: String {
        return self.rawValue
    }
    
    public var badgeColor: Color {
        switch self {
        case .available:
            return Color(red: 0.18, green: 0.80, blue: 0.44) // Vibrant Green
        case .reserved:
            return Color(red: 0.95, green: 0.32, blue: 0.32) // Coral Red
        case .dropInOpenPlay:
            return Color(red: 0.20, green: 0.60, blue: 0.98) // Burlingame Blue
        case .lessonsProgram:
            return Color(red: 0.96, green: 0.65, blue: 0.14) // Amber
        case .past:
            return Color(red: 0.50, green: 0.54, blue: 0.60) // Neutral Slate
        }
    }
    
    public var iconName: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .reserved: return "lock.fill"
        case .dropInOpenPlay: return "person.3.sequence.fill"
        case .lessonsProgram: return "graduationcap.fill"
        case .past: return "clock.fill"
        }
    }
}

public struct ReservationSlot: Identifiable, Codable, Hashable {
    public let id: String
    public let courtId: String
    public let courtName: String
    public let date: Date
    public let startTimeString: String // e.g. "09:00 AM"
    public let endTimeString: String   // e.g. "10:00 AM"
    public let startHour: Int          // 7 .. 21
    public let endHour: Int
    public var status: SlotStatus
    public var bookerName: String?
    public var eventName: String?
    public var isReservableCourt: Bool
    public let reserveWebTracUrl: String?
    
    public init(
        id: String = UUID().uuidString,
        courtId: String,
        courtName: String,
        date: Date,
        startTimeString: String,
        endTimeString: String,
        startHour: Int,
        endHour: Int,
        status: SlotStatus,
        bookerName: String? = nil,
        eventName: String? = nil,
        isReservableCourt: Bool = false,
        reserveWebTracUrl: String? = nil
    ) {
        self.id = id
        self.courtId = courtId
        self.courtName = courtName
        self.date = date
        self.startTimeString = startTimeString
        self.endTimeString = endTimeString
        self.startHour = startHour
        self.endHour = endHour
        self.status = status
        self.bookerName = bookerName
        self.eventName = eventName
        self.isReservableCourt = isReservableCourt
        self.reserveWebTracUrl = reserveWebTracUrl
    }
    
    public var timeRangeFormatted: String {
        "\(startTimeString) – \(endTimeString)"
    }
    
    public var displaySubtitle: String {
        if let booker = bookerName, !booker.isEmpty {
            if let ev = eventName, !ev.isEmpty, ev.lowercased() != "pickleball" && ev.lowercased() != "tennis" {
                return "\(booker) (\(ev))"
            }
            return booker
        } else if let ev = eventName, !ev.isEmpty {
            return ev
        }
        return status.rawValue
    }
}
