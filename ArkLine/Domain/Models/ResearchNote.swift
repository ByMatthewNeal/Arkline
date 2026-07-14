import Foundation

// MARK: - Research Note

/// A published investment thesis backing a model portfolio position.
/// Notes are versioned — a revision inserts a new row that `supersedes` the
/// prior one, so the thinking behind a position is never silently rewritten.
struct ResearchNote: Codable, Identifiable, Hashable {
    let id: UUID
    let ticker: String
    let assetClass: String
    let title: String
    let thesis: String
    let classification: String?
    let slot: String?
    let targetWeight: Double?
    let stage: String?
    let bullCase: String?
    let bearCase: String?
    let upsideDriver: String?
    let downsideRisk: String?
    let invalidation: [InvalidationCriterion]
    let kpis: [String]
    let valuationAtPublish: ValuationSnapshot?
    let bodyMarkdown: String?
    let version: Int
    let supersedes: UUID?
    let publishedAt: Date?

    struct InvalidationCriterion: Codable, Hashable {
        let criterion: String
        let triggered: Bool?
        let triggeredAt: String?

        enum CodingKeys: String, CodingKey {
            case criterion, triggered
            case triggeredAt = "triggered_at"
        }
    }

    /// Valuation metrics frozen at publication — what we saw when we made the call.
    /// Stocks populate PE/PEG fields; crypto populates the Arkline risk model fields.
    struct ValuationSnapshot: Codable, Hashable {
        let price: Double?
        let marketCap: String?
        let pe: Double?
        let forwardPe: Double?
        let peg: Double?
        let evFwdRevenue: Double?
        let riskLevel: Double?
        let riskCategory: String?
        let fairValue: Double?
        let asOf: String?

        enum CodingKeys: String, CodingKey {
            case price, pe, peg
            case marketCap = "market_cap"
            case forwardPe = "forward_pe"
            case evFwdRevenue = "ev_fwd_revenue"
            case riskLevel = "risk_level"
            case riskCategory = "risk_category"
            case fairValue = "fair_value"
            case asOf = "as_of"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, ticker, title, thesis, classification, slot, stage, invalidation, kpis, version, supersedes
        case assetClass = "asset_class"
        case targetWeight = "target_weight"
        case bullCase = "bull_case"
        case bearCase = "bear_case"
        case upsideDriver = "upside_driver"
        case downsideRisk = "downside_risk"
        case valuationAtPublish = "valuation_at_publish"
        case bodyMarkdown = "body_markdown"
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ticker = try c.decode(String.self, forKey: .ticker)
        assetClass = try c.decodeIfPresent(String.self, forKey: .assetClass) ?? "stock"
        title = try c.decode(String.self, forKey: .title)
        thesis = try c.decode(String.self, forKey: .thesis)
        classification = try c.decodeIfPresent(String.self, forKey: .classification)
        slot = try c.decodeIfPresent(String.self, forKey: .slot)
        targetWeight = try c.decodeIfPresent(Double.self, forKey: .targetWeight)
        stage = try c.decodeIfPresent(String.self, forKey: .stage)
        bullCase = try c.decodeIfPresent(String.self, forKey: .bullCase)
        bearCase = try c.decodeIfPresent(String.self, forKey: .bearCase)
        upsideDriver = try c.decodeIfPresent(String.self, forKey: .upsideDriver)
        downsideRisk = try c.decodeIfPresent(String.self, forKey: .downsideRisk)
        invalidation = try c.decodeIfPresent([InvalidationCriterion].self, forKey: .invalidation) ?? []
        kpis = try c.decodeIfPresent([String].self, forKey: .kpis) ?? []
        valuationAtPublish = try c.decodeIfPresent(ValuationSnapshot.self, forKey: .valuationAtPublish)
        bodyMarkdown = try c.decodeIfPresent(String.self, forKey: .bodyMarkdown)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        supersedes = try c.decodeIfPresent(UUID.self, forKey: .supersedes)
        publishedAt = try c.decodeIfPresent(Date.self, forKey: .publishedAt)
    }
}
