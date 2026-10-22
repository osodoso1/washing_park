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
    
    func testLiveCrossDeviceQueueAndWaitTimeSync() async throws {
        let liveFeedURL = URL(string: "https://picklepark-sync.cf-watcher.workers.dev/wp_live_feed_v1")!
        
        // 1. Fetch current production state so we can restore it cleanly after the test
        var backupData: Data? = nil
        if let (data, resp) = try? await URLSession.shared.data(from: liveFeedURL),
           let http = resp as? HTTPURLResponse, http.statusCode == 200 {
            backupData = data
        }
        
        defer {
            if let backup = backupData {
                let sem = DispatchSemaphore(value: 0)
                var restoreReq = URLRequest(url: liveFeedURL)
                restoreReq.httpMethod = "POST"
                restoreReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                restoreReq.httpBody = backup
                URLSession.shared.dataTask(with: restoreReq) { _, _, _ in
                    sem.signal()
                }.resume()
                _ = sem.wait(timeout: .now() + 5.0)
            }
        }
        
        // 2. Simulate Device A broadcasting a live Queue Update (4 courts full, 8 in queue, 2 walk-on open)
        let testTimestamp = Date().timeIntervalSince1970
        let deviceAPayload = ParkCloudSyncPayload(
            courtsInUse: 4,
            extraCourts: 2,
            inQueue: 8,
            lastAuthor: "SyncTestDeviceA",
            extraNotes: "E2E Cross-Device Test",
            reportTimestamp: testTimestamp,
            court2State: "Free",
            court3State: "Both Sides Taken",
            priorUpdates: []
        )
        
        var postReq = URLRequest(url: liveFeedURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        postReq.httpMethod = "POST"
        postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        postReq.httpBody = try JSONEncoder.pickleParkCloudEncoder.encode(deviceAPayload)
        
        let (_, postResp) = try await URLSession.shared.data(for: postReq)
        let postHttp = try XCTUnwrap(postResp as? HTTPURLResponse)
        XCTAssertEqual(postHttp.statusCode, 200, "Device A POST to /wp_live_feed_v1 must return 200 OK")
        
        // 3. Simulate Device B starting from a fresh install state (epoch 0) and pulling from cloud
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
        
        await CommunityCloudService.shared.pullLatestFromCloud()
        
        // 4. Verify Device B loaded Device A's exact crowdsourced queue & wait time state
        let syncedStatus = await MainActor.run { PickleQueueManager.shared.queueStatus }
        XCTAssertEqual(syncedStatus.courtsInUse, 4)
        XCTAssertEqual(syncedStatus.inQueue, 8)
        XCTAssertEqual(syncedStatus.extraCourts, 2)
        XCTAssertEqual(syncedStatus.lastAuthor, "SyncTestDeviceA")
        XCTAssertEqual(syncedStatus.pickleQueReportDate.timeIntervalSince1970, testTimestamp, accuracy: 1.0)
        
        let syncedWaitMins = CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(
            courtsInUse: syncedStatus.courtsInUse,
            peopleInQueue: syncedStatus.inQueue,
            walkOnCourtsOpen: syncedStatus.extraCourts
        )
        XCTAssertEqual(syncedWaitMins, 8, "Device B must compute ~8 mins wait time from Device A's 8-person queue")
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
        let endpointURL = URL(string: "https://picklepark-sync.cf-watcher.workers.dev/wp_lost_and_found_v1?envelope=1")!
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
    
    // MARK: - 4. User Notification Preferences (Enable / Disable on Phone)
    
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
