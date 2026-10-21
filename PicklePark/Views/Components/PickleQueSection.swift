import SwiftUI
import Foundation
import UIKit

public enum LiveFeedTab: String, CaseIterable, Identifiable {
    case ourData = "Washington Park"
    case estWaitTime = "Est. Wait Time"
    
    public var id: String { self.rawValue }
}

public struct PickleQueSection: View {
    @ObservedObject var queueManager = PickleQueueManager.shared
    @ObservedObject var walkOnManager = WalkOnCourtManager.shared
    @ObservedObject var scheduleStore = CourtScheduleStore.shared
    @ObservedObject var cloudService = CommunityCloudService.shared
    @ObservedObject var leaderboardManager = LeaderboardManager.shared
    @ObservedObject var rateLimiter = SubmissionRateLimiter.shared
    @ObservedObject var analyticsService = CourtUsageAnalyticsService.shared
    
    @State private var selectedTab: LiveFeedTab = .ourData
    @State private var isRefreshing: Bool = false
    @State private var spinDegrees: Double = 0.0
    @State private var showUpdatedFeedback: Bool = false
    @State private var showingUpdateStatusSheet: Bool = false
    @State private var selectedDayFilter: WaitGraphDayFilter = .allDays
    @State private var inspectedHour: Int = min(21, max(7, Calendar.current.component(.hour, from: Date())))
    
    public init() {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("wait_time") {
            _selectedTab = State(initialValue: .estWaitTime)
        }
        #endif
    }
    
    /// Computes live walk-on courts available dynamically synced with Courts 2 & 3
    private var liveWalkOnCourtsAvailable: Int {
        var openCount = 0
        let c2Slot = scheduleStore.currentHourSlot(for: 2)
        if c2Slot?.status != .reserved {
            openCount += walkOnManager.status.court2State.pickleballCourtsOpen
        }
        let c3Slot = scheduleStore.currentHourSlot(for: 3)
        if c3Slot?.status != .reserved {
            openCount += walkOnManager.status.court3State.pickleballCourtsOpen
        }
        return openCount
    }
    
    /// Live estimated wait in minutes taking into account ~15 min average pickleball game
    private var liveEstimatedWaitMinutes: Int {
        CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(
            courtsInUse: queueManager.queueStatus.courtsInUse,
            peopleInQueue: queueManager.queueStatus.inQueue,
            walkOnCourtsOpen: liveWalkOnCourtsAvailable
        )
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // TAB SWITCHER: [ Washington Park | Est. Wait Time ]
            HStack(spacing: 4) {
                ForEach(LiveFeedTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                        HapticFeedback.light()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .ourData ? "figure.pickleball" : "clock.badge.checkmark.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                        }
                        .foregroundColor(isSelected ? .black : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
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
            
            // CONTENT BY TAB
            if selectedTab == .ourData {
                ourDataView
            } else {
                estimatedWaitTimeView
            }
        }
        .padding(14)
        .cleanCardStyle()
        .sheet(isPresented: $showingUpdateStatusSheet) {
            UpdateCourtStatusSheet(
                initialCourts: queueManager.queueStatus.courtsInUse,
                initialExtra: liveWalkOnCourtsAvailable,
                initialQueue: queueManager.queueStatus.inQueue,
                initialAuthor: leaderboardManager.currentUser.name
            ) { courts, extra, queue, author in
                let cleanAuthor = ContentModerator.shared.cleanse(author)
                queueManager.submitActivity(courts: courts, extra: extra, queue: queue, author: cleanAuthor, extraNotes: nil)
                
                // Remember user name in profile
                if !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    _ = leaderboardManager.updateUserProfile(
                        name: cleanAuthor,
                        favoriteSnack: leaderboardManager.currentUser.favoriteSnack,
                        avatarEmoji: leaderboardManager.currentUser.avatarEmoji
                    )
                }
                
                showingUpdateStatusSheet = false
            }
        }
    }
    
    // MARK: - TAB 1: WASHINGTON PARK LIVE FEED
    
    private var ourDataView: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 2) {
                Text("TIME TO PICKLE ?")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.burlingameSky)
                
