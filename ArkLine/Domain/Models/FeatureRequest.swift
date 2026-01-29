import Foundation

// MARK: - Feature Request Model

/// A user-submitted feature request for the app
struct FeatureRequest: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var category: FeatureCategory
    let authorId: UUID
    var authorEmail: String?
    var status: FeatureStatus
    var priority: FeaturePriority?
    var voteCount: Int
    let createdAt: Date
    var reviewedAt: Date?
    var reviewedBy: UUID?
    var adminNotes: String?
    var aiAnalysis: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case category
        case authorId = "author_id"
        case authorEmail = "author_email"
        case status
        case priority
        case voteCount = "vote_count"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
        case reviewedBy = "reviewed_by"
        case adminNotes = "admin_notes"
        case aiAnalysis = "ai_analysis"
    }

    // MARK: - Convenience Initializers

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        category: FeatureCategory,
        authorId: UUID,
        authorEmail: String? = nil,
        status: FeatureStatus = .pending,
        priority: FeaturePriority? = nil,
        voteCount: Int = 0,
        createdAt: Date = Date(),
        reviewedAt: Date? = nil,
        reviewedBy: UUID? = nil,
        adminNotes: String? = nil,
        aiAnalysis: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.authorId = authorId
        self.authorEmail = authorEmail
        self.status = status
        self.priority = priority
        self.voteCount = voteCount
        self.createdAt = createdAt
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.adminNotes = adminNotes
        self.aiAnalysis = aiAnalysis
    }

    // MARK: - Display Helpers

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var statusColor: String {
        status.color
    }
}

// MARK: - Feature Status

enum FeatureStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case reviewing = "reviewing"
    case approved = "approved"
    case rejected = "rejected"
    case implemented = "implemented"

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .reviewing: return "Under Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .implemented: return "Implemented"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .reviewing: return "magnifyingglass"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .implemented: return "checkmark.seal.fill"
        }
    }

    var color: String {
        switch self {
        case .pending: return "#F59E0B"      // Amber
        case .reviewing: return "#3B82F6"    // Blue
        case .approved: return "#22C55E"     // Green
        case .rejected: return "#EF4444"     // Red
        case .implemented: return "#8B5CF6"  // Purple
        }
    }
}

// MARK: - Feature Priority

enum FeaturePriority: String, Codable, CaseIterable {
    case critical = "critical"
    case high = "high"
    case medium = "medium"
    case low = "low"

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.3"
        case .high: return "exclamationmark.2"
        case .medium: return "exclamationmark"
        case .low: return "minus"
        }
    }

    var color: String {
        switch self {
        case .critical: return "#DC2626"  // Red-600
        case .high: return "#F97316"      // Orange
        case .medium: return "#EAB308"    // Yellow
        case .low: return "#6B7280"       // Gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

// MARK: - Feature Category

enum FeatureCategory: String, Codable, CaseIterable {
    case portfolio = "portfolio"
    case market = "market"
    case alerts = "alerts"
    case social = "social"
    case ui = "ui_ux"
    case performance = "performance"
    case other = "other"

    var displayName: String {
        switch self {
        case .portfolio: return "Portfolio"
        case .market: return "Market Data"
        case .alerts: return "Alerts & Notifications"
        case .social: return "Social Features"
        case .ui: return "UI/UX"
        case .performance: return "Performance"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .portfolio: return "chart.pie.fill"
        case .market: return "chart.line.uptrend.xyaxis"
        case .alerts: return "bell.fill"
        case .social: return "person.2.fill"
        case .ui: return "paintbrush.fill"
        case .performance: return "gauge.with.needle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}
