import SwiftUI

// MARK: - Notifications Sheet
struct NotificationsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    // TODO: Replace with real notifications from a NotificationService
    @State private var notifications: [AppNotification] = []

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .background(sheetBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(textPrimary.opacity(0.05))
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(textPrimary.opacity(0.3))
            }

            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("You're all caught up")
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notificationsList: some View {
        ScrollView {
            VStack(spacing: 16) {
                let unreadNotifications = notifications.filter { !$0.isRead }
                if !unreadNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        ForEach(unreadNotifications) { notification in
                            NotificationRow(notification: notification)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                let readNotifications = notifications.filter { $0.isRead }
                if !readNotifications.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Earlier")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        ForEach(readNotifications) { notification in
                            NotificationRow(notification: notification)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - App Notification Model
struct AppNotification: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: Date
    let isRead: Bool

    var timeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: time, relativeTo: Date())
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: AppNotification
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

                    Text(notification.timeFormatted)
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
