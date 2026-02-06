import Foundation

// MARK: - User Role

/// User access level for the app
enum UserRole: String, Codable, CaseIterable {
    case user           // Regular user - can view broadcasts
    case premium        // Premium subscriber - gets notifications for broadcasts
    case admin          // App creator - can create and publish broadcasts

    var displayName: String {
        switch self {
        case .user: return "User"
        case .premium: return "Premium"
        case .admin: return "Admin"
        }
    }
}

// MARK: - User Model
struct User: Codable, Identifiable, Equatable {
    let id: UUID
    var username: String
    var email: String
    var fullName: String?
    var avatarUrl: String?
    var usePhotoAvatar: Bool
    var dateOfBirth: Date?
    var careerIndustry: String?
    var experienceLevel: String?
    var socialLinks: SocialLinks?
    var preferredCurrency: String
    var riskCoins: [String]
    var darkMode: String
    var notifications: NotificationSettings?
    var passcodeHash: String?
    var faceIdEnabled: Bool
    var role: UserRole
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case usePhotoAvatar = "use_photo_avatar"
        case dateOfBirth = "date_of_birth"
        case careerIndustry = "career_industry"
        case experienceLevel = "experience_level"
        case socialLinks = "social_links"
        case preferredCurrency = "preferred_currency"
        case riskCoins = "risk_coins"
        case darkMode = "dark_mode"
        case notifications
        case passcodeHash = "passcode_hash"
        case faceIdEnabled = "face_id_enabled"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Default Values
    init(
        id: UUID = UUID(),
        username: String,
        email: String,
        fullName: String? = nil,
        avatarUrl: String? = nil,
        usePhotoAvatar: Bool = true,
        dateOfBirth: Date? = nil,
        careerIndustry: String? = nil,
        experienceLevel: String? = nil,
        socialLinks: SocialLinks? = nil,
        preferredCurrency: String = "USD",
        riskCoins: [String] = ["BTC", "ETH"],
        darkMode: String = "automatic",
        notifications: NotificationSettings? = nil,
        passcodeHash: String? = nil,
        faceIdEnabled: Bool = false,
        role: UserRole = .user,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.usePhotoAvatar = usePhotoAvatar
        self.dateOfBirth = dateOfBirth
        self.careerIndustry = careerIndustry
        self.experienceLevel = experienceLevel
        self.socialLinks = socialLinks
        self.preferredCurrency = preferredCurrency
        self.riskCoins = riskCoins
        self.darkMode = darkMode
        self.notifications = notifications
        self.passcodeHash = passcodeHash
        self.faceIdEnabled = faceIdEnabled
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Social Links
struct SocialLinks: Codable, Equatable {
    var twitter: String?
    var linkedin: String?
    var telegram: String?
    var website: String?

    var isEmpty: Bool {
        twitter == nil && linkedin == nil && telegram == nil && website == nil
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Codable, Equatable {
    var pushEnabled: Bool
    var emailEnabled: Bool
    var dcaReminders: Bool
    var priceAlerts: Bool
    var communityUpdates: Bool
    var marketNews: Bool

    static let `default` = NotificationSettings(
        pushEnabled: true,
        emailEnabled: true,
        dcaReminders: true,
        priceAlerts: true,
        communityUpdates: true,
        marketNews: true
    )
}

// MARK: - Experience Level
enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
}

// MARK: - Career Industry
enum CareerIndustry: String, Codable, CaseIterable {
    case technology = "technology"
    case finance = "finance"
    case healthcare = "healthcare"
    case education = "education"
    case retail = "retail"
    case manufacturing = "manufacturing"
    case marketing = "marketing"
    case legal = "legal"
    case realEstate = "real_estate"
    case other = "other"

    var displayName: String {
        switch self {
        case .technology: return "Technology"
        case .finance: return "Finance"
        case .healthcare: return "Healthcare"
        case .education: return "Education"
        case .retail: return "Retail"
        case .manufacturing: return "Manufacturing"
        case .marketing: return "Marketing"
        case .legal: return "Legal"
        case .realEstate: return "Real Estate"
        case .other: return "Other"
        }
    }
}

// MARK: - Admin Configuration

/// Admin user IDs - these users always have admin access regardless of role
private let adminUserIds: Set<UUID> = [
    UUID(uuidString: "5269677e-cc2c-4ea8-9246-1e6574f35b0b")! // Matt (Supabase auth)
]

/// Admin emails - fallback check for admin access
private let adminEmails: Set<String> = [
    "mneal.jw@gmail.com"
]

// MARK: - User Extensions
extension User {
    var displayName: String {
        fullName ?? username
    }

    /// First name extracted from fullName, or username as fallback
    var firstName: String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName.components(separatedBy: " ").first ?? fullName
        }
        return username
    }

    var initials: String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName.initials
        }
        return String(username.prefix(2)).uppercased()
    }

    var hasCompletedProfile: Bool {
        fullName != nil && !fullName!.isEmpty
    }

    var hasSetupSecurity: Bool {
        passcodeHash != nil || faceIdEnabled
    }

    /// Whether the user has admin privileges (can create broadcasts)
    var isAdmin: Bool {
        adminUserIds.contains(id) || adminEmails.contains(email.lowercased()) || role == .admin
    }

    /// Whether the user has premium access
    var isPremium: Bool {
        role == .premium || role == .admin
    }
}

// MARK: - User for Creation
struct CreateUserRequest: Encodable {
    let id: UUID
    let username: String
    let email: String
    let fullName: String?
    let dateOfBirth: Date?
    let careerIndustry: String?
    let experienceLevel: String?
    let socialLinks: SocialLinks?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case fullName = "full_name"
        case dateOfBirth = "date_of_birth"
        case careerIndustry = "career_industry"
        case experienceLevel = "experience_level"
        case socialLinks = "social_links"
        case avatarUrl = "avatar_url"
    }
}

// MARK: - User Update Request
struct UpdateUserRequest: Encodable {
    var username: String?
    var fullName: String?
    var avatarUrl: String?
    var usePhotoAvatar: Bool?
    var dateOfBirth: Date?
    var careerIndustry: String?
    var experienceLevel: String?
    var socialLinks: SocialLinks?
    var preferredCurrency: String?
    var riskCoins: [String]?
    var darkMode: String?
    var notifications: NotificationSettings?
    var passcodeHash: String?
    var faceIdEnabled: Bool?
    var role: UserRole?

    enum CodingKeys: String, CodingKey {
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case usePhotoAvatar = "use_photo_avatar"
        case dateOfBirth = "date_of_birth"
        case careerIndustry = "career_industry"
        case experienceLevel = "experience_level"
        case socialLinks = "social_links"
        case preferredCurrency = "preferred_currency"
        case riskCoins = "risk_coins"
        case darkMode = "dark_mode"
        case notifications
        case passcodeHash = "passcode_hash"
        case faceIdEnabled = "face_id_enabled"
        case role
    }
}
