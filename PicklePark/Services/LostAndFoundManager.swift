import Foundation
import SwiftUI
import UIKit
import CloudKit
import Vision

// MARK: - Lost & Found Models

public enum LostItemStatus: String, Codable, CaseIterable, Identifiable {
    case lost = "LOST"
    case found = "MARKED FOUND"
    
    public var id: String { rawValue }
}

public enum LostItemCategory: String, Codable, CaseIterable, Identifiable {
    case paddle = "Paddle"
    case waterBottle = "Bottle / Jug"
    case apparel = "Jacket / Hat"
    case bagGear = "Bag / Gear"
    case keysTech = "Keys / Phone"
    case other = "Other Item"
    
    public var id: String { rawValue }
    
    public var sfSymbol: String {
        switch self {
        case .paddle: return "figure.pickleball"
        case .waterBottle: return "waterbottle.fill"
        case .apparel: return "tshirt.fill"
        case .bagGear: return "bag.fill"
        case .keysTech: return "key.fill"
        case .other: return "shippingbox.fill"
        }
    }
    
    public var tintColor: Color {
        switch self {
        case .paddle: return AppTheme.pickleballGreen
        case .waterBottle: return AppTheme.burlingameBlue
        case .apparel: return Color(red: 0.55, green: 0.28, blue: 0.85)
        case .bagGear: return Color(red: 0.90, green: 0.48, blue: 0.12)
        case .keysTech: return Color(red: 0.85, green: 0.22, blue: 0.28)
        case .other: return Color(red: 0.35, green: 0.45, blue: 0.55)
        }
    }
}

public struct LostAndFoundItem: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var descriptionText: String
    public var category: LostItemCategory
    public var courtLocation: String
    public var status: LostItemStatus
    public var lostDate: Date
    public var foundDate: Date?
    public var updatedAt: Date?
    public var reporterName: String
    public var foundByName: String?
    public var imageBase64: String?
    public var isFlagged: Bool
    public var flagReason: String?
    public var flagCount: Int
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        descriptionText: String,
        category: LostItemCategory = .paddle,
        courtLocation: String = "Court 1 — Open Play Area",
        status: LostItemStatus = .lost,
        lostDate: Date = Date(),
        foundDate: Date? = nil,
        updatedAt: Date? = Date(),
        reporterName: String = "Local Player",
        foundByName: String? = nil,
        imageBase64: String? = nil,
        isFlagged: Bool = false,
        flagReason: String? = nil,
        flagCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.descriptionText = descriptionText
        self.category = category
        self.courtLocation = courtLocation
        self.status = status
        self.lostDate = lostDate
        self.foundDate = foundDate
        self.updatedAt = updatedAt
        self.reporterName = reporterName
        self.foundByName = foundByName
        self.imageBase64 = imageBase64
        self.isFlagged = isFlagged
        self.flagReason = flagReason
        self.flagCount = flagCount
    }
    
    public var decodedImage: UIImage? {
        guard let base64 = imageBase64,
              let data = Data(base64Encoded: base64) else {
            return nil
        }
        return UIImage(data: data)
    }
}

// MARK: - Automated Content & Vision Safety Scanner

public struct ContentSafetyScanResult {
    public let isFlagged: Bool
    public let reason: String?
    public let sanitizedTitle: String
    public let sanitizedDescription: String
    public let sanitizedAuthor: String
}

public final class LostAndFoundSafetyScanner {
    public static let shared = LostAndFoundSafetyScanner()
    
    private let suspiciousPatterns: [String] = [
        "http://", "https://", "bit.ly", "t.me/", "whatsapp", "crypto",
        "bitcoin", "onlyfans", "cashapp", "venmo me", "nsfw", "xxx", "nude"
    ]
    
    private init() {}
    
