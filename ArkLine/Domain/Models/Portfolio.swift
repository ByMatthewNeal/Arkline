import Foundation

// MARK: - Time Period Enum
/// Represents time periods for portfolio charts and data views
enum TimePeriod: String, CaseIterable, Identifiable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case ytd = "YTD"
    case year = "1Y"
    case all = "ALL"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Number of days for this period (for API calls)
    var days: Int {
        switch self {
        case .hour: return 1
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .ytd:
            let calendar = Calendar.current
            let now = Date()
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 365
        case .year: return 365
        case .all: return 365 * 5
        }
    }
}

// MARK: - Portfolio Model
struct Portfolio: Codable, Identifiable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: UUID
    let userId: UUID
    var name: String
    var isPublic: Bool
    let createdAt: Date

    // Computed properties (not stored)
    var holdings: [PortfolioHolding]?
    var totalValue: Double?
    var totalCost: Double?
    var totalProfitLoss: Double?
    var totalProfitLossPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case isPublic = "is_public"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String = "Main Portfolio",
        isPublic: Bool = false,
        createdAt: Date = Date(),
        holdings: [PortfolioHolding]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.holdings = holdings
    }
}

// MARK: - Portfolio Holding
struct PortfolioHolding: Codable, Identifiable, Equatable {
    let id: UUID
    let portfolioId: UUID
    var assetType: String
    var symbol: String
    var name: String
    var quantity: Double
    var averageBuyPrice: Double?
    let createdAt: Date
    var updatedAt: Date
    var targetPercentage: Double?

    // Live data (not stored in DB)
    var currentPrice: Double?
    var priceChange24h: Double?
    var priceChangePercentage24h: Double?
    var iconUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case portfolioId = "portfolio_id"
        case assetType = "asset_type"
        case symbol
        case name
        case quantity
        case averageBuyPrice = "average_buy_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case targetPercentage = "target_percentage"
    }

    init(
        id: UUID = UUID(),
        portfolioId: UUID,
        assetType: String,
        symbol: String,
        name: String,
        quantity: Double,
        averageBuyPrice: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        targetPercentage: Double? = nil
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.assetType = assetType
        self.symbol = symbol
        self.name = name
        self.quantity = quantity
        self.averageBuyPrice = averageBuyPrice
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.targetPercentage = targetPercentage
    }
}

// MARK: - Holding Computed Properties
extension PortfolioHolding {
    var currentValue: Double {
        guard let price = currentPrice else { return 0 }
        return quantity * price
    }

    var totalCost: Double {
        guard let avgPrice = averageBuyPrice else { return 0 }
        return quantity * avgPrice
    }

    var profitLoss: Double {
        currentValue - totalCost
    }

    var profitLossPercentage: Double {
        guard totalCost > 0 else { return 0 }
        return ((currentValue - totalCost) / totalCost) * 100
    }

    var isProfit: Bool {
        profitLoss >= 0
    }

    var assetTypeEnum: Constants.AssetType? {
        Constants.AssetType(rawValue: assetType)
    }

    /// Merges holdings with the same symbol into a single entry per asset.
    /// Combines quantities, computes weighted average buy price, and sums target percentages.
    static func mergeBySymbol(_ holdings: [PortfolioHolding]) -> [PortfolioHolding] {
        let grouped = Dictionary(grouping: holdings) { $0.symbol.uppercased() }
        return grouped.values.compactMap { group -> PortfolioHolding? in
            guard let first = group.first else { return nil }
            if group.count == 1 { return first }

            let totalQuantity = group.reduce(0) { $0 + $1.quantity }
            let totalCost = group.reduce(0) { $0 + ($1.quantity * ($1.averageBuyPrice ?? 0)) }
            let weightedAvgPrice = totalQuantity > 0 ? totalCost / totalQuantity : nil

            let totalTarget: Double? = {
                let targets = group.compactMap(\.targetPercentage)
                return targets.isEmpty ? nil : targets.reduce(0, +)
            }()

            var merged = PortfolioHolding(
                id: first.id,
                portfolioId: first.portfolioId,
                assetType: first.assetType,
                symbol: first.symbol,
                name: first.name,
                quantity: totalQuantity,
                averageBuyPrice: weightedAvgPrice,
                createdAt: first.createdAt,
                updatedAt: group.map(\.updatedAt).max() ?? first.updatedAt,
                targetPercentage: totalTarget
            )
            merged.currentPrice = first.currentPrice
            merged.priceChange24h = first.priceChange24h
            merged.priceChangePercentage24h = first.priceChangePercentage24h
            merged.iconUrl = first.iconUrl
            return merged
        }
    }
}

