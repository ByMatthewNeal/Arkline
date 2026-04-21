import Foundation

// MARK: - DCA Plan Model
/// Represents a structured DCA investment plan with allocation targets,
/// progress tracking, and streak management.
struct DCAPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var assetSymbol: String
    var assetName: String
    var targetAllocationPct: Double
    var cashAllocationPct: Double
    var startingCapital: Double
    var startingQty: Double
    var preDcaAvgCost: Double?
    var frequency: String
    var startDate: String   // DATE column (yyyy-MM-dd)
    var endDate: String?    // DATE column (yyyy-MM-dd)
    var totalWeeks: Int
    var currentQty: Double
    var totalInvested: Double
    var cashRemaining: Double
    var streakCurrent: Int
    var streakBest: Int
    var status: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case assetSymbol = "asset_symbol"
        case assetName = "asset_name"
        case targetAllocationPct = "target_allocation_pct"
        case cashAllocationPct = "cash_allocation_pct"
        case startingCapital = "starting_capital"
        case startingQty = "starting_qty"
        case preDcaAvgCost = "pre_dca_avg_cost"
        case frequency
        case startDate = "start_date"
        case endDate = "end_date"
        case totalWeeks = "total_weeks"
        case currentQty = "current_qty"
        case totalInvested = "total_invested"
        case cashRemaining = "cash_remaining"
        case streakCurrent = "streak_current"
        case streakBest = "streak_best"
        case status
        case createdAt = "created_at"
    }

    // MARK: - Status Helpers

    var isActive: Bool { status == "active" }
    var isPaused: Bool { status == "paused" }
    var isCompleted: Bool { status == "completed" }

    // MARK: - Computed Properties (price-independent)

    /// Total cost basis including any pre-DCA position
    var totalCostBasis: Double {
        if let preCost = preDcaAvgCost, startingQty > 0 {
            return preCost * startingQty + totalInvested
        }
        return totalInvested
    }

    /// Blended average cost per unit across pre-DCA and DCA purchases
    var blendedAvgCost: Double {
        guard currentQty > 0 else { return 0 }
        return totalCostBasis / currentQty
    }

    /// Number of weeks remaining until end date (nil if no end date)
    var weeksRemaining: Int? {
        guard let end = endDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let endDateParsed = formatter.date(from: end) else { return nil }
        let now = Date()
        let components = Calendar.current.dateComponents([.weekOfYear], from: now, to: endDateParsed)
        return max(components.weekOfYear ?? 0, 0)
    }

    /// Number of weeks completed so far
    var weeksCompleted: Int {
        guard let remaining = weeksRemaining else { return totalWeeks }
        return max(totalWeeks - remaining, 0)
    }

    /// DCA progress as a fraction (0...1)
    var dcaProgress: Double {
        guard totalWeeks > 0 else { return 0 }
        return min(Double(weeksCompleted) / Double(totalWeeks), 1.0)
    }

    // MARK: - Price-Dependent Computed Properties

    /// Current value of the position at live price
    func currentValue(price: Double) -> Double {
        currentQty * price
    }

    /// Total portfolio value (position + cash)
    func totalPortfolioValue(price: Double) -> Double {
        currentValue(price: price) + cashRemaining
    }

    /// Current allocation percentage of the asset
    func currentAllocationPct(price: Double) -> Double {
        let total = totalPortfolioValue(price: price)
        guard total > 0 else { return 0 }
        return currentValue(price: price) / total * 100
    }

    /// Gap between target and current allocation (positive = underweight)
    func allocationGap(price: Double) -> Double {
        targetAllocationPct - currentAllocationPct(price: price)
    }

    /// USD amount still needed to reach target allocation
    func stillToBuy(price: Double) -> Double {
        let gap = allocationGap(price: price)
        guard gap > 0 else { return 0 }
        let total = totalPortfolioValue(price: price)
        return total * gap / 100
    }

    /// Recommended weekly DCA amount based on remaining gap and weeks
    func recommendedWeeklyDCA(price: Double) -> Double {
        guard let remaining = weeksRemaining, remaining > 0 else { return 0 }
        return stillToBuy(price: price) / Double(remaining)
    }

    /// Unrealized P&L at current price
    func unrealizedPnL(price: Double) -> Double {
        let basis = totalCostBasis
        guard basis > 0 else { return 0 }
        return currentValue(price: price) - basis
    }

    /// Unrealized P&L as a percentage
    func unrealizedPnLPct(price: Double) -> Double {
        let basis = totalCostBasis
        guard basis > 0 else { return 0 }
        return unrealizedPnL(price: price) / basis * 100
    }
}

