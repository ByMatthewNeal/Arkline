import Foundation
import SwiftUI

// MARK: - DCA Tracker ViewModel
@MainActor
@Observable
class DCATrackerViewModel {
    // MARK: - State
    var plans: [DCAPlan] = []
    var selectedPlan: DCAPlan?
    var entries: [DCAEntry] = []
    var livePrice: Double = 0
    var isLoading = false
    var errorMessage: String?
    var showLogEntry = false
    var showCreatePlan = false
    var showAddFunds = false

    // MARK: - Dependencies
    private let service = ServiceContainer.shared.dcaTrackerService

    // MARK: - Computed Properties

    /// Active plans only
    var activePlans: [DCAPlan] { plans.filter(\.isActive) }

    /// Completed entries for the selected plan (reverse chronological)
    var completedEntries: [DCAEntry] {
        entries.filter(\.isCompleted).sorted { $0.weekNumber > $1.weekNumber }
    }

    /// Capital injection entries
    var injectionEntries: [DCAEntry] {
        entries.filter(\.isCapitalInjection)
    }

    /// Best entry (lowest price paid)
    var bestEntry: DCAEntry? {
        entries
            .filter { $0.isCompleted && !$0.isCapitalInjection && $0.pricePaid != nil }
            .min { ($0.pricePaid ?? .infinity) < ($1.pricePaid ?? .infinity) }
    }

    /// Worst entry (highest price paid)
    var worstEntry: DCAEntry? {
        entries
            .filter { $0.isCompleted && !$0.isCapitalInjection && $0.pricePaid != nil }
            .max { ($0.pricePaid ?? 0) < ($1.pricePaid ?? 0) }
    }

    /// Next week number for a new entry
    var nextWeekNumber: Int {
        (entries.map(\.weekNumber).max() ?? 0) + 1
    }

    // MARK: - Plan Loading

