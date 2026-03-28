import Foundation

// MARK: - Market Update Deck

struct MarketUpdateDeck: Codable, Identifiable, Hashable {
    static func == (lhs: MarketUpdateDeck, rhs: MarketUpdateDeck) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    let weekStart: Date
    let weekEnd: Date
    var status: DeckStatus
    var slides: [DeckSlide]
    var adminNotes: String?
    var adminContext: AdminContext?
    let publishedAt: Date?
    let createdAt: Date

    enum DeckStatus: String, Codable {
        case draft, published, archived
    }

    enum CodingKeys: String, CodingKey {
        case id
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case status, slides
        case adminNotes = "admin_notes"
        case adminContext = "admin_context"
        case publishedAt = "published_at"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        status = try container.decode(DeckStatus.self, forKey: .status)
        slides = try container.decode([DeckSlide].self, forKey: .slides)
        adminNotes = try container.decodeIfPresent(String.self, forKey: .adminNotes)
        adminContext = try container.decodeIfPresent(AdminContext.self, forKey: .adminContext)

        // Dates: Supabase returns DATE columns as "yyyy-MM-dd" and TIMESTAMPTZ as ISO8601
        weekStart = try Self.decodeDate(from: container, forKey: .weekStart)
        weekEnd = try Self.decodeDate(from: container, forKey: .weekEnd)
        createdAt = try Self.decodeDate(from: container, forKey: .createdAt)
        publishedAt = try? Self.decodeDate(from: container, forKey: .publishedAt)
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date {
        // Try decoding as Date first (in case decoder already handles it)
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        // Fall back to string parsing
        let string = try container.decode(String.self, forKey: key)
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        // Try with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        // Try date-only format (from DATE columns)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        if let date = df.date(from: string) { return date }
        // Try Supabase timestamptz format: "2026-03-26T22:00:00.000000+00:00"
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
        if let date = df.date(from: string) { return date }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        if let date = df.date(from: string) { return date }
        throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Cannot decode date: \(string)")
    }

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: weekStart)
        formatter.dateFormat = "d, yyyy"
        let end = formatter.string(from: weekEnd)
        return "\(start)-\(end)"
    }
}

// MARK: - Admin Context

/// Stores per-slide admin notes and global insights for narrative regeneration.
struct AdminContext: Codable {
    var slideNotes: [String: String]
    var insights: String
    var attachments: [InsightAttachment]?

    enum CodingKeys: String, CodingKey {
        case slideNotes = "slide_notes"
        case insights
        case attachments
    }

    init(slideNotes: [String: String] = [:], insights: String = "", attachments: [InsightAttachment]? = nil) {
        self.slideNotes = slideNotes
        self.insights = insights
        self.attachments = attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slideNotes = (try? container.decode([String: String].self, forKey: .slideNotes)) ?? [:]
        insights = (try? container.decode(String.self, forKey: .insights)) ?? ""
        attachments = try? container.decode([InsightAttachment].self, forKey: .attachments)
    }
}

/// An attachment added by admin to provide additional context for deck generation.
struct InsightAttachment: Codable, Identifiable {
    var id: String { storagePath ?? url ?? label ?? UUID().uuidString }
    let type: AttachmentType
    let storagePath: String?   // Supabase storage path (for images/PDFs)
    let url: String?           // External URL
    let label: String?         // User description
    let extractedText: String? // Pre-extracted text from PDFs

    enum AttachmentType: String, Codable {
        case image, pdf, url
    }

    enum CodingKeys: String, CodingKey {
        case type
        case storagePath = "storage_path"
        case url, label
        case extractedText = "extracted_text"
    }
}

// MARK: - Deck Slide

struct DeckSlide: Codable, Identifiable {
    var id: String { "\(type.rawValue)_\(title)" }
    let type: SlideType
    let title: String
    var data: SlideData

    enum SlideType: String, Codable, CaseIterable {
        case cover, marketPulse, macro, positioning, economic, setups, rundown
        case sectionTitle, editorial, snapshot, weeklyOutlook, correlation