// MARK: - DCA Entry Model
/// Represents a single DCA purchase entry within a plan,
/// including planned vs actual tracking and capital injections.
struct DCAEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let planId: UUID
    var weekNumber: Int
    var entryDate: String   // DATE column (yyyy-MM-dd)
    var plannedAmount: Double
    var actualAmount: Double?
    var pricePaid: Double?
    var qtyBought: Double?
    var cumulativeInvested: Double
    var cumulativeQty: Double
    var variance: Double?
    var isCompleted: Bool
    var isCapitalInjection: Bool
    var injectionAmount: Double?
    var notes: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case planId = "plan_id"
        case weekNumber = "week_number"
        case entryDate = "entry_date"
        case plannedAmount = "planned_amount"
        case actualAmount = "actual_amount"
        case pricePaid = "price_paid"
        case qtyBought = "qty_bought"
        case cumulativeInvested = "cumulative_invested"
        case cumulativeQty = "cumulative_qty"
        case variance
        case isCompleted = "is_completed"
        case isCapitalInjection = "is_capital_injection"
        case injectionAmount = "injection_amount"
        case notes
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// Whether the actual amount exceeded the planned amount
    var isOverPlan: Bool {
        (actualAmount ?? 0) > plannedAmount
    }

    /// Whether the entry was completed but under the planned amount
    var isUnderPlan: Bool {
        (actualAmount ?? 0) < plannedAmount && isCompleted
    }
}

// MARK: - Request DTOs

/// Request body for creating a new DCA plan
struct CreateDCAPlanRequest: Encodable {
    let userId: UUID
    let assetSymbol: String
    let assetName: String
    let targetAllocationPct: Double
    let cashAllocationPct: Double
    let startingCapital: Double
    let startingQty: Double
    let preDcaAvgCost: Double?
    let frequency: String
    let startDate: String
    let endDate: String?
    let totalWeeks: Int
    let currentQty: Double
    let totalInvested: Double
    let cashRemaining: Double
    let status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case assetSymbol = "asset_symbol"
        case assetName = "asset_name"
        case targetAllocationPct = "target_allocation_pct"
        case cashAllocationPct = "cash_allocation_pct"
        case startingCapital = "starting_capital"
        case startingQty = "starting_qty"
        case preDcaAvgCost = "pre_dca_avg_cost"
        case frequency
        case startDate = "start_date"
        case endDate = "end_date"
        case totalWeeks = "total_weeks"
        case currentQty = "current_qty"
        case totalInvested = "total_invested"
        case cashRemaining = "cash_remaining"
        case status
    }
}

/// Request body for updating an existing DCA plan
struct UpdateDCAPlanRequest: Encodable {
    var targetAllocationPct: Double?
    var cashAllocationPct: Double?
    var endDate: String?
    var totalWeeks: Int?
    var currentQty: Double?
    var totalInvested: Double?
    var cashRemaining: Double?
    var streakCurrent: Int?
    var streakBest: Int?
    var status: String?

    enum CodingKeys: String, CodingKey {
        case targetAllocationPct = "target_allocation_pct"
        case cashAllocationPct = "cash_allocation_pct"
        case endDate = "end_date"
        case totalWeeks = "total_weeks"
        case currentQty = "current_qty"
        case totalInvested = "total_invested"
        case cashRemaining = "cash_remaining"
        case streakCurrent = "streak_current"
        case streakBest = "streak_best"
        case status
    }
}

/// Request body for creating a new DCA entry
struct CreateDCAEntryRequest: Encodable {
    let planId: UUID
    let weekNumber: Int
    let entryDate: String
    let plannedAmount: Double
    let actualAmount: Double?
    let pricePaid: Double?
    let qtyBought: Double?
    let cumulativeInvested: Double
    let cumulativeQty: Double
    let variance: Double?
    let isCompleted: Bool
    let isCapitalInjection: Bool
    let injectionAmount: Double?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case weekNumber = "week_number"
        case entryDate = "entry_date"
        case plannedAmount = "planned_amount"
        case actualAmount = "actual_amount"
        case pricePaid = "price_paid"
        case qtyBought = "qty_bought"
        case cumulativeInvested = "cumulative_invested"
        case cumulativeQty = "cumulative_qty"
        case variance
        case isCompleted = "is_completed"
        case isCapitalInjection = "is_capital_injection"
        case injectionAmount = "injection_amount"
        case notes
    }
}

/// Request body for updating an existing DCA entry
struct UpdateDCAEntryRequest: Encodable {
    var actualAmount: Double?
    var pricePaid: Double?
    var qtyBought: Double?
    var cumulativeInvested: Double?
    var cumulativeQty: Double?
    var variance: Double?
    var isCompleted: Bool?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case actualAmount = "actual_amount"
        case pricePaid = "price_paid"
        case qtyBought = "qty_bought"
        case cumulativeInvested = "cumulative_invested"
        case cumulativeQty = "cumulative_qty"
        case variance
        case isCompleted = "is_completed"
        case notes
    }
}
