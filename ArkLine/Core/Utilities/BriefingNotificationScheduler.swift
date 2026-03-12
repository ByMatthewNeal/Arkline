import UserNotifications
import Foundation

/// Schedules repeating daily briefing notifications (morning + evening) in US Eastern time.
/// Pinned to ET so notifications align with US market hours regardless of user's timezone.
/// Uses `UNCalendarNotificationTrigger(repeats: true)` — no APNs needed.
enum BriefingNotificationScheduler {

    /// US Eastern timezone (handles EST/EDT automatically)
    private static let eastern = TimeZone(identifier: "America/New_York") ?? .current

    // MARK: - Slots

    enum Slot: String, CaseIterable {
        case morning
        case evening

        var identifier: String { "briefing_\(rawValue)" }

        /// Hour in US Eastern time
        var hour: Int {
            switch self {
            case .morning: return 10
            case .evening: return 17
            }
        }

        var minute: Int {
            switch self {
            case .morning: return 15
            case .evening: return 0
            }
        }

        var title: String {
            switch self {
            case .morning: return "Morning Intel"
            case .evening: return "Close & Context"
            }
        }

        var body: String {
            switch self {
            case .morning: return "Your morning market briefing is ready."
            case .evening: return "Markets are closing. Here's your evening recap."
            }
        }
    }

    // MARK: - Public API

    /// Whether the user has briefing notifications enabled (defaults to true).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.notifyBriefings) as? Bool ?? true
    }

    /// Idempotent sync: schedule or cancel based on current preference.
    /// Call on every app launch.
    static func sync() async {
        if isEnabled {
            await scheduleAll()
        } else {
            cancelAll()
        }
    }

    /// Schedule both morning and evening repeating triggers.
    static func scheduleAll() async {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        // Remove stale briefing notifications before re-adding
        cancelAll()

        for slot in Slot.allCases {
            let content = UNMutableNotificationContent()
            content.title = slot.title
            content.body = slot.body
            content.sound = .default
            content.categoryIdentifier = "BRIEFING"
            content.userInfo = [
                "type": "briefing",
                "slot": slot.rawValue
            ]

            var dateComponents = DateComponents()
            dateComponents.timeZone = eastern
            dateComponents.hour = slot.hour
            dateComponents.minute = slot.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: slot.identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                logInfo("Scheduled briefing notification: \(slot.identifier) at \(slot.hour):\(String(format: "%02d", slot.minute))", category: .data)
            } catch {
                logError("Failed to schedule briefing notification \(slot.identifier): \(error)", category: .data)
            }
        }
    }

    /// Remove all pending briefing notifications.
    static func cancelAll() {
        let identifiers = Slot.allCases.map(\.identifier)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        logInfo("Cancelled all briefing notifications", category: .data)
    }
}
