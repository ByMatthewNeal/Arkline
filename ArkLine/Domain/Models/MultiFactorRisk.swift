import Foundation

// MARK: - Risk Factor Type
/// Enum representing the 7 risk factors in the multi-factor model.
enum RiskFactorType: String, CaseIterable, Codable {
    case logRegression = "Log Regression"
    case rsi = "RSI"
    case smaPosition = "SMA Position"
    case bullMarketBands = "Bull Market Bands"
    case fundingRate = "Funding Rate"
    case fearGreed = "Fear & Greed"
    case macroRisk = "Macro Risk"

    /// Default weight for this factor in the composite calculation
    var defaultWeight: Double {
        switch self {
        case .logRegression: return 0.35
        case .rsi: return 0.12
        case .smaPosition: return 0.12
        case .bullMarketBands: return 0.11
        case .fundingRate: return 0.10
        case .fearGreed: return 0.10
        case .macroRisk: return 0.10
        }
    }

    /// Human-readable description of the factor
    var description: String {
        switch self {
        case .logRegression:
            return "Fair value deviation based on logarithmic regression"
        case .rsi:
            return "Relative Strength Index (14-period)"
        case .smaPosition:
            return "Price position relative to 200-day SMA"
        case .bullMarketBands:
            return "Position relative to 20W SMA & 21W EMA support"
        case .fundingRate:
            return "Perpetual futures funding rate sentiment"
        case .fearGreed:
            return "Crypto Fear & Greed Index"
        case .macroRisk:
            return "Macro indicators (VIX + DXY average)"
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .logRegression: return "chart.line.uptrend.xyaxis"
        case .rsi: return "waveform.path.ecg"
        case .smaPosition: return "chart.xyaxis.line"
        case .bullMarketBands: return "arrow.up.arrow.down"
        case .fundingRate: return "percent"
        case .fearGreed: return "face.smiling"
        case .macroRisk: return "globe"
        }
    }
}

// MARK: - Risk Factor
/// Individual risk factor with raw and normalized values.
struct RiskFactor: Identifiable, Codable, Equatable {
    var id: String { type.rawValue }

    /// The type of this risk factor
    let type: RiskFactorType

    /// Raw value before normalization (nil if unavailable)
    let rawValue: Double?

    /// Normalized value (0.0 - 1.0, where 1.0 = highest risk)
    let normalizedValue: Double?

    /// Weight applied to this factor
    let weight: Double

    /// Whether this factor's data was available
    var isAvailable: Bool {
        normalizedValue != nil
    }

    /// Weighted contribution to final risk score
    var weightedContribution: Double? {
        guard let normalized = normalizedValue else { return nil }
        return normalized * weight
    }

    /// Display string for raw value
    var rawValueDisplay: String {
        guard let raw = rawValue else { return "N/A" }
        switch type {
        case .logRegression:
            return String(format: "%.2f", raw)
        case .rsi:
            return String(format: "%.1f", raw)
        case .smaPosition:
            return raw > 0.5 ? "Below 200 SMA" : "Above 200 SMA"
        case .bullMarketBands:
            return String(format: "%+.1f%%", raw)
        case .fundingRate:
            return String(format: "%.4f%%", raw * 100)
        case .fearGreed:
            return String(format: "%.0f", raw)
        case .macroRisk:
            return String(format: "%.1f", raw)
        }
    }

    /// Display string for normalized value
    var normalizedValueDisplay: String {
        guard let normalized = normalizedValue else { return "N/A" }
        return String(format: "%.0f%%", normalized * 100)
    }

    // MARK: - Factory Methods

    /// Create an unavailable factor
    static func unavailable(_ type: RiskFactorType, weight: Double) -> RiskFactor {
        RiskFactor(type: type, rawValue: nil, normalizedValue: nil, weight: weight)
    }
}

// MARK: - Risk Factor Weights
/// Configurable weights for the multi-factor model.
struct RiskFactorWeights: Codable, Equatable {
    let logRegression: Double
    let rsi: Double
    let smaPosition: Double
    let bullMarketBands: Double
    let fundingRate: Double
    let fearGreed: Double
    let macroRisk: Double

    /// Default weights (7 factors)
    static let `default` = RiskFactorWeights(
        logRegression: 0.35,
        rsi: 0.12,
        smaPosition: 0.12,
        bullMarketBands: 0.11,
        fundingRate: 0.10,
        fearGreed: 0.10,
        macroRisk: 0.10
    )

    /// Conservative weights (more emphasis on regression)
    static let conservative = RiskFactorWeights(
        logRegression: 0.50,
        rsi: 0.10,
        smaPosition: 0.10,
        bullMarketBands: 0.10,
        fundingRate: 0.08,
        fearGreed: 0.06,
        macroRisk: 0.06
    )

