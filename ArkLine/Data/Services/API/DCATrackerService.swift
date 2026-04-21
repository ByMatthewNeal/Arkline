import Foundation

// MARK: - DCA Tracker Service
/// Service for managing DCA plans and entries via Supabase.
/// Handles plan CRUD, entry logging, capital injections, and streak updates.
final class DCATrackerService {
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared

    // MARK: - Plans

    /// Fetch all DCA plans for a user
    func fetchPlans(userId: UUID) async throws -> [DCAPlan] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let plans: [DCAPlan] = try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(plans.count) DCA plans", category: .data)
            return plans
        } catch {
            logError(error, context: "Fetch DCA plans", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Fetch a single DCA plan by ID
    func fetchPlan(id: UUID) async throws -> DCAPlan {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let plans: [DCAPlan] = try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .select()
                .eq("id", value: id.uuidString)
                .execute()
                .value

            guard let plan = plans.first else {
                throw AppError.dataNotFound
            }

            return plan
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Fetch DCA plan", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Create a new DCA plan
    func createPlan(_ plan: CreateDCAPlanRequest) async throws -> DCAPlan {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let created: [DCAPlan] = try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .insert(plan)
                .select()
                .execute()
                .value

            guard let result = created.first else {
                throw AppError.custom(message: "Failed to create DCA plan")
            }

            logInfo("Created DCA plan: \(result.assetSymbol) (id: \(result.id))", category: .data)
            return result
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create DCA plan", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Update an existing DCA plan
    func updatePlan(id: UUID, updates: UpdateDCAPlanRequest) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .update(updates)
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Updated DCA plan: \(id)", category: .data)
        } catch {
            logError(error, context: "Update DCA plan", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Delete a DCA plan (entries cascade delete)
    func deletePlan(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Deleted DCA plan: \(id)", category: .data)
        } catch {
            logError(error, context: "Delete DCA plan", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Entries

    /// Fetch all entries for a DCA plan, ordered by week number
    func fetchEntries(planId: UUID) async throws -> [DCAEntry] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let entries: [DCAEntry] = try await supabase.database
                .from(SupabaseTable.dcaEntries.rawValue)
                .select()
                .eq("plan_id", value: planId.uuidString)
                .order("week_number", ascending: true)
                .execute()
                .value

            logInfo("Fetched \(entries.count) DCA entries for plan \(planId)", category: .data)
            return entries
        } catch {
            logError(error, context: "Fetch DCA entries", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Log a new DCA entry
    func logEntry(_ entry: CreateDCAEntryRequest) async throws -> DCAEntry {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let created: [DCAEntry] = try await supabase.database
                .from(SupabaseTable.dcaEntries.rawValue)
                .insert(entry)
                .select()
                .execute()
                .value

            guard let result = created.first else {
                throw AppError.custom(message: "Failed to log DCA entry")
            }

            logInfo("Logged DCA entry week \(result.weekNumber) for plan \(result.planId)", category: .data)
            return result
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Log DCA entry", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Update an existing DCA entry
    func updateEntry(id: UUID, updates: UpdateDCAEntryRequest) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.dcaEntries.rawValue)
                .update(updates)
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Updated DCA entry: \(id)", category: .data)
        } catch {
            logError(error, context: "Update DCA entry", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    /// Delete a DCA entry
    func deleteEntry(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.dcaEntries.rawValue)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Deleted DCA entry: \(id)", category: .data)
        } catch {
            logError(error, context: "Delete DCA entry", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Capital Injection

    /// Add a capital injection as a special DCA entry and update the plan's cash remaining
    func addCapitalInjection(planId: UUID, amount: Double, date: Date, notes: String?) async throws -> DCAEntry {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        // 1. Fetch current plan to get cumulative values
        let plan = try await fetchPlan(id: planId)
        let entries = try await fetchEntries(planId: planId)
        let nextWeek = (entries.map(\.weekNumber).max() ?? 0) + 1

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date)

        // 2. Create entry marked as capital injection
        let entryRequest = CreateDCAEntryRequest(
            planId: planId,
            weekNumber: nextWeek,
            entryDate: dateString,
            plannedAmount: 0,
            actualAmount: 0,
            pricePaid: nil,
            qtyBought: nil,
            cumulativeInvested: plan.totalInvested,
            cumulativeQty: plan.currentQty,
            variance: nil,
            isCompleted: true,
            isCapitalInjection: true,
            injectionAmount: amount,
            notes: notes
        )

        let entry = try await logEntry(entryRequest)

        // 3. Update plan's cash remaining
        let planUpdates = UpdateDCAPlanRequest(
            cashRemaining: plan.cashRemaining + amount
        )
        try await updatePlan(id: planId, updates: planUpdates)

        logInfo("Added capital injection of \(amount) to plan \(planId)", category: .data)
        return entry
    }

    // MARK: - Streak

    /// Update the streak counters on a plan
    func updateStreak(planId: UUID, current: Int, best: Int) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let patch = StreakPatch(streakCurrent: current, streakBest: best)
            try await supabase.database
                .from(SupabaseTable.dcaPlans.rawValue)
                .update(patch)
                .eq("id", value: planId.uuidString)
                .execute()

            logInfo("Updated streak for plan \(planId): current=\(current), best=\(best)", category: .data)
        } catch {
            logError(error, context: "Update DCA streak", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }
}

// MARK: - Private Patch Structs

private struct StreakPatch: Encodable {
    let streakCurrent: Int
    let streakBest: Int

    enum CodingKeys: String, CodingKey {
        case streakCurrent = "streak_current"
        case streakBest = "streak_best"
    }
}
