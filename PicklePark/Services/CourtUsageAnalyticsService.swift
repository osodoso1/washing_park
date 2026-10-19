import Foundation
import CloudKit
import Combine
import SwiftUI

// MARK: - Telemetry Record Model (100% Real Player Data for City of Burlingame)

public struct CourtUsageTelemetryEntry: Identifiable, Codable, Hashable {
    public let id: String
    public let timestamp: Date
    public let dayOfWeek: String
    public let isWeekend: Bool
    public let hourOfDay: Int
    public let courtsInUse: Int          // 0..4 (Court 1 permanent PB courts)
    public let peopleInQueue: Int        // Paddles waiting in rack
    public let walkOnCourtsOpen: Int     // 0..4 (Courts 2 & 3 extra PB courts open)
    public let court2State: String
    public let court3State: String
    public let estimatedWaitMinutes: Int // Calculated from real queue & 15-min avg pickleball game
    public let estimatedTotalPlayers: Int
    public let reporterTag: String
    
    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        courtsInUse: Int,
        peopleInQueue: Int,
        walkOnCourtsOpen: Int,
        court2State: String,
        court3State: String,
        estimatedWaitMinutes: Int,
        reporterTag: String = "Community"
    ) {
        self.id = id
        self.timestamp = timestamp
        
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        self.dayOfWeek = formatter.string(from: timestamp)
        self.isWeekend = (weekday == 1 || weekday == 7)
        self.hourOfDay = cal.component(.hour, from: timestamp)
        
        self.courtsInUse = min(4, max(0, courtsInUse))
        self.peopleInQueue = max(0, peopleInQueue)
        self.walkOnCourtsOpen = min(4, max(0, walkOnCourtsOpen))
        self.court2State = court2State
        self.court3State = court3State
        self.estimatedWaitMinutes = max(0, estimatedWaitMinutes)
        
        let walkOnUsed = max(0, 4 - self.walkOnCourtsOpen)
        self.estimatedTotalPlayers = (self.courtsInUse * 4) + self.peopleInQueue + (walkOnUsed * 4)
        self.reporterTag = reporterTag
    }
}

// MARK: - Hourly Wait Profile Point (100% Real Aggregated Player Reports)

public struct HourlyWaitPoint: Identifiable {
    public var id: Int { hour }
    public let hour: Int               // 7..21 (7 AM to 9 PM)
    public let label: String           // e.g. "8a", "12p", "5p"
    public let fullLabel: String       // e.g. "8:00 AM"
    public let usualWaitMinutes: Int   // Average wait from real player reports only
    public let usualQueueCount: Int    // Average paddles in queue from real player reports only
    public let sampleCount: Int        // Number of real player reports for this hour
    
    public var hasRealData: Bool {
        sampleCount > 0
    }
    
    public var crowdLevelText: String {
        guard hasRealData else {
            return "No reports logged for this hour yet"
        }
        switch usualWaitMinutes {
        case 0: return "0m Wait · Open Courts"
        case 1...7: return "Short Wait (<1/2 Game)"
        case 8...15: return "Moderate (~1 Game Wait)"
        case 16...25: return "Busy (1–1.5 Games Wait)"
        default: return "Peak Rush (2+ Games Wait)"
        }
    }
}

public enum WaitGraphDayFilter: String, CaseIterable, Identifiable {
    case allDays = "All Reports"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    
    public var id: String { rawValue }
}

// MARK: - Court Usage & Wait Time Analytics Service (100% Real Data Only)

public final class CourtUsageAnalyticsService: ObservableObject {
    public static let shared = CourtUsageAnalyticsService()
    
    /// Standard recreational pickleball game to 11 pts (win by 2) averages 15 minutes.
    /// Each court holds 4 players (4-on / 4-off paddle rack rotation).
    /// Across 4 active courts, 16 players rotate every 15 minutes (~3.75 mins per 4-player rack).
    public static let averagePickleballGameMinutes: Double = 15.0
    public static let permanentCourtCount: Int = 4
    