        var displayName: String {
            switch self {
            case .cover: return "Cover"
            case .marketPulse: return "Market Pulse"
            case .macro: return "Macro Dashboard"
            case .positioning: return "Positioning"
            case .economic: return "Economic Calendar"
            case .setups: return "Active Setups"
            case .rundown: return "The Rundown"
            case .sectionTitle: return "Section"
            case .editorial: return "Analysis"
            case .snapshot: return "Arkline Snapshot"
            case .weeklyOutlook: return "Weekly Outlook"
            case .correlation: return "Cross-Market"
            }
        }

        var icon: String {
            switch self {
            case .cover: return "rectangle.portrait"
            case .marketPulse: return "chart.line.uptrend.xyaxis"
            case .macro: return "chart.bar.xaxis"
            case .positioning: return "waveform.path.ecg"
            case .economic: return "calendar"
            case .setups: return "scope"
            case .rundown: return "text.alignleft"
            case .sectionTitle: return "text.badge.star"
            case .editorial: return "doc.text"
            case .snapshot: return "gauge.with.dots.needle.33percent"
            case .weeklyOutlook: return "eye.circle"
            case .correlation: return "arrow.triangle.branch"
            }
        }
    }
}

// MARK: - Slide Data

enum SlideData: Codable {
    case cover(CoverSlideData)
    case marketPulse(MarketPulseSlideData)
    case macro(MacroSlideData)
    case positioning(PositioningSlideData)
    case economic(EconomicSlideData)
    case setups(SetupsSlideData)
    case rundown(RundownSlideData)
    case sectionTitle(SectionTitleSlideData)
    case editorial(EditorialSlideData)
    case snapshot(SnapshotSlideData)
    case weeklyOutlook(WeeklyOutlookSlideData)
    case correlation(CorrelationSlideData)

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "cover":
            self = .cover(try container.decode(CoverSlideData.self, forKey: .payload))
        case "marketPulse":
            self = .marketPulse(try container.decode(MarketPulseSlideData.self, forKey: .payload))
        case "macro":
            self = .macro(try container.decode(MacroSlideData.self, forKey: .payload))
        case "positioning":
            self = .positioning(try container.decode(PositioningSlideData.self, forKey: .payload))
        case "economic":
            self = .economic(try container.decode(EconomicSlideData.self, forKey: .payload))
        case "setups":
            self = .setups(try container.decode(SetupsSlideData.self, forKey: .payload))
        case "rundown":
            self = .rundown(try container.decode(RundownSlideData.self, forKey: .payload))
        case "sectionTitle":
            self = .sectionTitle(try container.decode(SectionTitleSlideData.self, forKey: .payload))
        case "editorial":
            self = .editorial(try container.decode(EditorialSlideData.self, forKey: .payload))
        case "snapshot":
            self = .snapshot(try container.decode(SnapshotSlideData.self, forKey: .payload))
        case "weeklyOutlook":
            self = .weeklyOutlook(try container.decode(WeeklyOutlookSlideData.self, forKey: .payload))
        case "correlation":
            self = .correlation(try container.decode(CorrelationSlideData.self, forKey: .payload))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown slide type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cover(let data):
            try container.encode("cover", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .marketPulse(let data):
            try container.encode("marketPulse", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .macro(let data):
            try container.encode("macro", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .positioning(let data):
            try container.encode("positioning", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .economic(let data):
            try container.encode("economic", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .setups(let data):
            try container.encode("setups", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .rundown(let data):
            try container.encode("rundown", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .sectionTitle(let data):
            try container.encode("sectionTitle", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .editorial(let data):
            try container.encode("editorial", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .snapshot(let data):
            try container.encode("snapshot", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .weeklyOutlook(let data):
            try container.encode("weeklyOutlook", forKey: .type)
            try container.encode(data, forKey: .payload)
        case .correlation(let data):
            try container.encode("correlation", forKey: .type)
            try container.encode(data, forKey: .payload)
        }
    }
}

// MARK: - Slide Data Types

struct CoverSlideData: Codable {
    var regime: String
    var fearGreedStart: Int?
    var fearGreedEnd: Int?
    var btcWeeklyChange: Double?
    var btcPrice: Double?

    enum CodingKeys: String, CodingKey {
        case regime
        case fearGreedStart = "fear_greed_start"
        case fearGreedEnd = "fear_greed_end"
        case btcWeeklyChange = "btc_weekly_change"
        case btcPrice = "btc_price"
    }
}

struct MarketPulseSlideData: Codable {
    var assets: [AssetWeeklyData]
}

struct AssetWeeklyData: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    var weekOpen: Double?
    var weekClose: Double?
    var weekChange: Double?
    let sparkline: [Double]?

    enum CodingKeys: String, CodingKey {
        case symbol, name
        case weekOpen = "week_open"
        case weekClose = "week_close"
        case weekChange = "week_change"
        case sparkline
    }
}

struct MacroSlideData: Codable {
    var vixValue: Double?
    var vixChange: Double?
    var dxyValue: Double?
    var dxyChange: Double?
    var m2Trend: String?
    var netLiquidityDirection: String?
    var regimeShifts: [String]?

    enum CodingKeys: String, CodingKey {
        case vixValue = "vix_value"
        case vixChange = "vix_change"
        case dxyValue = "dxy_value"
        case dxyChange = "dxy_change"
        case m2Trend = "m2_trend"
        case netLiquidityDirection = "net_liquidity_direction"
        case regimeShifts = "regime_shifts"
    }
}

struct PositioningSlideData: Codable {
    var signalChanges: [SignalChangeEntry]
    var distribution: [CategoryDistribution]

    enum CodingKeys: String, CodingKey {
        case signalChanges = "signal_changes"
        case distribution
    }
}

struct SignalChangeEntry: Codable, Identifiable {
    var id: String { asset }
    let asset: String
    let category: String
    let from: String
    let to: String
    let date: String
}

struct CategoryDistribution: Codable, Identifiable {
    var id: String { category }
    let category: String
    let bullish: Int
    let neutral: Int
    let bearish: Int
}

struct EconomicSlideData: Codable {
    var thisWeek: [EconomicEventEntry]
    var nextWeek: [EconomicEventEntry]

    enum CodingKeys: String, CodingKey {
        case thisWeek = "this_week"
        case nextWeek = "next_week"
    }
}

struct EconomicEventEntry: Codable, Identifiable {
    var id: String { "\(date)-\(title)" }
    let title: String
    let date: String
    let actual: String?
    let forecast: String?
    let impact: String
    let beat: Bool?
}

struct SetupsSlideData: Codable {
    var signalsTriggered: Int
    var signalsResolved: Int
    var winRate: Double?
    var avgPnl: Double?
    var signals: [SetupSignalEntry]

    enum CodingKeys: String, CodingKey {
        case signalsTriggered = "signals_triggered"
        case signalsResolved = "signals_resolved"
        case winRate = "win_rate"
        case avgPnl = "avg_pnl"
        case signals
    }
}

struct SetupSignalEntry: Codable, Identifiable {
    var id: String { "\(asset)-\(direction)-\(entry)" }
    let asset: String
    let direction: String
    let entry: Double
    let outcome: String
    let pnl: Double?
}

struct RundownSlideData: Codable {
    var narrative: String
}

struct SectionTitleSlideData: Codable {
    var subtitle: String?
}

struct EditorialSlideData: Codable {
    var bullets: [EditorialBullet]
    var category: String?  // e.g. "fed", "inflation", "geopolitics", "liquidity", "crypto"
}

struct EditorialBullet: Codable, Identifiable {
    var id: String { text.prefix(40).description }
    let text: String
    let detail: String?  // optional secondary line / source attribution
}

struct SnapshotSlideData: Codable {
    var assetRisks: [AssetRiskSnapshot]
    var riskType: String?            // "regression" or "multi_factor" — displayed as section header
    var fearGreedAvg: Int?
    var fearGreedEnd: Int?
    var sentimentRegime: String?     // "Panic", "FOMO", "Apathy", "Complacency"
    var spyWeekChange: Double?
    var qqqWeekChange: Double?
    var spyPrice: Double?
    var qqqPrice: Double?
    var spySignal: String?           // "bullish", "neutral", "bearish"
    var qqqSignal: String?
    var btcSupplyInProfit: Double?   // 0-100 percentage

    var riskTypeLabel: String {
        switch riskType {
        case "multi_factor": return "MULTI-FACTOR RISK"
        case "regression": return "REGRESSION RISK"
        default: return "REGRESSION RISK"
        }
    }

    enum CodingKeys: String, CodingKey {
        case assetRisks = "asset_risks"
        case riskType = "risk_type"
        case fearGreedAvg = "fear_greed_avg"
        case fearGreedEnd = "fear_greed_end"
        case sentimentRegime = "sentiment_regime"
        case spyWeekChange = "spy_week_change"
        case qqqWeekChange = "qqq_week_change"
        case spyPrice = "spy_price"
        case qqqPrice = "qqq_price"
        case spySignal = "spy_signal"
        case qqqSignal = "qqq_signal"
        case btcSupplyInProfit = "btc_supply_in_profit"
    }
}

struct AssetRiskSnapshot: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let riskLevel: Double       // 0-1 normalized risk (decimal like 0.323)
    let weekAverage: Double?    // 7-day average risk
    let riskLabel: String       // "Low Risk", "Moderate", "Elevated", "High Risk", "Extreme"
    let signal: String?         // "bullish", "neutral", "bearish"
    let daysAtLevel: Int?       // days at current risk category

    enum CodingKeys: String, CodingKey {
        case symbol
        case riskLevel = "risk_level"
        case weekAverage = "week_average"
        case riskLabel = "risk_label"
        case signal
        case daysAtLevel = "days_at_level"
    }
}

// MARK: - Weekly Outlook Data

struct WeeklyOutlookSlideData: Codable {
    var headline: String           // One-line thesis, e.g. "Risk assets face headwinds as yields climb"
    var riskAssetImpact: String    // 2-3 sentence summary of how the week affects crypto/equities
    var lookAhead: [String]        // 3-5 bullet points for what to watch in coming weeks
    var tone: String               // "bullish", "bearish", "cautious", "neutral"

    enum CodingKeys: String, CodingKey {
        case headline
        case riskAssetImpact = "risk_asset_impact"
        case lookAhead = "look_ahead"
        case tone
    }
}

// MARK: - Cross-Market Correlation Data

struct CorrelationSlideData: Codable {
    var groups: [MarketGroupPerformance]
    var narrative: String?          // Optional one-liner on correlation theme

    enum CodingKeys: String, CodingKey {
        case groups, narrative
    }
}

struct MarketGroupPerformance: Codable, Identifiable {
    var id: String { group }
    let group: String               // "Crypto", "Equities", "Commodities", "Macro"
    let assets: [CorrelationAsset]
}

struct CorrelationAsset: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let weekChange: Double?
    let signal: String?             // "bullish", "neutral", "bearish"
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case symbol
        case weekChange = "week_change"
        case signal, price
    }
}

// MARK: - Admin Update Payloads

// MARK: - Deck Feedback

struct DeckFeedback: Codable {
    let rating: Bool
    let note: String?
}

// MARK: - Per-Slide Feedback

struct SlideFeedback: Codable, Identifiable {
    var id: String { "\(deckId)-\(slideType)" }
    let deckId: UUID
    let slideType: String
    let rating: Bool
    let feedback: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case deckId = "deck_id"
        case slideType = "slide_type"
        case rating, feedback
        case createdAt = "created_at"
    }
}

struct SlideFeedbackPayload: Encodable {
    let deckId: String
    let slideType: String
    let rating: Bool
    let feedback: String?

    enum CodingKeys: String, CodingKey {
        case deckId = "deck_id"
        case slideType = "slide_type"
        case rating, feedback
    }
}

struct DeckFeedbackPayload: Encodable {
    let userId: String
    let deckId: String
    let rating: Bool
    let note: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deckId = "deck_id"
        case rating, note
    }
}

// MARK: - Admin Update Payloads

struct DeckPublishUpdate: Encodable {
    let status: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case publishedAt = "published_at"
    }
}

struct DeckFullUpdate: Encodable {
    let slides: [DeckSlide]
    let adminNotes: String?
    let adminContext: AdminContext?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case slides
        case adminNotes = "admin_notes"
        case adminContext = "admin_context"
        case updatedAt = "updated_at"
    }
}
