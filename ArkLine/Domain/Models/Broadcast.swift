import Foundation
import SwiftUI

// MARK: - Broadcast Model

/// A market insight broadcast published by an admin
struct Broadcast: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var audioURL: URL?
    var images: [BroadcastImage]
    var appReferences: [AppReference]
    var portfolioAttachment: BroadcastPortfolioAttachment?
    var meetingLink: URL?
    var targetAudience: TargetAudience
    var status: BroadcastStatus
    let createdAt: Date
    var publishedAt: Date?
    var scheduledAt: Date?
    var templateId: UUID?
    var tags: [String]
    let authorId: UUID

    // Analytics (populated when fetched)
    var viewCount: Int?
    var reactionCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case audioURL = "audio_url"
        case images
        case appReferences = "app_references"
        case portfolioAttachment = "portfolio_attachment"
        case meetingLink = "meeting_link"
        case targetAudience = "target_audience"
        case status
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case scheduledAt = "scheduled_at"
        case templateId = "template_id"
        case tags
        case authorId = "author_id"
        case viewCount = "view_count"
        case reactionCount = "reaction_count"
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        audioURL: URL? = nil,
        images: [BroadcastImage] = [],
        appReferences: [AppReference] = [],
        portfolioAttachment: BroadcastPortfolioAttachment? = nil,
        meetingLink: URL? = nil,
        targetAudience: TargetAudience = .all,
        status: BroadcastStatus = .draft,
        createdAt: Date = Date(),
        publishedAt: Date? = nil,
        scheduledAt: Date? = nil,
        templateId: UUID? = nil,
        tags: [String] = [],
        authorId: UUID,
        viewCount: Int? = nil,
        reactionCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.audioURL = audioURL
        self.images = images
        self.appReferences = appReferences
        self.portfolioAttachment = portfolioAttachment
        self.meetingLink = meetingLink
        self.targetAudience = targetAudience
        self.status = status
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.scheduledAt = scheduledAt
        self.templateId = templateId
        self.tags = tags
        self.authorId = authorId
        self.viewCount = viewCount
        self.reactionCount = reactionCount
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(images, forKey: .images)
        try container.encode(appReferences, forKey: .appReferences)
        try container.encodeIfPresent(meetingLink, forKey: .meetingLink)
        try container.encode(targetAudience, forKey: .targetAudience)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(publishedAt, forKey: .publishedAt)
        try container.encodeIfPresent(scheduledAt, forKey: .scheduledAt)
        try container.encode(authorId, forKey: .authorId)
        // Note: viewCount, reactionCount, portfolioAttachment, templateId, tags
        // are NOT encoded — they don't exist as columns in the broadcasts table
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        images = (try? container.decodeIfPresent([BroadcastImage].self, forKey: .images)) ?? []
        appReferences = (try? container.decodeIfPresent([AppReference].self, forKey: .appReferences)) ?? []
        portfolioAttachment = try? container.decodeIfPresent(BroadcastPortfolioAttachment.self, forKey: .portfolioAttachment)
        meetingLink = try? container.decodeIfPresent(URL.self, forKey: .meetingLink)
        targetAudience = (try? container.decode(TargetAudience.self, forKey: .targetAudience)) ?? .all
        status = try container.decode(BroadcastStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        publishedAt = try container.decodeIfPresent(Date.self, forKey: .publishedAt)
        scheduledAt = try container.decodeIfPresent(Date.self, forKey: .scheduledAt)
        templateId = try container.decodeIfPresent(UUID.self, forKey: .templateId)
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        authorId = try container.decode(UUID.self, forKey: .authorId)
        viewCount = try container.decodeIfPresent(Int.self, forKey: .viewCount)
        reactionCount = try container.decodeIfPresent(Int.self, forKey: .reactionCount)
    }
}

// MARK: - Broadcast Image

