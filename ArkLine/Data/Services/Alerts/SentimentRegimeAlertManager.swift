import Foundation
import UserNotifications

// MARK: - Sentiment Regime Alert Manager
/// Detects and alerts when the sentiment regime quadrant changes
/// (e.g., Apathy → FOMO, Complacency → Panic).
@MainActor
class SentimentRegimeAlertManager: ObservableObject {
    static let shared = SentimentRegimeAlertManager()

    private let regimeKey = "arkline_last_sentiment_regime"
    private let lastChangeKey = "arkline_last_sentiment_regime_change"
    private let lastNotificationKey = "arkline_last_sentiment_notification"
    private let notificationsEnabledKey = "arkline_sentiment_regime_notifications_enabled"

    /// Minimum time between sentiment shift notifications (6 hours).
    /// Prevents flip-flop noise when sentiment oscillates near a boundary.
    private let notificationCooldown: TimeInterval = 3600 * 6

    @Published var showRegimeShiftAlert = false
    @Published var regimeShiftInfo: (from: SentimentRegime, to: SentimentRegime)?

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: notificationsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
    }

    var lastKnownRegime: SentimentRegime? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: regimeKey) else { return nil }
            return SentimentRegime(rawValue: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: regimeKey)
        }
    }

    var lastRegimeChange: Date? {
        get { UserDefaults.standard.object(forKey: lastChangeKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastChangeKey) }
    }

    private var lastNotificationDate: Date? {
        get { UserDefaults.standard.object(forKey: lastNotificationKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastNotificationKey) }
    }

    private init() {
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            notificationsEnabled = true
        }
    }

    /// Check if the sentiment regime quadrant has changed
    func checkRegimeShift(newRegime: SentimentRegime) {
        let previousRegime = lastKnownRegime

        if let previous = previousRegime, previous != newRegime {
            // Always update the stored regime
            lastKnownRegime = newRegime
            lastRegimeChange = Date()

            // Only notify if outside cooldown window
            let inCooldown: Bool
            if let lastNotif = lastNotificationDate {
                inCooldown = Date().timeIntervalSince(lastNotif) < notificationCooldown
            } else {
                inCooldown = false
            }

            if notificationsEnabled && !inCooldown {
                regimeShiftInfo = (from: previous, to: newRegime)
                showRegimeShiftAlert = true
                lastNotificationDate = Date()
                scheduleLocalNotification(from: previous, to: newRegime)
            } else if inCooldown {
                logInfo("Sentiment shifted to \(newRegime.rawValue) — notification suppressed (cooldown)", category: .data)
            }

            logInfo("Sentiment regime shifted from \(previous.rawValue) to \(newRegime.rawValue)", category: .data)
        } else if previousRegime == nil {
            lastKnownRegime = newRegime
            lastRegimeChange = Date()
        }
    }

    private func scheduleLocalNotification(from oldRegime: SentimentRegime, to newRegime: SentimentRegime) {
        let content = UNMutableNotificationContent()
        content.title = "Sentiment Shift: \(newRegime.rawValue)"
        content.body = notificationBody(from: oldRegime, to: newRegime)
        content.sound = .default
        content.categoryIdentifier = "SENTIMENT_REGIME_SHIFT"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sentiment_regime_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logError("Failed to schedule sentiment regime notification: \(error)", category: .data)
            }
        }
    }

    private func notificationBody(from oldRegime: SentimentRegime, to newRegime: SentimentRegime) -> String {
        switch newRegime {
        case .panic:
            return "Market shifted to Panic — high fear with heavy activity. Historically near capitulation events."
        case .fomo:
            return "Market shifted to FOMO — greedy sentiment with surging activity. Historically near local tops."
        case .apathy:
            return "Market shifted to Apathy — low interest and fearful. Often a bottoming signal."
        case .complacency:
            return "Market shifted to Complacency — quiet confidence on thin volume. Vulnerable to sudden moves."
        }
    }

    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                logInfo("Sentiment regime notification permissions granted", category: .data)
            } else if let error = error {
                logError("Sentiment regime notification permission error: \(error)", category: .data)
            }
        }
    }

    func dismissAlert() {
        showRegimeShiftAlert = false
        regimeShiftInfo = nil
    }
}
