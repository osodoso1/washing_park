import SwiftUI
import UserNotifications

public struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = ParkNotificationManager.shared
    @ObservedObject private var queueManager = PickleQueueManager.shared
    
    @State private var testSentMessage: String? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                // Section 1: Master Switch & Permission Status
                Section(
                    header: Text("PHONE NOTIFICATIONS"),
                    footer: Text("Turn alerts on or off anytime. When enabled, you'll receive alerts when players update the Washington Park queue/wait time or post to Lost & Found.")
                ) {
                    Toggle(isOn: $notificationManager.isMasterEnabled) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(notificationManager.isMasterEnabled ? AppTheme.burlingameBlue.opacity(0.15) : Color.gray.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: notificationManager.isMasterEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(notificationManager.isMasterEnabled ? AppTheme.burlingameBlue : .gray)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable Park Notifications")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(statusSubtitle)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(statusColor)
                            }
                        }
                    }
                    .tint(AppTheme.pickleballGreen)
                    
                    if notificationManager.authorizationStatus == .denied {
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Enable Notifications in iOS Settings")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(AppTheme.burlingameBlue)
                        }
                    } else if notificationManager.authorizationStatus == .notDetermined {
                        Button(action: {
                            notificationManager.requestAuthorizationIfNeeded()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                Text("Allow Notifications on This iPhone")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Spacer()
                            }
                            .foregroundColor(AppTheme.burlingameBlue)
                        }
                    }
                }
                
                // Section 2: Individual Alert Types
                Section(
                    header: Text("ALERT TYPES"),
                    footer: Text("Queue alerts tell you how many people are in the queue and the live estimated wait time (~15m per game once all 4 courts are filled).")
                ) {
                    Toggle(isOn: $notificationManager.queueWaitAlertsEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.wave.2.fill")
                                    .foregroundColor(Color(red: 0.96, green: 0.52, blue: 0.15))
                                Text("Court Queue & Wait Time Updates")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            }
                            Text("Example: \"Queue updated for 8 people — Est. wait time is ~8 mins (4/4 courts full).\"")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .disabled(!notificationManager.isMasterEnabled)
                    .tint(AppTheme.pickleballGreen)
                    
                    Toggle(isOn: $notificationManager.lostAndFoundAlertsEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundColor(AppTheme.burlingameBlue)
                                Text("New Lost & Found Posts")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            }
                            Text("Alerts when a player posts a lost or found paddle, bottle, jacket, or item at Washington Park.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .disabled(!notificationManager.isMasterEnabled)
                    .tint(AppTheme.pickleballGreen)
                }
                
                // Section 3: Preview / Test Alert on Phone
                Section(
                    header: Text("TEST ON YOUR PHONE"),
                    footer: Text("Tap to send a live preview notification banner to your phone right now.")
                ) {
                    Button(action: {
                        sendTestQueueAlert()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .foregroundColor(AppTheme.burlingameBlue)
                            Text("Send Test Queue & Wait Time Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.burlingameBlue)
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        sendTestLostFoundAlert()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "shippingbox.and.arrow.backward.fill")
                                .foregroundColor(AppTheme.burlingameBlue)
                            Text("Send Test Lost & Found Alert")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.burlingameBlue)
                            Spacer()
                        }
                    }
                    
                    if let msg = testSentMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.availableGreen)
                            Text(msg)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.availableGreen)
                        }
                    }
                }
            }
            .navigationTitle("Park Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.burlingameBlue)
                }
            }
            .onAppear {
                notificationManager.refreshAuthorizationStatus()
            }
        }
    }
    
    private var statusSubtitle: String {
        if !notificationManager.isMasterEnabled {
            return "Paused on this iPhone"
        }
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Active · Receiving live park alerts"
        case .denied:
            return "Blocked in iOS Settings — tap below to allow"
        case .notDetermined:
            return "Tap 'Allow Notifications' below to activate"
        @unknown default:
            return "Ready"
        }
    }
    
    private var statusColor: Color {
        if !notificationManager.isMasterEnabled {
            return AppTheme.textSecondary
        }
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return AppTheme.availableGreen
        case .denied:
            return AppTheme.reservedRed
        case .notDetermined:
            return .orange
        @unknown default:
            return AppTheme.textSecondary
        }
    }
    
    private func sendTestQueueAlert() {
        HapticFeedback.light()
        notificationManager.requestAuthorizationIfNeeded { granted in
            guard granted else {
                testSentMessage = "Please allow notifications in iOS Settings first."
                return
            }
            let q = queueManager.queueStatus
            notificationManager.sendQueueUpdatedNotification(
                courtsInUse: q.courtsInUse,
                peopleInQueue: q.inQueue,
                walkOnCourtsOpen: q.extraCourts,
                author: q.lastAuthor ?? "Washington Park Player"
            )
            testSentMessage = "Sent Queue & Wait Time alert banner!"
        }
    }
    
    private func sendTestLostFoundAlert() {
        HapticFeedback.light()
        notificationManager.requestAuthorizationIfNeeded { granted in
            guard granted else {
                testSentMessage = "Please allow notifications in iOS Settings first."
                return
            }
            let sample = LostAndFoundManager.shared.visibleItems.first ?? LostAndFoundItem(
                title: "JOOLA Perseus 16mm Paddle",
                descriptionText: "Left near the Court 1 paddle rack.",
                category: .paddle,
                courtLocation: "Court 1 — Open Play Rack",
                status: .lost,
                reporterName: "Washington Park Player"
            )
            notificationManager.sendLostAndFoundNotification(for: sample)
            testSentMessage = "Sent Lost & Found alert banner!"
        }
    }
}