    /// Scans text and optional image for inappropriate content, profanity, spam, or unsafe visuals
    public func evaluateSubmission(
        title: String,
        description: String,
        author: String,
        image: UIImage?
    ) async -> ContentSafetyScanResult {
        let moderator = ContentModerator.shared
        var flagReasons: [String] = []
        
        // 1. Check text fields for profanity / slurs
        if moderator.containsProhibitedContent(title) ||
            moderator.containsProhibitedContent(description) ||
            moderator.containsProhibitedContent(author) {
            flagReasons.append("Auto-detected prohibited language in text")
        }
        
        // 2. Check for suspicious spam / solicitation links
        let combinedLower = "\(title) \(description) \(author)".lowercased()
        for pattern in suspiciousPatterns {
            if combinedLower.contains(pattern) {
                flagReasons.append("Auto-detected external link or solicitation pattern")
                break
            }
        }
        
        // 3. Scan attached image using Apple Vision OCR + visual exposure heuristics
        if let img = image {
            let imageCheck = await analyzeImageSafety(img)
            if imageCheck.isFlagged, let reason = imageCheck.reason {
                flagReasons.append(reason)
            }
        }
        
        let cleanedTitle = moderator.cleanse(title.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanedDesc = moderator.cleanse(description.trimmingCharacters(in: .whitespacesAndNewlines))
        let cleanedAuthor = moderator.cleanse(author.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return ContentSafetyScanResult(
            isFlagged: !flagReasons.isEmpty,
            reason: flagReasons.isEmpty ? nil : flagReasons.joined(separator: " · "),
            sanitizedTitle: cleanedTitle,
            sanitizedDescription: cleanedDesc,
            sanitizedAuthor: cleanedAuthor.isEmpty ? "Local Player" : cleanedAuthor
        )
    }
    
    private func analyzeImageSafety(_ image: UIImage) async -> (isFlagged: Bool, reason: String?) {
        guard let cgImage = image.cgImage else {
            return (false, nil)
        }
        
        // A. Vision OCR Text Recognition inside the photo
        let ocrFlagged: Bool = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                let hasBadText = ContentModerator.shared.containsProhibitedContent(recognizedStrings)
                continuation.resume(returning: hasBadText)
            }
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: false)
            }
        }
        
        if ocrFlagged {
            return (true, "Auto-detected inappropriate text inside photo")
        }
        
        // B. High skin-tone exposure / NSFW pixel heuristic on downsampled 64x64 thumbnail
        if detectExcessiveSkinToneRatio(in: cgImage) {
            return (true, "Auto-flagged photo by visual safety filter for owner review")
        }
        
        return (false, nil)
    }
    
    private func detectExcessiveSkinToneRatio(in cgImage: CGImage) -> Bool {
        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &rawData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return false
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var skinLikePixels = 0
        let totalPixels = width * height
        
        for i in 0..<totalPixels {
            let offset = i * bytesPerPixel
            let r = Double(rawData[offset])
            let g = Double(rawData[offset + 1])
            let b = Double(rawData[offset + 2])
            
            // Standard RGB + YCbCr skin-cluster check
            let isRgbCluster = (r > 95 && g > 40 && b > 20) &&
                               (max(r, max(g, b)) - min(r, min(g, b)) > 15) &&
                               (abs(r - g) > 15 && r > g && r > b)
            
            let cb = 128.0 - 0.168736 * r - 0.331264 * g + 0.5 * b
            let cr = 128.0 + 0.5 * r - 0.418688 * g - 0.081312 * b
            let isYCbCrCluster = (cb >= 77 && cb <= 127) && (cr >= 133 && cr <= 173)
            
            if isRgbCluster && isYCbCrCluster {
                skinLikePixels += 1
            }
        }
        
        let ratio = Double(skinLikePixels) / Double(totalPixels)
        // Flag only if an overwhelmingly high fraction (> 68%) of the entire photo is skin-tone cluster
        return ratio > 0.68
    }
}

// MARK: - Lost & Found Manager (CloudKit + Community Cloud + Red Badge + Owner Management)

