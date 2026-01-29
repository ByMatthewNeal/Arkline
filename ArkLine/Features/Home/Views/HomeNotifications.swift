import SwiftUI

// MARK: - Notifications Sheet
struct NotificationsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    // Mock notifications data
    private let mockNotifications: [MockNotification] = [
        MockNotification(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: AppColors.success,
            title: "BTC up 5.2% today",
            subtitle: "Bitcoin is showing strong momentum",
            time: "2m ago",
            isRead: false
        ),
        MockNotification(
            icon: "exclamationmark.triangle.fill",
            iconColor: AppColors.warning,
            title: "High volatility alert",
            subtitle: "Market volatility index above 70",
            time: "15m ago",
            isRead: false
        ),
        MockNotification(
            icon: "bell.badge.fill",
            iconColor: AppColors.accent,
            title: "DCA reminder",
            subtitle: "Weekly Bitcoin purchase scheduled",
            time: "1h ago",
            isRead: true
        ),
        MockNotification(
            icon: "calendar.badge.exclamationmark",
            iconColor: AppColors.error,
            title: "FOMC meeting tomorrow",
            subtitle: "High impact event at 2:00 PM EST",
            time: "3h ago",
            isRead: true
        ),
        MockNotification(
            icon: "arrow.up.circle.fill",
            iconColor: AppColors.success,
            title: "Fear & Greed at 72",
            subtitle: "Market sentiment shifted to Greed",
            time: "5h ago",
            isRead: true
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Unread section
                    let unreadNotifications = mockNotifications.filter { !$0.isRead }
                    if !unreadNotifications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, 4)

                            ForEach(unreadNotifications) { notification in
                                HomeNotificationRow(notification: notification)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Read section
                    let readNotifications = mockNotifications.filter { $0.isRead }
                    if !readNotifications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Earlier")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, 4)

                            ForEach(readNotifications) { notification in
                                HomeNotificationRow(notification: notification)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Mark all as read
                    }) {
                        Text("Clear All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Mock Notification Model
struct MockNotification: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: String
    let isRead: Bool
}

// MARK: - Home Notification Row
struct HomeNotificationRow: View {
    let notification: MockNotification
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: notification.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(notification.iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Text(notification.time)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.4))
                }

                Text(notification.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .lineLimit(1)
            }

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notification.isRead ? Color.clear : AppColors.accent.opacity(0.2), lineWidth: 1)
        )
    }
}
