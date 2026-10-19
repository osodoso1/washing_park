import Foundation

public struct PickleQueUpdate: Identifiable, Codable, Hashable {
    public let id: String
    public let courts: Int
    public let extra: Int
    public let queue: Int
    public let authorName: String?
    public let extraNotes: String?
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        courts: Int,
        extra: Int,
        queue: Int,
        authorName: String? = nil,
        extraNotes: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.courts = courts
        self.extra = extra
        self.queue = queue
        self.authorName = authorName
        self.extraNotes = extraNotes
        self.timestamp = timestamp
    }
    
    public var formattedSummary: String {
        var summary = "Courts: \(courts) | Extra: \(extra) | Queue: \(queue)"
        if let author = authorName, !author.isEmpty {
            summary += " by \(author)"
        }
        summary += " • \(timeAgo(from: timestamp))"
        return summary
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = max(1, seconds / 3600)
        if hours < 24 { return "\(hours) hr. ago" }
        let days = hours / 24
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

public struct QueueStatus: Codable {
    public var courtsInUse: Int       // e.g. 4
    public var extraCourts: Int       // e.g. 2
    public var inQueue: Int           // e.g. 14
    public var lastAuthor: String?
    public var pickleQueReportDate: Date // Aug 25, 6:27 PM or now
    public var lastAppSyncDate: Date      // Just now
    public var priorUpdates: [PickleQueUpdate]
    
    public init(
        courtsInUse: Int = 4,
        extraCourts: Int = 2,
        inQueue: Int = 14,
        lastAuthor: String? = nil,
        pickleQueReportDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 18, minute: 27)) ?? Date().addingTimeInterval(-17 * 3600),
        lastAppSyncDate: Date = Date(),
        priorUpdates: [PickleQueUpdate] = []
    ) {
        self.courtsInUse = courtsInUse
        self.extraCourts = extraCourts
        self.inQueue = inQueue
        self.lastAuthor = lastAuthor
        self.pickleQueReportDate = pickleQueReportDate
        self.lastAppSyncDate = lastAppSyncDate
        self.priorUpdates = priorUpdates
    }
    
    public static var defaultPickleQueData: QueueStatus {
        let reportDate = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 18, minute: 27)) ?? Date().addingTimeInterval(-17 * 3600)
        
        let updates = [
            PickleQueUpdate(courts: 4, extra: 0, queue: 9, authorName: nil, timestamp: reportDate),
            PickleQueUpdate(courts: 2, extra: 0, queue: 4, authorName: nil, timestamp: reportDate.addingTimeInterval(-24 * 3600))
        ]
        
        return QueueStatus(
            courtsInUse: 4,
            extraCourts: 2,
            inQueue: 14,
            lastAuthor: nil,
            pickleQueReportDate: reportDate,
            lastAppSyncDate: Date(),
            priorUpdates: updates
        )
    }
}
