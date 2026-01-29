import Foundation

// MARK: - DCA Strategy Type
enum DCAStrategyType: String, CaseIterable, Identifiable {
    case timeBased = "Time-Based"
    case riskBased = "Risk-Based"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .timeBased: return "calendar"
        case .riskBased: return "gauge.with.dots.needle.50percent"
        }
    }

    var description: String {
        switch self {
        case .timeBased: return "Invest on a regular schedule"
        case .riskBased: return "Invest when BTC risk hits target levels"
        }
    }
}

// MARK: - Risk Band for DCA
enum DCABTCRiskBand: String, CaseIterable, Identifiable {
    case veryLow = "Very Low"
    case low = "Low"
    case neutral = "Neutral"
    case high = "High"
    case veryHigh = "Very High"

    var id: String { rawValue }

    var riskRange: ClosedRange<Double> {
        switch self {
        case .veryLow: return 0...20
        case .low: return 20...40
        case .neutral: return 40...60
        case .high: return 60...80
        case .veryHigh: return 80...100
        }
    }

    var color: String {
        switch self {
        case .veryLow: return "00C853"   // Green
        case .low: return "64DD17"       // Light green
        case .neutral: return "FFD600"   // Yellow
        case .high: return "FF9100"      // Orange
        case .veryHigh: return "FF1744"  // Red
        }
    }

    var investmentAdvice: String {
        switch self {
        case .veryLow: return "Excellent time to accumulate"
        case .low: return "Good buying opportunity"
        case .neutral: return "Consider dollar cost averaging"
        case .high: return "Be cautious, consider taking profits"
        case .veryHigh: return "High risk, avoid large purchases"
        }
    }

    /// Returns bands recommended for DCA (typically lower risk)
    static var recommendedForDCA: [DCABTCRiskBand] {
        [.veryLow, .low, .neutral]
    }
}

// MARK: - DCA Calculation Result
struct DCACalculation: Equatable {
    let totalAmount: Double
    let asset: DCAAsset
    let strategyType: DCAStrategyType
    let targetPortfolioId: UUID?
    let targetPortfolioName: String?

    // Time-based fields
    let frequency: DCAFrequency
    let duration: DCADuration
    let startDate: Date
    let selectedDays: Set<Weekday>

    // Risk-based fields
    let riskBands: Set<DCABTCRiskBand>

    // Computed properties for time-based DCA
    var numberOfPurchases: Int {
        guard strategyType == .timeBased else { return 0 }
        return DCACalculatorService.purchaseCount(
            frequency: frequency,
            duration: duration,
            selectedDays: selectedDays
        )
    }

    var amountPerPurchase: Double {
        guard strategyType == .timeBased else { return totalAmount }
        guard numberOfPurchases > 0 else { return 0 }
        return totalAmount / Double(numberOfPurchases)
    }

    var purchaseDates: [Date] {
        guard strategyType == .timeBased else { return [] }
        return DCACalculatorService.generatePurchaseDates(
            frequency: frequency,
            duration: duration,
            startDate: startDate,
            selectedDays: selectedDays
        )
    }

    var endDate: Date? {
        purchaseDates.last
    }

    var formattedAmountPerPurchase: String {
        amountPerPurchase.asCurrency
    }

    var formattedTotalAmount: String {
        totalAmount.asCurrency
    }

    // Risk-based helpers
    var riskBandDescription: String {
        guard strategyType == .riskBased else { return "" }
        let sortedBands = riskBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
        return sortedBands.map { $0.rawValue }.joined(separator: ", ")
    }

    var riskRangeDescription: String {
        guard strategyType == .riskBased, !riskBands.isEmpty else { return "" }
        let sortedBands = riskBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
        guard let firstBand = sortedBands.first, let lastBand = sortedBands.last else { return "" }
        let minRisk = Int(firstBand.riskRange.lowerBound)
        let maxRisk = Int(lastBand.riskRange.upperBound)
        return "\(minRisk) - \(maxRisk)"
    }
}

// MARK: - DCA Duration
enum DCADuration: Equatable, Hashable {
    case threeMonths
    case sixMonths
    case oneYear
    case twoYears
    case custom(months: Int)

    var displayName: String {
        switch self {
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        case .twoYears: return "2 years"
        case .custom(let months): return "\(months) months"
        }
    }

    var months: Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .twoYears: return 24
        case .custom(let months): return months
        }
    }

    var approximateWeeks: Int {
        // Approximate 4.33 weeks per month
        return Int(Double(months) * 4.33)
    }

    var approximateDays: Int {
        // Approximate 30.44 days per month
        return Int(Double(months) * 30.44)
    }

    static var presets: [DCADuration] {
        [.threeMonths, .sixMonths, .oneYear, .twoYears]
    }
}

