import Foundation

// MARK: - Model Portfolio

struct ModelPortfolio: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let strategy: String
    let description: String?
    let universe: [String]
    let startingNav: Double
    let createdAt: Date?

    var isCore: Bool { strategy == "core" }
    var isEdge: Bool { strategy == "edge" }
    var isAlpha: Bool { strategy == "alpha" }

    enum CodingKeys: String, CodingKey {
        case id, name, strategy, description, universe
        case startingNav = "starting_nav"
        case createdAt = "created_at"
    }
}

// MARK: - NAV Snapshot

struct ModelPortfolioNav: Codable, Identifiable, Hashable {
    let id: UUID
    let portfolioId: UUID
    let navDate: String
    let nav: Double
    let allocations: [String: AllocationDetail]
    let btcSignal: String?
    let btcRiskLevel: Double?
    let btcRiskCategory: String?
    let goldSignal: String?
    let macroRegime: String?
    let dominantAlt: String?
    let createdAt: Date?

    var returnPct: Double {
        ((nav / 50000) - 1) * 100
    }

    enum CodingKeys: String, CodingKey {
        case id, nav, allocations
        case portfolioId = "portfolio_id"
        case navDate = "nav_date"
        case btcSignal = "btc_signal"
        case btcRiskLevel = "btc_risk_level"
        case btcRiskCategory = "btc_risk_category"
        case goldSignal = "gold_signal"
        case macroRegime = "macro_regime"
        case dominantAlt = "dominant_alt"
        case createdAt = "created_at"
    }

    struct AllocationDetail: Codable, Hashable {
        let pct: Double
        let value: Double?
        let qty: Double?

        init(from decoder: Decoder) throws {
            // Handle both formats: {pct, value, qty} or raw number
            if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                pct = try container.decode(Double.self, forKey: .pct)
                value = try container.decodeIfPresent(Double.self, forKey: .value)
                qty = try container.decodeIfPresent(Double.self, forKey: .qty)
            } else {
                // Raw number (backfill format: {"BTC": 60.0})
                let single = try decoder.singleValueContainer()
                pct = try single.decode(Double.self)
                value = nil
                qty = nil
            }
        }

        enum CodingKeys: String, CodingKey {
            case pct, value, qty
        }
    }
}

// MARK: - Trade Log

struct ModelPortfolioTrade: Codable, Identifiable, Hashable {
    let id: UUID
    let portfolioId: UUID
    let tradeDate: String
    let trigger: String
    let fromAllocation: [String: Double]
    let toAllocation: [String: Double]
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, trigger
        case portfolioId = "portfolio_id"
        case tradeDate = "trade_date"
        case fromAllocation = "from_allocation"
        case toAllocation = "to_allocation"
        case createdAt = "created_at"
    }
}

// MARK: - Benchmark NAV

struct BenchmarkNav: Codable, Identifiable, Hashable {
    let id: UUID
    let navDate: String
    let spyPrice: Double
    let nav: Double
    let createdAt: Date?

    var returnPct: Double {
        ((nav / 50000) - 1) * 100
    }

    enum CodingKeys: String, CodingKey {
        case id, nav
        case navDate = "nav_date"
        case spyPrice = "spy_price"
        case createdAt = "created_at"
    }
}

// MARK: - Risk History

struct ModelPortfolioRiskHistory: Codable, Identifiable, Hashable {
    let id: UUID
    let asset: String
    let riskDate: String
    let riskLevel: Double
    let price: Double
    let fairValue: Double
    let deviation: Double
    let createdAt: Date?

    var riskCategory: String {
        if riskLevel < 0.20 { return "Very Low Risk" }
        if riskLevel < 0.40 { return "Low Risk" }
        if riskLevel < 0.55 { return "Neutral" }
        if riskLevel < 0.70 { return "Elevated Risk" }
        if riskLevel < 0.90 { return "High Risk" }
        return "Extreme Risk"
    }

    enum CodingKeys: String, CodingKey {
        case id, asset, price, deviation
        case riskDate = "risk_date"
        case riskLevel = "risk_level"
        case fairValue = "fair_value"
        case createdAt = "created_at"
    }
}
