import SwiftUI
import Foundation

// MARK: - DCA View Model
@Observable
final class DCAViewModel {
    // MARK: - Dependencies
    private let dcaService: DCAServiceProtocol

    // MARK: - State
    var reminders: [DCAReminder] = []
    var selectedReminder: DCAReminder?
    var isLoading = false
    var error: AppError?

    // MARK: - Create/Edit State
    var editingReminder: DCAReminder?
    var showCreateSheet = false

    // User context
    private var currentUserId: UUID?

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
    init(dcaService: DCAServiceProtocol = ServiceContainer.shared.dcaService) {
        self.dcaService = dcaService
        Task { await loadInitialData() }
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        do {
            let userId = currentUserId ?? UUID()
            let fetchedReminders = try await dcaService.fetchReminders(userId: userId)

            await MainActor.run {
                self.reminders = fetchedReminders
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
                self.isLoading = false
            }
        }
    }

    private func loadInitialData() async {
        await refresh()
    }

    // MARK: - Actions
    func createReminder(_ reminder: DCAReminder) async {
        do {
            let request = CreateDCARequest(
                userId: reminder.userId,
                symbol: reminder.symbol,
                name: reminder.name,
                amount: reminder.amount,
                frequency: reminder.frequency.rawValue,
                totalPurchases: reminder.totalPurchases,
                notificationTime: reminder.notificationTime,
                startDate: reminder.startDate,
                nextReminderDate: reminder.nextReminderDate ?? Date()
            )
            let createdReminder = try await dcaService.createReminder(request)

            await MainActor.run {
                self.reminders.append(createdReminder)
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    func updateReminder(_ reminder: DCAReminder) async {
        do {
            try await dcaService.updateReminder(reminder)

            await MainActor.run {
                if let index = self.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.reminders[index] = reminder
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    func deleteReminder(_ reminder: DCAReminder) async {
        do {
            try await dcaService.deleteReminder(id: reminder.id)

            await MainActor.run {
                self.reminders.removeAll { $0.id == reminder.id }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    func toggleReminder(_ reminder: DCAReminder) async {
        var updatedReminder = reminder
        updatedReminder.isActive.toggle()
        await updateReminder(updatedReminder)
    }

    func markAsInvested(_ reminder: DCAReminder) async {
        do {
            try await dcaService.markAsInvested(id: reminder.id)

            await MainActor.run {
                if let index = self.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.reminders[index].completedPurchases += 1
                    self.reminders[index].nextReminderDate = self.calculateNextDate(for: self.reminders[index])
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    func skipReminder(_ reminder: DCAReminder) async {
        do {
            try await dcaService.skipReminder(id: reminder.id)

            await MainActor.run {
                if let index = self.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.reminders[index].nextReminderDate = self.calculateNextDate(for: self.reminders[index])
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? AppError ?? .unknown(message: error.localizedDescription)
            }
        }
    }

    func dismissError() {
        error = nil
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