    private let localArchiveKey = "washington_park_city_usage_telemetry_real_v2"
    private let ownerUnlockedKey = "washington_park_owner_vault_unlocked_v1"
    
    @Published public private(set) var telemetryLogs: [CourtUsageTelemetryEntry] = []
    @Published public var isSyncingCloudLogs: Bool = false
    @Published public var isOwnerUnlocked: Bool = false
    
    private let container = CKContainer.default()
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    private init() {
        self.isOwnerUnlocked = UserDefaults.standard.bool(forKey: ownerUnlockedKey)
        loadLocalLogs()
        
        Task {
            await fetchCloudTelemetryLogs()
        }
    }
    
    // MARK: - Owner-Only Access Control (Dominic / osodoso)
    
    public func verifyOwnerPasscode(_ input: String) -> Bool {
        let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleaned == "osodoso" || cleaned == "dominic" || cleaned == "8500" {
            isOwnerUnlocked = true
            UserDefaults.standard.set(true, forKey: ownerUnlockedKey)
            HapticFeedback.success()
            Task {
                await fetchCloudTelemetryLogs()
            }
            return true
        }
        return false
    }
    
    public func lockOwnerVault() {
        isOwnerUnlocked = false
        UserDefaults.standard.set(false, forKey: ownerUnlockedKey)
    }
    
    // MARK: - Pickleball Game Wait Time Calculator (15-Min Average Game)
    
    /// Calculates court wait time in minutes strictly from reported queue & active courts:
    /// - Wait time ONLY triggers when all 4 permanent courts are filled (`courtsInUse >= 4`) AND `peopleInQueue > 0`.
    /// - If fewer than 4 courts are in use (`courtsInUse < 4`), at least 1 court is empty so wait time is 0 minutes.
    /// - Average pickleball game = 15 minutes across the 4 filled courts (~3.75 mins per 4 players in queue).
    public static func calculateEstimatedWaitMinutes(
        courtsInUse: Int,
        peopleInQueue: Int,
        walkOnCourtsOpen: Int = 0
    ) -> Int {
        let activeCourts = min(4, max(0, courtsInUse))
        let queue = max(0, peopleInQueue)
        
        // Wait time ONLY exists when all 4 courts are filled AND players are waiting in the queue
        guard activeCourts >= 4, queue > 0 else {
            return 0
        }
        
        // Each 15-minute game rotates 4 players per court across the 4 full courts (3.75 mins per 4 players)
        let turnoverMinutesPerFourPlayers = averagePickleballGameMinutes / Double(permanentCourtCount)
        let groupsOfFourWaiting = Double(queue) / 4.0
        
        let rawWait = groupsOfFourWaiting * turnoverMinutesPerFourPlayers
        return max(1, Int(rawWait.rounded()))
    }
    
    /// Number of 4-paddle racks waiting in the queue
    public static func paddleRacksAhead(for peopleInQueue: Int) -> Int {
        guard peopleInQueue > 0 else { return 0 }
        return Int(ceil(Double(peopleInQueue) / 4.0))
    }
    
    // MARK: - Record & Sync Real Player Usage Telemetry
    
    public func recordUsageSnapshot(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        courtsInUse: Int,
        peopleInQueue: Int,
        walkOnCourtsOpen: Int,
        court2State: String,
        court3State: String,
        reporter: String?,
        pushToCloud: Bool = true
    ) {
        let waitMins = Self.calculateEstimatedWaitMinutes(
            courtsInUse: courtsInUse,
            peopleInQueue: peopleInQueue,
            walkOnCourtsOpen: walkOnCourtsOpen
        )
        
        let entry = CourtUsageTelemetryEntry(
            id: id,
            timestamp: timestamp,
            courtsInUse: courtsInUse,
            peopleInQueue: peopleInQueue,
            walkOnCourtsOpen: walkOnCourtsOpen,
            court2State: court2State,
            court3State: court3State,
            estimatedWaitMinutes: waitMins,
            reporterTag: (reporter?.isEmpty == false) ? reporter! : "Player"
        )
        
        DispatchQueue.main.async {
            // Avoid duplicate rapid-fire entries within 10 seconds with identical timestamp/values
            if let latest = self.telemetryLogs.first,
               abs(latest.timestamp.timeIntervalSince(entry.timestamp)) < 10,
               latest.courtsInUse == entry.courtsInUse,
               latest.peopleInQueue == entry.peopleInQueue,
               latest.walkOnCourtsOpen == entry.walkOnCourtsOpen {
                return
            }
            
            if !self.telemetryLogs.contains(where: { $0.id == entry.id }) {
                self.telemetryLogs.insert(entry, at: 0)
                self.telemetryLogs.sort { $0.timestamp > $1.timestamp }
                if self.telemetryLogs.count > 2000 {
                    self.telemetryLogs = Array(self.telemetryLogs.prefix(2000))
                }
                self.saveLocalLogs()
            }
        }
        
        if pushToCloud {
            pushTelemetryToCloudKit(entry)
            Task {
                await syncTelemetryWithPrivateCloudEndpoint()
            }
        }
    }
    
