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

    /// Stores the last notification tap result for cold-start deep linking.
    /// Views should check this on appear and clear it after handling.
    var pendingNotificationResult: (type: String, id: String)?

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

    /// Re-sync the locally cached device token to Supabase.
    /// Call this after authentication is confirmed to ensure the token is stored server-side.
    func syncDeviceTokenIfNeeded() async {
        guard let token = deviceToken else { return }
        await storeDeviceTokenInSupabase(token)
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
                .from("user_devices")
                .upsert([
                    "user_id": userId.uuidString,
                    "device_token": token,
                    "platform": "ios",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ], onConflict: "user_id,device_token")
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

    /// Send notification to specific audience.
    /// Tries the server-side edge function first; falls back to local notification on failure.
    func sendBroadcastNotification(for broadcast: Broadcast, audience: TargetAudience, eventType: String? = nil) async {
        guard SupabaseManager.shared.isConfigured else {
            await sendBroadcastNotification(for: broadcast)
            return
        }

        // Build request body matching the edge function schema
        var body: [String: Any] = [
            "broadcast_id": broadcast.id.uuidString,
            "title": eventType == "market_deck" ? "Weekly Market Update" : "New Insight",
            "body": broadcast.title
        ]

        if let eventType {
            body["event_type"] = eventType
        }

        switch audience {
        case .all:
            body["target_audience"] = ["type": "all"]
        case .premium:
            body["target_audience"] = ["type": "premium"]
        case .specific(let userIds):
            body["target_audience"] = [
                "type": "specific",
                "user_ids": userIds.map { $0.uuidString }
            ] as [String: Any]
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            let _: Data = try await SupabaseManager.shared.functions.invoke(
                "send-broadcast-notification",
                options: .init(body: jsonData)
            )
            logInfo("Server-side notification triggered for broadcast: \(broadcast.title)", category: .data)
        } catch {
            logWarning("Edge function notification failed, falling back to local: \(error)", category: .data)
            await sendBroadcastNotification(for: broadcast)
        }
    }

    // MARK: - Swing Signal Notifications

    /// Whether swing signal notifications are enabled
    var swingSignalNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.notifySwingSignals) as? Bool ?? true
    }

    /// Send a local notification for a strong swing trade signal
    func sendSwingSignalNotification(for signal: TradeSignal) async {
        guard swingSignalNotificationsEnabled else { return }
        guard isNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        let emoji = signal.signalType.isBuy ? "🎯" : "⚠️"
        content.title = "\(emoji) \(signal.asset) Trade Signal"
        content.body = "\(signal.signalType.displayName) detected at $\(formatNotifPrice(signal.entryZoneLow))–$\(formatNotifPrice(signal.entryZoneHigh)). R:R \(String(format: "%.1f", signal.riskRewardRatio))x"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "SWING_SIGNAL"
        content.userInfo = [
            "type": "swing_signal",
            "signal_id": signal.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: "swing_signal_\(signal.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logInfo("Swing signal notification sent for \(signal.asset) \(signal.signalType.displayName)", category: .data)
        } catch {
            logError("Failed to send swing signal notification: \(error)", category: .data)
        }
    }

    // MARK: - QPS Change Notifications

    /// Whether QPS change notifications are enabled
    var qpsChangeNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.notifyQPSChanges) as? Bool ?? true
    }

    /// Send a local notification for a daily positioning signal change
    func sendQPSChangeNotification(for signal: DailyPositioningSignal) async {
        guard qpsChangeNotificationsEnabled else { return }
        guard isNotificationsEnabled else { return }
        guard let change = signal.changeDescription else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(signal.asset) Signal Changed"
        content.body = "\(signal.asset): \(change)"
        content.sound = .default
        content.categoryIdentifier = "QPS_CHANGE"
        content.userInfo = [
            "type": "qps_change",
            "asset": signal.asset
        ]

        let request = UNNotificationRequest(
            identifier: "qps_\(signal.asset)_\(signal.signalDate.timeIntervalSince1970)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logInfo("QPS change notification sent for \(signal.asset): \(change)", category: .data)
        } catch {
            logError("Failed to send QPS notification: \(error)", category: .data)
        }
    }

    private func formatNotifPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        }
        return String(format: "%.2f", price)
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

        let briefingCategory = UNNotificationCategory(
            identifier: "BRIEFING",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let viewSignalAction = UNNotificationAction(
            identifier: "VIEW_SIGNAL",
            title: "View Signal",
            options: [.foreground]
        )

        let swingSignalCategory = UNNotificationCategory(
            identifier: "SWING_SIGNAL",
            actions: [viewSignalAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let qpsCategory = UNNotificationCategory(
            identifier: "QPS_CHANGE",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        let viewPortfolioAction = UNNotificationAction(
            identifier: "VIEW_PORTFOLIO",
            title: "View Portfolio",
            options: [.foreground]
        )

        let modelPortfolioCategory = UNNotificationCategory(
            identifier: "MODEL_PORTFOLIO",
            actions: [viewPortfolioAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let sentimentRegimeCategory = UNNotificationCategory(
            identifier: "SENTIMENT_REGIME_SHIFT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([broadcastCategory, briefingCategory, swingSignalCategory, qpsCategory, modelPortfolioCategory, sentimentRegimeCategory])
    }
}

// MARK: - Notification Handling Extension

extension BroadcastNotificationService {
    /// Handle notification response (user tapped notification)
    func handleNotificationResponse(_ response: UNNotificationResponse) -> (type: String, id: String)? {
        let userInfo = response.notification.request.content.userInfo

        guard let type = userInfo["type"] as? String else { return nil }

        var result: (type: String, id: String)?

        switch type {
        case "broadcast":
            if let broadcastId = userInfo["broadcast_id"] as? String {
                result = (type: "broadcast", id: broadcastId)
            }
        case "briefing":
            let slot = userInfo["slot"] as? String ?? "morning"
            result = (type: "briefing", id: slot)
        case "swing_signal":
            if let signalId = userInfo["signal_id"] as? String {
                result = (type: "swing_signal", id: signalId)
            }
        case "qps_change":
            let asset = userInfo["asset"] as? String ?? ""
            result = (type: "qps_change", id: asset)
        case "dca_reminder":
            let reminderId = userInfo["reminder_id"] as? String ?? ""
            result = (type: "dca_reminder", id: reminderId)
        case "model_portfolio":
            let strategy = userInfo["strategy"] as? String ?? ""
            result = (type: "model_portfolio", id: strategy)
        case "sentiment_regime":
            result = (type: "sentiment_regime", id: "")
        default:
            break
        }

        // Store for cold-start deep linking (views may not be mounted yet)
        if let result {
            pendingNotificationResult = result
        }

        return result
    }
}
