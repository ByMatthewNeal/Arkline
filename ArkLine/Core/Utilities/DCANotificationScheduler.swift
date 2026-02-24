import UserNotifications
import Foundation

/// Centralized DCA notification scheduling.
/// Schedules a one-shot notification for the reminder's `nextReminderDate`
/// at the user's chosen notification time, rather than a daily repeating trigger.
enum DCANotificationScheduler {

    /// Schedule (or re-schedule) a local notification for a DCA reminder.
    /// Removes any existing notification for this reminder before adding a new one.
    static func schedule(_ reminder: DCAReminder) async {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        guard await center.notificationSettings().authorizationStatus == .authorized else { return }
        guard reminder.isActive, !reminder.isCompleted else { return }

        // Remove any existing notification for this reminder
        let identifier = "dca_reminder_\(reminder.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Build fire date: nextReminderDate with the user's chosen hour/minute
        guard let nextDate = reminder.nextReminderDate else { return }
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.notificationTime)

        var fireComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
        fireComponents.hour = timeComponents.hour
        fireComponents.minute = timeComponents.minute

        // If the fire date is in the past, skip (the app will advance nextReminderDate on next refresh)
        if let fireDate = calendar.date(from: fireComponents), fireDate <= Date() {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "DCA Reminder: \(reminder.name)"
        content.body = "Time to invest \(reminder.amount.asCurrency) in \(reminder.symbol)"
        content.sound = .default
        content.categoryIdentifier = "DCA_REMINDER"
        content.userInfo = [
            "type": "dca_reminder",
            "reminder_id": reminder.id.uuidString,
            "symbol": reminder.symbol
        ]

        // One-shot trigger for the specific date (not repeating)
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logInfo("Scheduled DCA notification for \(reminder.name) on \(fireComponents.month ?? 0)/\(fireComponents.day ?? 0) at \(fireComponents.hour ?? 0):\(fireComponents.minute ?? 0)", category: .data)
        } catch {
            logError("Failed to schedule DCA notification: \(error)", category: .data)
        }
    }

    /// Remove pending notification for a reminder.
    static func cancel(_ reminderId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["dca_reminder_\(reminderId.uuidString)"]
        )
    }

    /// Re-schedule notifications for all active reminders (call on app launch).
    static func syncAll(_ reminders: [DCAReminder]) async {
        // Clear all existing DCA notifications
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let dcaIds = pending.filter { $0.identifier.hasPrefix("dca_reminder_") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: dcaIds)

        // Re-schedule active, non-completed reminders
        for reminder in reminders where reminder.isActive && !reminder.isCompleted {
            await schedule(reminder)
        }
    }
}
