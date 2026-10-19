import Foundation
import Combine
import SwiftUI

public enum ScheduleScope: String, CaseIterable, Identifiable {
    case today = "Today"
    case sevenDays = "7 Days"
    case month = "Month"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .today: return "sun.max.fill"
        case .sevenDays: return "calendar.badge.clock"
        case .month: return "calendar"
        }
    }
}

public final class CourtScheduleStore: ObservableObject {
    public static let shared = CourtScheduleStore()
    
    @Published public var selectedScope: ScheduleScope = .today
    @Published public var selectedDate: Date = Date()
    
    @Published public var todaySlots: [ReservationSlot] = []
    @Published public var weekSlots: [Date: [ReservationSlot]] = [:]
    @Published public var monthSlots: [Date: [ReservationSlot]] = [:]
    
    @Published public var isRefreshing: Bool = false
    @Published public var lastRefreshTime: Date? = nil
    
    private let scraper = WebTracScraper.shared
    private let calendarService = BurlingameCalendarService.shared
    private let calendar = Calendar.current
    
    public init() {
        self.loadInitialData()
        Task {
            await self.refreshAll()
        }
    }
    
    public func loadInitialData() {
        let initialEvents = calendarService.liveEvents
        self.todaySlots = scraper.generateSchedule(for: Date(), liveEvents: initialEvents)
        self.populateWeekSlots(liveEvents: initialEvents)
        self.populateMonthSlots(liveEvents: initialEvents)
        self.lastRefreshTime = Date()
    }
    
    /// Pull-to-refresh & on-load live sync
    public func refreshAll() async {
        await MainActor.run {
            self.isRefreshing = true
        }
        
        let liveEvents = await calendarService.fetchLiveCalendar()
        
        await MainActor.run {
            self.todaySlots = self.scraper.generateSchedule(for: Date(), liveEvents: liveEvents)
            self.populateWeekSlots(liveEvents: liveEvents)
            self.populateMonthSlots(liveEvents: liveEvents)
            self.lastRefreshTime = Date()
            self.isRefreshing = false
            HapticFeedback.light()
        }
    }
    
    public func currentHourSlot(for courtNumber: Int) -> ReservationSlot? {
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let targetCourtId = "wp_tennis_\(courtNumber)"
        for slot in todaySlots {
            if (slot.courtId == targetCourtId || slot.courtName.contains("\(courtNumber)")) && slot.startHour == currentHour {
                return slot
            }
        }
        return nil
    }
    
    private func populateWeekSlots(liveEvents: [CivicPlusEvent]) {
        var slotsByDay: [Date: [ReservationSlot]] = [:]
        for dayOffset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                slotsByDay[startOfDay] = scraper.generateSchedule(for: date, liveEvents: liveEvents)
            }
        }
        self.weekSlots = slotsByDay
    }
    
    private func populateMonthSlots(liveEvents: [CivicPlusEvent]) {
        var slotsByDay: [Date: [ReservationSlot]] = [:]
        for dayOffset in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                slotsByDay[startOfDay] = scraper.generateSchedule(for: date, liveEvents: liveEvents)
            }
        }
        self.monthSlots = slotsByDay
    }
    
    public func slots(for date: Date) -> [ReservationSlot] {
        let startOfDay = calendar.startOfDay(for: date)
        if calendar.isDateInToday(date) {
            return todaySlots
        }
        return weekSlots[startOfDay] ?? monthSlots[startOfDay] ?? []
    }
    
    public func slotsForDate(_ date: Date) -> [ReservationSlot] {
        return slots(for: date)
    }
}
