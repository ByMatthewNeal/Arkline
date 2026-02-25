import SwiftUI
import UserNotifications

// MARK: - Notifications Detail View
struct NotificationsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @AppStorage(Constants.UserDefaults.notifyDCAReminders)
    private var dcaReminders = true

    @AppStorage(Constants.UserDefaults.notifyExtremeMoves)
    private var extremeMoves = true

    @AppStorage(Constants.UserDefaults.notifySentimentShifts)
    private var sentimentShifts = true

    @AppStorage(Constants.UserDefaults.notifyInsights)
    private var insights = true

    @AppStorage(Constants.UserDefaults.notifyEmail)
    private var emailNotifications = true

    var body: some View {
        ZStack {
            MeshGradientBackground()
            List {
                // MARK: - Investment Reminders
                Section {
                    Toggle(isOn: $dcaReminders) {
                        NotificationRow(
                            icon: "calendar.badge.clock",
                            iconColor: AppColors.accent,
                            title: "DCA Reminders",
                            description: "Reminders for your scheduled purchases"
                        )
                    }
                    .onChange(of: dcaReminders) { _, newValue in
                        Haptics.selection()
                        if !newValue {
                            cancelAllDCANotifications()
                        }
                    }
                } header: {
                    Text("Investment Reminders")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // MARK: - Market Alerts
                Section {
                    Toggle(isOn: $extremeMoves) {
                        NotificationRow(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: AppColors.warning,
                            title: "Extreme Moves",
                            description: "Alerts when macro indicators hit rare levels"
                        )
                    }
                    .onChange(of: extremeMoves) { _, newValue in
                        Haptics.selection()
                        ExtremeMoveAlertManager.shared.extremeAlertsEnabled = newValue
                        if !newValue {
                            ExtremeMoveAlertManager.shared.significantAlertsEnabled = false
                        }
                    }

                    Toggle(isOn: $sentimentShifts) {
                        NotificationRow(
                            icon: "brain.head.profile",
                            iconColor: AppColors.error,
                            title: "Sentiment Shifts",
                            description: "Alerts when market mood changes (Panic, FOMO, etc.)"
                        )
                    }
                    .onChange(of: sentimentShifts) { _, newValue in
                        Haptics.selection()
                        SentimentRegimeAlertManager.shared.notificationsEnabled = newValue
                    }
                } header: {
                    Text("Market Alerts")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // MARK: - Insights
                Section {
                    Toggle(isOn: $insights) {
                        NotificationRow(
                            icon: "megaphone.fill",
                            iconColor: AppColors.accent,
                            title: "Insights & Broadcasts",
                            description: "New insights published in the Insights tab"
                        )
                    }
                    .onChange(of: insights) { _, newValue in
                        Haptics.selection()
                        BroadcastNotificationService.shared.broadcastNotificationsEnabled = newValue
                    }
                } header: {
                    Text("Insights")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // MARK: - Email
                Section {
                    Toggle(isOn: $emailNotifications) {
                        NotificationRow(
                            icon: "envelope.fill",
                            iconColor: AppColors.accent,
                            title: "Email Notifications",
                            description: "Receive important updates via email"
                        )
                    }
                    .onChange(of: emailNotifications) { _, newValue in
                        Haptics.selection()
                    }
                } header: {
                    Text("Email")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func cancelAllDCANotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let dcaIds = requests.filter { $0.identifier.hasPrefix("dca_reminder_") }.map(\.identifier)
            if !dcaIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: dcaIds)
            }
        }
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(description)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
