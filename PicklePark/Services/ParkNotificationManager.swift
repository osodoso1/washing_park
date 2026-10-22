import Foundation
import UserNotifications
import CloudKit
import UIKit
import SwiftUI

// MARK: - Bulletproof Cross-Platform JSON Date Coders (ISO8601 + Fractional + Epoch)

public extension JSONDecoder {
    static var pickleParkCloudDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                let isoFractional = ISO8601DateFormatter()
                isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFractional.date(from: str) {
                    return date
                }
                let isoStandard = ISO8601DateFormatter()
                isoStandard.formatOptions = [.withInternetDateTime]
                if let date = isoStandard.date(from: str) {
                    return date
                }
                if let num = Double(str) {
                    return Self.dateFromNumeric(num)
                }
            }
            if let num = try? container.decode(Double.self) {
                return Self.dateFromNumeric(num)
            }
            return Date()
        }
        return decoder
    }
    
    private static func dateFromNumeric(_ num: Double) -> Date {
        // Distinguish Swift reference date (< 1.2B) vs Unix epoch seconds vs milliseconds
        if num > 100_000_000 && num < 1_200_000_000 {
            return Date(timeIntervalSinceReferenceDate: num)
        } else if num >= 10_000_000_000 {
            return Date(timeIntervalSince1970: num / 1000.0)
        } else {
            return Date(timeIntervalSince1970: num)
        }
    }
}

public extension JSONEncoder {
    static var pickleParkCloudEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

// MARK: - Park Notification Manager (Queue Wait Time & Lost and Found Alerts)

public final class ParkNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = ParkNotificationManager()
    
    private let masterEnabledKey = "wp_notifications_master_enabled_v1"
    private let queueAlertsKey = "wp_notifications_queue_wait_enabled_v1"
    private let lostFoundAlertsKey = "wp_notifications_lost_found_enabled_v1"
    private let lastNotifiedQueueTsKey = "wp_last_notified_queue_ts_v1"
    private let lastLocalQueueTsKey = "wp_last_local_queue_ts_v1"
    private let notifiedLostFoundIdsKey = "wp_notified_lost_found_ids_v1"
    private let localLostFoundIdsKey = "wp_local_submitted_lost_found_ids_v1"
    private let hasInitializedBaselineKey = "wp_notifications_baseline_initialized_v1"
    