                Text("COURT ACTIVITY @")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.burlingameSky)
                
                Text("Washington Park, Burlingame, CA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.top, 2)
            
            // 3 METRIC CARDS: [ Courts in Use | People in Queue | Walk-On Courts ]
            HStack(spacing: 8) {
                // Left: Courts in Use
                PickleMetricCard(
                    icon: "figure.pickleball",
                    iconColor: Color(red: 0.13, green: 0.72, blue: 0.38),
                    number: "\(queueManager.queueStatus.courtsInUse)",
                    numberColor: Color(red: 0.13, green: 0.72, blue: 0.38),
                    label: "Courts in Use"
                )
                
                // Middle: People in Queue
                PickleMetricCard(
                    icon: "person.2.fill",
                    iconColor: Color(red: 0.96, green: 0.52, blue: 0.15),
                    number: "\(queueManager.queueStatus.inQueue)",
                    numberColor: Color(red: 0.96, green: 0.52, blue: 0.15),
                    label: "People in Queue"
                )
                
                // Right: Walk-On Courts
                PickleMetricCard(
                    icon: "tennis.racket",
                    iconColor: Color(red: 0.75, green: 0.20, blue: 0.85),
                    number: "\(liveWalkOnCourtsAvailable)",
                    numberColor: Color(red: 0.75, green: 0.20, blue: 0.85),
                    label: "Walk-On Courts"
                )
            }
            
            // Quick Live Est. Wait Time Pill (taps over to Est. Wait Time Graph tab)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTab = .estWaitTime
                }
                HapticFeedback.light()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(waitBadgeColor(for: liveEstimatedWaitMinutes))
                    
                    Text(liveEstimatedWaitMinutes == 0 ? "Est. Wait: 0 mins (Walk Right On!)" : "Est. Wait: ~\(liveEstimatedWaitMinutes) mins")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("· ~15m/game")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text("Hourly Graph")
                            .font(.system(size: 10, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(AppTheme.burlingameBlue)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Color(red: 0.95, green: 0.97, blue: 0.99))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(red: 0.88, green: 0.91, blue: 0.95), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            // Timestamps: Last Reported & Live Synced
            VStack(spacing: 3) {
                Text("Last Reported: \(formattedReportDate(from: queueManager.queueStatus.pickleQueReportDate))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(AppTheme.availableGreen)
                        .frame(width: 6, height: 6)
                    Text("Live Cloud Synced: \(formattedSyncTime(from: queueManager.queueStatus.lastAppSyncDate))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(.top, 1)
            
            // Refresh Button Banner with Spin Animation
            Button(action: {
                triggerSmoothRefresh()
            }) {
                HStack(spacing: 8) {
                    if isRefreshing {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .rotationEffect(.degrees(spinDegrees))
                        Text("Syncing Latest Activity...")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    } else if showUpdatedFeedback {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.availableGreen)
                        Text("Activity Synced!")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.availableGreen)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("Refresh for Latest Activity")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(showUpdatedFeedback ? AppTheme.availableGreen : AppTheme.burlingameBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    showUpdatedFeedback
                    ? AppTheme.availableGreen.opacity(0.10)
                    : AppTheme.burlingameBlue.opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .stroke(
                            showUpdatedFeedback
                            ? AppTheme.availableGreen.opacity(0.35)
                            : AppTheme.burlingameBlue.opacity(0.25),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            
            // Prior Updates (Capped at exactly the last 2 updates)
            if !queueManager.queueStatus.priorUpdates.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Past Updates")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    ForEach(queueManager.queueStatus.priorUpdates.prefix(2)) { update in
                        let pastWait = CourtUsageAnalyticsService.calculateEstimatedWaitMinutes(courtsInUse: update.courts, peopleInQueue: update.queue, walkOnCourtsOpen: update.extra)
                        Text("Courts: \(update.courts) | Queue: \(update.queue) (~\(pastWait)m wait) | Walk-On: \(update.extra) • \(timeAgo(from: update.timestamp))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            
            // Full-Width Action: [ Input Activity ]
            Button(action: {
                HapticFeedback.light()
                showingUpdateStatusSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Input Activity")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.burlingameBlue)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .shadow(color: AppTheme.burlingameBlue.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - TAB 2: ESTIMATED WAIT TIME & USUAL HOURLY WAIT GRAPH
    
    private var estimatedWaitTimeView: some View {
        let racksAhead = CourtUsageAnalyticsService.paddleRacksAhead(for: queueManager.queueStatus.inQueue)
        let hourlyPoints = analyticsService.hourlyWaitProfile(for: selectedDayFilter)
        let currentHour24 = Calendar.current.component(.hour, from: Date())
        let activePoint = hourlyPoints.first(where: { $0.hour == inspectedHour }) ?? hourlyPoints.first(where: { $0.hour == currentHour24 }) ?? hourlyPoints[3]
        let maxGraphWait = max(25, hourlyPoints.map(\.usualWaitMinutes).max() ?? 25)
        
        let liveReportDate: Date? = queueManager.queueStatus.pickleQueReportDate.timeIntervalSince1970 > 1000 ? queueManager.queueStatus.pickleQueReportDate : nil
        let latestRealReportDate: Date? = [analyticsService.telemetryLogs.first?.timestamp, liveReportDate, queueManager.queueStatus.priorUpdates.first?.timestamp].compactMap { $0 }.max()
        let secondsSinceLastReport: TimeInterval? = latestRealReportDate.map { Date().timeIntervalSince($0) }
        let isStaleOverFourHours: Bool = {
            guard let elapsed = secondsSinceLastReport else { return true }
            return elapsed >= (4 * 3600)
        }()
        
        return VStack(alignment: .leading, spacing: 14) {
            // STALE WAIT TIME NOTIFICATION (Shown when no one has logged a wait time in 4+ hours)
            if isStaleOverFourHours {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 9) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 30, height: 30)
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.90, green: 0.45, blue: 0.05))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wait Time Analytics May Be Off (4h+ Since Last Report)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.72, green: 0.34, blue: 0.02))
                            
                            Text(
                                latestRealReportDate != nil
                                    ? "No one has logged a wait time in over 4 hours (last update \(formattedReportDate(from: latestRealReportDate!))). Go play at the courts and log a live wait time to refresh the feed!"
                                    : "No one has logged a court wait time in the last 4 hours! Head out to the courts to play and add a live court & queue update (+10 Leaderboard pts)."
                            )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Button(action: {
                        HapticFeedback.light()
                        showingUpdateStatusSheet = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.pickleball")
                                .font(.system(size: 12, weight: .bold))
                            Text("Go Play & Add a Live Wait Time (+10 Pts)")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.92, green: 0.48, blue: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(11)
                .background(Color(red: 1.0, green: 0.97, blue: 0.91))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1.2)
                )
            }
            
            // 1. LIVE RIGHT-NOW WAIT TIME SUMMARY CARD
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LIVE ESTIMATED COURT WAIT")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.burlingameBlue)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(liveEstimatedWaitMinutes == 0 ? "0 mins" : "~\(liveEstimatedWaitMinutes) mins")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(waitBadgeColor(for: liveEstimatedWaitMinutes))
                            
                            Text(liveWaitStatusTitle)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    // Racks Ahead Badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(queueManager.queueStatus.inQueue) in Queue")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text(racksAhead == 0 ? "0 racks ahead" : "\(racksAhead) rack\(racksAhead == 1 ? "" : "s") (4-on/4-off)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                // Pickleball Game Duration Math Strip
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.burlingameBlue)
                    
                    Text("Wait time only triggers once all **4 courts are filled**. Standard game to 11 pts ≈ **15 mins** (**~3.75 mins** per 4-paddle group).")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color(red: 0.95, green: 0.97, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(waitBadgeColor(for: liveEstimatedWaitMinutes).opacity(0.3), lineWidth: 1)
            )
            
            // 2. INTERACTIVE USUAL WAIT TIME GRAPH (BY HOUR — 100% REAL COMMUNITY DATA)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("USUAL WAIT TIME BY HOUR (REAL REPORTS)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Built 100% from real player submissions (~15m avg game)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    Text("\(analyticsService.telemetryLogs.count) report\(analyticsService.telemetryLogs.count == 1 ? "" : "s")")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AppTheme.burlingameBlue.opacity(0.12))
                        .foregroundColor(AppTheme.burlingameBlue)
                        .clipShape(Capsule())
                }
                
                // Day Pattern Filter: [ All Reports | Weekdays | Weekends ]
                HStack(spacing: 4) {
                    ForEach(WaitGraphDayFilter.allCases) { filter in
                        let isSelected = selectedDayFilter == filter
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDayFilter = filter
                            }
                            HapticFeedback.light()
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(isSelected ? AppTheme.burlingameBlue : Color(red: 0.92, green: 0.94, blue: 0.96))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Selected Hour Callout Strip
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(activePoint.fullLabel)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if activePoint.hour == currentHour24 {
                                Text("NOW")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(AppTheme.pickleballLime)
                                    .foregroundColor(.black)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(activePoint.crowdLevelText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(activePoint.hasRealData ? waitBadgeColor(for: activePoint.usualWaitMinutes) : AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        if activePoint.hasRealData {
                            Text(activePoint.usualWaitMinutes == 0 ? "0 min wait" : "~\(activePoint.usualWaitMinutes) min wait")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(waitBadgeColor(for: activePoint.usualWaitMinutes))
                            
                            Text("Avg queue: ~\(activePoint.usualQueueCount) paddles (\(activePoint.sampleCount) report\(activePoint.sampleCount == 1 ? "" : "s"))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        } else {
                            Text("No data yet")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.textSecondary)
                            
                            Text("0 reports logged for this hour")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94), lineWidth: 1)
                )
                
                // Bar Chart (7 AM to 9 PM)
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(hourlyPoints) { pt in
                            let isCurrentHour = (pt.hour == currentHour24)
                            let isInspected = (pt.hour == activePoint.hour)
                            let ratio = CGFloat(pt.usualWaitMinutes) / CGFloat(max(1, maxGraphWait))
                            let barHeight: CGFloat = pt.hasRealData ? max(10, min(92, ratio * 92)) : 0
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    inspectedHour = pt.hour
                                }
                                HapticFeedback.light()
                            }) {
                                VStack(spacing: 3) {
                                    // Top wait label on selected or current hour
                                    if isInspected {
                                        Text(pt.hasRealData ? "\(pt.usualWaitMinutes)m" : "—")
                                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                            .foregroundColor(pt.hasRealData ? waitBadgeColor(for: pt.usualWaitMinutes) : AppTheme.textSecondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    } else if isCurrentHour {
                                        Circle()
                                            .fill(AppTheme.burlingameBlue)
                                            .frame(width: 4, height: 4)
                                    } else {
                                        Color.clear.frame(height: 10)
                                    }
                                    
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(Color(red: 0.92, green: 0.94, blue: 0.96))
                                            .frame(height: 92)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .stroke(isInspected ? Color.black.opacity(0.45) : Color.clear, lineWidth: 1.2)
                                            )
                                        
                                        if pt.hasRealData {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(barColor(for: pt.usualWaitMinutes, isInspected: isInspected))
                                                .frame(height: barHeight)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                        .stroke(isInspected ? Color.black.opacity(0.65) : Color.clear, lineWidth: 1.5)
                                                )
                                        }
                                    }
                                    
                                    Text(pt.label)
                                        .font(.system(size: 8.5, weight: (isCurrentHour || isInspected) ? .black : .medium, design: .rounded))
                                        .foregroundColor((isCurrentHour || isInspected) ? AppTheme.textPrimary : AppTheme.textSecondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 124)
                    .padding(.top, 4)
                    
                    // Legend Strip
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle().fill(AppTheme.availableGreen).frame(width: 6, height: 6)
                            Text("0–8m (<1 Game)")
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 0.96, green: 0.55, blue: 0.15)).frame(width: 6, height: 6)
                            Text("9–18m (~1 Game)")
                        }
                        HStack(spacing: 4) {
                            Circle().fill(AppTheme.reservedRed).frame(width: 6, height: 6)
                            Text("19m+ (Peak Rush)")
                        }
                        Spacer()
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.90, green: 0.92, blue: 0.95), lineWidth: 1)
            )
            
            // 3. HOMAGE TO THE PICKLEQUE APP
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.pickleballGreen.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.pickleballGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Homage to the PickleQue App")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Special credit & gratitude to the original PickleQue app for pioneering the idea of community-reported court & paddle queue tracking at Washington Park.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(11)
            .background(Color(red: 0.95, green: 0.98, blue: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.pickleballGreen.opacity(0.25), lineWidth: 1)
            )
            
            // Quick Input Activity Button from Wait Time Tab as well
            Button(action: {
                HapticFeedback.light()
                showingUpdateStatusSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Update Live Queue & Courts")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(AppTheme.burlingameBlue)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Wait Time Helpers
    
    private var liveWaitStatusTitle: String {
        if queueManager.queueStatus.courtsInUse < 4 {
            let emptyCount = 4 - max(0, queueManager.queueStatus.courtsInUse)
            return "\(emptyCount) Empty Court\(emptyCount == 1 ? "" : "s") — Walk Right On!"
        }
        switch liveEstimatedWaitMinutes {
        case 0: return "Walk Right On!"
        case 1...6: return "Next Up (<1/2 Game)"
        case 7...15: return "~1 Game Wait"
        case 16...24: return "~1.5 Games Wait"
        default: return "Peak Rotation (2+ Games)"
        }
    }
    
    private func waitBadgeColor(for minutes: Int) -> Color {
        if minutes <= 8 { return AppTheme.availableGreen }
        if minutes <= 18 { return Color(red: 0.96, green: 0.52, blue: 0.12) }
        return AppTheme.reservedRed
    }
    
    private func barColor(for minutes: Int, isInspected: Bool) -> Color {
        let base = waitBadgeColor(for: minutes)
        return isInspected ? base : base.opacity(0.78)
    }
    
    // MARK: - Actions & Helpers
    
    private func triggerSmoothRefresh() {
        HapticFeedback.light()
        isRefreshing = true
        showUpdatedFeedback = false
        
        withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) {
            spinDegrees = 360
        }
        
        Task {
            let startTime = Date()
            
            async let calendarRefresh: () = CourtScheduleStore.shared.refreshAll()
            async let cloudRefresh: () = CommunityCloudService.shared.pullLatestFromCloud()
            async let telemetryRefresh: () = CourtUsageAnalyticsService.shared.fetchCloudTelemetryLogs()
            queueManager.refreshActivity()
            _ = await (calendarRefresh, cloudRefresh, telemetryRefresh)
            walkOnManager.check11PMReset()
            
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 0.7 {
                try? await Task.sleep(nanoseconds: UInt64((0.7 - elapsed) * 1_000_000_000))
            }
            
            await MainActor.run {
                walkOnManager.check11PMReset()
                withAnimation(.easeOut(duration: 0.2)) {
                    isRefreshing = false
                    spinDegrees = 0
                    showUpdatedFeedback = true
                }
                HapticFeedback.success()
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    showUpdatedFeedback = false
                }
            }
        }
    }
    
    private func formattedReportDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let dateString = formatter.string(from: date)
        
        let seconds = Int(Date().timeIntervalSince(date))
        let relativeString: String
        if seconds < 60 {
            relativeString = "Just now"
        } else if seconds < 3600 {
            relativeString = "\(seconds / 60)m ago"
        } else if seconds < 86400 {
            relativeString = "\(seconds / 3600) hr. ago"
        } else {
            relativeString = "\(seconds / 86400)d ago"
        }
        
        return "\(dateString) (\(relativeString))"
    }
    
    private func formattedSyncTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
    
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Metric Card Component

