import Foundation

// MARK: - Portfolio Model
struct Portfolio: Codable, Identifiable, Equatable {
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
        updatedAt: Date = Date()
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
    var id: String { category }
    let category: String
    let value: Double
    let percentage: Double
    let color: String

    static func calculate(from holdings: [PortfolioHolding]) -> [PortfolioAllocation] {
        let totalValue = holdings.reduce(0) { $0 + $1.currentValue }
        guard totalValue > 0 else { return [] }

        let grouped = Dictionary(grouping: holdings) { $0.assetType }
        let colors = ["crypto": "#6366F1", "stock": "#22C55E", "metal": "#F59E0B"]

        return grouped.map { type, items in
            let typeValue = items.reduce(0) { $0 + $1.currentValue }
            return PortfolioAllocation(
                category: type.capitalized,
                value: typeValue,
                percentage: (typeValue / totalValue) * 100,
                color: colors[type] ?? "#71717A"
            )
        }.sorted { $0.value > $1.value }
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
