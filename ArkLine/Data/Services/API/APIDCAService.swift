import Foundation

// MARK: - API DCA Service
/// Real API implementation of DCAServiceProtocol.
/// Uses Supabase for DCA reminder storage.
final class APIDCAService: DCAServiceProtocol {
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    /// Custom decoder that handles PostgreSQL `time` columns (returned as "HH:mm:ss")
    /// alongside normal ISO 8601 timestamps for other date fields.
    private static let dcaDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f
        }()
        let iso8601WithFrac = ISO8601DateFormatter()
        iso8601WithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let d = timeFormatter.date(from: string) { return d }
            if let d = iso8601WithFrac.date(from: string) { return d }
            if let d = iso8601.date(from: string) { return d }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()

    // MARK: - Time-Based DCA Methods

    func fetchReminders(userId: UUID) async throws -> [DCAReminder] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let data = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .data

            let reminders = try Self.dcaDecoder.decode([DCAReminder].self, from: data)
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
            let data = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("next_reminder_date", ascending: true)
                .execute()
                .data

            return try Self.dcaDecoder.decode([DCAReminder].self, from: data)
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
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
                return []
            }

            let data = try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .gte("next_reminder_date", value: today.ISO8601Format())
                .lt("next_reminder_date", value: tomorrow.ISO8601Format())
                .execute()
                .data

            return try Self.dcaDecoder.decode([DCAReminder].self, from: data)
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
            // Insert without decoding — the `time` column can't round-trip through
            // the Supabase SDK's ISO 8601 date decoder, so we skip .select().value
            // and construct the result from the request data.
            try await supabase.database
                .from(SupabaseTable.dcaReminders.rawValue)
                .insert(request)
                .execute()

            // Parse the time string back to a Date for the local model
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            f.locale = Locale(identifier: "en_US_POSIX")
            let notifDate = f.date(from: request.notificationTime) ?? Date()

            let created = DCAReminder(
                userId: request.userId,
                symbol: request.symbol,
                name: request.name,
                amount: request.amount,
                frequency: DCAFrequency(rawValue: request.frequency) ?? .daily,
                totalPurchases: request.totalPurchases,
                completedPurchases: 0,
                notificationTime: notifDate,
                startDate: request.startDate,
                nextReminderDate: request.nextReminderDate,
                isActive: true
            )

            logInfo("Created DCA reminder: \(created.name)", category: .data)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create DCA reminder", category: .data)
            let message = "\(error)"
            if message.contains("column") || message.contains("schema") || message.contains("postgrest") {
                throw AppError.supabaseError(message: "Failed to save reminder. Please update the app or try again.")
            }
            throw AppError.from(error)
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
                .limit(500)
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
                .limit(100)
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
            let price = await fetchCurrentPrice(for: reminder.symbol)
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
                .limit(500)
                .execute()
                .value

            return investments
        } catch {
            logError(error, context: "Fetch risk DCA investment history", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchRiskLevel(symbol: String) async throws -> AssetRiskLevel {
        let itcRiskService = ServiceContainer.shared.itcRiskService

        do {
            let riskPoint = try await itcRiskService.calculateCurrentRisk(coin: symbol.uppercased())
            let score = riskPoint.riskLevel * 100 // Convert 0-1 to 0-100
            return AssetRiskLevel(
                assetId: symbol.lowercased(),
                symbol: symbol.uppercased(),
                riskScore: score,
                riskCategory: RiskCategory.from(score: score),
                lastUpdated: riskPoint.date
            )
        } catch {
            logWarning("ITC risk fetch failed for \(symbol), falling back to moderate: \(error.localizedDescription)", category: .data)
            return AssetRiskLevel(
                assetId: symbol.lowercased(),
                symbol: symbol.uppercased(),
                riskScore: 50.0,
                riskCategory: .moderate,
                lastUpdated: Date()
            )
        }
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

    /// Fetches current price for a symbol from Binance
    private func fetchCurrentPrice(for symbol: String) async -> Double {
        let pair = "\(symbol.uppercased())USDT"
        do {
            let endpoint = BinanceEndpoint.tickerPrice(symbol: pair)
            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let priceStr = json["price"] as? String,
               let price = Double(priceStr) {
                return price
            }
        } catch {
            logError("DCA price fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
        }
        return 0
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
