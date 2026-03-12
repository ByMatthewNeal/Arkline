import Foundation

// MARK: - Trade Signal Model

struct TradeSignal: Codable, Identifiable, Equatable {
    let id: UUID
    let asset: String
    let signalType: SignalType
    let status: SignalStatus

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
        case id, asset, status, outcome
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
        case bestPrice = "best_price"
        case runnerStop = "runner_stop"
        case runnerExitPrice = "runner_exit_price"
        case risk1r = "risk_1r"
        case t1PnlPct = "t1_pnl_pct"
        case runnerPnlPct = "runner_pnl_pct"
        case emaTrendAligned = "ema_trend_aligned"
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
    static let assetProfiles: [String: AssetProfile] = [
        "LINK": AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 68.9, shortWinRate: 70.4, profitFactor: 3.25),
        "SUI":  AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 67.5, shortWinRate: 68.1, profitFactor: 3.85),
        "AVAX": AssetProfile(confidence: .high, directionBias: .balanced, longWinRate: 64.9, shortWinRate: 66.0, profitFactor: 3.08),
        "RENDER": AssetProfile(confidence: .high, directionBias: .longPreferred, longWinRate: 78.8, shortWinRate: 60.8, profitFactor: 3.07),
        "APT":  AssetProfile(confidence: .medium, directionBias: .balanced, longWinRate: 67.6, shortWinRate: 65.5, profitFactor: 2.85),
        "ETH":  AssetProfile(confidence: .medium, directionBias: .longPreferred, longWinRate: 71.1, shortWinRate: 60.0, profitFactor: 2.59),
        "ADA":  AssetProfile(confidence: .medium, directionBias: .shortPreferred, longWinRate: 55.2, shortWinRate: 69.0, profitFactor: 2.68),
        "SOL":  AssetProfile(confidence: .medium, directionBias: .longPreferred, longWinRate: 71.1, shortWinRate: 52.9, profitFactor: 2.34),
        "BTC":  AssetProfile(confidence: .low, directionBias: .shortPreferred, longWinRate: 48.5, shortWinRate: 63.0, profitFactor: 1.95),
    ]

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

    /// All assets with backtest data are eligible for Flash Intel.
    var isFlashIntelWorthy: Bool { true }
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
    var entryPctFromTarget1: Double? {
        guard let t1 = target1 else { return nil }
        return ((t1 - entryPriceMid) / entryPriceMid) * 100
    }

    var entryPctFromTarget2: Double? {
        guard let t2 = target2 else { return nil }
        return ((t2 - entryPriceMid) / entryPriceMid) * 100
    }

    var stopLossPct: Double {
        ((stopLoss - entryPriceMid) / entryPriceMid) * 100
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

    var phaseDescription: String {
        if status == .triggered {
            return isT1Hit ? "Runner trailing" : "Watching T1"
        }
        return status.displayName
    }
}
