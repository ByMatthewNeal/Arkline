import Foundation

// MARK: - DCA Service Protocol
/// Protocol defining DCA (Dollar Cost Averaging) reminder operations.
protocol DCAServiceProtocol {
    /// Fetches all DCA reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of DCAReminder
    func fetchReminders(userId: UUID) async throws -> [DCAReminder]

    /// Fetches active DCA reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of active DCAReminder
    func fetchActiveReminders(userId: UUID) async throws -> [DCAReminder]

    /// Fetches reminders due today
    /// - Parameter userId: User identifier
    /// - Returns: Array of DCAReminder due today
    func fetchTodayReminders(userId: UUID) async throws -> [DCAReminder]

    /// Creates a new DCA reminder
    /// - Parameter request: CreateDCARequest with reminder details
    /// - Returns: Created DCAReminder
    func createReminder(_ request: CreateDCARequest) async throws -> DCAReminder

    /// Updates an existing DCA reminder
    /// - Parameter reminder: DCAReminder with updated values
    func updateReminder(_ reminder: DCAReminder) async throws

    /// Deletes a DCA reminder
    /// - Parameter id: Reminder identifier to delete
    func deleteReminder(id: UUID) async throws

    /// Marks a reminder as invested (increments completed purchases)
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder
    func markAsInvested(id: UUID) async throws -> DCAReminder

    /// Skips the current reminder occurrence
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder with next date calculated
    func skipReminder(id: UUID) async throws -> DCAReminder

    /// Toggles the active state of a reminder
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder
    func toggleReminder(id: UUID) async throws -> DCAReminder

    /// Fetches investment history for a reminder
    /// - Parameter reminderId: Reminder identifier
    /// - Returns: Array of DCAInvestment
    func fetchInvestmentHistory(reminderId: UUID) async throws -> [DCAInvestment]
}
