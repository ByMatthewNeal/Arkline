import SwiftUI
import UserNotifications

// MARK: - Market Regime
/// Synthesized market conditions based on macro indicators
enum MarketRegime: String, Codable {
    case riskOn = "RISK-ON"
    case riskOff = "RISK-OFF"
    case mixed = "MIXED"
    case noData = "NO DATA"

    var description: String {
        switch self {
        case .riskOn:
            return "Favorable conditions for risk assets"
        case .riskOff:
            return "Defensive positioning recommended"
        case .mixed:
            return "Conflicting signals across indicators"
        case .noData:
            return "Awaiting market data"
        }
    }

    var color: Color {
        switch self {
        case .riskOn: return AppColors.success
        case .riskOff: return AppColors.error
        case .mixed: return AppColors.warning
        case .noData: return AppColors.textSecondary
        }
    }

    var notificationTitle: String {
        switch self {
        case .riskOn: return "Market Regime: RISK-ON"
        case .riskOff: return "Market Regime: RISK-OFF"
        case .mixed: return "Market Regime: MIXED"
        case .noData: return "Market Data Unavailable"
        }
    }

    var notificationBody: String {
        switch self {
        case .riskOn:
            return "Macro conditions have shifted bullish. Low volatility and expanding liquidity favor risk assets."
        case .riskOff:
            return "Macro conditions have shifted bearish. Elevated VIX and dollar strength may pressure crypto."
        case .mixed:
            return "Macro signals are now conflicting. Consider reducing position sizes until clarity emerges."
        case .noData:
            return "Unable to determine market conditions."
        }
    }
}

// MARK: - Correlation Strength
/// Represents how strongly an indicator correlates with crypto
enum CorrelationStrength: Int, CaseIterable {
    case weak = 1
    case moderate = 2
    case strong = 3
    case veryStrong = 4

    var label: String {
        switch self {
        case .weak: return "Weak"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        case .veryStrong: return "Very Strong"
        }
    }

    var description: String {
        switch self {
        case .weak: return "Historical correlation currently weak"
        case .moderate: return "Moderate historical correlation"
        case .strong: return "Strong historical correlation"
        case .veryStrong: return "Very strong correlation observed"
        }
    }
}

// MARK: - Regime Change Manager
/// Manages regime state persistence and change detection
class RegimeChangeManager: ObservableObject {
    static let shared = RegimeChangeManager()

    private let regimeKey = "arkline_last_market_regime"
    private let lastChangeKey = "arkline_last_regime_change"
    private let notificationsEnabledKey = "arkline_regime_notifications_enabled"

    @Published var showRegimeChangeAlert = false
    @Published var regimeChangeInfo: (from: MarketRegime, to: MarketRegime)?

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: notificationsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
    }

    var lastKnownRegime: MarketRegime? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: regimeKey) else { return nil }
            return MarketRegime(rawValue: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: regimeKey)
        }
    }

    var lastRegimeChange: Date? {
        get { UserDefaults.standard.object(forKey: lastChangeKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastChangeKey) }
    }

    private init() {
        // Default to notifications enabled
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            notificationsEnabled = true
        }
    }

    /// Check if regime has changed and handle accordingly
    func checkRegimeChange(newRegime: MarketRegime) {
        // Skip if no data
        guard newRegime != .noData else { return }

        // Get previous regime
        let previousRegime = lastKnownRegime

        // Check if this is a meaningful change
        if let previous = previousRegime, previous != newRegime {
            // Regime has changed
            regimeChangeInfo = (from: previous, to: newRegime)

            // Update stored regime
            lastKnownRegime = newRegime
            lastRegimeChange = Date()

            // Trigger notifications if enabled
            if notificationsEnabled {
                showRegimeChangeAlert = true
                scheduleLocalNotification(for: newRegime, from: previous)
            }

            logInfo("Market regime changed from \(previous.rawValue) to \(newRegime.rawValue)", category: .data)
        } else if previousRegime == nil {
            // First time seeing a regime, just store it
            lastKnownRegime = newRegime
            lastRegimeChange = Date()
        }
    }

    /// Schedule a local push notification for regime change
    private func scheduleLocalNotification(for newRegime: MarketRegime, from oldRegime: MarketRegime) {
        let content = UNMutableNotificationContent()
        content.title = newRegime.notificationTitle
        content.body = newRegime.notificationBody
        content.sound = .default
        content.badge = 1

        // Add category for actionable notifications
        content.categoryIdentifier = "REGIME_CHANGE"

        // Deliver immediately (with slight delay for system processing)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "regime_change_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logError("Failed to schedule regime change notification: \(error)", category: .data)
            } else {
                logInfo("Regime change notification scheduled", category: .data)
            }
        }
    }

    /// Request notification permissions
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                logInfo("Notification permissions granted", category: .data)
            } else if let error = error {
                logError("Notification permission error: \(error)", category: .data)
            }
        }
    }

    /// Clear the alert state
    func dismissAlert() {
        showRegimeChangeAlert = false
        regimeChangeInfo = nil
    }
}
