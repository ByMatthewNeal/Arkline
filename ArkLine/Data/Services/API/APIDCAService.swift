import Foundation

// MARK: - API DCA Service
/// Real API implementation of DCAServiceProtocol.
/// Uses Supabase for DCA reminder storage.
final class APIDCAService: DCAServiceProtocol {
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    // MARK: - Time-Based DCA Methods

    func fetchReminders(userId: UUID) async throws -> [DCAReminder] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(reminders.count) DCA reminders", category: .data)
            return reminders
        } catch {
            logError(error, context: "Fetch DCA reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchActiveReminders(userId: UUID) async throws -> [DCAReminder] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("next_reminder_date", ascending: true)
                .execute()
                .value

            return reminders
        } catch {
            logError(error, context: "Fetch active DCA reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchTodayReminders(userId: UUID) async throws -> [DCAReminder] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .gte("next_reminder_date", value: today.ISO8601Format())
                .lt("next_reminder_date", value: tomorrow.ISO8601Format())
                .execute()
                .value

            return reminders
        } catch {
            logError(error, context: "Fetch today's DCA reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func createReminder(_ request: CreateDCARequest) async throws -> DCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let createdReminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .insert(request)
                .select()
                .execute()
                .value

            guard let created = createdReminders.first else {
                throw AppError.custom(message: "Failed to create DCA reminder")
            }

            logInfo("Created DCA reminder: \(created.name)", category: .data)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func updateReminder(_ reminder: DCAReminder) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .update(reminder)
                .eq("id", value: reminder.id.uuidString)
                .execute()

            logInfo("Updated DCA reminder: \(reminder.name)", category: .data)
        } catch {
            logError(error, context: "Update DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func deleteReminder(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // Investments cascade delete due to ON DELETE CASCADE
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Deleted DCA reminder: \(id)", category: .data)
        } catch {
            logError(error, context: "Delete DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func markAsInvested(id: UUID) async throws -> DCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // 1. Fetch current reminder
            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard var reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            // 2. Update reminder
            reminder = DCAReminder(
                id: reminder.id,
                userId: reminder.userId,
                symbol: reminder.symbol,
                name: reminder.name,
                amount: reminder.amount,
                frequency: reminder.frequency,
                totalPurchases: reminder.totalPurchases,
                completedPurchases: reminder.completedPurchases + 1,
                notificationTime: reminder.notificationTime,
                startDate: reminder.startDate,
                nextReminderDate: calculateNextDate(from: reminder.nextReminderDate ?? Date(), frequency: reminder.frequency),
                isActive: reminder.isActive,
                createdAt: reminder.createdAt
            )

            // 3. Save updated reminder
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .update(reminder)
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Marked DCA reminder as invested: \(reminder.name)", category: .data)
            return reminder
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Mark DCA as invested", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func skipReminder(id: UUID) async throws -> DCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // 1. Fetch current reminder
            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard var reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            // 2. Calculate next date without incrementing completed purchases
            reminder = DCAReminder(
                id: reminder.id,
                userId: reminder.userId,
                symbol: reminder.symbol,
                name: reminder.name,
                amount: reminder.amount,
                frequency: reminder.frequency,
                totalPurchases: reminder.totalPurchases,
                completedPurchases: reminder.completedPurchases,
                notificationTime: reminder.notificationTime,
                startDate: reminder.startDate,
                nextReminderDate: calculateNextDate(from: reminder.nextReminderDate ?? Date(), frequency: reminder.frequency),
                isActive: reminder.isActive,
                createdAt: reminder.createdAt
            )

            // 3. Save updated reminder
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .update(reminder)
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Skipped DCA reminder: \(reminder.name)", category: .data)
            return reminder
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Skip DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func toggleReminder(id: UUID) async throws -> DCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // 1. Fetch current reminder
            let reminders: [DCAReminder] = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard var reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            // 2. Toggle active state
            reminder = DCAReminder(
                id: reminder.id,
                userId: reminder.userId,
                symbol: reminder.symbol,
                name: reminder.name,
                amount: reminder.amount,
                frequency: reminder.frequency,
                totalPurchases: reminder.totalPurchases,
                completedPurchases: reminder.completedPurchases,
                notificationTime: reminder.notificationTime,
                startDate: reminder.startDate,
                nextReminderDate: reminder.nextReminderDate,
                isActive: !reminder.isActive,
                createdAt: reminder.createdAt
            )

            // 3. Save updated reminder
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .update(reminder)
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Toggled DCA reminder: \(reminder.name) - active: \(reminder.isActive)", category: .data)
            return reminder
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Toggle DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchInvestmentHistory(reminderId: UUID) async throws -> [DCAInvestment] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let investments: [DCAInvestment] = try await supabase.database
                .from("dca_investments")
                .select()
                .eq("reminder_id", value: reminderId.uuidString)
                .order("purchase_date", ascending: false)
                .execute()
                .value

            return investments
        } catch {
            logError(error, context: "Fetch DCA investment history", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Risk-Based DCA Methods

    func fetchRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(reminders.count) risk-based DCA reminders", category: .data)
            return reminders
        } catch {
            logError(error, context: "Fetch risk-based DCA reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchActiveRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        guard supabase.isConfigured else { return [] }

        do {
            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value

            return reminders
        } catch {
            logError(error, context: "Fetch active risk-based DCA reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchTriggeredReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        guard supabase.isConfigured else { return [] }

        do {
            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .eq("is_triggered", value: true)
                .execute()
                .value

            return reminders
        } catch {
            logError(error, context: "Fetch triggered reminders", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func createRiskBasedReminder(_ request: CreateRiskBasedDCARequest) async throws -> RiskBasedDCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let created: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .insert(request)
                .select()
                .execute()
                .value

            guard let reminder = created.first else {
                throw AppError.custom(message: "Failed to create risk-based DCA reminder")
            }

            logInfo("Created risk-based DCA reminder: \(reminder.name)", category: .data)
            return reminder
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create risk-based DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func updateRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .update(reminder)
                .eq("id", value: reminder.id.uuidString)
                .execute()

            logInfo("Updated risk-based DCA reminder: \(reminder.name)", category: .data)
        } catch {
            logError(error, context: "Update risk-based DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func deleteRiskBasedReminder(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // Investments cascade delete due to ON DELETE CASCADE
            try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Deleted risk-based DCA reminder: \(id)", category: .data)
        } catch {
            logError(error, context: "Delete risk-based DCA reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func markRiskBasedAsInvested(id: UUID) async throws -> RiskBasedDCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // 1. Fetch current reminder
            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            // 2. Create investment record
            let riskLevel = reminder.lastTriggeredRiskLevel ?? 50.0
            let price = fetchCurrentPriceSync(for: reminder.symbol)
            let investment = RiskDCAInvestment(
                id: UUID(),
                reminderId: id,
                amount: reminder.amount,
                priceAtPurchase: price,
                quantity: reminder.amount / price,
                riskLevelAtPurchase: riskLevel,
                purchaseDate: Date()
            )

            try await supabase.database
                .from(SupabaseTable.riskDcaInvestments.rawValue)
                .insert(investment)
                .execute()

            // 3. Reset triggered state
            struct TriggerReset: Encodable {
                let isTriggered: Bool
                let lastTriggeredRiskLevel: Double?

                enum CodingKeys: String, CodingKey {
                    case isTriggered = "is_triggered"
                    case lastTriggeredRiskLevel = "last_triggered_risk_level"
                }
            }

            try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .update(TriggerReset(isTriggered: false, lastTriggeredRiskLevel: nil))
                .eq("id", value: id.uuidString)
                .execute()

            // 4. Fetch and return updated reminder
            let updated: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let result = updated.first else {
                throw AppError.dataNotFound
            }

            logInfo("Marked risk-based DCA as invested: \(result.name)", category: .data)
            return result
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Mark risk-based DCA as invested", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func resetTrigger(id: UUID) async throws -> RiskBasedDCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            struct TriggerReset: Encodable {
                let isTriggered: Bool
                let lastTriggeredRiskLevel: Double?

                enum CodingKeys: String, CodingKey {
                    case isTriggered = "is_triggered"
                    case lastTriggeredRiskLevel = "last_triggered_risk_level"
                }
            }

            try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .update(TriggerReset(isTriggered: false, lastTriggeredRiskLevel: nil))
                .eq("id", value: id.uuidString)
                .execute()

            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            logInfo("Reset trigger for reminder: \(reminder.name)", category: .data)
            return reminder
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Reset trigger", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func toggleRiskBasedReminder(id: UUID) async throws -> RiskBasedDCAReminder {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // Fetch current state
            let reminders: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let reminder = reminders.first else {
                throw AppError.dataNotFound
            }

            // Toggle active state
            struct ActiveToggle: Encodable {
                let isActive: Bool

                enum CodingKeys: String, CodingKey {
                    case isActive = "is_active"
                }
            }

            try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .update(ActiveToggle(isActive: !reminder.isActive))
                .eq("id", value: id.uuidString)
                .execute()

            // Fetch updated
            let updated: [RiskBasedDCAReminder] = try await supabase.database
                .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let result = updated.first else {
                throw AppError.dataNotFound
            }

            logInfo("Toggled risk-based reminder: \(result.name) - active: \(result.isActive)", category: .data)
            return result
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Toggle risk-based reminder", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchRiskBasedInvestmentHistory(reminderId: UUID) async throws -> [RiskDCAInvestment] {
        guard supabase.isConfigured else { return [] }

        do {
            let investments: [RiskDCAInvestment] = try await supabase.database
                .from(SupabaseTable.riskDcaInvestments.rawValue)
                .select()
                .eq("reminder_id", value: reminderId.uuidString)
                .order("purchase_date", ascending: false)
                .execute()
                .value

            return investments
        } catch {
            logError(error, context: "Fetch risk DCA investment history", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchRiskLevel(symbol: String) async throws -> AssetRiskLevel {
        // TODO: Integrate with real risk assessment API (e.g., Into The Cryptoverse)
        // For now, return a moderate risk level placeholder
        return AssetRiskLevel(
            assetId: symbol.lowercased(),
            symbol: symbol.uppercased(),
            riskScore: 50.0,
            riskCategory: .moderate,
            lastUpdated: Date()
        )
    }

    func checkAndTriggerReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        let activeReminders = try await fetchActiveRiskBasedReminders(userId: userId)
        var triggeredReminders: [RiskBasedDCAReminder] = []

        for reminder in activeReminders where !reminder.isTriggered {
            let riskLevel = try await fetchRiskLevel(symbol: reminder.symbol)

            if reminder.shouldTrigger(currentRisk: riskLevel.riskScore) {
                // Update trigger state in database
                struct TriggerUpdate: Encodable {
                    let isTriggered: Bool
                    let lastTriggeredRiskLevel: Double

                    enum CodingKeys: String, CodingKey {
                        case isTriggered = "is_triggered"
                        case lastTriggeredRiskLevel = "last_triggered_risk_level"
                    }
                }

                try await supabase.database
                    .from(SupabaseTable.riskBasedDcaReminders.rawValue)
                    .update(TriggerUpdate(isTriggered: true, lastTriggeredRiskLevel: riskLevel.riskScore))
                    .eq("id", value: reminder.id.uuidString)
                    .execute()

                var updatedReminder = reminder
                updatedReminder.isTriggered = true
                updatedReminder.lastTriggeredRiskLevel = riskLevel.riskScore
                triggeredReminders.append(updatedReminder)

                logInfo("Triggered risk-based reminder: \(reminder.name) at risk \(riskLevel.riskScore)%", category: .data)
            }
        }

        return triggeredReminders
    }

    // MARK: - Private Price Helper

    /// Fetches current price for a symbol (placeholder until market service integration)
    private func fetchCurrentPriceSync(for symbol: String) -> Double {
        // Placeholder prices - integrate with market service for real prices
        let prices: [String: Double] = [
            "BTC": 67000, "ETH": 3500, "SOL": 175,
            "XRP": 0.55, "ADA": 0.48, "DOGE": 0.12
        ]
        return prices[symbol.uppercased()] ?? 100.0
    }

    // MARK: - Private Helpers

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
