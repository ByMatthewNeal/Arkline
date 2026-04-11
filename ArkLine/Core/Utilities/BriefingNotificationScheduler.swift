import UserNotifications
import Foundation

/// Schedules repeating daily briefing notifications in US Eastern time.
/// - Mon–Fri: Morning Intel (10:15 AM) + Close & Context (5:00 PM)
/// - Sat–Sun: Weekend Update (12:00 PM)
/// Pinned to ET so notifications align with US market hours regardless of user's timezone.
/// Uses `UNCalendarNotificationTrigger(repeats: true)` — no APNs needed.
enum BriefingNotificationScheduler {

    /// US Eastern timezone (handles EST/EDT automatically)
    private static let eastern = TimeZone(identifier: "America/New_York") ?? .current

    // MARK: - Slots

    enum Slot: String, CaseIterable {
        case morning
        case evening
        case weekend

        var identifier: String { "briefing_\(rawValue)" }

        var hour: Int {
            switch self {
            case .morning: return 10
            case .evening: return 17
            case .weekend: return 12
            }
        }

        var minute: Int {
            switch self {
            case .morning: return 15
            case .evening: return 0
            case .weekend: return 0
            }
        }

        var title: String {
            switch self {
            case .morning: return "Morning Intel"
            case .evening: return "Close & Context"
            case .weekend: return "Weekend Update"
            }
        }

        var body: String {
            switch self {
            case .morning: return "Your morning market briefing is ready."
            case .evening: return "Markets are closing. Here's your evening recap."
            case .weekend: return "Your weekend market update is ready."
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

    /// Schedule weekday and weekend briefing notifications.
    static func scheduleAll() async {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        cancelAll()

        // Mon–Fri (weekday 2=Mon through 6=Fri): morning + evening
        for slot: Slot in [.morning, .evening] {
            for weekday in 2...6 {
                await scheduleNotification(slot: slot, weekday: weekday, center: center)
            }
            logInfo("Scheduled \(slot.identifier) at \(slot.hour):\(String(format: "%02d", slot.minute)) ET (Mon-Fri)", category: .data)
        }

        // Sat–Sun (weekday 1=Sun, 7=Sat): weekend update at noon
        for weekday in [1, 7] {
            await scheduleNotification(slot: .weekend, weekday: weekday, center: center)
        }
        logInfo("Scheduled weekend update at 12:00 ET (Sat-Sun)", category: .data)
    }

    private static func scheduleNotification(slot: Slot, weekday: Int, center: UNUserNotificationCenter) async {
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
        dateComponents.weekday = weekday

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let identifier = "\(slot.identifier)_wd\(weekday)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            logError("Failed to schedule briefing notification \(identifier): \(error)", category: .data)
        }
    }

    /// Remove all pending briefing notifications.
    static func cancelAll() {
        var identifiers: [String] = []
        // Old format (briefing_morning, briefing_evening)
        for slot in Slot.allCases {
            identifiers.append(slot.identifier)
        }
        // New weekday format (briefing_morning_wd2, briefing_weekend_wd7, etc.)
        for slot in Slot.allCases {
            for weekday in 1...7 {
                identifiers.append("\(slot.identifier)_wd\(weekday)")
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        logInfo("Cancelled all briefing notifications", category: .data)
    }
}
