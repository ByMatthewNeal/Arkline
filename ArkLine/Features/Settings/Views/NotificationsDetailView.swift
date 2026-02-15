import SwiftUI

// MARK: - Notifications Detail View
struct NotificationsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var dcaReminders: Bool
    @State private var priceAlerts: Bool
    @State private var marketNews: Bool
    @State private var communityUpdates: Bool
    @State private var emailNotifications: Bool

    init() {
        let defaults = Foundation.UserDefaults.standard
        _dcaReminders = State(initialValue: defaults.object(forKey: Constants.UserDefaults.notifyDCAReminders) as? Bool ?? true)
        _priceAlerts = State(initialValue: defaults.object(forKey: Constants.UserDefaults.notifyPriceAlerts) as? Bool ?? true)
        _marketNews = State(initialValue: defaults.object(forKey: Constants.UserDefaults.notifyMarketNews) as? Bool ?? true)
        _communityUpdates = State(initialValue: defaults.object(forKey: Constants.UserDefaults.notifyCommunityUpdates) as? Bool ?? false)
        _emailNotifications = State(initialValue: defaults.object(forKey: Constants.UserDefaults.notifyEmail) as? Bool ?? true)
    }

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            List {
                Section {
                    Toggle(isOn: $dcaReminders) {
                        NotificationRow(
                            icon: "calendar.badge.clock",
                            iconColor: AppColors.accent,
                            title: "DCA Reminders",
                            description: "Get reminded about your scheduled purchases"
                        )
                    }
                    .onChange(of: dcaReminders) { _, newValue in
                        Foundation.UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.notifyDCAReminders)
                    }

                    Toggle(isOn: $priceAlerts) {
                        NotificationRow(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: AppColors.success,
                            title: "Price Alerts",
                            description: "Notifications when prices hit your targets"
                        )
                    }
                    .onChange(of: priceAlerts) { _, newValue in
                        Foundation.UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.notifyPriceAlerts)
                    }

                    Toggle(isOn: $marketNews) {
                        NotificationRow(
                            icon: "newspaper",
                            iconColor: AppColors.warning,
                            title: "Market News",
                            description: "Breaking news and market updates"
                        )
                    }
                    .onChange(of: marketNews) { _, newValue in
                        Foundation.UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.notifyMarketNews)
                    }

                    Toggle(isOn: $communityUpdates) {
                        NotificationRow(
                            icon: "person.3",
                            iconColor: AppColors.info,
                            title: "Community Updates",
                            description: "Posts and discussions from the community"
                        )
                    }
                    .onChange(of: communityUpdates) { _, newValue in
                        Foundation.UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.notifyCommunityUpdates)
                    }
                } header: {
                    Text("Push Notifications")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                Section {
                    Toggle(isOn: $emailNotifications) {
                        NotificationRow(
                            icon: "envelope",
                            iconColor: AppColors.accent,
                            title: "Email Notifications",
                            description: "Receive important updates via email"
                        )
                    }
                    .onChange(of: emailNotifications) { _, newValue in
                        Foundation.UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.notifyEmail)
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