    private let privateTelemetryEndpointURL = "https://kvdb.io/4yHj935398713589/wp_city_telemetry_osodoso_v1"
    
    private func pushTelemetryToCloudKit(_ entry: CourtUsageTelemetryEntry) {
        let recordID = CKRecord.ID(recordName: "telemetry_\(entry.id)")
        let record = CKRecord(recordType: "CityUsageTelemetryRecord", recordID: recordID)
        record["entryId"] = entry.id as NSString
        record["timestamp"] = entry.timestamp as NSDate
        record["dayOfWeek"] = entry.dayOfWeek as NSString
        record["isWeekend"] = (entry.isWeekend ? 1 : 0) as NSNumber
        record["hourOfDay"] = entry.hourOfDay as NSNumber
        record["courtsInUse"] = entry.courtsInUse as NSNumber
        record["peopleInQueue"] = entry.peopleInQueue as NSNumber
        record["walkOnCourtsOpen"] = entry.walkOnCourtsOpen as NSNumber
        record["court2State"] = entry.court2State as NSString
        record["court3State"] = entry.court3State as NSString
        record["estimatedWaitMinutes"] = entry.estimatedWaitMinutes as NSNumber
        record["estimatedTotalPlayers"] = entry.estimatedTotalPlayers as NSNumber
        record["reporterTag"] = entry.reporterTag as NSString
        
        publicDB.save(record) { _, _ in }
    }
    
