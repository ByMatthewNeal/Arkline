import Foundation
import SwiftUI
import UserNotifications

/// Manages detection and alerting of extreme moves in macro indicators
class ExtremeMoveAlertManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ExtremeMoveAlertManager()

    // MARK: - UserDefaults Keys

    private let alertHistoryKey = "arkline_extreme_move_history"
    private let lastAlertTimesKey = "arkline_extreme_move_last_alert_times"
    private let extremeAlertsEnabledKey = "arkline_extreme_alerts_enabled"
    private let significantAlertsEnabledKey = "arkline_significant_alerts_enabled"

    // MARK: - Configuration

    /// Cooldown period between alerts for the same indicator/direction (4 hours)
    private let cooldownPeriod: TimeInterval = 3600 * 4

    /// Maximum number of alerts to keep in history
    private let maxHistorySize = 50

    // MARK: - Published State

    /// Currently pending alerts to show
    @Published var pendingAlerts: [ExtremeMove] = []

    /// Whether to show the extreme move alert sheet
    @Published var showExtremeMoveAlert = false

    /// The current alert being displayed
    @Published var currentAlert: ExtremeMove?

    // MARK: - Settings

    /// Whether extreme move alerts (±3σ) are enabled
    var extremeAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: extremeAlertsEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: extremeAlertsEnabledKey) }
    }

    /// Whether significant move alerts (±2σ) are enabled
    var significantAlertsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: significantAlertsEnabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: significantAlertsEnabledKey) }
    }

    // MARK: - Initialization

    private init() {
        // Clean up old alerts on init
        cleanupOldAlerts()
    }

    // MARK: - Alert Detection

    /// Check macro z-score data for extreme moves and trigger alerts if needed
    /// - Parameter zScoreData: The z-score data to check
    func checkForExtremeMove(_ zScoreData: MacroZScoreData) {
        let severity: Severity
        let shouldAlert: Bool

        if zScoreData.isExtreme {
            severity = .extreme
            shouldAlert = extremeAlertsEnabled
        } else if zScoreData.isSignificant {
            severity = .significant
            shouldAlert = significantAlertsEnabled
        } else {
            return // No significant move
        }

        guard shouldAlert else { return }

        let direction: Direction = zScoreData.zScore.zScore > 0 ? .high : .low

        // Check cooldown
        guard !isInCooldown(indicator: zScoreData.indicator, direction: direction) else {
            logInfo("Skipping alert for \(zScoreData.indicator.rawValue) - in cooldown", category: .data)
            return
        }

        // Create the alert
        let move = ExtremeMove(
            id: UUID(),
            indicator: zScoreData.indicator,
            zScore: zScoreData.zScore.zScore,
            currentValue: zScoreData.currentValue,
            direction: direction,
            detectedAt: Date(),
            severity: severity,
            interpretation: zScoreData.interpretation,
            marketImplication: zScoreData.marketImplication
        )

        // Record this alert
        recordAlert(move)

        // Update cooldown
        updateCooldown(indicator: zScoreData.indicator, direction: direction)

        // Add to pending and show
        pendingAlerts.append(move)
        currentAlert = move
        showExtremeMoveAlert = true

        // Schedule push notification
        scheduleLocalNotification(for: move)

        logInfo("Extreme move alert triggered for \(move.indicator.rawValue): \(move.formattedZScore)", category: .data)
    }

    /// Check all z-score data for extreme moves
    /// - Parameter allZScores: Dictionary of all macro z-score data
    func checkAllForExtremeMoves(_ allZScores: [MacroIndicatorType: MacroZScoreData]) {
        for (_, zScoreData) in allZScores {
            checkForExtremeMove(zScoreData)
        }
    }

    // MARK: - Alert History

    /// Get the history of extreme move alerts
    /// - Returns: Array of past extreme moves, newest first
    func getAlertHistory() -> [ExtremeMove] {
        guard let data = UserDefaults.standard.data(forKey: alertHistoryKey),
              let history = try? JSONDecoder().decode([ExtremeMove].self, from: data) else {
            return []
        }
        return history.sorted { $0.detectedAt > $1.detectedAt }
    }

    /// Clear all alert history
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: alertHistoryKey)
        pendingAlerts.removeAll()
    }

    /// Dismiss the current alert
    func dismissAlert() {
        showExtremeMoveAlert = false
        currentAlert = nil
        if !pendingAlerts.isEmpty {
            pendingAlerts.removeFirst()
        }
    }

    // MARK: - Push Notifications

    /// Schedule a local push notification for an extreme move
    func scheduleLocalNotification(for move: ExtremeMove) {
        let content = UNMutableNotificationContent()
        content.title = move.notificationTitle
        content.body = move.notificationBody
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "EXTREME_MOVE"

        // Add user info for deep linking
        content.userInfo = [
            "type": "extreme_move",
            "indicator": move.indicator.rawValue,
            "direction": move.direction.rawValue
        ]

        // Deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "extreme_move_\(move.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logError("Failed to schedule extreme move notification: \(error)", category: .data)
            } else {
                logInfo("Extreme move notification scheduled", category: .data)
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

    // MARK: - Private Helpers

    private func isInCooldown(indicator: MacroIndicatorType, direction: Direction) -> Bool {
        let key = "\(indicator.rawValue)_\(direction.rawValue)"
        guard let lastAlertTimes = UserDefaults.standard.dictionary(forKey: lastAlertTimesKey),
              let lastTime = lastAlertTimes[key] as? TimeInterval else {
            return false
        }

        let lastDate = Date(timeIntervalSince1970: lastTime)
        return Date().timeIntervalSince(lastDate) < cooldownPeriod
    }

    private func updateCooldown(indicator: MacroIndicatorType, direction: Direction) {
        let key = "\(indicator.rawValue)_\(direction.rawValue)"
        var lastAlertTimes = UserDefaults.standard.dictionary(forKey: lastAlertTimesKey) ?? [:]
        lastAlertTimes[key] = Date().timeIntervalSince1970
        UserDefaults.standard.set(lastAlertTimes, forKey: lastAlertTimesKey)
    }

    private func recordAlert(_ move: ExtremeMove) {
        var history = getAlertHistory()
        history.insert(move, at: 0)

        // Trim to max size
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: alertHistoryKey)
        }
    }

    private func cleanupOldAlerts() {
        var history = getAlertHistory()
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days
        history = history.filter { $0.detectedAt > cutoff }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: alertHistoryKey)
        }
    }
}

