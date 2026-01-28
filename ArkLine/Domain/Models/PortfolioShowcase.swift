import Foundation
import SwiftUI

// MARK: - Privacy Level

/// Defines how much financial information to reveal in showcase
enum PrivacyLevel: String, Codable, CaseIterable, Identifiable {
    case full           // Show dollar amounts, quantities, percentages
    case percentageOnly // Hide dollars, show only percentages and allocation
    case performanceOnly // Hide all amounts, show only gains/losses as %
    case anonymous      // Show only asset names and allocation pie, no numbers

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .full: return "Full Details"
        case .percentageOnly: return "Percentages Only"
        case .performanceOnly: return "Performance Only"
        case .anonymous: return "Anonymous"
        }
    }

    var icon: String {
        switch self {
        case .full: return "eye"
        case .percentageOnly: return "percent"
        case .performanceOnly: return "chart.line.uptrend.xyaxis"
        case .anonymous: return "eye.slash"
        }
    }

    var description: String {
        switch self {
        case .full: return "Show all amounts and quantities"
        case .percentageOnly: return "Hide dollar amounts"
        case .performanceOnly: return "Show only gain/loss %"
        case .anonymous: return "Hide all numbers"
        }
    }
}

// MARK: - Portfolio Snapshot

/// A frozen snapshot of portfolio data for sharing
struct PortfolioSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let portfolioId: UUID
    let portfolioName: String
    let snapshotDate: Date
    let privacyLevel: PrivacyLevel

    // Summary data (privacy-filtered - nil if hidden)
    let totalValue: Double?
    let totalCost: Double?
    let totalProfitLoss: Double?
    let profitLossPercentage: Double?
    let dayChange: Double?
    let dayChangePercentage: Double?

    // Holdings snapshot
    let holdings: [HoldingSnapshot]
    let allocations: [AllocationSnapshot]

    // Metadata
    let assetCount: Int
    let primaryAssetType: String

    /// Create a privacy-filtered snapshot from a portfolio
    init(
        from portfolio: Portfolio,
        holdings: [PortfolioHolding],
        privacyLevel: PrivacyLevel
    ) {
        self.id = UUID()
        self.portfolioId = portfolio.id
        self.portfolioName = portfolio.name
        self.snapshotDate = Date()
        self.privacyLevel = privacyLevel

        // Calculate totals
        let totalValue = holdings.reduce(0) { $0 + $1.currentValue }
        let totalCost = holdings.reduce(0) { $0 + $1.totalCost }
        let profitLoss = totalValue - totalCost
        let profitLossPercentage = totalCost > 0 ? (profitLoss / totalCost) * 100 : 0
        let dayChange = holdings.reduce(0) { $0 + ($1.priceChange24h ?? 0) * $1.quantity }
        let dayChangePercentage = totalValue > 0 ? (dayChange / (totalValue - dayChange)) * 100 : 0

        // Apply privacy filtering
        switch privacyLevel {
        case .full:
            self.totalValue = totalValue
            self.totalCost = totalCost
            self.totalProfitLoss = profitLoss
            self.profitLossPercentage = profitLossPercentage
            self.dayChange = dayChange
            self.dayChangePercentage = dayChangePercentage

        case .percentageOnly:
            self.totalValue = nil
            self.totalCost = nil
            self.totalProfitLoss = nil
            self.profitLossPercentage = profitLossPercentage
            self.dayChange = nil
            self.dayChangePercentage = dayChangePercentage

        case .performanceOnly:
            self.totalValue = nil
            self.totalCost = nil
            self.totalProfitLoss = nil
            self.profitLossPercentage = profitLossPercentage
            self.dayChange = nil
            self.dayChangePercentage = dayChangePercentage

        case .anonymous:
            self.totalValue = nil
            self.totalCost = nil
            self.totalProfitLoss = nil
            self.profitLossPercentage = nil
            self.dayChange = nil
            self.dayChangePercentage = nil
        }

        // Generate holdings snapshots with privacy
        self.holdings = holdings
            .sorted { $0.currentValue > $1.currentValue }
            .map { HoldingSnapshot(from: $0, privacyLevel: privacyLevel, portfolioTotalValue: totalValue) }

        // Generate allocation snapshots
        self.allocations = PortfolioAllocation.calculate(from: holdings)
            .map { AllocationSnapshot(from: $0, privacyLevel: privacyLevel) }

        self.assetCount = holdings.count
        self.primaryAssetType = Self.determinePrimaryAssetType(holdings)
    }

    /// Manual initializer for decoding
    init(
        id: UUID,
        portfolioId: UUID,
        portfolioName: String,
        snapshotDate: Date,
        privacyLevel: PrivacyLevel,
        totalValue: Double?,
        totalCost: Double?,
        totalProfitLoss: Double?,
        profitLossPercentage: Double?,
        dayChange: Double?,
        dayChangePercentage: Double?,
        holdings: [HoldingSnapshot],
        allocations: [AllocationSnapshot],
        assetCount: Int,
        primaryAssetType: String
    ) {
        self.id = id
        self.portfolioId = portfolioId
        self.portfolioName = portfolioName
        self.snapshotDate = snapshotDate
        self.privacyLevel = privacyLevel
        self.totalValue = totalValue
        self.totalCost = totalCost
        self.totalProfitLoss = totalProfitLoss
        self.profitLossPercentage = profitLossPercentage
        self.dayChange = dayChange
        self.dayChangePercentage = dayChangePercentage
        self.holdings = holdings
        self.allocations = allocations
        self.assetCount = assetCount
        self.primaryAssetType = primaryAssetType
    }

    private static func determinePrimaryAssetType(_ holdings: [PortfolioHolding]) -> String {
        let grouped = Dictionary(grouping: holdings) { $0.assetType }
        let byValue = grouped.mapValues { items in
            items.reduce(0) { $0 + $1.currentValue }
        }

        if let (type, _) = byValue.max(by: { $0.value < $1.value }) {
            // Check if it's dominant (>70%)
            let total = byValue.values.reduce(0, +)
            if let typeValue = byValue[type], total > 0, (typeValue / total) > 0.7 {
                return type
            }
        }
        return "mixed"
    }

    /// Whether this is a profitable portfolio
    var isProfit: Bool {
        (profitLossPercentage ?? 0) >= 0
    }
}

