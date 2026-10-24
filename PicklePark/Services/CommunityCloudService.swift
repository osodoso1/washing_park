import Foundation
import Combine
import SwiftUI

/// Prior update item serialized with Unix Epoch seconds for cross-platform JSON compatibility
public struct CloudPriorUpdate: Codable {
    public var id: String
    public var courts: Int
    public var extra: Int
    public var queue: Int
    public var authorName: String?
    public var extraNotes: String?
    public var timestamp: Double
    
    public init(
        id: String = UUID().uuidString,
        courts: Int,
        extra: Int,
        queue: Int,
        authorName: String? = nil,
        extraNotes: String? = nil,
        timestamp: Double
    ) {
        self.id = id
        self.courts = courts
        self.extra = extra
        self.queue = queue
        self.authorName = authorName
        self.extraNotes = extraNotes
        self.timestamp = timestamp
    }
}

/// Payload for live Washington Park crowdsourced activity synced across all players' devices
public struct ParkCloudSyncPayload: Codable {
    public var courtsInUse: Int
    public var extraCourts: Int
    public var inQueue: Int
    public var lastAuthor: String?
    public var extraNotes: String?
    public var reportTimestamp: Double // Unix Epoch seconds
    
    // Walk-On Sides Status (Courts 2 & 3)
    public var court2State: String
    public var court3State: String
    public var priorUpdates: [CloudPriorUpdate]?
    
    // Upload-only: seconds since the report happened on this device. The server converts it to
    // its own clock, so phones with a wrong clock can't make a report look newer or older than it is.
    public var reportAgeSeconds: Double?
    // Upload-only: which fields this upload changes (LiveFeedUpdateKind raw value)
    public var updateKind: String?
    // Download-only: server clock when the response was produced
    public var serverTime: Double?
    
    public init(
        courtsInUse: Int,
        extraCourts: Int,
        inQueue: Int,
        lastAuthor: String? = nil,
        extraNotes: String? = nil,
        reportTimestamp: Double = Date().timeIntervalSince1970,
        court2State: String = "Free",
        court3State: String = "Free",
        priorUpdates: [CloudPriorUpdate]? = nil,
        reportAgeSeconds: Double? = nil,
        updateKind: String? = nil
    ) {
        self.courtsInUse = courtsInUse
        self.extraCourts = extraCourts
        self.inQueue = inQueue
        self.lastAuthor = lastAuthor
        self.extraNotes = extraNotes
        self.reportTimestamp = reportTimestamp
        self.court2State = court2State
        self.court3State = court3State
        self.priorUpdates = priorUpdates
        self.reportAgeSeconds = reportAgeSeconds
        self.updateKind = updateKind
    }
}

/// What a live-feed upload changes. Walk-on toggles only touch their own court on the server,
/// so a phone that is a few seconds behind can't overwrite everyone's courts/queue numbers.
public enum LiveFeedUpdateKind: String, Codable {
    case full
    case walkOnCourt2
    case walkOnCourt3
}

public final class CommunityCloudService: ObservableObject {
    public static let shared = CommunityCloudService()
    
    // Shared Washington Park Community Cloud Endpoint (Cloudflare Workers + Durable Object)
    public static let baseWorkerURL: String = {
        #if DEBUG
        // Lets Debug builds sync against a local `wrangler dev` Worker; never compiled into App Store builds
        if let override = ProcessInfo.processInfo.environment["PICKLEPARK_WORKER_URL"], !override.isEmpty {
            return override
        }
        #endif
        return "https://picklepark-sync.cf-watcher.workers.dev"
    }()
    public static let productionFeedPath = "wp_live_feed_v1"
    /// Overridable so the test suite syncs against an isolated feed instead of production
    var liveFeedPath = CommunityCloudService.productionFeedPath
    private var cloudEndpointURL: URL? { URL(string: "\(Self.baseWorkerURL)/\(liveFeedPath)") }
    
    private let pendingUploadKey = "wp_live_feed_pending_upload_v1"
    private let lastClipboardChangeCountKey = "wp_clipboard_last_change_count_v1"
    