/// An annotated image attached to a broadcast
struct BroadcastImage: Codable, Identifiable, Equatable {
    let id: UUID
    var imageURL: URL
    var annotations: [ImageAnnotation]
    var caption: String?

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL = "image_url"
        case annotations
        case caption
    }

    init(
        id: UUID = UUID(),
        imageURL: URL,
        annotations: [ImageAnnotation] = [],
        caption: String? = nil
    ) {
        self.id = id
        self.imageURL = imageURL
        self.annotations = annotations
        self.caption = caption
    }
}

// MARK: - Image Annotation

/// A drawing annotation on an image (line, arrow, circle, etc.)
struct ImageAnnotation: Codable, Identifiable, Equatable {
    let id: UUID
    let type: AnnotationType
    var points: [CGPoint]
    var color: String
    var strokeWidth: CGFloat
    var text: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case points
        case color
        case strokeWidth = "stroke_width"
        case text
    }

    init(
        id: UUID = UUID(),
        type: AnnotationType,
        points: [CGPoint],
        color: String = "#FF0000",
        strokeWidth: CGFloat = 3.0,
        text: String? = nil
    ) {
        self.id = id
        self.type = type
        self.points = points
        self.color = color
        self.strokeWidth = strokeWidth
        self.text = text
    }

    /// Convert hex color string to SwiftUI Color
    var swiftUIColor: Color {
        Color(hex: color)
    }
}

// MARK: - Annotation Type

enum AnnotationType: String, Codable, CaseIterable {
    case line
    case arrow
    case circle
    case rectangle
    case text
    case freehand

    var displayName: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .circle: return "Circle"
        case .rectangle: return "Rectangle"
        case .text: return "Text"
        case .freehand: return "Freehand"
        }
    }

    var iconName: String {
        switch self {
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .freehand: return "scribble"
        }
    }
}

// MARK: - App Reference

/// A reference to an app section, asset, or external link with optional screenshot
struct AppReference: Codable, Identifiable, Equatable {
    let id: UUID
    var section: AppSection?
    var assetReference: AssetReference?
    var externalLink: ExternalLink?
    var screenshotURL: URL?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case section
        case assetReference = "asset_reference"
        case externalLink = "external_link"
        case screenshotURL = "screenshot_url"
        case note
    }

    // MARK: - Convenience Inits

    /// Macro indicator reference (backward-compatible)
    init(
        id: UUID = UUID(),
        section: AppSection,
        screenshotURL: URL? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.section = section
        self.assetReference = nil
        self.externalLink = nil
        self.screenshotURL = screenshotURL
        self.note = note
    }

    /// Asset reference (crypto, stock, commodity)
    init(
        id: UUID = UUID(),
        assetReference: AssetReference,
        note: String? = nil
    ) {
        self.id = id
        self.section = nil
        self.assetReference = assetReference
        self.externalLink = nil
        self.screenshotURL = nil
        self.note = note
    }

    /// External link reference
    init(
        id: UUID = UUID(),
        externalLink: ExternalLink,
        note: String? = nil
    ) {
        self.id = id
        self.section = nil
        self.assetReference = nil
        self.externalLink = externalLink
        self.screenshotURL = nil
        self.note = note
    }

    // MARK: - Custom Decoder (backward compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        section = try container.decodeIfPresent(AppSection.self, forKey: .section)
        assetReference = try container.decodeIfPresent(AssetReference.self, forKey: .assetReference)
        externalLink = try container.decodeIfPresent(ExternalLink.self, forKey: .externalLink)
        screenshotURL = try container.decodeIfPresent(URL.self, forKey: .screenshotURL)
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    // MARK: - Computed Properties

    /// The kind of reference this represents
    var referenceKind: ReferenceKind {
        if section != nil { return .macroIndicator }
        if assetReference != nil { return .asset }
        if externalLink != nil { return .externalLink }
        return .macroIndicator
    }

    /// Display name for any reference type
    var displayName: String {
        if let section { return section.displayName }
        if let asset = assetReference { return asset.displayName }
        if let link = externalLink { return link.title ?? link.domain ?? link.url.absoluteString }
        return "Unknown"
    }

    /// SF Symbol icon name for any reference type
    var iconName: String {
        if let section { return section.iconName }
        if let asset = assetReference { return asset.iconName }
        if externalLink != nil { return "link" }
        return "questionmark.circle"
    }
}

