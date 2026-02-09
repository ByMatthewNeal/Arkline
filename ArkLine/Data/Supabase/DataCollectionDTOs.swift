import Foundation

// MARK: - Market Snapshot DTO

/// Daily snapshot of a crypto asset's market data
struct MarketSnapshotDTO: Codable {
    let id: UUID
    let coinId: String
    let recordedDate: String
    let currentPrice: Double
    let marketCap: Double?
    let totalVolume: Double?
    let priceChange24h: Double?
    let priceChangePct24h: Double?
    let high24h: Double?
    let low24h: Double?
    let marketCapRank: Int?
    let circulatingSupply: Double?
    let totalSupply: Double?
    let maxSupply: Double?
    let ath: Double?
    let athChangePercentage: Double?
    let atl: Double?
    let atlChangePercentage: Double?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case coinId = "coin_id"
        case recordedDate = "recorded_date"
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case totalVolume = "total_volume"
        case priceChange24h = "price_change_24h"
        case priceChangePct24h = "price_change_pct_24h"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case marketCapRank = "market_cap_rank"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case maxSupply = "max_supply"
        case ath
        case athChangePercentage = "ath_change_percentage"
        case atl
        case atlChangePercentage = "atl_change_percentage"
        case createdAt = "created_at"
    }

    init(from asset: CryptoAsset, date: String) {
        self.id = UUID()
        self.coinId = asset.id
        self.recordedDate = date
        self.currentPrice = asset.currentPrice
        self.marketCap = asset.marketCap
        self.totalVolume = asset.totalVolume
        self.priceChange24h = asset.priceChange24h
        self.priceChangePct24h = asset.priceChangePercentage24h
        self.high24h = asset.high24h
        self.low24h = asset.low24h
        self.marketCapRank = asset.marketCapRank
        self.circulatingSupply = asset.circulatingSupply
        self.totalSupply = asset.totalSupply
        self.maxSupply = asset.maxSupply
        self.ath = asset.ath
        self.athChangePercentage = asset.athChangePercentage
        self.atl = asset.atl
        self.atlChangePercentage = asset.atlChangePercentage
        self.createdAt = nil
    }
}

// MARK: - Indicator Snapshot DTO

/// Daily snapshot of a market indicator (VIX, DXY, M2, Fear/Greed, funding, etc.)
struct IndicatorSnapshotDTO: Codable {
    let id: UUID
    let indicator: String
    let recordedDate: String
    let value: Double
    let metadata: [String: AnyCodableValue]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case indicator
        case recordedDate = "recorded_date"
        case value
        case metadata
        case createdAt = "created_at"
    }

    init(indicator: String, date: String, value: Double, metadata: [String: AnyCodableValue]? = nil) {
        self.id = UUID()
        self.indicator = indicator
        self.recordedDate = date
        self.value = value
        self.metadata = metadata
        self.createdAt = nil
    }
}

/// Type-erased Codable value for JSONB metadata columns
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else { self = .string("") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}

// MARK: - Technicals Snapshot DTO