    func loadPlans() async {
        guard let userId = SupabaseAuthManager.shared.currentUserId else {
            errorMessage = "Please sign in to view DCA plans"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            plans = try await service.fetchPlans(userId: userId)

            // Auto-select first active plan if none selected
            if selectedPlan == nil, let first = activePlans.first {
                selectedPlan = first
                await loadEntries(planId: first.id)
                await fetchLivePrice(symbol: first.assetSymbol)
            }
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    func loadEntries(planId: UUID) async {
        do {
            entries = try await service.fetchEntries(planId: planId)
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Plan Management

    func createPlan(
        assetSymbol: String,
        assetName: String,
        targetAllocationPct: Double,
        startingCapital: Double,
        startingQty: Double,
        preDcaAvgCost: Double?,
        frequency: String,
        totalWeeks: Int
    ) async {
        guard let userId = SupabaseAuthManager.shared.currentUserId else {
            errorMessage = "Please sign in to create a DCA plan"
            return
        }

        isLoading = true
        defer { isLoading = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let startDate = formatter.string(from: Date())

        let endDate: String? = {
            guard let end = Calendar.current.date(byAdding: .weekOfYear, value: totalWeeks, to: Date()) else { return nil }
            return formatter.string(from: end)
        }()

        // Calculate initial cash remaining after accounting for existing position value
        let existingPositionValue = startingQty * (preDcaAvgCost ?? 0)
        let cashRemaining = startingCapital - existingPositionValue
        let totalInvested = existingPositionValue

        let request = CreateDCAPlanRequest(
            userId: userId,
            assetSymbol: assetSymbol,
            assetName: assetName,
            targetAllocationPct: targetAllocationPct,
            cashAllocationPct: 100 - targetAllocationPct,
            startingCapital: startingCapital,
            startingQty: startingQty,
            preDcaAvgCost: preDcaAvgCost,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate,
            totalWeeks: totalWeeks,
            currentQty: startingQty,
            totalInvested: totalInvested,
            cashRemaining: max(cashRemaining, 0),
            status: "active"
        )

        do {
            let plan = try await service.createPlan(request)
            plans.insert(plan, at: 0)
            selectedPlan = plan
            entries = []
            await fetchLivePrice(symbol: plan.assetSymbol)
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Entry Logging

    func logEntry(
        date: Date,
        amount: Double,
        price: Double,
        notes: String?
    ) async {
        guard let plan = selectedPlan else { return }

        isLoading = true
        defer { isLoading = false }

        let qty = price > 0 ? amount / price : 0
        let newCumulativeInvested = plan.totalInvested + amount
        let newCumulativeQty = plan.currentQty + qty
        let recommendedAmount = plan.recommendedWeeklyDCA(price: livePrice)
        let variance = recommendedAmount > 0 ? (amount - recommendedAmount) / recommendedAmount * 100 : nil

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date)

        let request = CreateDCAEntryRequest(
            planId: plan.id,
            weekNumber: nextWeekNumber,
            entryDate: dateString,
            plannedAmount: recommendedAmount,
            actualAmount: amount,
            pricePaid: price,
            qtyBought: qty,
            cumulativeInvested: newCumulativeInvested,
            cumulativeQty: newCumulativeQty,
            variance: variance,
            isCompleted: true,
            isCapitalInjection: false,
            injectionAmount: nil,
            notes: notes
        )

        do {
            let entry = try await service.logEntry(request)
            entries.append(entry)

            // Update plan totals
            let updates = UpdateDCAPlanRequest(
                currentQty: newCumulativeQty,
                totalInvested: newCumulativeInvested,
                cashRemaining: plan.cashRemaining - amount
            )
            try await service.updatePlan(id: plan.id, updates: updates)

            // Refresh plan
            selectedPlan = try await service.fetchPlan(id: plan.id)
            if let idx = plans.firstIndex(where: { $0.id == plan.id }), let updated = selectedPlan {
                plans[idx] = updated
            }

            // Update streak
            let newStreak = plan.streakCurrent + 1
            let newBest = max(newStreak, plan.streakBest)
            await updateStreak(current: newStreak, best: newBest)
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Capital Injection

    func addInjection(amount: Double, notes: String?) async {
        guard let plan = selectedPlan else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let entry = try await service.addCapitalInjection(
                planId: plan.id,
                amount: amount,
                date: Date(),
                notes: notes
            )
            entries.append(entry)

            // Refresh plan
            selectedPlan = try await service.fetchPlan(id: plan.id)
            if let idx = plans.firstIndex(where: { $0.id == plan.id }), let updated = selectedPlan {
                plans[idx] = updated
            }
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Streak

    func updateStreak(current: Int, best: Int) async {
        guard let plan = selectedPlan else { return }

        do {
            try await service.updateStreak(planId: plan.id, current: current, best: best)
            selectedPlan?.streakCurrent = current
            selectedPlan?.streakBest = best
            if let idx = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[idx].streakCurrent = current
                plans[idx].streakBest = best
            }
        } catch {
            logError(error, context: "Update DCA streak", category: .data)
        }
    }

    // MARK: - Price Fetching

    func fetchLivePrice(symbol: String) async {
        // Try Coinbase spot price first
        do {
            let pair = "\(symbol.uppercased())-USD"
            let candles = try await CoinbaseCandle.fetch(pair: pair, granularity: "ONE_HOUR", limit: 1)
            if let latest = candles.last {
                livePrice = latest.close
                return
            }
        } catch {
            logDebug("Coinbase price fetch failed for \(symbol), trying market service", category: .network)
        }

        // Fallback: try market service (CoinGecko cache)
        do {
            let assets = try await ServiceContainer.shared.marketService.fetchCryptoAssets(page: 1, perPage: 100)
            if let match = assets.first(where: { $0.symbol.uppercased() == symbol.uppercased() }) {
                livePrice = match.currentPrice
            }
        } catch {
            logWarning("Failed to fetch live price for \(symbol)", category: .network)
        }
    }

    // MARK: - Delete

    func deletePlan(id: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.deletePlan(id: id)
            plans.removeAll { $0.id == id }
            if selectedPlan?.id == id {
                selectedPlan = activePlans.first
                if let plan = selectedPlan {
                    await loadEntries(planId: plan.id)
                    await fetchLivePrice(symbol: plan.assetSymbol)
                } else {
                    entries = []
                    livePrice = 0
                }
            }
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Refresh

    func refresh() async {
        await loadPlans()
    }

    // MARK: - Select Plan

    func selectPlan(_ plan: DCAPlan) async {
        selectedPlan = plan
        await loadEntries(planId: plan.id)
        await fetchLivePrice(symbol: plan.assetSymbol)
    }
}