private struct PickleMetricCard: View {
    let icon: String
    let iconColor: Color
    let number: String
    let numberColor: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(height: 24)
            
            Text(number)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(numberColor)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(Color(red: 0.90, green: 0.92, blue: 0.94), lineWidth: 1)
        )
    }
}

// MARK: - Update Court Status Sheet (Unlimited Updates with 4-Hour Points Safeguard)

public struct UpdateCourtStatusSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var rateLimiter = SubmissionRateLimiter.shared
    
    @State private var courtsInUse: Int
    @State private var extraCourts: Int
    @State private var inQueue: Int
    @State private var authorName: String
    
    let onSave: (Int, Int, Int, String) -> Void
    
    public init(
        initialCourts: Int,
        initialExtra: Int,
        initialQueue: Int,
        initialAuthor: String,
        onSave: @escaping (Int, Int, Int, String) -> Void
    ) {
        _courtsInUse = State(initialValue: initialCourts)
        _extraCourts = State(initialValue: initialExtra)
        _inQueue = State(initialValue: initialQueue)
        _authorName = State(initialValue: initialAuthor)
        self.onSave = onSave
    }
    
    private var pointsStatus: (eligible: Bool, remainingSeconds: TimeInterval, message: String?) {
        rateLimiter.shouldAwardPoints()
    }
    
    public var body: some View {
        NavigationView {
            Form {
                // Points Eligibility Banner
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: pointsStatus.eligible ? "star.circle.fill" : "hourglass.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(pointsStatus.eligible ? AppTheme.pickleballGreen : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pointsStatus.eligible ? "Leaderboard Points Active" : "Points Cooldown (4h)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(pointsStatus.eligible ? AppTheme.pickleballGreen : .orange)
                            Text(pointsStatus.message ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                // Section 1: Courts In Use (0 to 4)
                Section(header: Text("COURTS IN USE (PERMANENT COURTS)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(0...4, id: \.self) { num in
                                PillNumberButton(
                                    title: "\(num)",
                                    isSelected: courtsInUse == num,
                                    activeColor: Color(red: 0.13, green: 0.72, blue: 0.38)
                                ) {
                                    courtsInUse = num
                                    if num < 4 {
                                        inQueue = 0
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 2: People in Queue (Only triggers wait when all 4 courts are filled)
                Section(
                    header: Text("PEOPLE IN QUEUE (DOUBLES ROTATION)"),
                    footer: Text("Queue & wait time only trigger once all 4 courts are filled.")
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Quick 4s multipliers
                        HStack(spacing: 6) {
                            ForEach([0, 4, 8, 12, 16, 20], id: \.self) { count in
                                Button(action: {
                                    inQueue = count
                                    if count > 0 {
                                        courtsInUse = 4
                                    }
                                    HapticFeedback.light()
                                }) {
                                    Text("\(count)")
                                        .font(.system(size: 13, weight: inQueue == count ? .bold : .medium, design: .rounded))
                                        .foregroundColor(inQueue == count ? .white : AppTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(inQueue == count ? Color(red: 0.96, green: 0.52, blue: 0.15) : Color(red: 0.92, green: 0.94, blue: 0.96))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Stepper for exact +/-
                        Stepper("Exact Queue Count: \(inQueue)", value: Binding(
                            get: { inQueue },
                            set: { newValue in
                                inQueue = newValue
                                if newValue > 0 {
                                    courtsInUse = 4
                                }
                            }
                        ), in: 0...50)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 3: Walk-On Courts Available (0 to 4 PB)
                Section(header: Text("WALK-ON PICKLEBALL COURTS AVAILABLE (COURTS 2 & 3)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(0...4, id: \.self) { num in
                                PillNumberButton(
                                    title: "\(num)",
                                    isSelected: extraCourts == num,
                                    activeColor: Color(red: 0.75, green: 0.20, blue: 0.85)
                                ) {
                                    extraCourts = num
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Section 4: Auto-Remembered Name with Content Governance
                Section(
                    header: Text("REPORTER NAME"),
                    footer: Text("Defaults to your profile name (\(authorName.isEmpty ? "You" : authorName)). Automatically saved and moderated.")
                ) {
                    TextField("Your Name (e.g. Dominic)", text: $authorName)
                        .font(.system(size: 15))
                }
            }
            .navigationTitle("Input Court Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.burlingameBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit Activity") {
                        onSave(courtsInUse, extraCourts, inQueue, authorName)
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(AppTheme.burlingameBlue)
                }
            }
        }
    }
}

// MARK: - Pill Number Button

private struct PillNumberButton: View {
    let title: String
    let isSelected: Bool
    let activeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? activeColor : Color(red: 0.92, green: 0.94, blue: 0.96))
                )
        }
        .buttonStyle(.plain)
    }
}
