import SwiftUI
import PhotosUI
import UIKit

public enum LostFoundFilterTab: String, CaseIterable, Identifiable {
    case all = "All Items"
    case lost = "Lost"
    case found = "Marked Found"
    case flagged = "Flagged"
    
    public var id: String { rawValue }
}

public struct LostAndFoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = LostAndFoundManager.shared
    
    @State private var selectedFilter: LostFoundFilterTab = .all
    @State private var searchText: String = ""
    @State private var isShowingPostSheet: Bool = false
    @State private var isShowingOwnerAuthAlert: Bool = false
    @State private var ownerKeyInput: String = ""
    @State private var ownerAuthFailed: Bool = false
    @State private var showIntroCard: Bool = false
    @State private var zoomedImage: UIImage? = nil
    @State private var editingItem: LostAndFoundItem? = nil
    @State private var toastMessage: String? = nil
    
    public init() {}
    
    private var availableTabs: [LostFoundFilterTab] {
        if manager.isOwnerManageMode {
            return [.all, .lost, .found, .flagged]
        }
        return [.all, .lost, .found]
    }
    
    private var filteredItems: [LostAndFoundItem] {
        var base = manager.visibleItems
        #if targetEnvironment(simulator)
        if base.isEmpty && ProcessInfo.processInfo.arguments.contains("lost_and_found") {
            base = [
                LostAndFoundItem(
                    title: "JOOLA Perseus 16mm Paddle",
                    descriptionText: "Black carbon surface with white Tourna overgrip. Left near the Court 1 paddle rack after morning open play.",
                    category: .paddle,
                    courtLocation: "Court 1 — Open Play Rack",
                    status: .lost,
                    lostDate: Date().addingTimeInterval(-3600 * 2),
                    foundDate: nil,
                    reporterName: "Sarah M."
                ),
                LostAndFoundItem(
                    title: "32oz Pacific Blue HydroFlask",
                    descriptionText: "Placed safely on the bench between Courts 1 & 2 by the net post. Has a Burlingame Pickleball sticker on the side.",
                    category: .waterBottle,
                    courtLocation: "Clubhouse / Benches",
                    status: .found,
                    lostDate: Date().addingTimeInterval(-3600 * 5),
                    foundDate: Date().addingTimeInterval(-3600 * 1),
                    reporterName: "Kevin T.",
                    foundByName: "Mike R."
                )
            ]
        }
        #endif
        let byTab = base.filter { item in
            switch selectedFilter {
            case .all:
                return !item.isFlagged || manager.isOwnerManageMode
            case .lost:
                return item.status == .lost && !item.isFlagged
            case .found:
                return item.status == .found && !item.isFlagged
            case .flagged:
                return item.isFlagged
            }
        }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return byTab }
        return byTab.filter {
            $0.title.lowercased().contains(query) ||
            $0.descriptionText.lowercased().contains(query) ||
            $0.courtLocation.lowercased().contains(query) ||
            $0.category.rawValue.lowercased().contains(query)
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppTheme.canvasBackground
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Toast Banner
                        if let msg = toastMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.white)
                                Text(msg)
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(AppTheme.pickleballGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // First-Time Feature Introduction Card
                        if showIntroCard {
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.burlingameBlue.opacity(0.14))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "Archivebox.fill".lowercased())
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(AppTheme.burlingameBlue)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("NEW · Washington Park Lost & Found")
                                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                                            .foregroundColor(AppTheme.burlingameBlue)
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                showIntroCard = false
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(AppTheme.textSecondary)
                                        }
                                    }
                                    
                                    Text("Left a paddle, water bottle, or jacket at the courts? Snap a photo to report lost or found gear, see exact lost & found timestamps, and mark items found with one tap.")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.burlingameBlue.opacity(0.28), lineWidth: 1)
                            )
                        }
                        
                        // Owner Admin Banner (Only visible when unlocked by Dominic)
                        if manager.isOwnerManageMode {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "shield.checkered")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppTheme.burlingameBlue)
                                    Text("Owner Manage Mode Active")
                                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    if manager.flaggedItemsCount > 0 {
                                        Text("\(manager.flaggedItemsCount) Flagged")
                                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(AppTheme.reservedRed.opacity(0.15))
                                            .foregroundColor(AppTheme.reservedRed)
                                            .clipShape(Capsule())
                                    }
                                    Button("Exit Manage") {
                                        manager.lockOwnerManageMode()
                                        if selectedFilter == .flagged {
                                            selectedFilter = .all
                                        }
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.reservedRed)
                                }
                                
                                HStack(spacing: 8) {
                                    Text("You can edit descriptions, toggle Lost/Found, review auto-flagged posts, or delete any item below.")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    if manager.items.contains(where: { $0.status == .found }) {
                                        Button(action: {
                                            manager.ownerClearAllFoundItems()
                                            showToast("Cleared all resolved Found items")
                                        }) {
                                            Text("Clear Found")
                                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color(red: 0.92, green: 0.94, blue: 0.96))
                                                .foregroundColor(AppTheme.textPrimary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.burlingameBlue.opacity(0.35), lineWidth: 1.2)
                            )
                        }
                        
                        // Top Action Button: [ + Report Lost or Found Item ]
                        Button(action: {
                            HapticFeedback.light()
                            isShowingPostSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.Macro.circle.fill".lowercased())
                                    .font(.system(size: 16, weight: .bold))
                                Text("Post Lost or Found Item")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Spacer()
                                Text("Add Photo & Details +")
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppTheme.burlingameBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: AppTheme.burlingameBlue.opacity(0.25), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        
                        // Search & Filter Controls
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.textSecondary)
                                TextField("Search paddles, bottles, jackets, Court 1...", text: $searchText)
                                    .font(.system(size: 13))
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 9)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                            )
                            
                            // Filter Tabs
                            HStack(spacing: 6) {
                                ForEach(availableTabs) { tab in
                                    let isSelected = selectedFilter == tab
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            selectedFilter = tab
                                        }
                                        HapticFeedback.light()
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(tab.rawValue)
                                            if tab == .flagged && manager.flaggedItemsCount > 0 {
                                                Text("(\(manager.flaggedItemsCount))")
                                            }
                                        }
                                        .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(isSelected ? (tab == .flagged ? AppTheme.reservedRed : AppTheme.burlingameBlue) : Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(isSelected ? Color.clear : Color(red: 0.88, green: 0.90, blue: 0.93), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Automated Content Moderation Notice
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.pickleballGreen)
                            Text("Protected by automated photo & text safety detection. Flagged posts are hidden immediately.")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.horizontal, 4)
                        
                        // Scrollable Feed of Lost & Found Cards
                        if filteredItems.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "shippingbox.and.arrow.backward.fill")
                                    .font(.system(size: 34))
                                    .foregroundColor(AppTheme.burlingameBlue.opacity(0.45))
                                Text(searchText.isEmpty ? "No Lost or Found Items Yet" : "No Matching Items")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("If you find a paddle, water bottle, or jacket left at Washington Park—or lost something yourself—tap 'Post Lost or Found Item' above.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 18)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredItems) { item in
                                    LostAndFoundItemCard(
                                        item: item,
                                        isOwnerManageMode: manager.isOwnerManageMode,
                                        onImageTap: { img in
                                            zoomedImage = img
                                        },
                                        onToggleFound: {
                                            manager.toggleFoundStatus(
                                                for: item.id,
                                                markedBy: LeaderboardManager.shared.users.first(where: { $0.isCurrentUser })?.name ?? "Local Player"
                                            )
                                            showToast(item.status == .lost ? "Marked as Found! ✓" : "Reopened as Lost")
                                        },
                                        onFlagItem: {
                                            manager.flagItemAsInappropriate(itemId: item.id)
                                            showToast("Post flagged & hidden for owner review")
                                        },
                                        onOwnerApprove: {
                                            manager.ownerApproveFlaggedItem(itemId: item.id)
                                            showToast("Approved post")
                                        },
                                        onOwnerEdit: {
                                            editingItem = item
                                        },
                                        onOwnerDelete: {
                                            manager.ownerDeleteItem(itemId: item.id)
                                            showToast("Deleted post")
                                        }
                                    )
                                }
                            }
                        }
                        
                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }
                .refreshable {
                    await manager.pullLatestFromCloud()
                }
            }
            .navigationTitle("Lost & Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticFeedback.light()
                        if manager.isOwnerManageMode {
                            manager.lockOwnerManageMode()
                        } else {
                            ownerKeyInput = ""
                            ownerAuthFailed = false
                            isShowingOwnerAuthAlert = true
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: manager.isOwnerManageMode ? "shield.checkered" : "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Manage")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(manager.isOwnerManageMode ? AppTheme.pickleballGreen : AppTheme.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            .onAppear {
                if !manager.hasSeenIntroBadge {
                    showIntroCard = true
                }
                manager.markLostAndFoundViewed()
                Task {
                    await manager.pullLatestFromCloud()
                    await MainActor.run {
                        manager.markLostAndFoundViewed()
                    }
                }
            }
            .alert("Manage Lost & Found", isPresented: $isShowingOwnerAuthAlert) {
                SecureField("Enter owner key", text: $ownerKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {
                    ownerKeyInput = ""
                }
                Button("Unlock") {
                    if manager.unlockOwnerManageMode(passcode: ownerKeyInput) {
                        ownerKeyInput = ""
                        showToast("Owner Manage Mode Unlocked")
                    } else {
                        ownerAuthFailed = true
                    }
                }
            } message: {
                Text(ownerAuthFailed ? "Invalid key." : "Enter your owner key to edit, unflag, or remove Lost & Found listings.")
            }
            .sheet(isPresented: $isShowingPostSheet) {
                PostLostFoundItemSheet { wasFlagged, reason in
                    if wasFlagged {
                        showToast("⚠️ Post auto-flagged for review: \(reason ?? "Safety check")")
                    } else {
                        showToast("Posted to Washington Park Lost & Found!")
                    }
                }
            }
            .sheet(item: $editingItem) { itemToEdit in
                OwnerEditLostFoundSheet(item: itemToEdit) { title, desc, loc in
                    manager.ownerUpdateItem(
                        itemId: itemToEdit.id,
                        newTitle: title,
                        newDescription: desc,
                        newLocation: loc
                    )
                    showToast("Updated listing details")
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { zoomedImage != nil },
                set: { if !$0 { zoomedImage = nil } }
            )) {
                if let img = zoomedImage {
                    ZoomableImagePreviewSheet(image: img) {
                        zoomedImage = nil
                    }
                }
            }
        }
    }
    
    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.25)) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Individual Lost & Found Item Card

