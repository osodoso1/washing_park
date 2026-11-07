import XCTest
import UIKit
@testable import PicklePark

final class CrossDeviceSyncAndNotificationTests: XCTestCase {
    
    // MARK: - 1. Wait Time Math Verification (4 Courts Full Rule + 15-Min Avg Game)
    
    func testWaitTimeCalculationMath() {
        // Under 4 courts in use -> always 0 wait time
        XCTAssertEqual(
            CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: 3, peopleInQueue: 8, walkOnCourtsOpen: 0),
            0,
            "Wait time must be 0 when fewer than 4 courts are filled"
        )
        
        // 4 courts in use, 0 in queue -> 0 wait time
        XCTAssertEqual(
            CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: 4, peopleInQueue: 0, walkOnCourtsOpen: 0),
            0
        )
        
        // 4 courts in use, 4 people in queue -> ~4 mins (3.75 rounded)
        XCTAssertEqual(
            CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: 4, peopleInQueue: 4, walkOnCourtsOpen: 0),
            4
        )
        
        // 4 courts in use, 8 people in queue -> ~8 mins (7.5 rounded)
        XCTAssertEqual(
            CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: 4, peopleInQueue: 8, walkOnCourtsOpen: 0),
            8
        )
        
        // 4 courts in use, 16 people in queue -> 15 mins (1 full 15-min game cycle across 4 courts)
        XCTAssertEqual(
            CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: 4, peopleInQueue: 16, walkOnCourtsOpen: 0),
            15
        )
    }
    
    // MARK: - 2. Live Cross-Device Queue & Wait Time Sync Verification
    
    // Tests write to an isolated feed on the same Worker so real players never see test reports
    private let testFeedPath = "wp_live_feed_test_v1"
    private var testFeedURL: URL {
        URL(string: "\(CommunityCloudService.baseWorkerURL)/\(testFeedPath)")!
    }
    
    private let testLostFoundPath = "wp_lost_and_found_test_v1"
    private let testLeaderboardPath = "wp_leaderboard_test_v1"
    
    override func setUp() async throws {
        await MainActor.run {
            CommunityCloudService.shared.liveFeedPath = testFeedPath
            LostAndFoundManager.shared.endpointPath = testLostFoundPath
            CloudKitManager.shared.leaderboardPath = testLeaderboardPath
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            CommunityCloudService.shared.liveFeedPath = CommunityCloudService.productionFeedPath
            LostAndFoundManager.shared.endpointPath = "wp_lost_and_found_v1"
            CloudKitManager.shared.leaderboardPath = "wp_leaderboard_v1"
        }
    }
    
    @discardableResult
    private func postToTestFeed(_ payload: ParkCloudSyncPayload) async throws -> ParkCloudSyncPayload {
        var postReq = URLRequest(url: testFeedURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        postReq.httpMethod = "POST"
        postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postReq.httpBody = try JSONEncoder.pickleParkCloudEncoder.encode(payload)
        
        let (data, postResp) = try await URLSession.shared.data(for: postReq)
        let postHttp = try XCTUnwrap(postResp as? HTTPURLResponse)
        XCTAssertEqual(postHttp.statusCode, 200, "POST to /\(testFeedPath) must return 200 OK")
        return try JSONDecoder.pickleParkCloudDecoder.decode(ParkCloudSyncPayload.self, from: data)
    }
    
    private func resetLocalStateToFreshInstall() async {
        await MainActor.run {
            PickleQueueManager.shared.queueStatus = QueueStatus(
                courtsInUse: 4,
                extraCourts: 0,
                inQueue: 0,
                lastAuthor: "Initial",
                pickleQueReportDate: Date(timeIntervalSince1970: 0),
                lastAppSyncDate: Date(),
                priorUpdates: []
            )
        }
    }
    
    func testLiveCrossDeviceQueueAndWaitTimeSync() async throws {
        // 1. Simulate Device A broadcasting a live Queue Update (4 courts full, 8 in queue, 2 walk-on open)
        let testTimestamp = Date().timeIntervalSince1970
        try await postToTestFeed(ParkCloudSyncPayload(
            courtsInUse: 4,
            extraCourts: 2,
            inQueue: 8,
            lastAuthor: "SyncTestDeviceA",
            extraNotes: "E2E Cross-Device Test",
            reportTimestamp: testTimestamp,
            court2State: "Free",
            court3State: "Both Sides Taken",
            reportAgeSeconds: 0,
            updateKind: LiveFeedUpdateKind.full.rawValue
        ))
        
        // 2. Simulate Device B starting from a fresh install state (epoch 0) and pulling from cloud
        await resetLocalStateToFreshInstall()
        await CommunityCloudService.shared.pullLatestFromCloud()
        
        // 3. Verify Device B loaded Device A's exact crowdsourced queue & wait time state
        let syncedStatus = await MainActor.run { PickleQueueManager.shared.queueStatus }
        XCTAssertEqual(syncedStatus.courtsInUse, 4)
        XCTAssertEqual(syncedStatus.inQueue, 8)
        XCTAssertEqual(syncedStatus.extraCourts, 2)
        XCTAssertEqual(syncedStatus.lastAuthor, "SyncTestDeviceA")
        XCTAssertEqual(syncedStatus.pickleQueReportDate.timeIntervalSince1970, testTimestamp, accuracy: 3.0)
        XCTAssertEqual(syncedStatus.priorUpdates.first?.queue, 8, "Past Updates must list the newest report first")
        
        let (lastSync, failed) = await MainActor.run {
            (CommunityCloudService.shared.lastCloudSyncDate, CommunityCloudService.shared.lastSyncFailed)
        }
        XCTAssertFalse(failed)
        XCTAssertLessThan(Date().timeIntervalSince(try XCTUnwrap(lastSync)), 5, "Live Cloud Synced must reflect a real server round trip")
        
        let syncedWaitMins = CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(
            courtsInUse: syncedStatus.courtsInUse,
            peopleInQueue: syncedStatus.inQueue,
            walkOnCourtsOpen: syncedStatus.extraCourts
        )
        XCTAssertEqual(syncedWaitMins, 8, "Device B must compute ~8 mins wait time from Device A's 8-person queue")
    }
    
    func testStalePhoneCannotRollBackLiveFeed() async throws {
        let fresh = try await postToTestFeed(ParkCloudSyncPayload(
            courtsInUse: 4,
            extraCourts: 0,
            inQueue: 12,
            lastAuthor: "FreshReporter",
            court2State: "Both Sides Taken",
            court3State: "Both Sides Taken",
            reportAgeSeconds: 0,
            updateKind: LiveFeedUpdateKind.full.rawValue
        ))
        
        // A phone still holding yesterday's numbers (older build, device timestamp) posts late
        let afterStale = try await postToTestFeed(ParkCloudSyncPayload(
            courtsInUse: 2,
            extraCourts: 4,
            inQueue: 0,
            lastAuthor: "StalePhone",
            reportTimestamp: Date().timeIntervalSince1970 - 86400,
            court2State: "Free",
            court3State: "Free"
        ))
        XCTAssertEqual(afterStale.lastAuthor, "FreshReporter")
        XCTAssertEqual(afterStale.inQueue, 12)
        XCTAssertEqual(afterStale.reportTimestamp, fresh.reportTimestamp, accuracy: 0.001)
    }
    
    func testWalkOnToggleKeepsLiveQueueNumbers() async throws {
        try await postToTestFeed(ParkCloudSyncPayload(
            courtsInUse: 4,
            extraCourts: 0,
            inQueue: 9,
            lastAuthor: "QueueReporter",
            court2State: "Both Sides Taken",
            court3State: "Both Sides Taken",
            reportAgeSeconds: 0,
            updateKind: LiveFeedUpdateKind.full.rawValue
        ))
        
        // Another phone flips Court 2 while its own courts/queue numbers are out of date
        let afterToggle = try await postToTestFeed(ParkCloudSyncPayload(
            courtsInUse: 1,
            extraCourts: 4,
            inQueue: 0,
            court2State: "Free",
            court3State: "Free",
            reportAgeSeconds: 0,
            updateKind: LiveFeedUpdateKind.walkOnCourt2.rawValue
        ))
        XCTAssertEqual(afterToggle.inQueue, 9, "Walk-on toggle must not overwrite the live queue")
        XCTAssertEqual(afterToggle.courtsInUse, 4)
        XCTAssertEqual(afterToggle.court2State, "Free")
        XCTAssertEqual(afterToggle.court3State, "Both Sides Taken", "Only the toggled court changes")
        XCTAssertEqual(afterToggle.extraCourts, 2)
    }
    
    // MARK: - 3. Live Cross-Device Lost & Found Post, Mark Found & Delete Verification
    
    func testLiveCrossDeviceLostAndFoundLifecycle() async throws {
        let manager = LostAndFoundManager.shared
        
        // Create a test 20x20 blue image (water bottle color so it doesn't trigger skin-tone filter)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let testImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        
        // 1. Device A submits a Lost & Found item
        let submission = await manager.submitItem(
            title: "E2E Test JOOLA Paddle",
            descriptionText: "Blue overgrip left near Court 1 bench",
            category: .paddle,
            courtLocation: "Court 1 — Open Play Area",
            initialStatus: .lost,
            reporterName: "DeviceAPlayer",
            photo: testImage
        )
        let createdId = submission.item.id
        XCTAssertFalse(submission.wasAutoFlagged)
        
        // 2. Verify item is persisted on the remote Cloudflare KV database for Device B
        let endpointURL = URL(string: "\(CommunityCloudService.baseWorkerURL)/\(testLostFoundPath)?envelope=1")!
        var getReq = URLRequest(url: endpointURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        getReq.httpMethod = "GET"
        
        let (data, resp) = try await URLSession.shared.data(for: getReq)
        let httpResp = try XCTUnwrap(resp as? HTTPURLResponse)
        XCTAssertEqual(httpResp.statusCode, 200)
        
        struct Envelope: Codable {
            let items: [LostAndFoundItem]
            let deletedIds: [String]?
        }
        let decodedEnvelope = try JSONDecoder.pickleParkCloudDecoder.decode(Envelope.self, from: data)
        let remoteItem = decodedEnvelope.items.first(where: { $0.id == createdId })
        XCTAssertNotNil(remoteItem, "Device B must see Device A's newly posted Lost & Found item in Cloudflare KV")
        XCTAssertEqual(remoteItem?.title, "E2E Test JOOLA Paddle")
        XCTAssertEqual(remoteItem?.status, .lost)
        XCTAssertNotNil(remoteItem?.imageBase64, "Attached photo base64 must sync across devices")
        
        // 3. Clean up the test item via Owner Delete and verify tombstone removes it
        await manager.ownerDeleteItem(itemId: createdId)
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        
        let (afterDelData, _) = try await URLSession.shared.data(for: getReq)
        let afterDelEnvelope = try JSONDecoder.pickleParkCloudDecoder.decode(Envelope.self, from: data)
        _ = afterDelEnvelope
        let afterDelDecoded = try JSONDecoder.pickleParkCloudDecoder.decode(Envelope.self, from: afterDelData)
        XCTAssertNil(
            afterDelDecoded.items.first(where: { $0.id == createdId }),
            "Deleted Lost & Found item must be removed from the remote store"
        )
        XCTAssertTrue(
            (afterDelDecoded.deletedIds ?? []).contains(createdId),
            "Deleted ID must be recorded in server tombstones so no device resurrects it"
        )
    }
    
    // MARK: - 4. Community Leaderboard Visible To Everyone
    
    func testEveryPlayerAppearsOnSharedLeaderboard() async throws {
        let url = URL(string: "\(CommunityCloudService.baseWorkerURL)/\(testLeaderboardPath)")!
        let suffix = UUID().uuidString.prefix(8)
        let otherA = "player_A\(suffix)", otherB = "player_B\(suffix)"
        
        // Two other phones that never set a name (older builds upload the "Player (You)" placeholder)
        for id in [otherA, otherB] {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode([LeaderboardUser(
                id: id, name: LeaderboardUser.legacyPlaceholderName,
                monthlyPoints: 10, allTimePoints: 10, monthlyReports: 1, allTimeReports: 1, isCurrentUser: true
            )])
            let (_, resp) = try await URLSession.shared.data(for: req)
            XCTAssertEqual((resp as? HTTPURLResponse)?.statusCode, 200)
        }
        
        // This phone earns points, then refreshes the board
        let before = await MainActor.run { LeaderboardManager.shared.currentUser.allTimePoints }
        await MainActor.run { LeaderboardManager.shared.addPoints(amount: 10) }
        await CloudKitManager.shared.uploadCurrentPlayerToWorker()
        await CloudKitManager.shared.fetchLeaderboardFromCloud()
        
        let users: [LeaderboardUser] = await MainActor.run { LeaderboardManager.shared.users }
        let me = await MainActor.run { LeaderboardManager.shared.currentUser }
        let a = try XCTUnwrap(users.first { $0.id == otherA }, "Other unnamed players must not be hidden behind this phone's name")
        let b = try XCTUnwrap(users.first { $0.id == otherB })
        XCTAssertNotEqual(a.displayName, b.displayName)
        XCTAssertFalse(a.displayName.contains("(You)"))
        XCTAssertEqual(users.filter { $0.isCurrentUser }.count, 1)
        XCTAssertEqual(me.allTimePoints, before + 10)
        
        // The server has this phone's points, so every other phone sees them too
        let (data, _) = try await URLSession.shared.data(from: url)
        let serverUsers = try JSONDecoder().decode([LeaderboardUser].self, from: data)
        XCTAssertEqual(serverUsers.first { $0.id == me.id }?.allTimePoints, me.allTimePoints)
    }
    
    // MARK: - 5. User Notification Preferences (Enable / Disable on Phone)
    
    func testNotificationPreferencesTogglePersistence() {
        let notif = ParkNotificationManager.shared
        
        notif.isMasterEnabled = false
        notif.queueWaitAlertsEnabled = false
        notif.lostAndFoundAlertsEnabled = false
        
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "wp_notifications_master_enabled_v1"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "wp_notifications_queue_wait_enabled_v1"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "wp_notifications_lost_found_enabled_v1"))
        
        // Re-enable all
        notif.isMasterEnabled = true
        notif.queueWaitAlertsEnabled = true
        notif.lostAndFoundAlertsEnabled = true
        
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "wp_notifications_master_enabled_v1"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "wp_notifications_queue_wait_enabled_v1"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "wp_notifications_lost_found_enabled_v1"))
    }
}

