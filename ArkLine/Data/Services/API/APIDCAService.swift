import Foundation

// MARK: - API DCA Service
/// Real API implementation of DCAServiceProtocol.
/// Uses Supabase for DCA reminder storage.
final class APIDCAService: DCAServiceProtocol {
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    // MARK: - DCAServiceProtocol

    func fetchReminders(userId: UUID) async throws -> [DCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from dca_reminders where user_id = userId order by created_at desc
        return []
    }

    func fetchActiveReminders(userId: UUID) async throws -> [DCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from dca_reminders where user_id = userId and is_active = true
        return []
    }

    func fetchTodayReminders(userId: UUID) async throws -> [DCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from dca_reminders where user_id = userId and is_active = true and next_reminder_date = today
        return []
    }

    func createReminder(_ request: CreateDCARequest) async throws -> DCAReminder {
        // TODO: Implement with Supabase
        // Insert into dca_reminders table
        throw AppError.notImplemented
    }

    func updateReminder(_ reminder: DCAReminder) async throws {
        // TODO: Implement with Supabase
        // Update dca_reminders where id = reminder.id
        throw AppError.notImplemented
    }

    func deleteReminder(id: UUID) async throws {
        // TODO: Implement with Supabase
        // Delete from dca_reminders where id = id
        // Also delete related dca_investments
        throw AppError.notImplemented
    }

    func markAsInvested(id: UUID) async throws -> DCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Increment completed_purchases
        // 3. Calculate and set next_reminder_date
        // 4. Create dca_investment record
        // 5. Update reminder
        throw AppError.notImplemented
    }

    func skipReminder(id: UUID) async throws -> DCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Calculate and set next_reminder_date
        // 3. Update reminder
        throw AppError.notImplemented
    }

    func toggleReminder(id: UUID) async throws -> DCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Toggle is_active
        // 3. Update reminder
        throw AppError.notImplemented
    }

    func fetchInvestmentHistory(reminderId: UUID) async throws -> [DCAInvestment] {
        // TODO: Implement with Supabase
        // Query: select * from dca_investments where reminder_id = reminderId order by purchase_date desc
        throw AppError.notImplemented
    }

    // MARK: - Risk-Based DCA Methods

    func fetchRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from risk_based_dca_reminders where user_id = userId order by created_at desc
        return []
    }

    func fetchActiveRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from risk_based_dca_reminders where user_id = userId and is_active = true
        return []
    }

    func fetchTriggeredReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        // TODO: Implement with Supabase
        // Query: select * from risk_based_dca_reminders where user_id = userId and is_active = true and is_triggered = true
        return []
    }

    func createRiskBasedReminder(_ request: CreateRiskBasedDCARequest) async throws -> RiskBasedDCAReminder {
        // TODO: Implement with Supabase
        // Insert into risk_based_dca_reminders table
        throw AppError.notImplemented
    }

    func updateRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async throws {
        // TODO: Implement with Supabase
        // Update risk_based_dca_reminders where id = reminder.id
        throw AppError.notImplemented
    }

    func deleteRiskBasedReminder(id: UUID) async throws {
        // TODO: Implement with Supabase
        // Delete from risk_based_dca_reminders where id = id
        // Also delete related risk_dca_investments
        throw AppError.notImplemented
    }

    func markRiskBasedAsInvested(id: UUID) async throws -> RiskBasedDCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Create risk_dca_investment record
        // 3. Reset is_triggered and last_triggered_risk_level
        // 4. Update reminder
        throw AppError.notImplemented
    }

    func resetTrigger(id: UUID) async throws -> RiskBasedDCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Set is_triggered = false and last_triggered_risk_level = null
        // 3. Update reminder
        throw AppError.notImplemented
    }

    func toggleRiskBasedReminder(id: UUID) async throws -> RiskBasedDCAReminder {
        // TODO: Implement with Supabase
        // 1. Fetch reminder
        // 2. Toggle is_active
        // 3. Update reminder
        throw AppError.notImplemented
    }

    func fetchRiskBasedInvestmentHistory(reminderId: UUID) async throws -> [RiskDCAInvestment] {
        // TODO: Implement with Supabase
        // Query: select * from risk_dca_investments where reminder_id = reminderId order by purchase_date desc
        throw AppError.notImplemented
    }

    func fetchRiskLevel(symbol: String) async throws -> AssetRiskLevel {
        // TODO: Implement with real API
        // This would call an external risk assessment API or internal calculation service
        // For now, return a placeholder
        return AssetRiskLevel(
            assetId: symbol.lowercased(),
            symbol: symbol.uppercased(),
            riskScore: 50.0,
            riskCategory: .moderate,
            lastUpdated: Date()
        )
    }

    func checkAndTriggerReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        // TODO: Implement with Supabase
        // 1. Fetch all active, non-triggered reminders
        // 2. For each reminder, fetch current risk level
        // 3. Check if condition is met
        // 4. If met, update is_triggered = true and last_triggered_risk_level
        // 5. Return array of newly triggered reminders
        return []
    }
}

// MARK: - Supabase Query Helpers
extension APIDCAService {
    /// Helper to calculate next reminder date based on frequency
    private func calculateNextDate(from current: Date, frequency: DCAFrequency) -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: current) ?? current
        case .twiceWeekly:
            return calendar.date(byAdding: .day, value: 3, to: current) ?? current
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: current) ?? current
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: current) ?? current
        }
    }
}