private struct LostAndFoundItemCard: View {
    let item: LostAndFoundItem
    let isOwnerManageMode: Bool
    let onImageTap: (UIImage) -> Void
    let onToggleFound: () -> Void
    let onFlagItem: () -> Void
    let onOwnerApprove: () -> Void
    let onOwnerEdit: () -> Void
    let onOwnerDelete: () -> Void
    
    @State private var confirmFlag: Bool = false
    
    private var formattedLostTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: item.lostDate)
    }
    
    private var formattedFoundTimestamp: String? {
        guard let fd = item.foundDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: fd)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Auto-Flagged Warning Banner (Only visible in Owner Manage Mode)
            if item.isFlagged {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(item.flagReason ?? "Flagged for inappropriate content (Hidden from players)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.reservedRed)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // 1. ITEM PICTURE / VISUAL HEADER
            ZStack(alignment: .topTrailing) {
                if let uiImage = item.decodedImage {
                    Button(action: {
                        onImageTap(uiImage)
                    }) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 190)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Tap to Zoom")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(8)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    // Clean Category Graphic when no photo was uploaded
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [item.category.tintColor.opacity(0.16), item.category.tintColor.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 115)
                        
                        VStack(spacing: 6) {
                            Image(systemName: item.category.sfSymbol)
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(item.category.tintColor)
                            Text(item.category.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(item.category.tintColor)
                        }
                    }
                }
                
                // Location Pill on Top Right of Photo
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10, weight: .bold))
                    Text(item.courtLocation)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.68))
                .clipShape(Capsule())
                .padding(8)
            }
            
            // 2. WORDS DIRECTLY UNDER THE PICTURE: [ LOST | MARKED FOUND ] + EXACT TIMESTAMPS
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    // Status Badge ("LOST" or "MARKED FOUND")
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.status == .lost ? AppTheme.reservedRed : AppTheme.availableGreen)
                            .frame(width: 7, height: 7)
                        Text(item.status == .lost ? "LOST" : "MARKED FOUND")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        (item.status == .lost ? AppTheme.reservedRed : AppTheme.availableGreen).opacity(0.14)
                    )
                    .foregroundColor(item.status == .lost ? AppTheme.reservedRed : AppTheme.availableGreen)
                    .clipShape(Capsule())
                    
                    Text(item.title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Date & Time of Lost AND Date & Time of Found
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.reservedRed)
                        Text("Lost / Reported:")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(formattedLostTimestamp)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    HStack(spacing: 5) {
                        Image(systemName: item.status == .found ? "checkmark.circle.fill" : "magnifyingglass.circle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(item.status == .found ? AppTheme.availableGreen : AppTheme.textSecondary)
                        Text("Marked Found:")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        if let foundStr = formattedFoundTimestamp {
                            Text(foundStr)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.availableGreen)
                        } else {
                            Text("Still missing / waiting to be claimed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            
            // 3. DEDICATED TEXT BOX DESCRIBING THE ITEM
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ITEM DESCRIPTION")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.burlingameBlue)
                    Spacer()
                    Text("Posted by \(item.reporterName)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                Text(item.descriptionText.isEmpty ? "No extra description provided." : item.descriptionText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.96, green: 0.97, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(red: 0.89, green: 0.91, blue: 0.95), lineWidth: 1)
            )
            
            // 4. INTERACTIVE ACTION BAR (Mark Found + Flag Inappropriate)
            HStack(spacing: 8) {
                Button(action: {
                    onToggleFound()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: item.status == .lost ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(item.status == .lost ? "Mark as Found" : "Reopen as Lost")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(item.status == .lost ? .white : AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(item.status == .lost ? AppTheme.availableGreen : Color(red: 0.92, green: 0.94, blue: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    confirmFlag = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Flag")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.94, green: 0.95, blue: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "Report or Block User",
                    isPresented: $confirmFlag,
                    titleVisibility: .visible
                ) {
                    Button("Flag & Hide Inappropriate Content", role: .destructive) {
                        onFlagItem()
                    }
                    Button("Block User & Hide Their Posts", role: .destructive) {
                        onFlagItem()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will immediately hide the post from the public feed and flag it for moderation.")
                }
            }
            
            // 5. OWNER MANAGEMENT CONTROLS (Visible when Dominic unlocks Manage Mode)
            if isOwnerManageMode {
                HStack(spacing: 8) {
                    if item.isFlagged {
                        Button(action: onOwnerApprove) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Approve")
                            }
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.burlingameBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: onOwnerEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit Text")
                        }
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.burlingameBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.burlingameBlue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: onOwnerDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash.fill")
                            Text("Delete Post")
                        }
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppTheme.reservedRed)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    item.status == .found
                        ? AppTheme.availableGreen.opacity(0.35)
                        : Color(red: 0.89, green: 0.91, blue: 0.94),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Post New Lost or Found Item Sheet

private struct PostLostFoundItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = LostAndFoundManager.shared
    
    @State private var itemTitle: String = ""
    @State private var descriptionText: String = ""
    @State private var selectedCategory: LostItemCategory = .paddle
    @State private var selectedLocation: String = "Court 1 — Open Play Area"
    @State private var initialStatus: LostItemStatus = .lost
    @State private var reporterName: String = LeaderboardManager.shared.users.first(where: { $0.isCurrentUser })?.name ?? "Local Player"
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker: Bool = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isSubmitting: Bool = false
    
    let onSubmitted: (Bool, String?) -> Void
    
    private let locations = [
        "Court 1 — Open Play Area",
        "Court 1 — Paddle Queue Rack",
        "Court 2",
        "Court 3",
        "Clubhouse / Benches",
        "Park Walkway / Tables"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("STATUS & ITEM PHOTO")) {
                    Picker("Report Type", selection: $initialStatus) {
                        Text("🔴 Lost / Left at Courts").tag(LostItemStatus.lost)
                        Text("🟢 Already Found / Safe").tag(LostItemStatus.found)
                    }
                    .pickerStyle(.segmented)
                    
                    if let img = selectedImage {
                        VStack(spacing: 8) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            
                            Button(role: .destructive) {
                                selectedImage = nil
                            } label: {
                                Label("Remove Photo", systemImage: "trash")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack(spacing: 10) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button(action: {
                                    imagePickerSource = .camera
                                    isShowingImagePicker = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "camera.fill")
                                        Text("Take Photo")
                                    }
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.burlingameBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: {
                                imagePickerSource = .photoLibrary
                                isShowingImagePicker = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                    Text("Choose Photo")
                                }
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.burlingameBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppTheme.burlingameBlue.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("ITEM DETAILS & DESCRIPTION BOX")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(LostItemCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.sfSymbol).tag(cat)
                        }
                    }
                    
                    TextField("Item Name (e.g. Black JOOLA Paddle, Blue Owala)", text: $itemTitle)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Picker("Where at Park", selection: $selectedLocation) {
                        ForEach(locations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    
                    ZStack(alignment: .topLeading) {
                        if descriptionText.isEmpty {
                            Text("Describe the item (brand, color, grip tape, where it was left or where the owner can pick it up)...")
                                .font(.system(size: 13.5))
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $descriptionText)
                            .frame(minHeight: 90)
                            .font(.system(size: 14))
                    }
                }
                
                Section(
                    header: Text("POSTED BY"),
                    footer: Text("All photos and descriptions are automatically scanned for inappropriate content.")
                ) {
                    TextField("Your Name (Optional)", text: $reporterName)
                        .font(.system(size: 14))
                }
            }
            .navigationTitle("Post Lost or Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        submitNewPost()
                    }) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Post Item")
                                .bold()
                        }
                    }
                    .disabled(
                        isSubmitting ||
                        (itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePickerControllerRepresentable(
                    sourceType: imagePickerSource,
                    selectedImage: $selectedImage
                )
            }
        }
    }
    
    private func submitNewPost() {
        isSubmitting = true
        Task {
            let result = await manager.submitItem(
                title: itemTitle,
                descriptionText: descriptionText,
                category: selectedCategory,
                courtLocation: selectedLocation,
                initialStatus: initialStatus,
                reporterName: reporterName,
                photo: selectedImage
            )
            await MainActor.run {
                isSubmitting = false
                onSubmitted(result.wasAutoFlagged, result.flagReason)
                dismiss()
            }
        }
    }
}

// MARK: - Owner Edit Listing Sheet

private struct OwnerEditLostFoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: LostAndFoundItem
    let onSave: (String, String, String) -> Void
    
    @State private var title: String
    @State private var descriptionText: String
    @State private var location: String
    
    init(item: LostAndFoundItem, onSave: @escaping (String, String, String) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _descriptionText = State(initialValue: item.descriptionText)
        _location = State(initialValue: item.courtLocation)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ITEM TITLE & LOCATION")) {
                    TextField("Title", text: $title)
                    TextField("Court Location", text: $location)
                }
                Section(header: Text("ITEM DESCRIPTION")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 110)
                }
            }
            .navigationTitle("Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, descriptionText, location)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Full-Screen Image Zoom Sheet

private struct ZoomableImagePreviewSheet: View {
    let image: UIImage
    let onClose: () -> Void
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in scale = max(1.0, min(4.0, val)) }
                        .onEnded { _ in
                            withAnimation(.spring()) { scale = 1.0 }
                        }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(20)
            }
        }
    }
}

// MARK: - UIKit Camera / Photo Library Picker Wrapper

private struct ImagePickerControllerRepresentable: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerControllerRepresentable
        
        init(_ parent: ImagePickerControllerRepresentable) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let edited = info[.editedImage] as? UIImage {
                parent.selectedImage = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.selectedImage = original
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