// MARK: - Extreme Move Model

/// Represents a detected extreme move in a macro indicator
struct ExtremeMove: Codable, Identifiable, Equatable {
    let id: UUID
    let indicator: MacroIndicatorType
    let zScore: Double
    let currentValue: Double
    let direction: Direction
    let detectedAt: Date
    let severity: Severity
    let interpretation: String
    let marketImplication: MarketImplication

    /// Formatted z-score string
    var formattedZScore: String {
        String(format: "%+.1fσ", zScore)
    }

    /// Title for notifications
    var notificationTitle: String {
        let severityText = severity == .extreme ? "Extreme" : "Significant"
        return "\(severityText) Move: \(indicator.displayName) \(formattedZScore)"
    }

    /// Body for notifications
    var notificationBody: String {
        let valueFormatted: String
        switch indicator {
        case .vix:
            valueFormatted = String(format: "%.1f", currentValue)
        case .dxy:
            valueFormatted = String(format: "%.2f", currentValue)
        case .m2:
            valueFormatted = formatLargeNumber(currentValue)
        }

        let rarityText: String
        if let rarity = StatisticsCalculator.ZScoreResult(mean: 0, standardDeviation: 1, zScore: zScore).rarity {
            rarityText = " (1 in \(rarity) occurrence)"
        } else {
            rarityText = ""
        }

        return "\(indicator.displayName) at \(valueFormatted)\(rarityText). \(marketImplication.description)."
    }

    /// Time ago string
    var timeAgo: String {
        let interval = Date().timeIntervalSince(detectedAt)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - Supporting Types

/// Direction of an extreme move
enum Direction: String, Codable {
    case high
    case low

    var description: String {
        switch self {
        case .high: return "High"
        case .low: return "Low"
        }
    }

    var iconName: String {
        switch self {
        case .high: return "arrow.up.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }
}

/// Severity of the move
enum Severity: String, Codable {
    case significant // ±2σ
    case extreme     // ±3σ

    var description: String {
        switch self {
        case .significant: return "Significant (±2σ)"
        case .extreme: return "Extreme (±3σ)"
        }
    }

    var threshold: Double {
        switch self {
        case .significant: return 2.0
        case .extreme: return 3.0
        }
    }

    var color: Color {
        switch self {
        case .significant: return AppColors.warning
        case .extreme: return AppColors.error
        }
    }
}