public final class LostAndFoundManager: ObservableObject {
    public static let shared = LostAndFoundManager()
    
    @Published public private(set) var items: [LostAndFoundItem] = []
    @Published public var hasSeenIntroBadge: Bool = false
    @Published public var lastViewedTimestamp: Double = 0
    @Published public var isOwnerManageMode: Bool = false
    @Published public var isSyncing: Bool = false
    
    private let itemsStorageKey = "washington_park_lost_and_found_items_v1"
    private let introSeenKey = "washington_park_lost_and_found_intro_seen_v1"
    private let lastViewedKey = "washington_park_lost_and_found_last_viewed_v1"
    private let ownerUnlockedKey = "washington_park_lost_and_found_owner_v1"
    private let ownerPasscode = "osodoso"
    
    private let cloudEndpointURL = "https://picklepark-sync.cf-watcher.workers.dev/wp_lost_and_found_v1"
    private var publicDB: CKDatabase {
        CKContainer(identifier: "iCloud.com.dominicsoriano.washingpark").publicCloudDatabase
    }
    
    private init() {
        self.hasSeenIntroBadge = UserDefaults.standard.bool(forKey: introSeenKey)
        self.lastViewedTimestamp = UserDefaults.standard.double(forKey: lastViewedKey)
        self.isOwnerManageMode = UserDefaults.standard.bool(forKey: ownerUnlockedKey)
        loadLocalItems()
        
        Task {
            await pullLatestFromCloud()
        }
    }
    
    // MARK: - Notification Badge Logic (First Download Intro + New Reports)
    
    /// Visible items for regular players (hides auto-flagged or community-flagged items unless in Owner Manage Mode)
    public var visibleItems: [LostAndFoundItem] {
        if isOwnerManageMode {
            return items
        }
        return items.filter { !$0.isFlagged }
    }
    
    /// Flagged items awaiting owner review
    public var flaggedItemsCount: Int {
        items.filter { $0.isFlagged }.count
    }
    
    /// Number of new reports posted since the user last opened Lost & Found
    public var newReportsCountSinceLastView: Int {
        guard lastViewedTimestamp > 0 else {
            return visibleItems.filter { $0.status == .lost }.count
        }
        return visibleItems.filter { $0.lostDate.timeIntervalSince1970 > lastViewedTimestamp }.count
    }
    
    /// Shows the red notification icon when:
    /// 1) The user first downloads/opens the app (`!hasSeenIntroBadge`) to introduce them to Lost & Found, OR
    /// 2) There is a new Lost & Found report posted since the user last opened the Lost & Found page.
    public var shouldShowRedNotificationBadge: Bool {
        if !hasSeenIntroBadge {
            return true
        }
        return newReportsCountSinceLastView > 0
    }
    
    /// Marks Lost & Found as viewed and clears the red notification badge
    public func markLostAndFoundViewed() {
        hasSeenIntroBadge = true
        let latestReportTime = visibleItems.map { $0.lostDate.timeIntervalSince1970 }.max() ?? Date().timeIntervalSince1970
        lastViewedTimestamp = max(Date().timeIntervalSince1970, latestReportTime)
        UserDefaults.standard.set(true, forKey: introSeenKey)
        UserDefaults.standard.set(lastViewedTimestamp, forKey: lastViewedKey)
    }
    
    // MARK: - Owner Management Authentication (osodoso)
    
    public func unlockOwnerManageMode(passcode: String) -> Bool {
        let cleaned = passcode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleaned == ownerPasscode {
            isOwnerManageMode = true
            UserDefaults.standard.set(true, forKey: ownerUnlockedKey)
            HapticFeedback.success()
            return true
        }
        return false
    }
    
    public func lockOwnerManageMode() {
        isOwnerManageMode = false
        UserDefaults.standard.set(false, forKey: ownerUnlockedKey)
    }
    