// MARK: - Holding Snapshot

/// A privacy-filtered snapshot of a single holding
struct HoldingSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let name: String
    let assetType: String
    let iconUrl: String?

    // Privacy-filtered fields (nil if hidden)
    let quantity: Double?
    let currentValue: Double?
    let profitLoss: Double?
    let profitLossPercentage: Double?
    let allocationPercentage: Double

    init(
        from holding: PortfolioHolding,
        privacyLevel: PrivacyLevel,
        portfolioTotalValue: Double
    ) {
        self.id = holding.id
        self.symbol = holding.symbol
        self.name = holding.name
        self.assetType = holding.assetType
        self.iconUrl = holding.iconUrl

        let allocation = portfolioTotalValue > 0 ? (holding.currentValue / portfolioTotalValue) * 100 : 0

        switch privacyLevel {
        case .full:
            self.quantity = holding.quantity
            self.currentValue = holding.currentValue
            self.profitLoss = holding.profitLoss
            self.profitLossPercentage = holding.profitLossPercentage
            self.allocationPercentage = allocation

        case .percentageOnly:
            self.quantity = nil
            self.currentValue = nil
            self.profitLoss = nil
            self.profitLossPercentage = holding.profitLossPercentage
            self.allocationPercentage = allocation

        case .performanceOnly:
            self.quantity = nil
            self.currentValue = nil
            self.profitLoss = nil
            self.profitLossPercentage = holding.profitLossPercentage
            self.allocationPercentage = allocation

        case .anonymous:
            self.quantity = nil
            self.currentValue = nil
            self.profitLoss = nil
            self.profitLossPercentage = nil
            self.allocationPercentage = allocation
        }
    }

    /// Manual initializer for decoding
    init(
        id: UUID,
        symbol: String,
        name: String,
        assetType: String,
        iconUrl: String?,
        quantity: Double?,
        currentValue: Double?,
        profitLoss: Double?,
        profitLossPercentage: Double?,
        allocationPercentage: Double
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.assetType = assetType
        self.iconUrl = iconUrl
        self.quantity = quantity
        self.currentValue = currentValue
        self.profitLoss = profitLoss
        self.profitLossPercentage = profitLossPercentage
        self.allocationPercentage = allocationPercentage
    }

    /// Whether this holding is profitable
    var isProfit: Bool {
        (profitLossPercentage ?? 0) >= 0
    }
}

