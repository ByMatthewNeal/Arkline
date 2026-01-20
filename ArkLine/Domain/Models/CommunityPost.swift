import Foundation

// MARK: - Community Post
struct CommunityPost: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var title: String
    var content: String
    var imageUrl: String?
    var category: PostCategory?
    var likesCount: Int
    var commentsCount: Int
    let createdAt: Date
    var updatedAt: Date

    // Joined data
    var author: PostAuthor?
    var isLikedByCurrentUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case content
        case imageUrl = "image_url"
        case category
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        content: String,
        imageUrl: String? = nil,
        category: PostCategory? = nil,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        author: PostAuthor? = nil,
        isLikedByCurrentUser: Bool? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.imageUrl = imageUrl
        self.category = category
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.author = author
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }

    var formattedDate: String {
        createdAt.relativeTime
    }

    var contentPreview: String {
        content.truncated(to: 200)
    }
}

// MARK: - Post Author (simplified user info)
struct PostAuthor: Codable, Equatable {
    let id: UUID
    let username: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Post Category
enum PostCategory: String, Codable, CaseIterable {
    case news
    case analysis
    case discussion

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .news: return "newspaper.fill"
        case .analysis: return "chart.bar.fill"
        case .discussion: return "bubble.left.and.bubble.right.fill"
        }
    }

    var color: String {
        switch self {
        case .news: return "#3B82F6"
        case .analysis: return "#8B5CF6"
        case .discussion: return "#22C55E"
        }
    }
}

// MARK: - Comment
struct Comment: Codable, Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    var parentId: UUID?
    var content: String
    var likesCount: Int
    let createdAt: Date

    // Joined data
    var author: PostAuthor?
    var replies: [Comment]?
    var isLikedByCurrentUser: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case parentId = "parent_id"
        case content
        case likesCount = "likes_count"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        postId: UUID,
        userId: UUID,
        parentId: UUID? = nil,
        content: String,
        likesCount: Int = 0,
        createdAt: Date = Date(),
        author: PostAuthor? = nil,
        replies: [Comment]? = nil,
        isLikedByCurrentUser: Bool? = nil
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.parentId = parentId
        self.content = content
        self.likesCount = likesCount
        self.createdAt = createdAt
        self.author = author
        self.replies = replies
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }

    var isReply: Bool {
        parentId != nil
    }

    var formattedDate: String {
        createdAt.relativeTime
    }
}

// MARK: - Chat Room
struct ChatRoom: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String?
    var type: ChatRoomType
    var isPremium: Bool
    let createdAt: Date

    // Computed
    var memberCount: Int?
    var lastMessage: ChatRoomMessage?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case type
        case isPremium = "is_premium"
        case createdAt = "created_at"
    }
}

enum ChatRoomType: String, Codable, CaseIterable {
    case general
    case premium
    case topic

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Chat Room Message
struct ChatRoomMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let roomId: UUID
    let userId: UUID
    var content: String
    let createdAt: Date

    // Joined data
    var author: PostAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
    }

    var formattedTime: String {
        if createdAt.isToday {
            return createdAt.displayTime
        }
        return createdAt.smartDisplay
    }
}

// MARK: - Create Post Request
struct CreatePostRequest: Encodable {
    let userId: UUID
    let title: String
    let content: String
    let imageUrl: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case content
        case imageUrl = "image_url"
        case category
    }
}

// MARK: - Create Comment Request
struct CreateCommentRequest: Encodable {
    let postId: UUID
    let userId: UUID
    let parentId: UUID?
    let content: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case parentId = "parent_id"
        case content
    }
}

// MARK: - Create Chat Message Request
struct CreateChatRoomMessageRequest: Encodable {
    let roomId: UUID
    let userId: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case userId = "user_id"
        case content
    }
}

// MARK: - Post Like
struct PostLike: Codable {
    let postId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

// MARK: - Comment Like
struct CommentLike: Codable {
    let commentId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case userId = "user_id"
    }
}