    @Published public var isSyncing: Bool = false
    @Published public var isBroadcasting: Bool = false
    /// Last time this phone actually exchanged data with the live feed server
    @Published public var lastCloudSyncDate: Date? = nil
    /// True when the most recent attempt to reach the live feed failed (no signal / server error)
    @Published public var lastSyncFailed: Bool = false
    @Published public var syncBannerMessage: String? = nil
    
    // Main-thread only. Bumped every time this phone changes the live report; a network response
    // is only applied if no newer local change happened while it was in flight.
    private var localChangeGeneration: Int = 0
    private var uploadsInFlight: Int = 0
    
    /// A local report that hasn't reached the server yet (e.g. no signal at the park); retried on the next sync
    private var pendingUploadKind: LiveFeedUpdateKind? {
        get { UserDefaults.standard.string(forKey: pendingUploadKey).flatMap(LiveFeedUpdateKind.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: pendingUploadKey) }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        Task {
            await pullLatestFromCloud()
        }
    }
    
    /// Pulls latest crowdsourced court activity & walk-on status from the cloud
    public func pullLatestFromCloud() async {
        guard let url = cloudEndpointURL else { return }
        
        let (startGeneration, pendingKind, uploading) = await MainActor.run {
            (self.localChangeGeneration, self.pendingUploadKind, self.uploadsInFlight > 0)
        }
        // Our own report is on its way up; its response carries the newest server state
        if uploading { return }
        if let pendingKind {
            // Deliver the report that never made it instead of overwriting it with older cloud data
            await uploadLocalReport(kind: pendingKind, generation: startGeneration)
            return
        }
        
        await MainActor.run { self.isSyncing = true }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        
        var payload: ParkCloudSyncPayload? = nil
        var succeeded = false
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpResp = response as? HTTPURLResponse {
            if httpResp.statusCode == 200 {
                payload = try? JSONDecoder.pickleParkCloudDecoder.decode(ParkCloudSyncPayload.self, from: data)
                succeeded = payload != nil
            } else if httpResp.statusCode == 404 {
                // Feed is empty: nobody has reported yet
                succeeded = true
            }
        }
        
        await MainActor.run {
            if let payload, self.localChangeGeneration == startGeneration, self.pendingUploadKind == nil {
                self.applyCloudPayload(payload)
            }
            if succeeded {
                self.lastCloudSyncDate = Date()
            }
            self.lastSyncFailed = !succeeded
            self.isSyncing = false
        }
    }
    
    /// Broadcasts this phone's latest court report to the community cloud. Call on the main thread.
    public func broadcastToCloud(kind: LiveFeedUpdateKind = .full) {
        localChangeGeneration += 1
        let generation = localChangeGeneration
        pendingUploadKind = kind
        Task {
            await uploadLocalReport(kind: kind, generation: generation)
        }
    }
    