    private func syncTelemetryWithPrivateCloudEndpoint() async {
        guard let url = URL(string: privateTelemetryEndpointURL) else { return }
        
        // 1. Pull existing cloud entries first so we never overwrite other players' logs
        var remoteLogs: [CourtUsageTelemetryEntry] = []
        var getReq = URLRequest(url: url)
        getReq.httpMethod = "GET"
        getReq.timeoutInterval = 4.0
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let (data, resp) = try? await URLSession.shared.data(for: getReq),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
           let decoded = try? decoder.decode([CourtUsageTelemetryEntry].self, from: data) {
            remoteLogs = decoded
        }
        
        await MainActor.run {
            if !remoteLogs.isEmpty {
                self.mergeLogs(remoteLogs)
            }
        }
        
        // 2. Push merged real logs back to private endpoint for Mac script export
        let logsToPush = await MainActor.run { Array(self.telemetryLogs.prefix(1000)) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let jsonData = try? encoder.encode(logsToPush) else { return }
        
        var postReq = URLRequest(url: url)
        postReq.httpMethod = "POST"
        postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postReq.httpBody = jsonData
        postReq.timeoutInterval = 4.0
        _ = try? await URLSession.shared.data(for: postReq)
    }
    
    /// Pulls all real player reports from CloudKit and private cloud telemetry endpoint across all devices
    public func fetchCloudTelemetryLogs() async {
        await MainActor.run { self.isSyncingCloudLogs = true }
        defer {
            Task { @MainActor in self.isSyncingCloudLogs = false }
        }
        
        // 1. Pull from private cloud telemetry endpoint
        if let url = URL(string: privateTelemetryEndpointURL) {
            var getReq = URLRequest(url: url)
            getReq.httpMethod = "GET"
            getReq.timeoutInterval = 4.0
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let (data, resp) = try? await URLSession.shared.data(for: getReq),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
               let decoded = try? decoder.decode([CourtUsageTelemetryEntry].self, from: data),
               !decoded.isEmpty {
                await MainActor.run {
                    self.mergeLogs(decoded)
                }
            }
        }
        
        // 2. Pull from Apple CloudKit public database
        let query = CKQuery(recordType: "CityUsageTelemetryRecord", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 500)
            var fetched: [CourtUsageTelemetryEntry] = []
            
            for (_, result) in matchResults {
                if case .success(let record) = result,
                   let timestamp = record["timestamp"] as? Date {
                    let id = (record["entryId"] as? String) ?? record.recordID.recordName
                    let courts = (record["courtsInUse"] as? Int) ?? 0
                    let queue = (record["peopleInQueue"] as? Int) ?? 0
                    let walkOn = (record["walkOnCourtsOpen"] as? Int) ?? 0
                    let c2 = (record["court2State"] as? String) ?? "Free"
                    let c3 = (record["court3State"] as? String) ?? "Free"
                    let waitMins = Self.calculateEstimatedWaitMinutes(courtsInUse: courts, peopleInQueue: queue, walkOnCourtsOpen: walkOn)
                    let reporter = (record["reporterTag"] as? String) ?? "Player"
                    
                    fetched.append(
                        CourtUsageTelemetryEntry(
                            id: id,
                            timestamp: timestamp,
                            courtsInUse: courts,
                            peopleInQueue: queue,
                            walkOnCourtsOpen: walkOn,
                            court2State: c2,
                            court3State: c3,
                            estimatedWaitMinutes: waitMins,
                            reporterTag: reporter
                        )
                    )
                }
            }
            
            if !fetched.isEmpty {
                await MainActor.run {
                    self.mergeLogs(fetched)
                }
            }
        } catch {
            // Keep existing real local logs if offline
        }
    }
    
    private func mergeLogs(_ incoming: [CourtUsageTelemetryEntry]) {
        var byId: [String: CourtUsageTelemetryEntry] = [:]
        for item in telemetryLogs { byId[item.id] = item }
        for item in incoming { byId[item.id] = item }
        
        telemetryLogs = byId.values.sorted { $0.timestamp > $1.timestamp }
        if telemetryLogs.count > 2000 {
            telemetryLogs = Array(telemetryLogs.prefix(2000))
        }
        saveLocalLogs()
    }
    
    // MARK: - Hourly Wait Profile (100% Real Data Only — Zero Synthetic Data)
    
    public func hourlyWaitProfile(for filter: WaitGraphDayFilter) -> [HourlyWaitPoint] {
        // Hours from 7 AM (7) to 9 PM (21)
        let hours = Array(7...21)
        
        return hours.map { hour in
            let matchingLogs = telemetryLogs.filter { entry in
                guard entry.hourOfDay == hour else { return false }
                switch filter {
                case .allDays:
                    return true
                case .weekdays:
                    return !entry.isWeekend
                case .weekends:
                    return entry.isWeekend
                }
            }
            
            guard !matchingLogs.isEmpty else {
                return HourlyWaitPoint(
                    hour: hour,
                    label: Self.shortHourLabel(hour),
                    fullLabel: Self.fullHourLabel(hour),
                    usualWaitMinutes: 0,
                    usualQueueCount: 0,
                    sampleCount: 0
                )
            }
            
            let totalWait = matchingLogs.map(\.estimatedWaitMinutes).reduce(0, +)
            let totalQueue = matchingLogs.map(\.peopleInQueue).reduce(0, +)
            let avgWait = Int((Double(totalWait) / Double(matchingLogs.count)).rounded())
            let avgQueue = Int((Double(totalQueue) / Double(matchingLogs.count)).rounded())
            
            return HourlyWaitPoint(
                hour: hour,
                label: Self.shortHourLabel(hour),
                fullLabel: Self.fullHourLabel(hour),
                usualWaitMinutes: max(0, avgWait),
                usualQueueCount: max(0, avgQueue),
                sampleCount: matchingLogs.count
            )
        }
    }
    
