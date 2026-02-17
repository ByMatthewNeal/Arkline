import SwiftUI
import Foundation

// MARK: - DCA Tab Selection
enum DCAViewTab: String, CaseIterable {
    case timeBased = "Time-Based"
    case riskBased = "Risk-Based"
}

// MARK: - DCA View Model
@Observable
final class DCAViewModel {
    // MARK: - Dependencies
    private let dcaService: DCAServiceProtocol

    // MARK: - State
    var reminders: [DCAReminder] = []
    var riskBasedReminders: [RiskBasedDCAReminder] = []
    var selectedReminder: DCAReminder?
    var selectedRiskBasedReminder: RiskBasedDCAReminder?
    var isLoading = false
    var error: AppError?

    // MARK: - Tab Selection
    var selectedTab: DCAViewTab = .timeBased

    // MARK: - Create/Edit State
    var editingReminder: DCAReminder?
    var showCreateSheet = false
    var showCreateRiskBasedSheet = false

    // MARK: - Risk Level Cache
    var cachedRiskLevels: [String: AssetRiskLevel] = [:]

    // User context
    private var cachedUserId: UUID?

    /// Resolves user ID from Supabase auth (must be called from async context)
    @MainActor
    private func resolveUserId() -> UUID? {
        let id = SupabaseAuthManager.shared.currentUserId
        cachedUserId = id
        return id
    }

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

    // MARK: - Risk-Based Computed Properties

    var activeRiskBasedReminders: [RiskBasedDCAReminder] {
        riskBasedReminders.filter { $0.isActive }
    }

    var triggeredReminders: [RiskBasedDCAReminder] {
        riskBasedReminders.filter { $0.isActive && $0.isTriggered }
    }

