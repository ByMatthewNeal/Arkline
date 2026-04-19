import Foundation

// MARK: - Trade Signal Model

struct TradeSignal: Codable, Identifiable, Equatable {
    let id: UUID
    let asset: String
    let signalType: SignalType
    let status: SignalStatus
    let timeframe: String?  // "1h" (scalp) or "4h" (swing)

    // Entry
    let entryZoneLow: Double
    let entryZoneHigh: Double
    let entryPriceMid: Double
    let confluenceZoneId: UUID?

    // Targets
    let target1: Double?
    let target2: Double?

    // Risk management
    let stopLoss: Double
    let riskRewardRatio: Double
    let invalidationNote: String?

    // Supporting signals
    let btcRiskScore: Double?
    let fearGreedIndex: Int?
    let macroRegime: String?
    let coinbaseRanking: Int?
    let arklineScore: Int?

    // Confirmation
    let bounceConfirmed: Bool
    let confirmationDetails: ConfirmationDetails?
    let counterTrend: Bool?
    let rangeCompressed: Bool?
    let compressionScore: Int?

    // Runner tracking (split exit: 50% at T1, trail runner)
    let bestPrice: Double?
    let runnerStop: Double?
    let runnerExitPrice: Double?
    let risk1r: Double?
    let t1PnlPct: Double?
    let runnerPnlPct: Double?
    let emaTrendAligned: Bool?

    // Outcomes
    let outcome: SignalOutcome?
    let outcomePct: Double?
    let durationHours: Int?

    // Resolution
    let resolutionSource: String?  // "automated" or "manual"

    // Metadata
    let generatedAt: Date
    let triggeredAt: Date?
    let t1HitAt: Date?
    let closedAt: Date?
    let expiresAt: Date?
    let compositeScore: Int?
    let volumeConfluence: VolumeConfluence?
    let briefingText: String?
    let shortRationale: String?
    let cardAnalysis: CardAnalysis?
    let chartPattern: ChartPattern?

    enum CodingKeys: String, CodingKey {
        case id, asset, status, outcome, timeframe
        case signalType = "signal_type"
        case entryZoneLow = "entry_zone_low"
        case entryZoneHigh = "entry_zone_high"
        case entryPriceMid = "entry_price_mid"
        case confluenceZoneId = "confluence_zone_id"
        case target1 = "target_1"
        case target2 = "target_2"
        case stopLoss = "stop_loss"
        case riskRewardRatio = "risk_reward_ratio"
        case invalidationNote = "invalidation_note"
        case btcRiskScore = "btc_risk_score"
        case fearGreedIndex = "fear_greed_index"
        case macroRegime = "macro_regime"
        case coinbaseRanking = "coinbase_ranking"
        case arklineScore = "arkline_score"
        case bounceConfirmed = "bounce_confirmed"
        case confirmationDetails = "confirmation_details"
        case counterTrend = "counter_trend"
        case rangeCompressed = "range_compressed"
        case compressionScore = "compression_score"
        case bestPrice = "best_price"
        case runnerStop = "runner_stop"
        case runnerExitPrice = "runner_exit_price"
        case risk1r = "risk_1r"
        case t1PnlPct = "t1_pnl_pct"
        case runnerPnlPct = "runner_pnl_pct"
        case emaTrendAligned = "ema_trend_aligned"
        case resolutionSource = "resolution_source"
        case outcomePct = "outcome_pct"
        case durationHours = "duration_hours"
        case generatedAt = "generated_at"
        case triggeredAt = "triggered_at"
        case t1HitAt = "t1_hit_at"
        case closedAt = "closed_at"
        case expiresAt = "expires_at"
        case compositeScore = "composite_score"
        case volumeConfluence = "volume_confluence"
        case briefingText = "briefing_text"
        case shortRationale = "short_rationale"
        case cardAnalysis = "card_analysis"
        case chartPattern = "chart_pattern"
    }
}

// MARK: - Volume Confluence

struct VolumeConfluence: Codable, Equatable {
    let hasVolumeConfluence: Bool
    let volumeNodeCount: Int?
    let maxRelativeVolume: Double?

    enum CodingKeys: String, CodingKey {
        case hasVolumeConfluence = "has_volume_confluence"
        case volumeNodeCount = "volume_node_count"
        case maxRelativeVolume = "max_relative_volume"
    }
}

// MARK: - Card Analysis

