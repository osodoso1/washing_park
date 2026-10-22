import SwiftUI

public struct MainDashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var scheduleStore = CourtScheduleStore.shared
    @StateObject private var queueManager = PickleQueueManager.shared
    @StateObject private var walkOnManager = WalkOnCourtManager.shared
    @StateObject private var leaderboardManager = LeaderboardManager.shared
    @StateObject private var cloudService = CommunityCloudService.shared
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var lostAndFoundManager = LostAndFoundManager.shared
    @StateObject private var notificationManager = ParkNotificationManager.shared
    
    @State private var isShowingReservationWeb: Bool = false
    @State private var isShowingDevFeedback: Bool = false
    @State private var isShowingPickleMatch: Bool = false
    @State private var isShowingClubhouseHours: Bool = false
    @State private var isShowingLostAndFound: Bool = false
    @State private var isShowingNotifications: Bool = false
    @State private var reservationTargetUrl: String = WebTracScraper.webTracSearchURL
    @State private var navSpinDegrees: Double = 0.0
    @State private var refreshStatusToast: String? = nil
    private let liveSyncTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                AppTheme.canvasBackground
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Top Toast Banner for Auto-Clipboard Ingestion or Refresh Confirmation
                        if let msg = cloudService.syncBannerMessage ?? refreshStatusToast {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                Text(msg)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.pickleballGreen)
                            .clipShape(Capsule())
                            .shadow(color: AppTheme.pickleballGreen.opacity(0.3), radius: 8, x: 0, y: 3)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: msg)
                        }
                        
                        // 1. Status Hero Banner (Park info, Reservable Courts 2 & 3 vs PB Drop-In, Clubhouse Hours & Lost & Found)
                        StatusHeroCard(
                            onReserveTap: {
                                reservationTargetUrl = WebTracScraper.webTracSearchURL
                                isShowingReservationWeb = true
                            },
                            onClubhouseHoursTap: {
                                isShowingClubhouseHours = true
                            },
                            onLostAndFoundTap: {
                                isShowingLostAndFound = true
                            }
                        )
                        
                        // 2. On-Court Doubles Match & Rotation Companion (PickleMatch)
                        Button(action: {
                            HapticFeedback.light()
                            isShowingPickleMatch = true
                        }) {
                            HStack(spacing: 9) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.pickleballLime.opacity(0.2))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundColor(AppTheme.pickleballLime)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("On-Court Doubles: PickleMatch")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Fair doubles rotations, sitting queue & live scores")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.75))
                                }
                                
                                Spacer()
                                
                                Text("Let's Play ↗")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(AppTheme.pickleballLime)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.pickleballLime.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.03, green: 0.16, blue: 0.32))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        
                        // 3. PickleQue Live Activity Card (Court 1's 4 Open PB Courts)
                        PickleQueSection()
                        
                        // 4. Crowdsourced Walk-On Court Status & Sides (Courts 2 & 3)
                        WalkOnCourtCard()
                        
                        // 5. Community Leaderboard & Snack MVP Rewards
                        LeaderboardCard()
                        
                        // 6. Clean Schedule Switcher: [ Today | 7 Days | Month ]
                        ScopeSegmentedControl(selectedScope: $scheduleStore.selectedScope)
                        
                        // 7. Active Schedule View (Courts 2 & 3 Reservable on WebTrac)
                        Group {
                            switch scheduleStore.selectedScope {
                            case .today:
                                TodayScheduleView { slot in
                                    handleSlotReservation(slot)
                                }
                            case .sevenDays:
                                SevenDayScheduleView { slot in
                                    handleSlotReservation(slot)
                                }
                            case .month:
                                MonthScheduleView { slot in
                                    handleSlotReservation(slot)
                                }
                            }
                        }
                        
                        /*
                        // 8. Lowkey Community & Support Footer (Commented out for future use — active in DevFeedbackSheet)
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.red.opacity(0.8))
                                Text("Built for the Washington Park Pickleball Community")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Text("Special thanks to Patreon supporters for their continued use & backing!")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            // Iconic Buy Me a Coffee Tag
                            Button(action: {
                                HapticFeedback.light()
                                if let url = URL(string: "https://www.buymeacoffee.com/osodoso") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text("☕️")
                                        .font(.system(size: 12))
                                    Text("Buy me a coffee")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.black)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(red: 1.0, green: 0.867, blue: 0.0))
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        */
                        
                        // Bottom padding
                        Color.clear.frame(height: 60)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                .refreshable {
                    await performFullSync(showToast: true)
                }
            }
            .navigationTitle("PicklePark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        // Lost & Found Button with Red Notification Badge right next to Club Info
                        Button(action: {
                            HapticFeedback.light()
                            isShowingLostAndFound = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppTheme.burlingameBlue)
                                
                                if lostAndFoundManager.shouldShowRedNotificationBadge {
                                    Circle()
                                        .fill(AppTheme.reservedRed)
                                        .frame(width: 8, height: 8)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 1.5)
                                        )
                                        .offset(x: 4, y: -3)
                                }
                            }
                        }
                        
                        Button(action: {
                            HapticFeedback.light()
                            isShowingClubhouseHours = true
                        }) {
                            Image(systemName: "building.2.crop.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppTheme.burlingameBlue)
                        }
                        
                        Button(action: {
                            HapticFeedback.light()
                            isShowingPickleMatch = true
                        }) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.burlingameBlue)
                        }
                        
                        Button(action: {
                            HapticFeedback.light()
                            isShowingNotifications = true
                        }) {
                            Image(systemName: notificationManager.isMasterEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(notificationManager.isMasterEnabled ? AppTheme.burlingameBlue : AppTheme.textSecondary)
                        }
                        
                        Button(action: {
                            HapticFeedback.light()
                            isShowingDevFeedback = true
                        }) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.burlingameBlue)
                        }
                        
                        Button(action: {
                            triggerNavRefresh()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppTheme.burlingameBlue)
                                .rotationEffect(.degrees(navSpinDegrees))
                        }
                        .disabled(scheduleStore.isRefreshing || cloudService.isSyncing)
                    }
                }
            }
            .sheet(isPresented: $isShowingLostAndFound) {
                LostAndFoundSheet()
            }
            .sheet(isPresented: $isShowingClubhouseHours) {
                ClubhouseHoursSheet()
            }
            .sheet(isPresented: $isShowingPickleMatch) {
                PickleMatchSheet()
            }
            .sheet(isPresented: $isShowingReservationWeb) {
                ReservationWebView(initialUrl: reservationTargetUrl) {
                    isShowingReservationWeb = false
                }
            }
            .sheet(isPresented: $isShowingDevFeedback) {
                DevFeedbackSheet()
            }
            .sheet(isPresented: $isShowingNotifications) {
                NotificationSettingsSheet()
            }
            .onAppear {
                #if targetEnvironment(simulator)
                let args = ProcessInfo.processInfo.arguments
                if args.contains("lost_and_found") {
                    isShowingLostAndFound = true
                } else if args.contains("picklematch") {
                    isShowingPickleMatch = true
                } else if args.contains("feedback") {
                    isShowingDevFeedback = true
                } else if args.contains("clubhouse") {
                    isShowingClubhouseHours = true
                } else if args.contains("seven_days") {
                    scheduleStore.selectedScope = .sevenDays
                }
                #endif
                // Auto-refresh instantly upon app launch / initial screen load
                Task {
                    await performFullSync(showToast: false)
                }
            }
            .onChange(of: scenePhase) { newPhase in
                // Auto-refresh immediately whenever returning from idle, background, or locked screen
                if newPhase == .active {
                    Task {
                        await performFullSync(showToast: false)
                    }
                }
            }
            .onReceive(liveSyncTimer) { _ in
                guard scenePhase == .active else { return }
                Task {
                    await cloudService.pullLatestFromCloud()
                    await lostAndFoundManager.pullLatestFromCloud()
                    await CourtUsageAnalyticsService.shared.fetchCloudTelemetryLogs()
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func triggerNavRefresh() {
        HapticFeedback.light()
        withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) {
            navSpinDegrees = 360
        }
        
        Task {
            let start = Date()
            await performFullSync(showToast: true)
            
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 0.7 {
                try? await Task.sleep(nanoseconds: UInt64((0.7 - elapsed) * 1_000_000_000))
            }
            
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    navSpinDegrees = 0
                }
            }
        }
    }
    
    private func performFullSync(showToast: Bool = false) async {
        _ = cloudService.checkAndIngestClipboard()
        
        async let sched: () = scheduleStore.refreshAll()
        async let cloud: () = cloudService.pullLatestFromCloud()
        async let ckActivity: () = cloudKitManager.fetchLatestCourtActivity()
        async let ckLeaderboard: () = cloudKitManager.fetchLeaderboardFromCloud()
        async let ckTelemetry: () = CourtUsageAnalyticsService.shared.fetchCloudTelemetryLogs()
        async let ckLostFound: () = lostAndFoundManager.pullLatestFromCloud()
        async let weather: () = WeatherService.shared.fetchCurrentWeather()
        
        queueManager.refreshActivity()
        leaderboardManager.checkMonthlyReset()
        
        _ = await (sched, cloud, ckActivity, ckLeaderboard, ckTelemetry, ckLostFound, weather)
        
        await MainActor.run {
            walkOnManager.check11PMReset()
        }
        
        if showToast {
            await MainActor.run {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    refreshStatusToast = "⚡️ Synced: City Calendar & Live Feed Updated!"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        refreshStatusToast = nil
                    }
                }
            }
        }
    }
    
    private func handleSlotReservation(_ slot: ReservationSlot) {
        reservationTargetUrl = WebTracScraper.webTracSearchURL
        isShowingReservationWeb = true
    }
}

// MARK: - Scope Segmented Control

private struct ScopeSegmentedControl: View {
    @Binding var selectedScope: ScheduleScope
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ScheduleScope.allCases) { scope in
                let isSelected = selectedScope == scope
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedScope = scope
                    }
                    HapticFeedback.light()
                }) {
                    Text(scope.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? AppTheme.pickleballLime : Color.clear)
                        )
                        .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(red: 0.90, green: 0.92, blue: 0.94))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