// MARK: - Weekday
enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    /// Weekdays only (Mon-Fri)
    static var weekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    /// Weekend days (Sat-Sun)
    static var weekend: [Weekday] {
        [.saturday, .sunday]
    }
}

// MARK: - DCA Asset
struct DCAAsset: Equatable, Identifiable, Hashable {
    let id: String  // Use symbol as stable ID
    let symbol: String
    let name: String
    let type: DCAAssetType

    init(symbol: String, name: String, type: DCAAssetType) {
        self.id = symbol  // Stable ID based on symbol
        self.symbol = symbol
        self.name = name
        self.type = type
    }

    // Common crypto assets
    static let bitcoin = DCAAsset(symbol: "BTC", name: "Bitcoin", type: .crypto)
    static let ethereum = DCAAsset(symbol: "ETH", name: "Ethereum", type: .crypto)
    static let solana = DCAAsset(symbol: "SOL", name: "Solana", type: .crypto)

    // Common stocks
    static let nvidia = DCAAsset(symbol: "NVDA", name: "NVIDIA", type: .stock)
    static let apple = DCAAsset(symbol: "AAPL", name: "Apple", type: .stock)
    static let tesla = DCAAsset(symbol: "TSLA", name: "Tesla", type: .stock)

    // Commodities
    static let gold = DCAAsset(symbol: "GOLD", name: "Gold", type: .commodity)
    static let silver = DCAAsset(symbol: "SILVER", name: "Silver", type: .commodity)
}

// MARK: - DCA Asset Type
enum DCAAssetType: String, CaseIterable, Identifiable {
    case crypto = "Crypto"
    case stock = "Stocks"
    case commodity = "Commodities"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle"
        case .stock: return "chart.line.uptrend.xyaxis"
        case .commodity: return "cube.box"
        }
    }
}

// MARK: - Predefined Asset Lists
extension DCAAsset {
    static var cryptoAssets: [DCAAsset] {
        [
            DCAAsset(symbol: "BTC", name: "Bitcoin", type: .crypto),
            DCAAsset(symbol: "ETH", name: "Ethereum", type: .crypto),
            DCAAsset(symbol: "SOL", name: "Solana", type: .crypto),
            DCAAsset(symbol: "ADA", name: "Cardano", type: .crypto),
            DCAAsset(symbol: "DOT", name: "Polkadot", type: .crypto),
            DCAAsset(symbol: "AVAX", name: "Avalanche", type: .crypto),
            DCAAsset(symbol: "LINK", name: "Chainlink", type: .crypto),
            DCAAsset(symbol: "DOGE", name: "Dogecoin", type: .crypto),
            DCAAsset(symbol: "XRP", name: "XRP", type: .crypto),
            DCAAsset(symbol: "MATIC", name: "Polygon", type: .crypto),
        ]
    }

    static var stockAssets: [DCAAsset] {
        [
            DCAAsset(symbol: "NVDA", name: "NVIDIA", type: .stock),
            DCAAsset(symbol: "AAPL", name: "Apple", type: .stock),
            DCAAsset(symbol: "MSFT", name: "Microsoft", type: .stock),
            DCAAsset(symbol: "GOOGL", name: "Alphabet", type: .stock),
            DCAAsset(symbol: "AMZN", name: "Amazon", type: .stock),
            DCAAsset(symbol: "TSLA", name: "Tesla", type: .stock),
            DCAAsset(symbol: "META", name: "Meta", type: .stock),
            DCAAsset(symbol: "SPY", name: "S&P 500 ETF", type: .stock),
            DCAAsset(symbol: "QQQ", name: "Nasdaq 100 ETF", type: .stock),
            DCAAsset(symbol: "VOO", name: "Vanguard S&P 500", type: .stock),
        ]
    }

    static var commodityAssets: [DCAAsset] {
        [
            DCAAsset(symbol: "GOLD", name: "Gold", type: .commodity),
            DCAAsset(symbol: "SILVER", name: "Silver", type: .commodity),
            DCAAsset(symbol: "OIL", name: "Crude Oil", type: .commodity),
            DCAAsset(symbol: "PLAT", name: "Platinum", type: .commodity),
        ]
    }

    static func assets(for type: DCAAssetType) -> [DCAAsset] {
        switch type {
        case .crypto: return cryptoAssets
        case .stock: return stockAssets
        case .commodity: return commodityAssets
        }
    }
}