// MARK: - Reference Kind

enum ReferenceKind: String, Codable {
    case macroIndicator
    case asset
    case externalLink
}

// MARK: - Asset Reference

/// A reference to a specific crypto, stock, or commodity asset
struct AssetReference: Codable, Equatable {
    let symbol: String
    let assetType: AssetType
    let displayName: String
    let coinGeckoId: String?

    var iconName: String {
        switch assetType {
        case .crypto: return "bitcoinsign.circle"
        case .stock: return "chart.line.uptrend.xyaxis"
        case .commodity: return "scalemass"
        }
    }
}

// MARK: - Asset Type

enum AssetType: String, Codable, CaseIterable {
    case crypto
    case stock
    case commodity
}

// MARK: - External Link

/// A reference to an external URL with optional metadata
struct ExternalLink: Codable, Equatable {
    let url: URL
    var title: String?
    var description: String?
    var imageURL: URL?
    var domain: String?

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case description
        case imageURL = "image_url"
        case domain
    }
}

// MARK: - App Section Group

/// Categories for grouping AppSection in the picker
enum AppSectionGroup: String, CaseIterable {
    case homeIndicators = "Home Indicators"
    case macroData = "Macro & Economy"
    case sentiment = "Sentiment & Retail"
    case positioning = "Positioning & Allocation"
    case market = "Market Sections"
}

// MARK: - App Section

/// Sections of the app that can be referenced in broadcasts
enum AppSection: String, Codable, CaseIterable {
    // Home Screen Widgets
    case arklineRiskScore = "arkline_risk_score"
    case fearGreed = "fear_greed"
    case bitcoinRisk = "bitcoin_risk"
    case coreAssets = "core_assets"
    case supplyInProfit = "supply_in_profit"
    case fedWatch = "fed_watch"
    case dailyNews = "daily_news"
    case upcomingEvents = "upcoming_events"
    case dcaReminders = "dca_reminders"
    case favorites
    case macroDashboard = "macro_dashboard"

    // Macro & Economy
    case vix
    case dxy
    case m2
    case macroRegime = "macro_regime"

    // Sentiment & Retail
    case sentimentOverview = "sentiment_overview"
    case sentimentRegime = "sentiment_regime"
    case coinbaseRanking = "coinbase_ranking"
    case bitcoinSearchIndex = "bitcoin_search_index"

    // Positioning & Allocation
    case cryptoPositioning = "crypto_positioning"

    // Market Sections
    case technicalAnalysis = "technical_analysis"
    case traditionalMarkets = "traditional_markets"
    case altcoinScreener = "altcoin_screener"
    case portfolioShowcase = "portfolio_showcase"

    // MARK: - Display Name

    var displayName: String {
        switch self {
        case .arklineRiskScore: return "ArkLine Risk Score"
        case .fearGreed: return "Fear & Greed Index"
        case .bitcoinRisk: return "Asset Risk Level"
        case .coreAssets: return "Core Assets (BTC/ETH/SOL)"
        case .supplyInProfit: return "BTC Supply in Profit"
        case .fedWatch: return "Fed Watch"
        case .dailyNews: return "Daily News"
        case .upcomingEvents: return "Upcoming Events"
        case .dcaReminders: return "DCA Reminders"
        case .favorites: return "Favorites"
        case .macroDashboard: return "Macro Dashboard"
        case .vix: return "VIX Index"
        case .dxy: return "Dollar Index (DXY)"
        case .m2: return "M2 Money Supply"
        case .macroRegime: return "Macro Regime"
        case .sentimentOverview: return "Market Sentiment Overview"
        case .sentimentRegime: return "Sentiment Regime"
        case .coinbaseRanking: return "Coinbase App Store Rank"
        case .bitcoinSearchIndex: return "Bitcoin Search Interest"
        case .cryptoPositioning: return "Crypto Positioning"
        case .technicalAnalysis: return "Technical Analysis"
        case .traditionalMarkets: return "Traditional Markets"
        case .altcoinScreener: return "Altcoin Screener"
        case .portfolioShowcase: return "Portfolio Showcase"
        }
    }

