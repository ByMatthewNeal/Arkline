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

    @AppStorage(Constants.UserDefaults.notifyBriefings)
    private var dailyBriefings = true

    @AppStorage(Constants.UserDefaults.notifySwingSignals)
    private var swingSignals = true

    @AppStorage(Constants.UserDefaults.notifyQPSChanges)
    private var qpsChanges = true

    @AppStorage(Constants.UserDefaults.notifySignalNew)
    private var signalNew = true

    @AppStorage(Constants.UserDefaults.notifySignalT1Hit)
    private var signalT1Hit = true

    @AppStorage(Constants.UserDefaults.notifySignalStopLoss)
    private var signalStopLoss = true

    @AppStorage(Constants.UserDefaults.notifySignalRunnerClose)
    private var signalRunnerClose = true

    @AppStorage(Constants.UserDefaults.notifySignalExpiry)
    private var signalExpiry = true

    @AppStorage(Constants.UserDefaults.notifySignalProximity)
    private var signalProximity = true

    @AppStorage(Constants.UserDefaults.notifyInsights)
    private var insights = true

    @AppStorage(Constants.UserDefaults.notifyEmail)
    private var emailNotifications = true

    @AppStorage(Constants.UserDefaults.notifyEmailMarketAlerts)
    private var emailMarketAlerts = true

    @AppStorage(Constants.UserDefaults.notifyEmailInsights)
    private var emailInsights = true

    @AppStorage(Constants.UserDefaults.notifyEmailDCAReminders)
    private var emailDCAReminders = true

    @AppStorage(Constants.UserDefaults.notifyEmailAccountUpdates)
    private var emailAccountUpdates = true

    var body: some View {
        ZStack {
            MeshGradientBackground()
            List {
                // MARK: - Daily Briefings
                Section {
                    Toggle(isOn: $dailyBriefings) {
                        NotificationRow(
                            icon: "sparkles",
                            iconColor: AppColors.accent,
                            title: "Daily Briefings",
                            description: "Morning Intel (10:15 AM ET) & Close & Context (5:00 PM ET)"
                        )
                    }
                    .onChange(of: dailyBriefings) { _, newValue in
                        Haptics.selection()
                        if newValue {
                            Task { await BriefingNotificationScheduler.scheduleAll() }
                        } else {
                            BriefingNotificationScheduler.cancelAll()
                        }
                    }
                } header: {
                    Text("Daily Briefings")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

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

                    Toggle(isOn: $swingSignals) {
                        NotificationRow(
                            icon: "scope",
                            iconColor: AppColors.success,
                            title: "Swing Trade Alerts",
                            description: "Master toggle for all signal notifications"
                        )
                    }
                    .onChange(of: swingSignals) { _, newValue in
                        Haptics.selection()
                        syncSignalPreferences()
                    }

                    Toggle(isOn: $qpsChanges) {
                        NotificationRow(
                            icon: "waveform.path.ecg",
                            iconColor: AppColors.accent,
                            title: "Positioning Changes",
                            description: "When daily signal changes (e.g. Bearish → Neutral)"
                        )
                    }
                    .onChange(of: qpsChanges) { _, _ in
                        Haptics.selection()
                    }
                } header: {
                    Text("Market Alerts")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // MARK: - Signal Alert Types
                if swingSignals {
                    Section {
                        Toggle(isOn: $signalNew) {
                            NotificationRow(
                                icon: "plus.circle.fill",
                                iconColor: AppColors.accent,
                                title: "New Signals",
                                description: "When a new trade signal is generated"
                            )
                        }
                        .onChange(of: signalNew) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }

                        Toggle(isOn: $signalT1Hit) {
                            NotificationRow(
                                icon: "target",
                                iconColor: AppColors.success,
                                title: "Target 1 Hit",
                                description: "When a signal reaches its first profit target"
                            )
                        }
                        .onChange(of: signalT1Hit) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }

                        Toggle(isOn: $signalStopLoss) {
                            NotificationRow(
                                icon: "xmark.octagon.fill",
                                iconColor: AppColors.error,
                                title: "Stop Loss Hit",
                                description: "When a signal hits its stop loss"
                            )
                        }
                        .onChange(of: signalStopLoss) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }

                        Toggle(isOn: $signalRunnerClose) {
                            NotificationRow(
                                icon: "flag.checkered",
                                iconColor: AppColors.warning,
                                title: "Runner Closed",
                                description: "When the trailing runner position closes"
                            )
                        }
                        .onChange(of: signalRunnerClose) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }

                        Toggle(isOn: $signalExpiry) {
                            NotificationRow(
                                icon: "clock.badge.xmark",
                                iconColor: AppColors.textSecondary,
                                title: "Signal Expired",
                                description: "When a signal expires without being triggered"
                            )
                        }
                        .onChange(of: signalExpiry) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }

                        Toggle(isOn: $signalProximity) {
                            NotificationRow(
                                icon: "location.circle.fill",
                                iconColor: AppColors.accent,
                                title: "Entry Zone Approaching",
                                description: "When price nears an active signal's entry zone"
                            )
                        }
                        .onChange(of: signalProximity) { _, _ in
                            Haptics.selection()
                            syncSignalPreferences()
                        }
                    } header: {
                        Text("Signal Alert Types")
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))
                }

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
                            description: "Master toggle for all email notifications"
                        )
                    }
                    .onChange(of: emailNotifications) { _, newValue in
                        Haptics.selection()
                    }

                    if emailNotifications {
                        Toggle(isOn: $emailMarketAlerts) {
                            NotificationRow(
                                icon: "chart.line.uptrend.xyaxis",
                                iconColor: AppColors.warning,
                                title: "Market Alerts",
                                description: "Significant market movements and macro events"
                            )
                        }
                        .onChange(of: emailMarketAlerts) { _, _ in Haptics.selection() }

                        Toggle(isOn: $emailInsights) {
                            NotificationRow(
                                icon: "megaphone",
                                iconColor: AppColors.accent,
                                title: "Insights & Broadcasts",
                                description: "New insights and broadcasts from the team"
                            )
                        }
                        .onChange(of: emailInsights) { _, _ in Haptics.selection() }

                        Toggle(isOn: $emailDCAReminders) {
                            NotificationRow(
                                icon: "calendar.badge.clock",
                                iconColor: AppColors.success,
                                title: "DCA Reminders",
                                description: "Scheduled purchase reminders"
                            )
                        }
                        .onChange(of: emailDCAReminders) { _, _ in Haptics.selection() }

                        Toggle(isOn: $emailAccountUpdates) {
                            NotificationRow(
                                icon: "person.crop.circle",
                                iconColor: AppColors.textSecondary,
                                title: "Account Updates",
                                description: "Security alerts and account changes"
                            )
                        }
                        .onChange(of: emailAccountUpdates) { _, _ in Haptics.selection() }
                    }
                } header: {
                    Text("Email")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Extra space so last row isn't hidden behind tab bar
                Section {} footer: {
                    Spacer().frame(height: 40)
                }
                .listRowBackground(Color.clear)
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

    private func syncSignalPreferences() {
        Task {
            guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }
            let prefs: [String: Bool] = [
                "signal_new": swingSignals && signalNew,
                "signal_t1_hit": swingSignals && signalT1Hit,
                "signal_stop_loss": swingSignals && signalStopLoss,
                "signal_runner_close": swingSignals && signalRunnerClose,
                "signal_expiry": swingSignals && signalExpiry,
                "signal_proximity": swingSignals && signalProximity,
            ]
            do {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(["notification_preferences": prefs])
                    .eq("id", value: userId.uuidString)
                    .execute()
            } catch {
                logWarning("Failed to sync notification preferences: \(error)", category: .network)
            }
        }
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
