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
    var targetAudience: TargetAudience
    var status: BroadcastStatus
    let createdAt: Date
    var publishedAt: Date?
    let authorId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case audioURL = "audio_url"
        case images
        case appReferences = "app_references"
        case targetAudience = "target_audience"
        case status
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case authorId = "author_id"
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        audioURL: URL? = nil,
        images: [BroadcastImage] = [],
        appReferences: [AppReference] = [],
        targetAudience: TargetAudience = .all,
        status: BroadcastStatus = .draft,
        createdAt: Date = Date(),
        publishedAt: Date? = nil,
        authorId: UUID
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.audioURL = audioURL
        self.images = images
        self.appReferences = appReferences
        self.targetAudience = targetAudience
        self.status = status
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.authorId = authorId
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

// MARK: - CGPoint Codable Extension

extension CGPoint: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
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

/// A reference to an app section with optional screenshot
struct AppReference: Codable, Identifiable, Equatable {
    let id: UUID
    let section: AppSection
    var screenshotURL: URL?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case section
        case screenshotURL = "screenshot_url"
        case note
    }

    init(
        id: UUID = UUID(),
        section: AppSection,
        screenshotURL: URL? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.section = section
        self.screenshotURL = screenshotURL
        self.note = note
    }
}

// MARK: - App Section

/// Sections of the app that can be referenced in broadcasts
enum AppSection: String, Codable, CaseIterable {
    case vix
    case dxy
    case m2
    case bitcoinRisk = "bitcoin_risk"
    case upcomingEvents = "upcoming_events"
    case fearGreed = "fear_greed"
    case sentiment
    case rainbowChart = "rainbow_chart"
    case technicalAnalysis = "technical_analysis"
    case portfolioShowcase = "portfolio_showcase"

    var displayName: String {
        switch self {
        case .vix: return "VIX Index"
        case .dxy: return "Dollar Index (DXY)"
        case .m2: return "M2 Money Supply"
        case .bitcoinRisk: return "Bitcoin Risk Level"
        case .upcomingEvents: return "Upcoming Events"
        case .fearGreed: return "Fear & Greed Index"
        case .sentiment: return "Market Sentiment"
        case .rainbowChart: return "Rainbow Chart"
        case .technicalAnalysis: return "Technical Analysis"
        case .portfolioShowcase: return "Portfolio Showcase"
        }
    }

    var iconName: String {
        switch self {
        case .vix: return "waveform.path.ecg"
        case .dxy: return "dollarsign.circle"
        case .m2: return "banknote"
        case .bitcoinRisk: return "exclamationmark.triangle"
        case .upcomingEvents: return "calendar"
        case .fearGreed: return "gauge.with.needle"
        case .sentiment: return "chart.bar"
        case .rainbowChart: return "rainbow"
        case .technicalAnalysis: return "chart.xyaxis.line"
        case .portfolioShowcase: return "square.split.2x1"
        }
    }

    /// Deep link URL for navigation
    var deepLinkURL: URL {
        URL(string: "arkline://section/\(rawValue)")!
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

    /// Preview of content (first 100 characters)
    var contentPreview: String {
        if content.count > 100 {
            return String(content.prefix(100)) + "..."
        }
        return content
    }
}
