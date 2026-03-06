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
    let briefingText: String?

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
        case outcomePct = "outcome_pct"
        case durationHours = "duration_hours"
        case generatedAt = "generated_at"
        case triggeredAt = "triggered_at"
        case t1HitAt = "t1_hit_at"
        case closedAt = "closed_at"
        case expiresAt = "expires_at"
        case briefingText = "briefing_text"
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
        case .strongBuy: return "Strong Buy"
        case .buy: return "Buy"
        case .strongSell: return "Strong Sell"
        case .sell: return "Sell"
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
}