    var pendingRiskReminders: [RiskBasedDCAReminder] {
        riskBasedReminders.filter { $0.isActive && !$0.isTriggered }
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
            guard let userId = await resolveUserId() else {
                await MainActor.run {
                    self.error = .authenticationRequired
                    self.isLoading = false
                }
                return
            }

            // Fetch time-based and risk-based reminders concurrently
            async let timeBasedTask = dcaService.fetchReminders(userId: userId)
            async let riskBasedTask = dcaService.fetchRiskBasedReminders(userId: userId)

            let (fetchedReminders, fetchedRiskBased) = try await (timeBasedTask, riskBasedTask)

            await MainActor.run {
                self.reminders = fetchedReminders
                self.riskBasedReminders = fetchedRiskBased
                self.isLoading = false
            }

            // Cache risk levels for all risk-based reminders
            await refreshRiskLevels()
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
                self.isLoading = false
            }
        }
    }

    private func loadInitialData() async {
        await refresh()
    }

    /// Refreshes risk levels for all risk-based reminder symbols
    func refreshRiskLevels() async {
        let symbols = Set(riskBasedReminders.map { $0.symbol })

        for symbol in symbols {
            do {
                let riskLevel = try await dcaService.fetchRiskLevel(symbol: symbol)
                await MainActor.run {
                    self.cachedRiskLevels[symbol.uppercased()] = riskLevel
                }
            } catch {
                // Silently fail - will retry on next refresh
            }
        }
    }

    /// Checks all risk-based reminders and triggers those that meet conditions
    func checkAndTriggerReminders() async {
        guard let userId = await resolveUserId() else { return }

        do {
            let triggered = try await dcaService.checkAndTriggerReminders(userId: userId)

            if !triggered.isEmpty {
                await MainActor.run {
                    // Update local state with triggered reminders
                    for triggered in triggered {
                        if let index = self.riskBasedReminders.firstIndex(where: { $0.id == triggered.id }) {
                            self.riskBasedReminders[index] = triggered
                        }
                    }
                }
            }
        } catch {
            // Silently fail - will retry on next check
        }
    }

    /// Gets cached risk level for a symbol
    func riskLevel(for symbol: String) -> AssetRiskLevel? {
        cachedRiskLevels[symbol.uppercased()]
    }

    /// Fetches current risk level for a symbol (for UI components that need fresh data)
    func fetchRiskLevel(for symbol: String) async -> AssetRiskLevel? {
        do {
            let level = try await dcaService.fetchRiskLevel(symbol: symbol)
            await MainActor.run {
                self.cachedRiskLevels[symbol.uppercased()] = level
            }
            return level
        } catch {
            return nil
        }
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
                nextReminderDate: reminder.nextReminderDate ?? Date(),
                portfolioId: nil
            )
            let createdReminder = try await dcaService.createReminder(request)

            // Track DCA creation
            Task {
                await AnalyticsService.shared.track("dca_created", properties: [
                    "coin": .string(reminder.symbol),
                    "frequency": .string(reminder.frequency.rawValue),
                    "amount": .double(reminder.amount)
                ])
            }

            await MainActor.run {
                self.reminders.append(createdReminder)
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
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
                self.error = AppError.from(error)
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
                self.error = AppError.from(error)
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
            _ = try await dcaService.markAsInvested(id: reminder.id)

            await MainActor.run {
                if let index = self.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.reminders[index].completedPurchases += 1
                    self.reminders[index].nextReminderDate = self.calculateNextDate(for: self.reminders[index])
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func skipReminder(_ reminder: DCAReminder) async {
        do {
            _ = try await dcaService.skipReminder(id: reminder.id)

            await MainActor.run {
                if let index = self.reminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.reminders[index].nextReminderDate = self.calculateNextDate(for: self.reminders[index])
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
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

    // MARK: - Risk-Based DCA Actions

    func createRiskBasedReminder(
        symbol: String,
        name: String,
        amount: Double,
        riskThreshold: Double,
        riskCondition: RiskCondition
    ) async {
        do {
            guard let userId = await resolveUserId() else {
                await MainActor.run { self.error = .authenticationRequired }
                return
            }
            let request = CreateRiskBasedDCARequest(
                userId: userId,
                symbol: symbol.uppercased(),
                name: name,
                amount: amount,
                riskThreshold: riskThreshold,
                riskCondition: riskCondition.rawValue
            )
            let createdReminder = try await dcaService.createRiskBasedReminder(request)

            await MainActor.run {
                self.riskBasedReminders.append(createdReminder)
            }

            // Fetch risk level for the new reminder
            let riskLevel = try await dcaService.fetchRiskLevel(symbol: symbol)
            await MainActor.run {
                self.cachedRiskLevels[symbol.uppercased()] = riskLevel
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func updateRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async {
        do {
            try await dcaService.updateRiskBasedReminder(reminder)

            await MainActor.run {
                if let index = self.riskBasedReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.riskBasedReminders[index] = reminder
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func deleteRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async {
        do {
            try await dcaService.deleteRiskBasedReminder(id: reminder.id)

            await MainActor.run {
                self.riskBasedReminders.removeAll { $0.id == reminder.id }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func toggleRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async {
        do {
            let updatedReminder = try await dcaService.toggleRiskBasedReminder(id: reminder.id)

            await MainActor.run {
                if let index = self.riskBasedReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.riskBasedReminders[index] = updatedReminder
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func markRiskBasedAsInvested(_ reminder: RiskBasedDCAReminder) async {
        do {
            let updatedReminder = try await dcaService.markRiskBasedAsInvested(id: reminder.id)

            await MainActor.run {
                if let index = self.riskBasedReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.riskBasedReminders[index] = updatedReminder
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func dismissRiskTrigger(_ reminder: RiskBasedDCAReminder) async {
        do {
            let updatedReminder = try await dcaService.resetTrigger(id: reminder.id)

            await MainActor.run {
                if let index = self.riskBasedReminders.firstIndex(where: { $0.id == reminder.id }) {
                    self.riskBasedReminders[index] = updatedReminder
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.from(error)
            }
        }
    }

    func fetchRiskBasedInvestmentHistory(reminderId: UUID) async -> [RiskDCAInvestment] {
        do {
            return try await dcaService.fetchRiskBasedInvestmentHistory(reminderId: reminderId)
        } catch {
            return []
        }
    }
}