    // MARK: - Icon Name

    var iconName: String {
        switch self {
        case .arklineRiskScore: return "shield.checkered"
        case .fearGreed: return "gauge.with.needle"
        case .bitcoinRisk: return "exclamationmark.triangle"
        case .coreAssets: return "bitcoinsign.circle"
        case .supplyInProfit: return "chart.pie"
        case .fedWatch: return "building.columns"
        case .dailyNews: return "newspaper"
        case .upcomingEvents: return "calendar"
        case .dcaReminders: return "repeat"
        case .favorites: return "star.fill"
        case .macroDashboard: return "square.grid.2x2"
        case .vix: return "chart.line.uptrend.xyaxis"
        case .dxy: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .m2: return "chart.bar.fill"
        case .macroRegime: return "globe"
        case .sentimentOverview: return "chart.bar"
        case .sentimentRegime: return "person.3"
        case .coinbaseRanking: return "arrow.up.arrow.down"
        case .bitcoinSearchIndex: return "magnifyingglass"
        case .cryptoPositioning: return "slider.horizontal.3"
        case .technicalAnalysis: return "chart.xyaxis.line"
        case .traditionalMarkets: return "building.2"
        case .altcoinScreener: return "list.number"
        case .portfolioShowcase: return "square.split.2x1"
        }
    }

    // MARK: - Section Group

    var sectionGroup: AppSectionGroup {
        switch self {
        case .arklineRiskScore, .fearGreed, .bitcoinRisk, .coreAssets, .supplyInProfit,
             .fedWatch, .dailyNews, .upcomingEvents, .dcaReminders, .favorites, .macroDashboard:
            return .homeIndicators
        case .vix, .dxy, .m2, .macroRegime:
            return .macroData
        case .sentimentOverview, .sentimentRegime, .coinbaseRanking, .bitcoinSearchIndex:
            return .sentiment
        case .cryptoPositioning:
            return .positioning
        case .technicalAnalysis, .traditionalMarkets, .altcoinScreener, .portfolioShowcase:
            return .market
        }
    }

    // MARK: - Navigation Tab

    var navigationTab: AppTab {
        switch self {
        case .cryptoPositioning, .macroRegime, .sentimentRegime, .sentimentOverview,
             .coinbaseRanking, .bitcoinSearchIndex, .traditionalMarkets, .altcoinScreener,
             .technicalAnalysis:
            return .market
        case .portfolioShowcase:
            return .portfolio
        default:
            return .home
        }
    }

    // MARK: - Deep Link URL

    // swiftlint:disable:next force_unwrapping
    private static let fallbackURL = URL(string: "arkline://home")! // Safe: compile-time constant
    var deepLinkURL: URL {
        URL(string: "arkline://section/\(rawValue)") ?? Self.fallbackURL
    }

    // MARK: - Backward Compatibility

    /// Custom decoding to handle removed cases from old broadcasts
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "sentiment":
            // Old "sentiment" maps to sentimentOverview
            self = .sentimentOverview
        case "rainbow_chart":
            // Old "rainbow_chart" maps to bitcoinRisk (it's just the risk level)
            self = .bitcoinRisk
        default:
            guard let section = AppSection(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown AppSection: \(rawValue)"
                )
            }
            self = section
        }
    }
}

// MARK: - Target Audience

/// Who should receive the broadcast
enum TargetAudience: Codable, Equatable {
    case all
    case premium
    case specific(userIds: [UUID])

