import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Broadcast Notification Service

/// Manages push notifications for broadcasts.
/// Handles permission requests, device token registration, and notification delivery.
@MainActor
class BroadcastNotificationService: ObservableObject {
    // MARK: - Singleton

    static let shared = BroadcastNotificationService()

    // MARK: - Published State

    @Published var isNotificationsEnabled = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - UserDefaults Keys

    private let deviceTokenKey = "arkline_device_token"
    private let broadcastNotificationsEnabledKey = "arkline_broadcast_notifications_enabled"

    // MARK: - Computed Properties

    /// Whether broadcast notifications are enabled in settings
    var broadcastNotificationsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: broadcastNotificationsEnabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: broadcastNotificationsEnabledKey)
            objectWillChange.send()
        }
    }

    /// The stored device token (if available)
    var deviceToken: String? {
        UserDefaults.standard.string(forKey: deviceTokenKey)
    }

    // MARK: - Initialization

    private init() {
        Task {
            await checkNotificationStatus()
        }
    }

    // MARK: - Permission Management

    /// Request notification permissions from the user
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            await MainActor.run {
                isNotificationsEnabled = granted
            }

            if granted {
                await registerForRemoteNotifications()
                logInfo("Broadcast notification permissions granted", category: .data)
            } else {
                logInfo("Broadcast notification permissions denied", category: .data)
            }

            await checkNotificationStatus()
            return granted
        } catch {
            logError("Failed to request notification permissions: \(error)", category: .data)
            return false
        }
    }

    /// Check current notification authorization status
    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        await MainActor.run {
            notificationStatus = settings.authorizationStatus
            isNotificationsEnabled = settings.authorizationStatus == .authorized
        }
    }

    /// Register for remote push notifications
    func registerForRemoteNotifications() async {
        #if canImport(UIKit) && !targetEnvironment(simulator)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
    }

    // MARK: - Device Token Management

    /// Handle device token received from APNs
    func handleDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: deviceTokenKey)

        logInfo("Device token registered: \(tokenString.prefix(20))...", category: .data)

        // Store in Supabase for server-side push
        Task {
            await storeDeviceTokenInSupabase(tokenString)
        }
    }

    /// Handle device token registration failure
    func handleDeviceTokenError(_ error: Error) {
        logError("Failed to register for remote notifications: \(error)", category: .data)
    }

    /// Store device token in Supabase for server-side push notifications
    private func storeDeviceTokenInSupabase(_ token: String) async {
        // Get current user ID
        guard let userId = try? await SupabaseManager.shared.client.auth.session.user.id else {
            logWarning("Cannot store device token - user not authenticated", category: .data)
            return
        }

        do {
            // Upsert device token (insert or update if exists)
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .upsert([
                    "user_id": userId.uuidString,
                    "token": token,
                    "platform": "ios",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id,platform")
                .execute()

            logInfo("Device token stored in Supabase", category: .data)
        } catch {
            // Table might not exist yet - this is fine for local notification mode
            logWarning("Could not store device token in Supabase: \(error)", category: .data)
        }
    }

    // MARK: - Send Broadcast Notification

    /// Send a local notification for a published broadcast
    /// In production, this would trigger a server-side push instead
    func sendBroadcastNotification(for broadcast: Broadcast) async {
        guard broadcastNotificationsEnabled else {
            logInfo("Broadcast notifications disabled - skipping", category: .data)
            return
        }

        guard isNotificationsEnabled else {
            logInfo("System notifications not enabled - skipping", category: .data)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "New Insight"
        content.subtitle = broadcast.title
        content.body = broadcast.contentPreview
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "BROADCAST"

        // Add user info for deep linking
        content.userInfo = [
            "type": "broadcast",
            "broadcast_id": broadcast.id.uuidString
        ]

        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "broadcast_\(broadcast.id.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logInfo("Broadcast notification scheduled for: \(broadcast.title)", category: .data)
        } catch {
            logError("Failed to schedule broadcast notification: \(error)", category: .data)
        }
    }

    /// Send notification to specific audience
    /// For local notifications, this sends to the current device only
    /// For server-side push, this would filter by user IDs
    func sendBroadcastNotification(for broadcast: Broadcast, audience: TargetAudience) async {
        // For local notifications, we just send to the current device
        // Server-side push would handle audience filtering
        await sendBroadcastNotification(for: broadcast)
    }

    // MARK: - Badge Management

    /// Clear the notification badge
    func clearBadge() {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    /// Set the notification badge count
    func setBadge(_ count: Int) {
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    // MARK: - Notification Categories

    /// Register notification categories for actions
    func registerNotificationCategories() {
        // Broadcast notification category with actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_BROADCAST",
            title: "View",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_BROADCAST",
            title: "Dismiss",
            options: []
        )

        let broadcastCategory = UNNotificationCategory(
            identifier: "BROADCAST",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([broadcastCategory])
    }
}

// MARK: - Notification Handling Extension

extension BroadcastNotificationService {
    /// Handle notification response (user tapped notification)
    func handleNotificationResponse(_ response: UNNotificationResponse) -> (type: String, id: String)? {
        let userInfo = response.notification.request.content.userInfo

        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "broadcast":
            if let broadcastId = userInfo["broadcast_id"] as? String {
                return (type: "broadcast", id: broadcastId)
            }
        default:
            break
        }

        return nil
    }
}