/// Daily snapshot of technical analysis indicators for a coin
struct TechnicalsSnapshotDTO: Codable {
    let id: UUID
    let coinId: String
    let recordedDate: String
    let rsi: Double?
    let sma21: Double?
    let sma50: Double?
    let sma200: Double?
    let bbUpper: Double?
    let bbMiddle: Double?
    let bbLower: Double?
    let bbBandwidth: Double?
    let bmsbSma20w: Double?
    let bmsbEma21w: Double?
    let trendDirection: String?
    let trendStrength: String?
    let currentPrice: Double?
    let metadata: [String: AnyCodableValue]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case coinId = "coin_id"
        case recordedDate = "recorded_date"
        case rsi
        case sma21 = "sma_21"
        case sma50 = "sma_50"
        case sma200 = "sma_200"
        case bbUpper = "bb_upper"
        case bbMiddle = "bb_middle"
        case bbLower = "bb_lower"
        case bbBandwidth = "bb_bandwidth"
        case bmsbSma20w = "bmsb_sma_20w"
        case bmsbEma21w = "bmsb_ema_21w"
        case trendDirection = "trend_direction"
        case trendStrength = "trend_strength"
        case currentPrice = "current_price"
        case metadata
        case createdAt = "created_at"
    }

    init(from ta: TechnicalAnalysis, date: String) {
        self.id = UUID()
        self.coinId = ta.assetId
        self.recordedDate = date
        self.rsi = ta.rsi.value
        self.sma21 = ta.smaAnalysis.sma21.value
        self.sma50 = ta.smaAnalysis.sma50.value
        self.sma200 = ta.smaAnalysis.sma200.value
        self.bbUpper = ta.bollingerBands.daily.upperBand
        self.bbMiddle = ta.bollingerBands.daily.middleBand
        self.bbLower = ta.bollingerBands.daily.lowerBand
        self.bbBandwidth = ta.bollingerBands.daily.bandwidth
        self.bmsbSma20w = ta.bullMarketBands.sma20Week
        self.bmsbEma21w = ta.bullMarketBands.ema21Week
        self.trendDirection = ta.trend.direction.rawValue
        self.trendStrength = ta.trend.strength.rawValue
        self.currentPrice = ta.currentPrice
        self.metadata = nil
        self.createdAt = nil
    }
}

// MARK: - Risk Snapshot DTO

/// Daily snapshot of the composite ArkLine risk score
struct RiskSnapshotDTO: Codable {
    let id: UUID
    let recordedDate: String
    let compositeScore: Int
    let tier: String
    let recommendation: String?
    let components: [RiskComponentDTO]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recordedDate = "recorded_date"
        case compositeScore = "composite_score"
        case tier
        case recommendation
        case components
        case createdAt = "created_at"
    }

    init(from riskScore: ArkLineRiskScore, date: String) {
        self.id = UUID()
        self.recordedDate = date
        self.compositeScore = riskScore.score
        self.tier = riskScore.tier.rawValue
        self.recommendation = riskScore.recommendation
        self.components = riskScore.components.map {
            RiskComponentDTO(name: $0.name, value: $0.value, weight: $0.weight, signal: $0.signal.rawValue)
        }
        self.createdAt = nil
    }
}

/// Individual risk score component for JSONB storage
struct RiskComponentDTO: Codable {
    let name: String
    let value: Double
    let weight: Double
    let signal: String
}

// MARK: - Analytics Event DTO

/// Generic user behavior event
struct AnalyticsEventDTO: Codable {
    let id: UUID
    let userId: UUID?
    let eventName: String
    let properties: [String: AnyCodableValue]?
    let sessionId: UUID?
    let deviceInfo: [String: AnyCodableValue]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventName = "event_name"
        case properties
        case sessionId = "session_id"
        case deviceInfo = "device_info"
        case createdAt = "created_at"
    }

    init(userId: UUID?, eventName: String, properties: [String: AnyCodableValue]? = nil, sessionId: UUID?, deviceInfo: [String: AnyCodableValue]? = nil) {
        self.id = UUID()
        self.userId = userId
        self.eventName = eventName
        self.properties = properties
        self.sessionId = sessionId
        self.deviceInfo = deviceInfo
        self.createdAt = nil
    }
}

// MARK: - Daily Active User DTO

/// Aggregated daily usage per user
struct DailyActiveUserDTO: Codable {
    let id: UUID
    let userId: UUID
    let recordedDate: String
    let sessionCount: Int
    let screenViews: Int
    let coinsViewed: [String]
    let appVersion: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recordedDate = "recorded_date"
        case sessionCount = "session_count"
        case screenViews = "screen_views"
        case coinsViewed = "coins_viewed"
        case appVersion = "app_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(userId: UUID, date: String, sessionCount: Int = 1, screenViews: Int = 0, coinsViewed: [String] = [], appVersion: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.recordedDate = date
        self.sessionCount = sessionCount
        self.screenViews = screenViews
        self.coinsViewed = coinsViewed
        self.appVersion = appVersion
        self.createdAt = nil
        self.updatedAt = nil
    }
}