struct CardAnalysis: Codable, Equatable {
    let narrative: String
    let macroRegimeLabel: String
    let fearGreedLabel: String
    let trendDirection: String
    let confluenceStrength: String

    enum CodingKeys: String, CodingKey {
        case narrative
        case macroRegimeLabel = "macro_regime_label"
        case fearGreedLabel = "fear_greed_label"
        case trendDirection = "trend_direction"
        case confluenceStrength = "confluence_strength"
    }
}

// MARK: - Chart Pattern

struct ChartPattern: Codable, Equatable {
    let name: String
    let type: String        // "reversal" or "continuation"
    let bias: String        // "bullish" or "bearish"
    let timeframe: String
    let confidence: Double
    let description: String
    let neckline: Double?
    let target: Double?

    var confidenceInt: Int { Int(confidence) }

    /// Short name for badge display (strips "Bullish"/"Bearish" prefix)
    var abbreviatedName: String {
        let stripped = name
            .replacingOccurrences(of: "Bullish ", with: "")
            .replacingOccurrences(of: "Bearish ", with: "")
        // Common abbreviations
        switch stripped.lowercased() {
        case "head and shoulders", "head & shoulders":
            return "H&S"
        case "inverse head and shoulders", "inverse head & shoulders":
            return "Inv H&S"
        default:
            return stripped
        }
    }
}

// MARK: - Signal Type

enum SignalType: String, Codable {
    case strongBuy = "strong_buy"
    case buy = "buy"
    case strongSell = "strong_sell"
    case sell = "sell"

    var displayName: String {
        switch self {
        case .strongBuy: return "Strong Long"
        case .buy: return "Long Setup"
        case .strongSell: return "Strong Short"
        case .sell: return "Short Setup"
        }
    }

    var isBuy: Bool {
        self == .strongBuy || self == .buy
    }

    var isStrong: Bool {
        self == .strongBuy || self == .strongSell
    }
}

// MARK: - Signal Status

enum SignalStatus: String, Codable {
    case active
    case triggered
    case invalidated
    case targetHit = "target_hit"
    case expired

    var displayName: String {
        switch self {
        case .active: return "Watching"
        case .triggered: return "In Play"
        case .invalidated: return "Stopped Out"
        case .targetHit: return "Target Hit"
        case .expired: return "Expired"
        }
    }

    var isLive: Bool {
        self == .active || self == .triggered
    }
}

// MARK: - Signal Outcome

enum SignalOutcome: String, Codable {
    case win, loss, partial
}

// MARK: - Confirmation Details

struct ConfirmationDetails: Codable, Equatable {
    let wickRejection: Bool?
    let volumeSpike: Bool?
    let consecutiveCloses: Bool?

    enum CodingKeys: String, CodingKey {
        case wickRejection = "wick_rejection"
        case volumeSpike = "volume_spike"
        case consecutiveCloses = "consecutive_closes"
    }
}

// MARK: - Confluence Zone

struct FibConfluenceZone: Codable, Identifiable, Equatable {
    let id: UUID
    let asset: String
    let zoneType: String
    let zoneLow: Double
    let zoneHigh: Double
    let zoneMid: Double
    let strength: Int
    let contributingLevels: [ContributingLevel]
    let distancePct: Double
    let isActive: Bool
    let computedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, asset, strength
        case zoneType = "zone_type"
        case zoneLow = "zone_low"
        case zoneHigh = "zone_high"
        case zoneMid = "zone_mid"
        case contributingLevels = "contributing_levels"
        case distancePct = "distance_pct"
        case isActive = "is_active"
        case computedAt = "computed_at"
    }
}

struct ContributingLevel: Codable, Equatable {
    let timeframe: String
    let levelName: String
    let price: Double

    enum CodingKeys: String, CodingKey {
        case timeframe
        case levelName = "level_name"
        case price
    }
}

// MARK: - Asset Confidence Profile (Backtest-derived)

/// Backtested performance data per asset used for confidence tiers and direction filtering.
/// Based on 1-year golden pocket backtests (Feb 2025 – Mar 2026).
enum SignalConfidence: String, Comparable {
    case high, medium, low

    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    static func < (lhs: SignalConfidence, rhs: SignalConfidence) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum DirectionBias: String {
    case longPreferred = "long_preferred"
    case shortPreferred = "short_preferred"
    case balanced = "balanced"
}

struct AssetProfile {
    let confidence: SignalConfidence
    let directionBias: DirectionBias
    let longWinRate: Double
    let shortWinRate: Double
    let profitFactor: Double