    // MARK: - Create, Mark Found, Flag, and Owner Manage Actions
    
    @MainActor
    public func submitItem(
        title: String,
        descriptionText: String,
        category: LostItemCategory,
        courtLocation: String,
        initialStatus: LostItemStatus = .lost,
        reporterName: String,
        photo: UIImage?
    ) async -> (item: LostAndFoundItem, wasAutoFlagged: Bool, flagReason: String?) {
        let safetyResult = await LostAndFoundSafetyScanner.shared.evaluateSubmission(
            title: title,
            description: descriptionText,
            author: reporterName,
            image: photo
        )
        
        let compressedBase64: String? = {
            guard let img = photo else { return nil }
            let resized = Self.downsampleImage(img, maxDimension: 720)
            guard let jpegData = resized.jpegData(compressionQuality: 0.62) else { return nil }
            return jpegData.base64EncodedString()
        }()
        
        let now = Date()
        let newItem = LostAndFoundItem(
            title: safetyResult.sanitizedTitle.isEmpty ? category.rawValue : safetyResult.sanitizedTitle,
            descriptionText: safetyResult.sanitizedDescription,
            category: category,
            courtLocation: courtLocation,
            status: initialStatus,
            lostDate: now,
            foundDate: initialStatus == .found ? now : nil,
            reporterName: safetyResult.sanitizedAuthor,
            foundByName: initialStatus == .found ? safetyResult.sanitizedAuthor : nil,
            imageBase64: compressedBase64,
            isFlagged: safetyResult.isFlagged,
            flagReason: safetyResult.reason,
            flagCount: safetyResult.isFlagged ? 1 : 0
        )
        
        items.insert(newItem, at: 0)
        items.sort { $0.lostDate > $1.lostDate }
        saveLocalItems()
        
        // Update viewer timestamp and local submission tracker so the poster doesn't self-notify
        lastViewedTimestamp = max(lastViewedTimestamp, now.timeIntervalSince1970)
        UserDefaults.standard.set(lastViewedTimestamp, forKey: lastViewedKey)
        ParkNotificationManager.shared.markLocalLostFoundSubmission(id: newItem.id)
        
        pushItemToCloudKit(newItem)
        await upsertItemToCommunityCloud(newItem)
        
        HapticFeedback.success()
        return (newItem, safetyResult.isFlagged, safetyResult.reason)
    }
    