    /// Sentiment-focused weights
    static let sentimentFocused = RiskFactorWeights(
        logRegression: 0.25,
        rsi: 0.12,
        smaPosition: 0.12,
        bullMarketBands: 0.11,
        fundingRate: 0.15,
        fearGreed: 0.15,
        macroRisk: 0.10
    )

    /// Get weight for a specific factor type
    func weight(for type: RiskFactorType) -> Double {
        switch type {
        case .logRegression: return logRegression
        case .rsi: return rsi
        case .smaPosition: return smaPosition
        case .bullMarketBands: return bullMarketBands
        case .fundingRate: return fundingRate
        case .fearGreed: return fearGreed
        case .macroRisk: return macroRisk
        }
    }

    /// Total of all weights (should equal 1.0)
    var total: Double {
        logRegression + rsi + smaPosition + bullMarketBands + fundingRate + fearGreed + macroRisk
    }

    /// Check if weights are valid (sum to 1.0)
    var isValid: Bool {
        abs(total - 1.0) < 0.001
    }
}

// MARK: - Multi-Factor Risk Point
/// Enhanced risk point with full factor breakdown.
struct MultiFactorRiskPoint: Identifiable, Codable, Equatable {
    /// Unique identifier (date-based)
    var id: String { dateString }

    /// Date string in ISO format
    let dateString: String

    /// Actual date
    let date: Date

    /// Composite risk level (0.0 - 1.0)
    let riskLevel: Double

    /// Current price
    let price: Double

    /// Fair value from log regression
    let fairValue: Double

    /// Log deviation from fair value
    let deviation: Double

    /// All individual risk factors
    let factors: [RiskFactor]

    /// Weights used for calculation
    let weights: RiskFactorWeights

    /// Number of factors that were available
    var availableFactorCount: Int {
        factors.filter { $0.isAvailable }.count
    }

    /// Total weight from available factors
    var availableWeight: Double {
        factors.compactMap { $0.isAvailable ? $0.weight : nil }.reduce(0, +)
    }

    /// Risk category based on risk level
    var riskCategory: String {
        RiskHistoryPoint.category(for: riskLevel)
    }

    /// Whether any supplementary factors were available
    var hasSupplementaryFactors: Bool {
        factors.filter { $0.type != .logRegression && $0.isAvailable }.count > 0
    }

    // MARK: - Convenience Accessors

    /// Get a specific factor by type
    func factor(for type: RiskFactorType) -> RiskFactor? {
        factors.first { $0.type == type }
    }

    /// Log regression factor (always present)
    var logRegressionFactor: RiskFactor? {
        factor(for: .logRegression)
    }

    /// RSI factor
    var rsiFactor: RiskFactor? {
        factor(for: .rsi)
    }

    /// SMA position factor
    var smaFactor: RiskFactor? {
        factor(for: .smaPosition)
    }

    /// Funding rate factor
    var fundingFactor: RiskFactor? {
        factor(for: .fundingRate)
    }

    /// Fear & Greed factor
    var fearGreedFactor: RiskFactor? {
        factor(for: .fearGreed)
    }

    /// Macro risk factor (VIX + DXY)
    var macroFactor: RiskFactor? {
        factor(for: .macroRisk)
    }

    // MARK: - Conversion

    /// Convert to legacy RiskHistoryPoint for backward compatibility
    func toRiskHistoryPoint() -> RiskHistoryPoint {
        RiskHistoryPoint(
            dateString: dateString,
            date: date,
            riskLevel: riskLevel,
            price: price,
            fairValue: fairValue,
            deviation: deviation
        )
    }

    // MARK: - Initializers

    init(
        date: Date,
        riskLevel: Double,
        price: Double,
        fairValue: Double,
        deviation: Double,
        factors: [RiskFactor],
        weights: RiskFactorWeights = .default
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateString = formatter.string(from: date)
        self.date = date
        self.riskLevel = riskLevel
        self.price = price
        self.fairValue = fairValue
        self.deviation = deviation
        self.factors = factors
        self.weights = weights
    }

    init(
        dateString: String,
        date: Date,
        riskLevel: Double,
        price: Double,
        fairValue: Double,
        deviation: Double,
        factors: [RiskFactor],
        weights: RiskFactorWeights = .default
    ) {
        self.dateString = dateString
        self.date = date
        self.riskLevel = riskLevel
        self.price = price
        self.fairValue = fairValue
        self.deviation = deviation
        self.factors = factors
        self.weights = weights
    }
}