    @discardableResult
    private func uploadLocalReport(kind: LiveFeedUpdateKind, generation: Int) async -> Bool {
        guard let url = cloudEndpointURL else { return false }
        
        let payload: ParkCloudSyncPayload = await MainActor.run {
            self.uploadsInFlight += 1
            self.isBroadcasting = true
            return self.makeLocalReportPayload(kind: kind)
        }
        
        var returnedPayload: ParkCloudSyncPayload? = nil
        if let jsonData = try? JSONEncoder().encode(payload) {
            for attempt in 1...3 {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 12.0)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                
                if let (data, response) = try? await URLSession.shared.data(for: request),
                   let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
                   let decoded = try? JSONDecoder.pickleParkCloudDecoder.decode(ParkCloudSyncPayload.self, from: data) {
                    returnedPayload = decoded
                    break
                }
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                }
            }
        }
        
        await MainActor.run {
            self.uploadsInFlight -= 1
            self.isBroadcasting = self.uploadsInFlight > 0
            if let returnedPayload {
                self.lastCloudSyncDate = Date()
                self.lastSyncFailed = false
                // An older upload finishing after a newer local change must not undo that change
                if generation == self.localChangeGeneration {
                    self.pendingUploadKind = nil
                    self.applyCloudPayload(returnedPayload)
                }
            } else {
                self.lastSyncFailed = true
            }
        }
        return returnedPayload != nil
    }
    
    private func makeLocalReportPayload(kind: LiveFeedUpdateKind) -> ParkCloudSyncPayload {
        let qStatus = PickleQueueManager.shared.queueStatus
        let walkOn = WalkOnCourtManager.shared.status
        let reportDate = qStatus.pickleQueReportDate
        return ParkCloudSyncPayload(
            courtsInUse: qStatus.courtsInUse,
            extraCourts: qStatus.extraCourts,
            inQueue: qStatus.inQueue,
            // Walk-on taps credit this phone's profile name, not whoever reported last
            lastAuthor: kind == .full ? qStatus.lastAuthor : LeaderboardManager.shared.currentUser.name,
            extraNotes: kind == .full ? qStatus.priorUpdates.first?.extraNotes : nil,
            reportTimestamp: reportDate.timeIntervalSince1970,
            court2State: walkOn.court2State.rawValue,
            court3State: walkOn.court3State.rawValue,
            reportAgeSeconds: max(0, Date().timeIntervalSince(reportDate)),
            updateKind: kind.rawValue
        )
    }
    
    /// Applies the server's live state. The server never lets the live report move backwards in time,
    /// so its answer is authoritative; callers skip responses that raced a newer local change.
    private func applyCloudPayload(_ payload: ParkCloudSyncPayload) {
        guard payload.reportTimestamp > 1000 else { return }
        let qManager = PickleQueueManager.shared
        let cloudDate = Date(timeIntervalSince1970: payload.reportTimestamp)
        
        // Check if this is a brand-new remote queue update to notify the user
        ParkNotificationManager.shared.evaluateIncomingQueuePayload(payload)
        
        var status = qManager.queueStatus
        status.courtsInUse = payload.courtsInUse
        status.extraCourts = payload.extraCourts
        status.inQueue = payload.inQueue
        status.lastAuthor = payload.lastAuthor
        status.pickleQueReportDate = cloudDate
        status.lastAppSyncDate = Date()
        if let cloudPriors = payload.priorUpdates, !cloudPriors.isEmpty {
            status.priorUpdates = cloudPriors
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(2)
                .map {
                    PickleQueUpdate(
                        id: $0.id,
                        courts: $0.courts,
                        extra: $0.extra,
                        queue: $0.queue,
                        authorName: $0.authorName,
                        extraNotes: $0.extraNotes,
                        timestamp: Date(timeIntervalSince1970: $0.timestamp)
                    )
                }
        }
        qManager.queueStatus = status
        qManager.saveLocalState()
        
        let deterministicId = "cf_live_\(Int(payload.reportTimestamp))"
        CourtUsageAnalyticsService.shared.recordUsageSnapshot(
            id: deterministicId,
            timestamp: cloudDate,
            courtsInUse: payload.courtsInUse,
            peopleInQueue: payload.inQueue,
            walkOnCourtsOpen: payload.extraCourts,
            court2State: payload.court2State,
            court3State: payload.court3State,
            reporter: payload.lastAuthor,
            pushToCloud: false
        )
        
        // Walk-on sides reset at 11 PM / on a new day; otherwise mirror the server
        let walkOnManager = WalkOnCourtManager.shared
        if WalkOnCourtStatus.isDateExpired(cloudDate) {
            walkOnManager.status.court2State = .free
            walkOnManager.status.court3State = .free
        } else {
            if let c2 = CourtSideOccupancy(rawValue: payload.court2State) {
                walkOnManager.status.court2State = c2
            }
            if let c3 = CourtSideOccupancy(rawValue: payload.court3State) {
                walkOnManager.status.court3State = c3
            }
            walkOnManager.status.lastReportDate = cloudDate
            walkOnManager.status.lastReporterName = payload.lastAuthor
        }
        walkOnManager.save()
    }
    
    // MARK: - Auto-Clipboard Ingestion Bridge
    
    /// Checks system pasteboard for PickleQue / Court activity text and auto-ingests it
    @MainActor
    public func checkAndIngestClipboard() -> Bool {
        // Only look at the clipboard once per new copy, so the same text is never re-posted
        // and iOS doesn't show a paste prompt on every app open
        let pasteboard = UIPasteboard.general
        let defaults = UserDefaults.standard
        guard pasteboard.hasStrings,
              pasteboard.changeCount != defaults.integer(forKey: lastClipboardChangeCountKey) else {
            return false
        }
        defaults.set(pasteboard.changeCount, forKey: lastClipboardChangeCountKey)
        
        guard let clipboardText = pasteboard.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboardText.isEmpty else {
            return false
        }
        
        // Check if clipboard contains PickleQue or court patterns
        // E.g., "Courts: 4, Extra: 2, Queue: 12", "4 courts in use, 14 waiting". Both a courts and a
        // queue keyword are required so copied dates, prices or phone numbers are never posted as a report.
        if let parsed = parseCourtText(clipboardText) {
            let lastStored = PickleQueueManager.shared.queueStatus
            
            // Avoid duplicate ingestion if exact same numbers and ingested within last 10 mins
            if parsed.courts == lastStored.courtsInUse &&
                parsed.extra == lastStored.extraCourts &&
                parsed.queue == lastStored.inQueue &&
                Date().timeIntervalSince(lastStored.pickleQueReportDate) < 300 {
                return false
            }
            
            PickleQueueManager.shared.submitActivity(
                courts: parsed.courts,
                extra: parsed.extra,
                queue: parsed.queue,
                author: parsed.author ?? "Auto-Sync",
                extraNotes: "Auto-synced from Clipboard"
            )
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                syncBannerMessage = "🟢 Auto-synced from PickleQue clipboard!"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.syncBannerMessage = nil
                }
            }
            
            return true
        }
        
        return false
    }
    
    private struct ParsedCourtInfo {
        let courts: Int
        let extra: Int
        let queue: Int
        let author: String?
    }
    
    private func parseCourtText(_ text: String) -> ParsedCourtInfo? {
        let lower = text.lowercased()
        
        // 1. Pattern: "Courts: X, Extra: Y, Queue: Z" or "X courts in use, Y extra, Z in queue"
        var courts: Int? = nil
        var extra: Int? = 0
        var queue: Int? = nil
        
        // Regex search for courts in use
        if let courtsMatch = regexMatch(pattern: #"(\d+)\s*(?:courts?|perm|in use)"#, in: lower) {
            courts = Int(courtsMatch)
        } else if let cMatch = regexMatch(pattern: #"courts?:\s*(\d+)"#, in: lower) {
            courts = Int(cMatch)
        }
        
        // Regex search for extra courts
        if let extraMatch = regexMatch(pattern: #"(\d+)\s*(?:extra|unreserved)"#, in: lower) {
            extra = Int(extraMatch)
        } else if let eMatch = regexMatch(pattern: #"extra:\s*(\d+)"#, in: lower) {
            extra = Int(eMatch)
        }
        
        // Regex search for queue / waiting
        if let queueMatch = regexMatch(pattern: #"(\d+)\s*(?:in queue|waiting|in line|queue)"#, in: lower) {
            queue = Int(queueMatch)
        } else if let qMatch = regexMatch(pattern: #"queue:\s*(\d+)"#, in: lower) {
            queue = Int(qMatch)
        }
        
        if let c = courts, let q = queue {
            return ParsedCourtInfo(
                courts: min(4, max(0, c)),
                extra: min(2, max(0, extra ?? 0)),
                queue: max(0, q),
                author: "PickleQue Sync"
            )
        }
        
        return nil
    }
    
    private func regexMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
            if let targetRange = Range(match.range(at: 1), in: text) {
                return String(text[targetRange])
            }
        }
        return nil
    }
}