    var displayName: String {
        switch self {
        case .all: return "All Users"
        case .premium: return "Premium Only"
        case .specific(let ids): return "\(ids.count) Selected Users"
        }
    }

    // Custom Codable implementation for associated values
    enum CodingKeys: String, CodingKey {
        case type
        case userIds = "user_ids"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "all":
            self = .all
        case "premium":
            self = .premium
        case "specific":
            let userIds = try container.decode([UUID].self, forKey: .userIds)
            self = .specific(userIds: userIds)
        default:
            self = .all
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .all:
            try container.encode("all", forKey: .type)
        case .premium:
            try container.encode("premium", forKey: .type)
        case .specific(let userIds):
            try container.encode("specific", forKey: .type)
            try container.encode(userIds, forKey: .userIds)
        }
    }
}

// MARK: - Broadcast Status

enum BroadcastStatus: String, Codable, CaseIterable {
    case draft
    case scheduled
    case published
    case archived

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .scheduled: return "Scheduled"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }

    var iconName: String {
        switch self {
        case .draft: return "doc"
        case .scheduled: return "clock"
        case .published: return "checkmark.circle"
        case .archived: return "archivebox"
        }
    }

    var color: Color {
        switch self {
        case .draft: return AppColors.textSecondary
        case .scheduled: return AppColors.warning
        case .published: return AppColors.success
        case .archived: return AppColors.textTertiary
        }
    }
}

// MARK: - Broadcast Read

/// Tracks when a user has read a broadcast
struct BroadcastRead: Codable, Identifiable {
    let id: UUID
    let broadcastId: UUID
    let userId: UUID
    let readAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case broadcastId = "broadcast_id"
        case userId = "user_id"
        case readAt = "read_at"
    }
}

// MARK: - Broadcast Reaction

/// A user's emoji reaction to a broadcast
struct BroadcastReaction: Codable, Identifiable, Equatable {
    let id: UUID
    let broadcastId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case broadcastId = "broadcast_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        broadcastId: UUID,
        userId: UUID,
        emoji: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.broadcastId = broadcastId
        self.userId = userId
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

/// Summary of reactions for a broadcast
struct ReactionSummary: Equatable {
    let emoji: String
    let count: Int
    let hasUserReacted: Bool
}

/// Available reaction emojis
enum ReactionEmoji: String, CaseIterable {
    case fire = "🔥"
    case rocket = "🚀"
    case thinking = "🤔"
    case clap = "👏"
    case heart = "❤️"
    case hundredPoints = "💯"

    var displayName: String {
        switch self {
        case .fire: return "Fire"
        case .rocket: return "Rocket"
        case .thinking: return "Thinking"
        case .clap: return "Clap"
        case .heart: return "Love"
        case .hundredPoints: return "100"
        }
    }
}

// MARK: - Broadcast Extensions

extension Broadcast {
    /// Whether the broadcast is ready to publish
    var canPublish: Bool {
        !title.isEmpty && !content.isEmpty && status == .draft
    }

    /// Formatted published date
    var formattedPublishedDate: String? {
        guard let publishedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedAt)
    }