    @Published public var isMasterEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMasterEnabled, forKey: masterEnabledKey)
            if isMasterEnabled {
                requestAuthorizationIfNeeded()
            } else {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
    
    @Published public var queueWaitAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(queueWaitAlertsEnabled, forKey: queueAlertsKey)
        }
    }
    
    @Published public var lostAndFoundAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(lostAndFoundAlertsEnabled, forKey: lostFoundAlertsKey)
        }
    }
    
    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private override init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: masterEnabledKey) == nil {
            defaults.set(true, forKey: masterEnabledKey)
        }
        if defaults.object(forKey: queueAlertsKey) == nil {
            defaults.set(true, forKey: queueAlertsKey)
        }
        if defaults.object(forKey: lostFoundAlertsKey) == nil {
            defaults.set(true, forKey: lostFoundAlertsKey)
        }
        
        self.isMasterEnabled = defaults.bool(forKey: masterEnabledKey)
        self.queueWaitAlertsEnabled = defaults.bool(forKey: queueAlertsKey)
        self.lostAndFoundAlertsEnabled = defaults.bool(forKey: lostFoundAlertsKey)
        
        super.init()
        UNUserNotificationCenter.current().delegate = self
        refreshAuthorizationStatus()
    }
    
    public func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    self.registerCloudKitSubscriptions()
                }
            }
        }
    }
    
    public func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.refreshAuthorizationStatus()
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.registerCloudKitSubscriptions()
                }
                completion?(granted)
            }
        }
    }
    
    // MARK: - Foreground Banner Presentation Delegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
    
    // MARK: - Local Submission Tracking (Prevents Self-Echo)
    
    public func markLocalQueueSubmission(timestamp: Double) {
        UserDefaults.standard.set(timestamp, forKey: lastLocalQueueTsKey)
        UserDefaults.standard.set(timestamp, forKey: lastNotifiedQueueTsKey)
    }
    
    public func markLocalLostFoundSubmission(id: String) {
        var localIds = Set(UserDefaults.standard.stringArray(forKey: localLostFoundIdsKey) ?? [])
        localIds.insert(id)
        UserDefaults.standard.set(Array(localIds), forKey: localLostFoundIdsKey)
        
        var notifiedIds = Set(UserDefaults.standard.stringArray(forKey: notifiedLostFoundIdsKey) ?? [])
        notifiedIds.insert(id)
        UserDefaults.standard.set(Array(notifiedIds), forKey: notifiedLostFoundIdsKey)
    }
    
    // MARK: - Queue & Wait Time Remote Change Detector
    
    public func evaluateIncomingQueuePayload(_ payload: ParkCloudSyncPayload) {
        let ts = payload.reportTimestamp
        guard ts > 1000 else { return }
        
        let defaults = UserDefaults.standard
        let lastNotifiedTs = defaults.double(forKey: lastNotifiedQueueTsKey)
        let lastLocalTs = defaults.double(forKey: lastLocalQueueTsKey)
        
        // First time the app boots, record the baseline timestamp so we only alert on NEW updates after install
        if lastNotifiedTs == 0 {
            defaults.set(ts, forKey: lastNotifiedQueueTsKey)
            return
        }
        
        // Must be strictly newer than the last notified report by > 3 seconds and not our own local submission
        guard ts > lastNotifiedTs + 3.0, abs(ts - lastLocalTs) > 3.0 else {
            return
        }
        
        // Only alert if the report happened within the last 2 hours
        guard Date().timeIntervalSince1970 - ts < 7200 else {
            defaults.set(ts, forKey: lastNotifiedQueueTsKey)
            return
        }
        
        defaults.set(ts, forKey: lastNotifiedQueueTsKey)
        
        guard isMasterEnabled && queueWaitAlertsEnabled else { return }
        
        sendQueueUpdatedNotification(
            courtsInUse: payload.courtsInUse,
            peopleInQueue: payload.inQueue,
            walkOnCourtsOpen: payload.extraCourts,
            author: payload.lastAuthor
        )
    }
    
    public func sendQueueUpdatedNotification(
        courtsInUse: Int,
        peopleInQueue: Int,
        walkOnCourtsOpen: Int,
        author: String?
    ) {
        let waitMins = CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(
            courtsInUse: courtsInUse,
            peopleInQueue: peopleInQueue,
            walkOnCourtsOpen: walkOnCourtsOpen
        )
        
        let content = UNMutableNotificationContent()
        let peopleWord = peopleInQueue == 1 ? "person" : "people"
        
        if waitMins > 0 {
            content.title = "🏓 Queue Updated for \(peopleInQueue) \(peopleWord.capitalized)"
            content.subtitle = "Est. Wait Time: ~\(waitMins) mins"
            content.body = "Queue updated for \(peopleInQueue) \(peopleWord) and estimated wait time is ~\(waitMins) mins (\(courtsInUse)/4 permanent courts full, \(walkOnCourtsOpen) walk-on open)."
        } else {
            content.title = "🏓 Queue Updated for \(peopleInQueue) \(peopleWord.capitalized)"
            content.subtitle = "Est. Wait Time: 0 mins (No Wait!)"
            content.body = "Queue updated for \(peopleInQueue) \(peopleWord) and wait time is 0 mins (\(courtsInUse)/4 permanent courts in use, \(walkOnCourtsOpen) walk-on open). Go play!"
        }
        content.sound = .default
        
        let req = UNNotificationRequest(
            identifier: "wp_queue_alert_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }
    
    // MARK: - Lost & Found Remote Change Detector
    
    public func evaluateIncomingLostAndFoundItems(_ items: [LostAndFoundItem]) {
        let defaults = UserDefaults.standard
        var notifiedIds = Set(defaults.stringArray(forKey: notifiedLostFoundIdsKey) ?? [])
        let localIds = Set(defaults.stringArray(forKey: localLostFoundIdsKey) ?? [])
        let hasInitialized = defaults.bool(forKey: hasInitializedBaselineKey)
        
        if !hasInitialized {
            for item in items {
                notifiedIds.insert(item.id)
            }
            defaults.set(Array(notifiedIds), forKey: notifiedLostFoundIdsKey)
            defaults.set(true, forKey: hasInitializedBaselineKey)
            return
        }
        
        var newlyDiscovered: [LostAndFoundItem] = []
        for item in items where !item.isFlagged {
            if !notifiedIds.contains(item.id) && !localIds.contains(item.id) {
                notifiedIds.insert(item.id)
                // Only notify if posted within the last 12 hours
                if Date().timeIntervalSince(item.lostDate) < 43200 {
                    newlyDiscovered.append(item)
                }
            }
        }
        
        if !newlyDiscovered.isEmpty {
            defaults.set(Array(notifiedIds.suffix(300)), forKey: notifiedLostFoundIdsKey)
        }
        
        guard isMasterEnabled && lostAndFoundAlertsEnabled else { return }
        
        for item in newlyDiscovered.prefix(2) {
            sendLostAndFoundNotification(for: item)
        }
    }
    
    public func sendLostAndFoundNotification(for item: LostAndFoundItem) {
        let content = UNMutableNotificationContent()
        let statusTag = item.status == .lost ? "LOST" : "FOUND"
        content.title = "📦 New Lost & Found: \(statusTag) \(item.category.rawValue)"
        content.subtitle = "\(item.title) · \(item.courtLocation)"
        let desc = item.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = desc.isEmpty
            ? "Posted by \(item.reporterName) at Washington Park. Tap to view on the Lost & Found board."
            : "\(desc) (Posted by \(item.reporterName))"
        content.sound = .default
        
        let req = UNNotificationRequest(
            identifier: "wp_lostfound_alert_\(item.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }
    
    // MARK: - CloudKit Push Subscriptions (Background APNs Support)
    
    public func registerCloudKitSubscriptions() {
        let publicDB = CKContainer(identifier: "iCloud.com.dominicsoriano.washingpark").publicCloudDatabase
        
        if queueWaitAlertsEnabled && isMasterEnabled {
            let sub = CKQuerySubscription(
                recordType: "CityUsageTelemetryRecord",
                predicate: NSPredicate(value: true),
                subscriptionID: "wp_queue_activity_sub_v1",
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            info.title = "🏓 Washington Park Queue Updated"
            info.alertLocalizationKey = "Queue updated for %1$@ people — Est. wait time: ~%2$@ mins (%3$@/4 courts in use)."
            info.alertLocalizationArgs = ["peopleInQueue", "estimatedWaitMinutes", "courtsInUse"]
            info.soundName = "default"
            sub.notificationInfo = info
            publicDB.save(sub) { _, _ in }
        }
        
        if lostAndFoundAlertsEnabled && isMasterEnabled {
            let sub = CKQuerySubscription(
                recordType: "LostAndFoundRecord",
                predicate: NSPredicate(value: true),
                subscriptionID: "wp_lost_found_sub_v1",
                options: [.firesOnRecordCreation]
            )
            let info = CKSubscription.NotificationInfo()
            info.title = "📦 New Washington Park Lost & Found Post"
            info.alertLocalizationKey = "%1$@: %2$@ near %3$@"
            info.alertLocalizationArgs = ["status", "title", "courtLocation"]
            info.soundName = "default"
            sub.notificationInfo = info
            publicDB.save(sub) { _, _ in }
        }
    }
}