    /// Whether a given signal direction is weak for this asset.
    func isWeakDirection(isBuy: Bool) -> Bool {
        switch directionBias {
        case .longPreferred: return !isBuy && (longWinRate - shortWinRate) > 10
        case .shortPreferred: return isBuy && (shortWinRate - longWinRate) > 10
        case .balanced: return false
        }
    }
}

extension TradeSignal {
    /// Backtest-derived profiles. Update these when backtests are re-run.
    /// Backtest: 2026-03-22, 365 days, Coinbase data, swing+scalp tiers, live pipeline params
    static let assetProfiles: [String: AssetProfile] = [
        // Current assets
        "BTC":    AssetProfile(confidence: .high, directionBias: .shortPreferred, longWinRate: 70.1, shortWinRate: 78.7, profitFactor: 3.48),
        "ETH":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 78.8, shortWinRate: 80.7, profitFactor: 4.52),
        "SOL":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 76.3, shortWinRate: 76.2, profitFactor: 3.56),
        "SUI":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 82.9, shortWinRate: 75.3, profitFactor: 4.51),
        "LINK":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 82.6, shortWinRate: 77.1, profitFactor: 4.31),
        "ADA":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 77.4, shortWinRate: 81.3, profitFactor: 4.75),
        "AVAX":   AssetProfile(confidence: .high, directionBias: .longPreferred, longWinRate: 79.0, shortWinRate: 70.7, profitFactor: 3.62),
        "RENDER": AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 74.7, shortWinRate: 74.5, profitFactor: 3.55),
        "APT":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 73.8, shortWinRate: 72.8, profitFactor: 3.53),
        "HYPE":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 81.6, shortWinRate: 78.0, profitFactor: 4.43),
        // New assets (2026-03-22)
        "ONDO":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 84.4, shortWinRate: 80.9, profitFactor: 5.31),
        "POL":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 80.3, shortWinRate: 76.1, profitFactor: 4.62),
        "BNB":    AssetProfile(confidence: .high, directionBias: .shortPreferred, longWinRate: 71.7, shortWinRate: 80.8, profitFactor: 4.51),
        "ATOM":   AssetProfile(confidence: .high, directionBias: .longPreferred, longWinRate: 84.6, shortWinRate: 75.3, profitFactor: 4.50),
        "TIA":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 80.7, shortWinRate: 78.1, profitFactor: 4.40),
        "XRP":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 79.6, shortWinRate: 77.1, profitFactor: 4.29),
        "INJ":    AssetProfile(confidence: .high, directionBias: .shortPreferred, longWinRate: 68.6, shortWinRate: 79.5, profitFactor: 3.99),
        "DOGE":   AssetProfile(confidence: .high, directionBias: .longPreferred, longWinRate: 87.2, shortWinRate: 73.0, profitFactor: 3.98),
        "AAVE":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 80.3, shortWinRate: 76.9, profitFactor: 3.52),
        "PEPE":   AssetProfile(confidence: .high, directionBias: .shortPreferred, longWinRate: 64.7, shortWinRate: 78.2, profitFactor: 3.51),
        "ENA":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 71.4, shortWinRate: 74.1, profitFactor: 3.48),
        "FET":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 71.2, shortWinRate: 75.0, profitFactor: 3.43),
        "ARB":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 74.7, shortWinRate: 75.5, profitFactor: 3.25),
        "DOT":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 75.2, shortWinRate: 70.7, profitFactor: 3.23),
        "UNI":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 72.2, shortWinRate: 76.4, profitFactor: 3.13),
        "NEAR":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 75.6, shortWinRate: 70.6, profitFactor: 3.04),
        // New assets (2026-04-10)
        "ALGO":   AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 78.8, shortWinRate: 82.0, profitFactor: 4.91),
        "FIL":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 80.8, shortWinRate: 75.7, profitFactor: 4.53),
        "ZEC":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 74.0, shortWinRate: 79.0, profitFactor: 4.12),
        "VET":    AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 73.3, shortWinRate: 80.7, profitFactor: 4.05),
    ]

    /// Assets currently active in the signal pipeline
    static let activeAssets: Set<String> = ["BTC", "ETH", "SOL", "SUI", "ADA"]

    /// Whether this signal's asset is currently paused from the pipeline
    var isAssetPaused: Bool {
        !Self.activeAssets.contains(asset)
    }

    var assetProfile: AssetProfile {
        Self.assetProfiles[asset] ?? AssetProfile(
            confidence: .medium, directionBias: .balanced,
            longWinRate: 50, shortWinRate: 50, profitFactor: 1.5
        )
    }

    var confidence: SignalConfidence { assetProfile.confidence }

    /// True when this signal goes against the asset's backtested strong direction.
    var isWeakDirection: Bool { assetProfile.isWeakDirection(isBuy: signalType.isBuy) }

    /// True when signal goes against the Bull Market Support Band macro regime.
    var isCounterTrend: Bool { counterTrend == true }
    var isRangeCompressed: Bool { rangeCompressed == true }

    /// All assets with backtest data are eligible for Flash Intel.
    var isFlashIntelWorthy: Bool { true }
}