    /// Time ago string for display
    var timeAgo: String {
        let date = publishedAt ?? createdAt
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    /// Content with markdown syntax stripped for use in previews and notifications.
    var plainTextContent: String {
        var text = content

        // Strip inline markdown: **bold**, *italic*, ~~strikethrough~~, <u>underline</u>
        // Order matters: strip ** before * to avoid partial matches
        let patterns: [(String, String)] = [
            (#"\*\*(.+?)\*\*"#, "$1"),          // **bold**
            (#"~~(.+?)~~"#, "$1"),               // ~~strikethrough~~
            (#"<u>(.+?)</u>"#, "$1"),            // <u>underline</u>
            (#"\*(.+?)\*"#, "$1"),               // *italic*
            (#"\[([^\]]+)\]\([^\)]+\)"#, "$1"),  // [text](url) -> text
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
            }
        }

        // Strip list prefixes
        let listPatterns: [(String, String)] = [
            (#"(?m)^\d+\.\s+"#, ""),  // ordered list prefix
            (#"(?m)^- "#, ""),         // unordered list prefix
        ]

        for (pattern, replacement) in listPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
            }
        }

        return text
    }

    /// Preview of content (first 100 characters, markdown stripped)
    var contentPreview: String {
        let plain = plainTextContent
        if plain.count > 100 {
            return String(plain.prefix(100)) + "..."
        }
        return plain
    }

    /// Whether this broadcast is scheduled for future publishing
    var isScheduled: Bool {
        status == .scheduled && scheduledAt != nil
    }

    /// Formatted scheduled date
    var formattedScheduledDate: String? {
        guard let scheduledAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledAt)
    }
}

// MARK: - Broadcast Template

/// A reusable template for creating broadcasts
struct BroadcastTemplate: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var titleTemplate: String
    var contentTemplate: String
    var defaultTags: [String]
    var icon: String
    var color: String
    let createdAt: Date
    var updatedAt: Date
    let authorId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case titleTemplate = "title_template"
        case contentTemplate = "content_template"
        case defaultTags = "default_tags"
        case icon
        case color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorId = "author_id"
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        titleTemplate: String = "",
        contentTemplate: String = "",
        defaultTags: [String] = [],
        icon: String = "doc.text",
        color: String = "#3B82F6",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        authorId: UUID
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.titleTemplate = titleTemplate
        self.contentTemplate = contentTemplate
        self.defaultTags = defaultTags
        self.icon = icon
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorId = authorId
    }

    /// Create a new broadcast from this template
    func createBroadcast(authorId: UUID) -> Broadcast {
        Broadcast(
            title: titleTemplate,
            content: contentTemplate,
            tags: defaultTags,
            authorId: authorId
        )
    }
}

/// Built-in template types
enum BuiltInTemplate: String, CaseIterable {
    case weeklyOutlook = "weekly_outlook"
    case marketAlert = "market_alert"
    case dcaReminder = "dca_reminder"
    case educationalTip = "educational_tip"

    var template: BroadcastTemplate {
        switch self {
        case .weeklyOutlook:
            return BroadcastTemplate(
                name: "Weekly Outlook",
                description: "Weekly market analysis and predictions",
                titleTemplate: "Weekly Market Outlook - [Date]",
                contentTemplate: """
                ## Market Overview
                [Summary of this week's market movements]

                ## Key Observations
                - [Observation 1]
                - [Observation 2]
                - [Observation 3]

                ## Looking Ahead
                [What to watch for next week]

                ## Action Items
                - [Recommendation 1]
                - [Recommendation 2]
                """,
                defaultTags: ["weekly", "outlook", "analysis"],
                icon: "calendar",
                color: "#3B82F6",
                authorId: UUID()
            )

        case .marketAlert:
            return BroadcastTemplate(
                name: "Market Alert",
                description: "Urgent market update or price movement",
                titleTemplate: "🚨 Market Alert: [Asset/Event]",
                contentTemplate: """
                ## What's Happening
                [Brief description of the event]

                ## Impact
                [How this affects the market]

                ## My Take
                [Your analysis and opinion]

                ## What To Do
                [Actionable advice]
                """,
                defaultTags: ["alert", "urgent"],
                icon: "exclamationmark.triangle",
                color: "#EF4444",
                authorId: UUID()
            )

        case .dcaReminder:
            return BroadcastTemplate(
                name: "DCA Reminder",
                description: "Dollar cost averaging reminder and context",
                titleTemplate: "DCA Day: [Asset] Update",
                contentTemplate: """
                ## Today's DCA
                It's time for your scheduled [Asset] purchase.

                ## Current Price Context
                - Current Price: $[price]
                - 7-Day Change: [change]%
                - From ATH: [distance]%

                ## Market Sentiment
                [Brief sentiment overview]

                ## Remember
                DCA removes emotion from investing. Stay consistent!
                """,
                defaultTags: ["dca", "reminder"],
                icon: "repeat",
                color: "#10B981",
                authorId: UUID()
            )

        case .educationalTip:
            return BroadcastTemplate(
                name: "Educational Tip",
                description: "Share knowledge and educate your audience",
                titleTemplate: "💡 Did You Know: [Topic]",
                contentTemplate: """
                ## The Concept
                [Explain the concept simply]

                ## Why It Matters
                [Why your audience should care]

                ## How To Apply It
                [Practical application]

                ## Learn More
                [Resources or next steps]
                """,
                defaultTags: ["education", "tip"],
                icon: "lightbulb",
                color: "#F59E0B",
                authorId: UUID()
            )
        }
    }

    var displayName: String {
        template.name
    }

    var icon: String {
        template.icon
    }

    var color: Color {
        Color(hex: template.color)
    }
}

// MARK: - Broadcast Analytics

/// Analytics data for a single broadcast
struct BroadcastAnalytics: Codable, Identifiable, Equatable {
    var id: UUID { broadcastId }
    let broadcastId: UUID
    let viewCount: Int
    let uniqueViewers: Int
    let reactionCount: Int
    let reactionBreakdown: [String: Int]
    let readCount: Int
    let avgTimeSpent: TimeInterval?
    let peakViewTime: Date?

    enum CodingKeys: String, CodingKey {
        case broadcastId = "broadcast_id"
        case viewCount = "view_count"
        case uniqueViewers = "unique_viewers"
        case reactionCount = "reaction_count"
        case reactionBreakdown = "reaction_breakdown"
        case readCount = "read_count"
        case avgTimeSpent = "avg_time_spent"
        case peakViewTime = "peak_view_time"
    }
}

/// Overall analytics summary for the admin dashboard
struct BroadcastAnalyticsSummary: Codable, Equatable {
    let totalBroadcasts: Int
    let totalViews: Int
    let totalReactions: Int
    let avgViewsPerBroadcast: Double
    let avgReactionsPerBroadcast: Double
    let topPerformingBroadcastId: UUID?
    let mostUsedReaction: String?
    let periodStart: Date
    let periodEnd: Date

    enum CodingKeys: String, CodingKey {
        case totalBroadcasts = "total_broadcasts"
        case totalViews = "total_views"
        case totalReactions = "total_reactions"
        case avgViewsPerBroadcast = "avg_views_per_broadcast"
        case avgReactionsPerBroadcast = "avg_reactions_per_broadcast"
        case topPerformingBroadcastId = "top_performing_broadcast_id"
        case mostUsedReaction = "most_used_reaction"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

// MARK: - Broadcast Tag

/// Predefined tags for categorizing broadcasts
enum BroadcastTag: String, CaseIterable {
    case btc = "BTC"
    case eth = "ETH"
    case altcoins = "Altcoins"
    case macro = "Macro"
    case technical = "Technical"
    case fundamental = "Fundamental"
    case alert = "Alert"
    case weekly = "Weekly"
    case education = "Education"
    case dca = "DCA"
    case news = "News"
    case xPost = "X Post"
    case marketUpdate = "Market Update"
    case outOfOffice = "Out of Office"

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .btc: return Color(hex: "F7931A")
        case .eth: return Color(hex: "627EEA")
        case .altcoins: return Color(hex: "8B5CF6")
        case .macro: return Color(hex: "3B82F6")
        case .technical: return Color(hex: "10B981")
        case .fundamental: return Color(hex: "F59E0B")
        case .alert: return Color(hex: "EF4444")
        case .weekly: return Color(hex: "6366F1")
        case .education: return Color(hex: "EC4899")
        case .dca: return Color(hex: "14B8A6")
        case .news: return Color(hex: "64748B")
        case .xPost: return Color(hex: "000000")
        case .marketUpdate: return Color(hex: "0EA5E9")
        case .outOfOffice: return Color(hex: "A3A3A3")
        }
    }
}