// MARK: - Portfolio Statistics
struct PortfolioStatistics: Equatable {
    let totalValue: Double
    let totalCost: Double
    let profitLoss: Double
    let profitLossPercentage: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let allocationByType: [String: Double]
    let topPerformers: [PortfolioHolding]
    let worstPerformers: [PortfolioHolding]
}

// MARK: - Portfolio Summary
struct PortfolioSummary: Codable, Equatable {
    let portfolioId: UUID
    let totalValue: Double
    let totalCost: Double
    let profitLoss: Double
    let profitLossPercentage: Double
    let holdingsCount: Int
    let lastUpdated: Date
}

// MARK: - Portfolio Allocation
struct PortfolioAllocation: Identifiable, Equatable {
    let allocationId = UUID()
    var id: UUID { allocationId }
    let category: String
    let value: Double
    let percentage: Double
    let actualPercentage: Double
    let color: String
    let targetPercentage: Double?

    /// Drift from target: positive means overweight, negative means underweight
    var drift: Double {
        actualPercentage - (targetPercentage ?? actualPercentage)
    }

    static func == (lhs: PortfolioAllocation, rhs: PortfolioAllocation) -> Bool {
        lhs.category == rhs.category && lhs.value == rhs.value && lhs.percentage == rhs.percentage
    }

    private static let holdingColors = [
        "#6366F1", "#22C55E", "#F59E0B", "#3B82F6",
        "#EC4899", "#8B5CF6", "#14B8A6", "#F97316",
        "#EF4444", "#06B6D4", "#84CC16", "#A855F7"
    ]

    static func calculate(from holdings: [PortfolioHolding]) -> [PortfolioAllocation] {
        let totalValue = holdings.reduce(0) { $0 + $1.currentValue }
        guard totalValue > 0 else { return [] }

        return holdings
            .sorted { $0.currentValue > $1.currentValue }
            .enumerated()
            .map { index, holding in
                let pct = (holding.currentValue / totalValue) * 100
                return PortfolioAllocation(
                    category: holding.symbol.uppercased(),
                    value: holding.currentValue,
                    percentage: pct,
                    actualPercentage: pct,
                    color: holdingColors[index % holdingColors.count],
                    targetPercentage: holding.targetPercentage
                )
            }
    }

    /// Calculates per-holding allocations within a single asset type category.
    static func calculateByHolding(from holdings: [PortfolioHolding], forAssetType assetType: String) -> [PortfolioAllocation] {
        let filtered = holdings.filter { $0.assetType.lowercased() == assetType.lowercased() }
        let categoryTotal = filtered.reduce(0) { $0 + $1.currentValue }
        guard categoryTotal > 0 else { return [] }

        return filtered
            .sorted { $0.currentValue > $1.currentValue }
            .enumerated()
            .map { index, holding in
                let pct = (holding.currentValue / categoryTotal) * 100
                return PortfolioAllocation(
                    category: holding.symbol.uppercased(),
                    value: holding.currentValue,
                    percentage: pct,
                    actualPercentage: pct,
                    color: holdingColors[index % holdingColors.count],
                    targetPercentage: holding.targetPercentage
                )
            }
    }

    /// Calculates allocations using target percentages for the pie chart.
    /// The `percentage` field (read by the pie chart) is set to the target value,
    /// while `actualPercentage` holds the real market-weight percentage.
    static func calculateWithTargets(from holdings: [PortfolioHolding], totalValue: Double) -> [PortfolioAllocation] {
        guard totalValue > 0 else { return [] }

        return holdings
            .sorted { ($0.targetPercentage ?? 0) > ($1.targetPercentage ?? 0) }
            .enumerated()
            .map { index, holding in
                let actual = (holding.currentValue / totalValue) * 100
                let target = holding.targetPercentage ?? actual
                return PortfolioAllocation(
                    category: holding.symbol.uppercased(),
                    value: holding.currentValue,
                    percentage: target,
                    actualPercentage: actual,
                    color: holdingColors[index % holdingColors.count],
                    targetPercentage: holding.targetPercentage
                )
            }
    }
}

// MARK: - Historical Portfolio Value
struct PortfolioHistoryPoint: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let value: Double
}

// MARK: - What-If Simulation
struct WhatIfSimulation: Equatable {
    let holdingId: UUID
    let symbol: String
    let currentQuantity: Double
    let currentPrice: Double
    let simulatedQuantity: Double
    let simulatedPrice: Double

    var currentValue: Double {
        currentQuantity * currentPrice
    }

    var simulatedValue: Double {
        simulatedQuantity * simulatedPrice
    }

    var difference: Double {
        simulatedValue - currentValue
    }

    var differencePercentage: Double {
        guard currentValue > 0 else { return 0 }
        return (difference / currentValue) * 100
    }
}