// MARK: - Timeframe Helpers

extension TradeSignal {
    var isScalp: Bool { timeframe == "1h" }

    var timeframeBadge: String {
        timeframe == "1h" ? "Scalp" : "Swing"
    }
}

// MARK: - Score Helpers

extension TradeSignal {
    var scoreGrade: String? {
        guard let score = compositeScore else { return nil }
        if score >= 90 { return "A+" }
        if score >= 80 { return "A" }
        if score >= 70 { return "B+" }
        if score >= 60 { return "B" }
        return nil // Below B not shown
    }

    var hasVolumeConfluence: Bool {
        volumeConfluence?.hasVolumeConfluence == true
    }
}

// MARK: - Computed Helpers

extension TradeSignal {
    /// Distance to T1 as a positive percentage (profit direction for both longs and shorts)
    var entryPctFromTarget1: Double? {
        guard let t1 = target1 else { return nil }
        let raw = ((t1 - entryPriceMid) / entryPriceMid) * 100
        return signalType.isBuy ? raw : -raw
    }

    /// Distance to T2 as a positive percentage (profit direction for both longs and shorts)
    var entryPctFromTarget2: Double? {
        guard let t2 = target2 else { return nil }
        let raw = ((t2 - entryPriceMid) / entryPriceMid) * 100
        return signalType.isBuy ? raw : -raw
    }

    /// Distance to stop loss as a negative percentage (loss direction for both longs and shorts)
    var stopLossPct: Double {
        let raw = ((stopLoss - entryPriceMid) / entryPriceMid) * 100
        return signalType.isBuy ? raw : -raw
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(generatedAt)
        let hours = Int(interval / 3600)
        if hours < 1 { return "Just now" }
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    var isT1Hit: Bool { t1HitAt != nil }

    var isRunnerPhase: Bool { isT1Hit && status == .triggered }

    var rMultiple: Double? {
        guard let pnl = outcomePct, let r1r = risk1r, r1r > 0 else { return nil }
        let rPct = (r1r / entryPriceMid) * 100
        return rPct > 0 ? pnl / rPct : nil
    }

    var combinedPnlDisplay: String? {
        guard let pnl = outcomePct else { return nil }
        return String(format: "%+.2f%%", pnl)
    }

    /// Maximum favorable excursion — how far price moved in the profitable direction before closing.
    var bestPricePct: Double? {
        guard let best = bestPrice else { return nil }
        let raw = ((best - entryPriceMid) / entryPriceMid) * 100
        return signalType.isBuy ? raw : -raw
    }

    /// "Consider Profit" zone — 30-75% of the way from entry to T1.
    /// Shown on live signals as guidance for active risk management.
    var considerProfitZone: (low: Double, high: Double)? {
        guard let t1 = target1 else { return nil }
        let distance = t1 - entryPriceMid  // positive for longs, negative for shorts
        let low = entryPriceMid + distance * 0.3
        let high = entryPriceMid + distance * 0.75
        return signalType.isBuy ? (low: low, high: high) : (low: high, high: low)
    }

    /// Whether the best price reached at least 50% of the way to T1 (opportunity was there).
    var hadOpportunity: Bool {
        guard let bestPct = bestPricePct, let t1Pct = entryPctFromTarget1, t1Pct > 0 else { return false }
        return bestPct >= t1Pct * 0.5
    }

    var isManuallyResolved: Bool { resolutionSource == "manual" }

    var phaseDescription: String {
        if status == .triggered {
            return isT1Hit ? "Runner trailing" : "Watching T1"
        }
        return status.displayName
    }
}