// MARK: - Allocation Snapshot

/// A privacy-filtered allocation entry
struct AllocationSnapshot: Codable, Identifiable, Equatable {
    var id: String { category }
    let category: String
    let percentage: Double
    let value: Double?
    let color: String

    init(from allocation: PortfolioAllocation, privacyLevel: PrivacyLevel) {
        self.category = allocation.category
        self.percentage = allocation.percentage
        self.color = allocation.color

        switch privacyLevel {
        case .full:
            self.value = allocation.value
        case .percentageOnly, .performanceOnly, .anonymous:
            self.value = nil
        }
    }

    init(category: String, percentage: Double, value: Double?, color: String) {
        self.category = category
        self.percentage = percentage
        self.value = value
        self.color = color
    }

    /// SwiftUI Color from hex string
    var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Showcase Configuration

/// Configuration for a dual-portfolio showcase
struct ShowcaseConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var leftPortfolioId: UUID?
    var rightPortfolioId: UUID?
    var privacyLevel: PrivacyLevel
    var showTimestamp: Bool
    var showBranding: Bool
    var theme: ShowcaseTheme
    var comparisonMetric: ComparisonMetric

    init(
        id: UUID = UUID(),
        leftPortfolioId: UUID? = nil,
        rightPortfolioId: UUID? = nil,
        privacyLevel: PrivacyLevel = .percentageOnly,
        showTimestamp: Bool = true,
        showBranding: Bool = true,
        theme: ShowcaseTheme = .dark,
        comparisonMetric: ComparisonMetric = .performance
    ) {
        self.id = id
        self.leftPortfolioId = leftPortfolioId
        self.rightPortfolioId = rightPortfolioId
        self.privacyLevel = privacyLevel
        self.showTimestamp = showTimestamp
        self.showBranding = showBranding
        self.theme = theme
        self.comparisonMetric = comparisonMetric
    }
}

enum ShowcaseTheme: String, Codable, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }
}

enum ComparisonMetric: String, Codable, CaseIterable, Identifiable {
    case totalValue
    case performance
    case allocation
    case holdings

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .totalValue: return "Total Value"
        case .performance: return "Performance"
        case .allocation: return "Allocation"
        case .holdings: return "Holdings"
        }
    }

    var icon: String {
        switch self {
        case .totalValue: return "dollarsign.circle"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .allocation: return "chart.pie"
        case .holdings: return "list.bullet"
        }
    }
}

// MARK: - Broadcast Portfolio Attachment

/// A portfolio snapshot attachment for broadcasts
struct BroadcastPortfolioAttachment: Codable, Identifiable, Equatable {
    let id: UUID
    let leftSnapshot: PortfolioSnapshot?
    let rightSnapshot: PortfolioSnapshot?
    let renderedImageURL: URL?
    let privacyLevel: PrivacyLevel
    let caption: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case leftSnapshot = "left_snapshot"
        case rightSnapshot = "right_snapshot"
        case renderedImageURL = "rendered_image_url"
        case privacyLevel = "privacy_level"
        case caption
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        leftSnapshot: PortfolioSnapshot? = nil,
        rightSnapshot: PortfolioSnapshot? = nil,
        renderedImageURL: URL? = nil,
        privacyLevel: PrivacyLevel = .percentageOnly,
        caption: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.leftSnapshot = leftSnapshot
        self.rightSnapshot = rightSnapshot
        self.renderedImageURL = renderedImageURL
        self.privacyLevel = privacyLevel
        self.caption = caption
        self.createdAt = createdAt
    }

    /// Whether this attachment has at least one portfolio
    var hasContent: Bool {
        leftSnapshot != nil || rightSnapshot != nil
    }

    /// Whether this is a comparison (two portfolios)
    var isComparison: Bool {
        leftSnapshot != nil && rightSnapshot != nil
    }
}