// MARK: - Clubhouse hours follow the real weekday (Pacific time)

final class ClubhouseScheduleTests: XCTestCase {
    private func pacific(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    func testFridayShowsFridayHoursNotMondayThursday() {
        let fridayAfternoon = pacific("2026-11-06T16:47:00-08:00")
        XCTAssertEqual(ClubhouseSchedule.weekday(at: fridayAfternoon), 6)
        XCTAssertEqual(ClubhouseSchedule.stripLabel(at: fridayAfternoon), "Clubhouse Fri 8a–5p · Lights 10p")
        XCTAssertEqual(ClubhouseSchedule.statusLabel(at: fridayAfternoon), "Open · Closes 5 PM")
    }

    func testClosedAfterFridayCloseRollsToSaturday() {
        let fridayEvening = pacific("2026-11-06T17:01:00-08:00")
        XCTAssertFalse(ClubhouseSchedule.isOpen(at: fridayEvening))
        XCTAssertEqual(ClubhouseSchedule.statusLabel(at: fridayEvening), "Closed · Opens Sat 9 AM")
    }

    func testWeekdayAndWeekendHours() {
        XCTAssertEqual(ClubhouseSchedule.stripLabel(at: pacific("2026-11-09T12:00:00-08:00")), "Clubhouse Mon 8a–8:30p · Lights 10p")
        XCTAssertEqual(ClubhouseSchedule.stripLabel(at: pacific("2026-11-07T12:00:00-08:00")), "Clubhouse Sat 9a–2p · Lights 10p")
        XCTAssertEqual(ClubhouseSchedule.statusLabel(at: pacific("2026-11-08T08:30:00-08:00")), "Closed · Opens 9 AM")
    }

    func testUsesPacificTimeRegardlessOfDeviceZone() {
        // 00:30 UTC Saturday is still 4:30 PM Friday at the park.
        let utcSaturday = pacific("2026-11-07T00:30:00Z")
        XCTAssertEqual(ClubhouseSchedule.weekday(at: utcSaturday), 6)
        XCTAssertTrue(ClubhouseSchedule.isOpen(at: utcSaturday))
    }
}
