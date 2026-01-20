import SwiftUI
import Foundation

// MARK: - Community Tab Selection
enum CommunityTab: String, CaseIterable {
    case feed = "Feed"
    case messages = "Messages"
    case chat = "Chat"
}

// MARK: - Community View Model
@Observable
final class CommunityViewModel {
    // MARK: - State
    var selectedTab: CommunityTab = .feed
    var posts: [CommunityPost] = []
    var chatRooms: [ChatRoom] = []
    var selectedCategory: PostCategory?

    var isLoading = false
    var error: AppError?

    // MARK: - Search & Filter
    var searchText = ""

    // MARK: - Computed Properties
    var filteredPosts: [CommunityPost] {
        var result = posts

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Initialization
    init() {
        loadMockData()
    }

    // MARK: - Data Loading
    func refresh() async {
        isLoading = true
        error = nil

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        loadMockData()
        isLoading = false
    }

    private func loadMockData() {
        let userId = UUID()
        let author = PostAuthor(id: userId, username: "cryptoTrader", avatarUrl: nil)

        posts = [
            CommunityPost(
                userId: userId,
                title: "Bitcoin Breaking $70k - Analysis",
                content: "Bitcoin has finally broken through the $70k resistance level. Here's my analysis of what this means for the market and potential targets going forward...",
                category: .analysis,
                likesCount: 45,
                commentsCount: 12,
                createdAt: Date().addingTimeInterval(-3600),
                author: author
            ),
            CommunityPost(
                userId: userId,
                title: "Fed Rate Decision Impact on Crypto",
                content: "The Federal Reserve just announced their latest interest rate decision. Let's discuss how this might affect cryptocurrency markets in the coming weeks.",
                category: .news,
                likesCount: 32,
                commentsCount: 8,
                createdAt: Date().addingTimeInterval(-7200),
                author: PostAuthor(id: UUID(), username: "macroAnalyst", avatarUrl: nil)
            ),
            CommunityPost(
                userId: userId,
                title: "What's your favorite DeFi protocol?",
                content: "I've been exploring different DeFi protocols lately. Curious to hear what everyone's favorites are and why. Share your experiences!",
                category: .discussion,
                likesCount: 18,
                commentsCount: 24,
                createdAt: Date().addingTimeInterval(-14400),
                author: PostAuthor(id: UUID(), username: "defiExplorer", avatarUrl: nil)
            ),
            CommunityPost(
                userId: userId,
                title: "ETH 2.0 Staking Rewards Update",
                content: "Here's an update on current ETH staking rewards and how they compare to previous months. Is staking still worth it?",
                category: .analysis,
                likesCount: 56,
                commentsCount: 15,
                createdAt: Date().addingTimeInterval(-28800),
                author: PostAuthor(id: UUID(), username: "stakingPro", avatarUrl: nil)
            )
        ]

        chatRooms = [
            ChatRoom(
                id: UUID(),
                name: "General Chat",
                description: "Discuss anything crypto-related",
                type: .general,
                isPremium: false,
                createdAt: Date()
            ),
            ChatRoom(
                id: UUID(),
                name: "Premium Signals",
                description: "Exclusive trading signals and analysis",
                type: .premium,
                isPremium: true,
                createdAt: Date()
            ),
            ChatRoom(
                id: UUID(),
                name: "Bitcoin Discussion",
                description: "All things Bitcoin",
                type: .topic,
                isPremium: false,
                createdAt: Date()
            ),
            ChatRoom(
                id: UUID(),
                name: "Altcoin Season",
                description: "Discuss altcoins and emerging projects",
                type: .topic,
                isPremium: false,
                createdAt: Date()
            )
        ]
    }

    // MARK: - Actions
    func selectTab(_ tab: CommunityTab) {
        selectedTab = tab
    }

    func selectCategory(_ category: PostCategory?) {
        selectedCategory = category
    }

    func likePost(_ post: CommunityPost) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].likesCount += 1
            posts[index].isLikedByCurrentUser = true
        }
    }

    func unlikePost(_ post: CommunityPost) {
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].likesCount -= 1
            posts[index].isLikedByCurrentUser = false
        }
    }
}
