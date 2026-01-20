import SwiftUI
import Foundation

// MARK: - DCA View Model
@Observable
final class DCAViewModel {
    // MARK: - State
    var reminders: [DCAReminder] = []
    var selectedReminder: DCAReminder?
    var isLoading = false
    var error: AppError?

    // MARK: - Create/Edit State
    var editingReminder: DCAReminder?
    var showCreateSheet = false

    // MARK: - Computed Properties
    var activeReminders: [DCAReminder] {
        reminders.filter { $0.isActive }
    }

    var todayReminders: [DCAReminder] {
        let today = Calendar.current.startOfDay(for: Date())
        return reminders.filter { reminder in
            guard let nextDate = reminder.nextReminderDate,
                  reminder.isActive else { return false }
            return Calendar.current.isDate(nextDate, inSameDayAs: today)
        }
    }

    var completedReminders: [DCAReminder] {
        reminders.filter { !$0.isActive || $0.isCompleted }
    }

    // MARK: - Initialization
    init() {
        loadMockData()
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        loadMockData()
        isLoading = false
    }

    private func loadMockData() {
        let userId = UUID()

        reminders = [
            DCAReminder(
                userId: userId,
                symbol: "BTC",
                name: "Bitcoin",
                amount: 100,
                frequency: .weekly,
                totalPurchases: 52,
                completedPurchases: 12,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 84),
                nextReminderDate: Date(),
                isActive: true
            ),
            DCAReminder(
                userId: userId,
                symbol: "ETH",
                name: "Ethereum",
                amount: 50,
                frequency: .biweekly,
                totalPurchases: 24,
                completedPurchases: 8,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 112),
                nextReminderDate: Date().addingTimeInterval(86400 * 3),
                isActive: true
            ),
            DCAReminder(
                userId: userId,
                symbol: "SOL",
                name: "Solana",
                amount: 25,
                frequency: .monthly,
                totalPurchases: 12,
                completedPurchases: 3,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 90),
                nextReminderDate: Date().addingTimeInterval(86400 * 15),
                isActive: true
            )
        ]
    }

    // MARK: - Actions
    func createReminder(_ reminder: DCAReminder) {
        reminders.append(reminder)
    }

    func updateReminder(_ reminder: DCAReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        }
    }

    func deleteReminder(_ reminder: DCAReminder) {
        reminders.removeAll { $0.id == reminder.id }
    }

    func toggleReminder(_ reminder: DCAReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].isActive.toggle()
        }
    }

    func markAsInvested(_ reminder: DCAReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].completedPurchases += 1
            reminders[index].nextReminderDate = calculateNextDate(for: reminders[index])
        }
    }

    func skipReminder(_ reminder: DCAReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index].nextReminderDate = calculateNextDate(for: reminders[index])
        }
    }

    private func calculateNextDate(for reminder: DCAReminder) -> Date? {
        let calendar = Calendar.current
        guard let current = reminder.nextReminderDate else { return nil }

        switch reminder.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: current)
        case .twiceWeekly:
            return calendar.date(byAdding: .day, value: 3, to: current)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: current)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: current)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: current)
        }
    }
}
