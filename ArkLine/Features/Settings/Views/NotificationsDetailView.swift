import SwiftUI

// MARK: - Notifications Detail View
struct NotificationsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var dcaReminders = true
    @State private var priceAlerts = true
    @State private var marketNews = true
    @State private var communityUpdates = false
    @State private var emailNotifications = true

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

                Toggle(isOn: $priceAlerts) {
                    NotificationRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppColors.success,
                        title: "Price Alerts",
                        description: "Notifications when prices hit your targets"
                    )
                }

                Toggle(isOn: $marketNews) {
                    NotificationRow(
                        icon: "newspaper",
                        iconColor: AppColors.warning,
                        title: "Market News",
                        description: "Breaking news and market updates"
                    )
                }

                Toggle(isOn: $communityUpdates) {
                    NotificationRow(
                        icon: "person.3",
                        iconColor: AppColors.info,
                        title: "Community Updates",
                        description: "Posts and discussions from the community"
                    )
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