    /// Marks an item as FOUND (recording exact date & time found) or reopens it as LOST
    @MainActor
    public func toggleFoundStatus(for itemId: String, markedBy: String? = nil) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        if items[idx].status == .lost {
            items[idx].status = .found
            items[idx].foundDate = Date()
            if let by = markedBy, !by.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                items[idx].foundByName = ContentModerator.shared.cleanse(by)
            }
        } else {
            items[idx].status = .lost
            items[idx].foundDate = nil
            items[idx].foundByName = nil
        }
        items[idx].updatedAt = Date()
        
        let updated = items[idx]
        saveLocalItems()
        pushItemToCloudKit(updated)
        Task {
            await upsertItemToCommunityCloud(updated)
        }
        HapticFeedback.success()
    }
    
    /// Flags an item as inappropriate by a player or auto-moderator
    @MainActor
    public func flagItemAsInappropriate(itemId: String, reason: String = "Flagged by player as inappropriate") {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[idx].flagCount += 1
        items[idx].isFlagged = true
        items[idx].flagReason = reason
        items[idx].updatedAt = Date()
        
        let updated = items[idx]
        saveLocalItems()
        pushItemToCloudKit(updated)
        Task {
            await upsertItemToCommunityCloud(updated)
        }
        HapticFeedback.medium()
    }
    
    /// Owner Action: Unflag / Approve an item
    @MainActor
    public func ownerApproveFlaggedItem(itemId: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[idx].isFlagged = false
        items[idx].flagReason = nil
        items[idx].flagCount = 0
        items[idx].updatedAt = Date()
        
        let updated = items[idx]
        saveLocalItems()
        pushItemToCloudKit(updated)
        Task {
            await upsertItemToCommunityCloud(updated)
        }
        HapticFeedback.success()
    }
    
    /// Owner Action: Update an item's title & description
    @MainActor
    public func ownerUpdateItem(itemId: String, newTitle: String, newDescription: String, newLocation: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[idx].title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        items[idx].descriptionText = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        items[idx].courtLocation = newLocation
        items[idx].updatedAt = Date()
        
        let updated = items[idx]
        saveLocalItems()
        pushItemToCloudKit(updated)
        Task {
            await upsertItemToCommunityCloud(updated)
        }
        HapticFeedback.success()
    }
    
    /// Owner Action: Permanently delete an item from Lost & Found
    @MainActor
    public func ownerDeleteItem(itemId: String) {
        items.removeAll { $0.id == itemId }
        saveLocalItems()
        
        let recordID = CKRecord.ID(recordName: "lostfound_\(itemId)")
        publicDB.delete(withRecordID: recordID) { _, _ in }
        
        Task {
            await deleteItemsFromCommunityCloud([itemId])
        }
        HapticFeedback.medium()
    }
    
    /// Owner Action: Clear all items already marked found
    @MainActor
    public func ownerClearAllFoundItems() {
        let foundIds = items.filter { $0.status == .found }.map(\.id)
        items.removeAll { $0.status == .found }
        saveLocalItems()
        
        for id in foundIds {
            let recordID = CKRecord.ID(recordName: "lostfound_\(id)")
            publicDB.delete(withRecordID: recordID) { _, _ in }
        }
        
        Task {
            await deleteItemsFromCommunityCloud(foundIds)
        }
        HapticFeedback.success()
    }
    
    // MARK: - Cloud Sync (Community Cloud + CloudKit)
    
    private struct LostFoundSyncEnvelope: Codable {
        let items: [LostAndFoundItem]
        let deletedIds: [String]?
    }
    
    public func pullLatestFromCloud() async {
        await MainActor.run { self.isSyncing = true }
        defer {
            Task { @MainActor in self.isSyncing = false }
        }
        
        // 1. Pull from Cloudflare Worker KV endpoint with deletedIds tombstone envelope
        var syncedFromWorker = false
        if let url = URL(string: "\(cloudEndpointURL)?envelope=1") {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
            request.httpMethod = "GET"
            let decoder = JSONDecoder.pickleParkCloudDecoder
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let envelope = try? decoder.decode(LostFoundSyncEnvelope.self, from: data) {
                    syncedFromWorker = true
                    await MainActor.run {
                        self.mergeWithServerEnvelope(remoteItems: envelope.items, deletedIds: Set(envelope.deletedIds ?? []))
                    }
                } else if let remoteItems = try? decoder.decode([LostAndFoundItem].self, from: data) {
                    syncedFromWorker = true
                    await MainActor.run {
                        self.mergeWithServerEnvelope(remoteItems: remoteItems, deletedIds: [])
                    }
                }
            }
        }
        
        // 2. Pull from CloudKit public database as secondary mirror
        let query = CKQuery(recordType: "LostAndFoundRecord", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "lostDate", ascending: false)]
        
        if let (matchResults, _) = try? await publicDB.records(matching: query, resultsLimit: 100) {
            var ckItems: [LostAndFoundItem] = []
            for (_, result) in matchResults {
                if case .success(let record) = result,
                   let title = record["title"] as? String,
                   let desc = record["descriptionText"] as? String,
                   let lostDate = record["lostDate"] as? Date {
                    let id = (record["itemId"] as? String) ?? record.recordID.recordName.replacingOccurrences(of: "lostfound_", with: "")
                    let catRaw = (record["category"] as? String) ?? LostItemCategory.paddle.rawValue
                    let statusRaw = (record["status"] as? String) ?? LostItemStatus.lost.rawValue
                    let location = (record["courtLocation"] as? String) ?? "Court 1"
                    let foundDate = record["foundDate"] as? Date
                    let reporter = (record["reporterName"] as? String) ?? "Local Player"
                    let foundBy = record["foundByName"] as? String
                    let imgBase64 = record["imageBase64"] as? String
                    let isFlagged = ((record["isFlagged"] as? Int) ?? 0) == 1
                    let flagReason = record["flagReason"] as? String
                    let flagCount = (record["flagCount"] as? Int) ?? 0
                    
                    ckItems.append(
                        LostAndFoundItem(
                            id: id,
                            title: title,
                            descriptionText: desc,
                            category: LostItemCategory(rawValue: catRaw) ?? .other,
                            courtLocation: location,
                            status: LostItemStatus(rawValue: statusRaw) ?? .lost,
                            lostDate: lostDate,
                            foundDate: foundDate,
                            updatedAt: record.modificationDate ?? lostDate,
                            reporterName: reporter,
                            foundByName: foundBy,
                            imageBase64: imgBase64,
                            isFlagged: isFlagged,
                            flagReason: flagReason,
                            flagCount: flagCount
                        )
                    )
                }
            }
            if !ckItems.isEmpty && !syncedFromWorker {
                await MainActor.run {
                    self.mergeRemoteItems(ckItems)
                }
            }
        }
    }
    
    private func mergeWithServerEnvelope(remoteItems: [LostAndFoundItem], deletedIds: Set<String>) {
        var map: [String: LostAndFoundItem] = [:]
        var unsyncedLocalToPush: [LostAndFoundItem] = []
        
        let remoteIds = Set(remoteItems.map(\.id))
        
        // 1. Add all remote items that aren't deleted
        for remote in remoteItems where !deletedIds.contains(remote.id) {
            map[remote.id] = remote
        }
        
        // 2. Preserve any local item that is NOT in deletedIds; if it's newer or missing on server, queue it for push
        for local in items where !deletedIds.contains(local.id) {
            if let existingRemote = map[local.id] {
                let localUpdated = local.updatedAt ?? local.foundDate ?? local.lostDate
                let remoteUpdated = existingRemote.updatedAt ?? existingRemote.foundDate ?? existingRemote.lostDate
                if localUpdated > remoteUpdated {
                    map[local.id] = local
                    unsyncedLocalToPush.append(local)
                }
            } else if !remoteIds.contains(local.id) {
                map[local.id] = local
                unsyncedLocalToPush.append(local)
            }
        }
        
        items = map.values.sorted { $0.lostDate > $1.lostDate }
        saveLocalItems()
        
        // Evaluate for new remote Lost & Found notifications
        ParkNotificationManager.shared.evaluateIncomingLostAndFoundItems(items)
        
        if !unsyncedLocalToPush.isEmpty {
            Task {
                await pushAllToCommunityCloud()
            }
        }
    }
    
    private func mergeRemoteItems(_ incoming: [LostAndFoundItem]) {
        if incoming.isEmpty && items.isEmpty { return }
        var map: [String: LostAndFoundItem] = [:]
        for item in items { map[item.id] = item }
        for remote in incoming {
            if let existing = map[remote.id] {
                let remoteUpdated = remote.updatedAt ?? remote.foundDate ?? remote.lostDate
                let existingUpdated = existing.updatedAt ?? existing.foundDate ?? existing.lostDate
                if remoteUpdated >= existingUpdated || remote.status == .found || remote.isFlagged || remote.flagCount >= existing.flagCount {
                    map[remote.id] = remote
                }
            } else {
                map[remote.id] = remote
            }
        }
        items = map.values.sorted { $0.lostDate > $1.lostDate }
        saveLocalItems()
        ParkNotificationManager.shared.evaluateIncomingLostAndFoundItems(items)
    }
    
    private struct UpsertPayload: Codable {
        let action: String
        let item: LostAndFoundItem
    }
    
    private struct DeletePayload: Codable {
        let action: String
        let ids: [String]
    }
    
    private func upsertItemToCommunityCloud(_ item: LostAndFoundItem) async {
        guard let url = URL(string: cloudEndpointURL) else { return }
        let encoder = JSONEncoder.pickleParkCloudEncoder
        guard let data = try? encoder.encode(UpsertPayload(action: "upsert", item: item)) else { return }
        
        for attempt in 1...3 {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15.0)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            
            let decoder = JSONDecoder.pickleParkCloudDecoder
            if let (respData, resp) = try? await URLSession.shared.data(for: request),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                if let updatedItems = try? decoder.decode([LostAndFoundItem].self, from: respData) {
                    await MainActor.run {
                        self.mergeWithServerEnvelope(remoteItems: updatedItems, deletedIds: [])
                    }
                }
                return
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 600_000_000)
            }
        }
    }
    
    private func deleteItemsFromCommunityCloud(_ ids: [String]) async {
        guard !ids.isEmpty, let url = URL(string: cloudEndpointURL) else { return }
        guard let data = try? JSONEncoder.pickleParkCloudEncoder.encode(DeletePayload(action: "delete", ids: ids)) else { return }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 12.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let decoder = JSONDecoder.pickleParkCloudDecoder
        if let (respData, resp) = try? await URLSession.shared.data(for: request),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
           let updatedItems = try? decoder.decode([LostAndFoundItem].self, from: respData) {
            await MainActor.run {
                self.items = updatedItems.sorted { $0.lostDate > $1.lostDate }
                self.saveLocalItems()
            }
        }
    }
    
    private func pushAllToCommunityCloud() async {
        guard let url = URL(string: cloudEndpointURL) else { return }
        let snapshot = await MainActor.run { Array(self.items.prefix(60)) }
        let encoder = JSONEncoder.pickleParkCloudEncoder
        guard let data = try? encoder.encode(snapshot) else { return }
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try? await URLSession.shared.data(for: request)
    }
    
    private func pushItemToCloudKit(_ item: LostAndFoundItem) {
        let recordID = CKRecord.ID(recordName: "lostfound_\(item.id)")
        let record = CKRecord(recordType: "LostAndFoundRecord", recordID: recordID)
        record["itemId"] = item.id as NSString
        record["title"] = item.title as NSString
        record["descriptionText"] = item.descriptionText as NSString
        record["category"] = item.category.rawValue as NSString
        record["courtLocation"] = item.courtLocation as NSString
        record["status"] = item.status.rawValue as NSString
        record["lostDate"] = item.lostDate as NSDate
        if let fd = item.foundDate {
            record["foundDate"] = fd as NSDate
        } else {
            record["foundDate"] = nil
        }
        record["reporterName"] = item.reporterName as NSString
        record["foundByName"] = (item.foundByName ?? "") as NSString
        if let b64 = item.imageBase64 {
            record["imageBase64"] = b64 as NSString
        }
        record["isFlagged"] = (item.isFlagged ? 1 : 0) as NSNumber
        record["flagReason"] = (item.flagReason ?? "") as NSString
        record["flagCount"] = item.flagCount as NSNumber
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.savePolicy = .allKeys
        publicDB.add(modifyOp)
    }
    
    // MARK: - Persistence & Image Compression Helpers
    
    private func loadLocalItems() {
        if let data = UserDefaults.standard.data(forKey: itemsStorageKey),
           let decoded = try? JSONDecoder().decode([LostAndFoundItem].self, from: data) {
            self.items = decoded.sorted { $0.lostDate > $1.lostDate }
        } else {
            self.items = []
        }
    }
    
    private func saveLocalItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsStorageKey)
        }
    }
    
    private static func downsampleImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