    private static func shortHourLabel(_ hour: Int) -> String {
        if hour == 12 { return "12p" }
        if hour > 12 { return "\(hour - 12)p" }
        return "\(hour)a"
    }
    
    private static func fullHourLabel(_ hour: Int) -> String {
        if hour == 12 { return "12:00 PM" }
        if hour > 12 { return "\(hour - 12):00 PM" }
        return "\(hour):00 AM"
    }
    
    // MARK: - City of Burlingame Summary & CSV Export (100% Real Logged Data)
    
    public var averageWaitMinutesLogged: Int {
        guard !telemetryLogs.isEmpty else { return 0 }
        let total = telemetryLogs.map(\.estimatedWaitMinutes).reduce(0, +)
        return Int((Double(total) / Double(telemetryLogs.count)).rounded())
    }
    
    public var peakWaitMinutesLogged: Int {
        telemetryLogs.map(\.estimatedWaitMinutes).max() ?? 0
    }
    
    public var courtFullSaturationPercentage: Int {
        guard !telemetryLogs.isEmpty else { return 0 }
        let fullCount = telemetryLogs.filter { $0.courtsInUse >= 4 }.count
        return Int((Double(fullCount) / Double(telemetryLogs.count) * 100.0).rounded())
    }
    
    public func generateCityCSVReport() -> String {
        var lines: [String] = [
            "Timestamp_ISO8601,Local_Date_Time,Day_Of_Week,Is_Weekend,Hour_24h,Permanent_Courts_In_Use_Max4,Players_In_Paddle_Queue,WalkOn_PB_Courts_Open_Max4,Court2_Status,Court3_Status,Estimated_Wait_Minutes_15mGameModel,Estimated_Total_Players_At_Park"
        ]
        
        let isoFormatter = ISO8601DateFormatter()
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for log in telemetryLogs {
            let iso = isoFormatter.string(from: log.timestamp)
            let local = localFormatter.string(from: log.timestamp)
            let row = "\(iso),\"\(local)\",\(log.dayOfWeek),\(log.isWeekend),\(log.hourOfDay),\(log.courtsInUse),\(log.peopleInQueue),\(log.walkOnCourtsOpen),\"\(log.court2State)\",\"\(log.court3State)\",\(log.estimatedWaitMinutes),\(log.estimatedTotalPlayers)"
            lines.append(row)
        }
        
        return lines.joined(separator: "\n")
    }
    
    public func generateCityExecutiveSummary() -> String {
        let count = telemetryLogs.count
        let avgWait = averageWaitMinutesLogged
        let maxWait = peakWaitMinutesLogged
        let saturation = courtFullSaturationPercentage
        
        return """
        WASHINGTON PARK PICKLEBALL — CITY OF BURLINGAME REAL USAGE & WAIT TIME REPORT
        Generated: \(Date().formatted(date: .abbreviated, time: .shortened))
        =============================================================================
        • Total Real Player Check-Ins Logged: \(count)
        • Average Recorded Court Wait Time: \(avgWait) mins (based on 15-min avg pickleball game)
        • Peak Recorded Wait Time: \(maxWait) mins
        • Permanent Court 1 Full-Capacity Rate: \(saturation)% of reports show all 4 courts full
        """
    }
    
    // MARK: - Local Persistence (No Seeded/Synthetic Data)
    
    private func loadLocalLogs() {
        if let data = UserDefaults.standard.data(forKey: localArchiveKey),
           let decoded = try? JSONDecoder().decode([CourtUsageTelemetryEntry].self, from: data) {
            self.telemetryLogs = decoded
        } else {
            self.telemetryLogs = []
        }
    }
    
    private func saveLocalLogs() {
        if let encoded = try? JSONEncoder().encode(telemetryLogs) {
            UserDefaults.standard.set(encoded, forKey: localArchiveKey)
        }
    }
}
