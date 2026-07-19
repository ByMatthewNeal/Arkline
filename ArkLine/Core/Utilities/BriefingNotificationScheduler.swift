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

// MARK: - Daily Digest Scheduler
//
// A single, once-daily LOCAL notification at a time the user picks (default
// 5:00 PM local). It surfaces the latest cached briefing headline plus a count
// of unread insights, so people who missed the real-time pushes get one clean
// catch-up nudge. Distinct from the server-side briefing/insight pushes.
//
// Local design notes: the notification repeats daily via a calendar trigger, and
// its CONTENT is re-armed on every app foreground/background from the latest
// persisted briefing + current unread count, so it stays as fresh as the last
// time the app was used. (A server-side variant could personalize per-user and
// suppress when fully caught up — a future upgrade.)
//
// Lives in this file rather than its own so it's always in the compiled target
// without an XcodeGen regen.
enum DailyDigestScheduler {

    static let identifier = "daily_digest"

    private static let defaultHour = 17   // 5 PM local
    private static let defaultMinute = 0

    // MARK: - Preferences

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.notifyDailyDigest) as? Bool ?? true
    }

    static var hour: Int {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.dailyDigestHour) as? Int ?? defaultHour
    }

    static var minute: Int {
        UserDefaults.standard.object(forKey: Constants.UserDefaults.dailyDigestMinute) as? Int ?? defaultMinute
    }

    // MARK: - Public API

    /// Re-arm (or cancel) the digest with the freshest known content. Safe to call
    /// often — on launch and on every foreground/background transition.
    /// - Parameter unreadInsights: current unread count from AppState.
    static func rearm(unreadInsights: Int) async {
        guard isEnabled else {
            cancel()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            // No permission yet — nothing to schedule. It'll arm once granted.
            return
        }

        // Suppression: if the user is fully caught up right now — no unread
        // insights AND they've already read the latest briefing — don't schedule.
        // We re-evaluate on every foreground/background, so the moment a backlog
        // appears the digest arms again, and the moment they catch up it's pulled.
        if isCaughtUp(unreadInsights: unreadInsights) {
            cancel()
            logInfo("Daily digest suppressed — user is caught up", category: .data)
            return
        }

        // Replace any existing digest so content/time updates cleanly.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Your Daily Market Digest"
        content.body = buildBody(unreadInsights: unreadInsights)
        content.sound = .default
        content.categoryIdentifier = "BRIEFING"
        content.userInfo = ["type": "daily_digest"]

        // No timeZone set → fires at the user's LOCAL wall-clock time.
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            logInfo("Armed daily digest at \(hour):\(String(format: "%02d", minute)) local", category: .data)
        } catch {
            logError("Failed to arm daily digest: \(error)", category: .data)
        }
    }

    /// Remove the pending digest notification.
    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Caught-up detection

    /// The user is "caught up" when there are no unread insights AND they've
    /// already read the latest cached briefing. Both signals live on-device:
    /// unread count comes from AppState (backed by broadcast_reads), and the
    /// briefing read-key is written when the briefing is expanded on Home
    /// (`lastReadBriefingKey`, synced across devices via preferences sync).
    static func isCaughtUp(unreadInsights: Int) -> Bool {
        guard unreadInsights <= 0 else { return false }

        // No briefing cached yet → nothing to be behind on.
        guard let briefing = MarketSummaryService.shared.loadPersistedBriefing() else {
            return true
        }
        let latestKey = "\(briefing.summaryDate)_\(briefing.slot)"
        let readKey = UserDefaults.standard.string(forKey: Constants.UserDefaults.lastReadBriefingKey) ?? ""
        return readKey == latestKey
    }

    // MARK: - Content

    /// Compose the notification body from the latest cached briefing + unread count.
    private static func buildBody(unreadInsights: Int) -> String {
        let tldr = latestBriefingTLDR()
        var parts: [String] = []

        if let tldr, !tldr.isEmpty {
            parts.append(tldr)
        } else {
            parts.append("Today's market briefing is ready.")
        }

        if unreadInsights > 0 {
            parts.append("\(unreadInsights) new insight\(unreadInsights == 1 ? "" : "s") waiting")
        }

        return parts.joined(separator: " · ")
    }

    /// Extract a short TLDR snippet from the persisted briefing markdown.
    private static func latestBriefingTLDR() -> String? {
        guard let summary = MarketSummaryService.shared.loadPersistedBriefing()?.summary else { return nil }

        // The briefing is markdown with "## TLDR" then prose until the next "##".
        let lines = summary.components(separatedBy: "\n")
        var capturing = false
        var collected: [String] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("##") {
                if capturing { break }               // reached the next section
                capturing = line.lowercased().contains("tldr")
                continue
            }
            if capturing, !line.isEmpty { collected.append(line) }
        }

        let text = collected.joined(separator: " ")
        guard !text.isEmpty else { return nil }

        // Trim any leading "Risk-On:"/"Risk-Off:" label into the sentence, then cap
        // length so the notification stays a glanceable headline.
        return snippet(from: text, maxLength: 150)
    }

    /// First sentence (or a clean truncation) up to `maxLength` characters.
    private static func snippet(from text: String, maxLength: Int) -> String {
        if let end = text.firstIndex(where: { $0 == "." }) {
            let sentence = String(text[..<end]).trimmingCharacters(in: .whitespaces)
            if sentence.count <= maxLength, sentence.count > 20 {
                return sentence + "."
            }
        }
        if text.count <= maxLength { return text }
        let idx = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<idx]).trimmingCharacters(in: .whitespaces) + "…"
    }
}
