import Foundation
import SwiftUI

// MARK: - Broadcast View Model

/// ViewModel for managing broadcasts in both admin and user views.
@MainActor
class BroadcastViewModel: ObservableObject {

    // MARK: - Published State

    @Published var broadcasts: [Broadcast] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var unreadCount: Int = 0
    @Published var analyticsSummary: BroadcastAnalyticsSummary?
    @Published var readBroadcastIds: Set<UUID> = []
    @Published var userHeartedBroadcastIds: Set<UUID> = []
    @Published var bookmarkedBroadcastIds: Set<UUID> = []

    // MARK: - Dependencies

    private let broadcastService: BroadcastServiceProtocol
    private let notificationService = BroadcastNotificationService.shared

    // MARK: - Computed Properties

    /// Broadcasts in draft status
    var drafts: [Broadcast] {
        broadcasts.filter { $0.status == .draft }
    }

    /// Published broadcasts
    var published: [Broadcast] {
        broadcasts.filter { $0.status == .published }
    }

    /// Archived broadcasts
    var archived: [Broadcast] {
        broadcasts.filter { $0.status == .archived }
    }

    // MARK: - Initialization

    init(broadcastService: BroadcastServiceProtocol? = nil) {
        self.broadcastService = broadcastService ?? ServiceContainer.shared.broadcastService
    }

    // MARK: - Load Operations

    /// Load all broadcasts (for admin view)
    func loadBroadcasts() async {
        isLoading = true
        errorMessage = nil

        do {
            broadcasts = try await broadcastService.fetchAllBroadcasts()
            logInfo("Loaded \(broadcasts.count) broadcasts", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError("Failed to load broadcasts: \(error)", category: .data)
        }

        isLoading = false
    }

    /// Load published broadcasts for a user
    func loadPublishedBroadcasts(for userId: UUID, limit: Int = 50, offset: Int = 0) async {
        isLoading = true
        errorMessage = nil

        do {
            broadcasts = try await broadcastService.fetchPublishedBroadcasts(
                for: userId,
                limit: limit,
                offset: offset
            )
            logInfo("Loaded \(broadcasts.count) published broadcasts", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError("Failed to load published broadcasts: \(error)", category: .data)
        }

        isLoading = false
    }

    /// Update unread count for a user
    func updateUnreadCount(for userId: UUID) async {
        do {
            unreadCount = try await broadcastService.unreadCount(for: userId)
        } catch {
            logError("Failed to get unread count: \(error)", category: .data)
        }
    }

    // MARK: - CRUD Operations

    /// Create a new broadcast
    func createBroadcast(_ broadcast: Broadcast) async throws {
        do {
            let created = try await broadcastService.createBroadcast(broadcast)
            broadcasts.insert(created, at: 0)
            logInfo("Created broadcast: \(created.id)", category: .data)
        } catch {
            print("🚨 VM CREATE ERROR: \(error)")
            throw error
        }
    }

    /// Update an existing broadcast
    func updateBroadcast(_ broadcast: Broadcast) async throws {
        do {
            let updated = try await broadcastService.updateBroadcast(broadcast)

            if let index = broadcasts.firstIndex(where: { $0.id == broadcast.id }) {
                broadcasts[index] = updated
            }

            logInfo("Updated broadcast: \(updated.id)", category: .data)
        } catch {
            print("🚨 VM UPDATE ERROR: \(error)")
            throw error
        }
    }

    /// Delete a broadcast
    func deleteBroadcast(_ broadcast: Broadcast) async throws {
        try await broadcastService.deleteBroadcast(id: broadcast.id)
        broadcasts.removeAll { $0.id == broadcast.id }
        logInfo("Deleted broadcast: \(broadcast.id)", category: .data)
    }

    /// Publish a broadcast (captures BTC price at publish time)
    func publishBroadcast(_ broadcast: Broadcast) async throws {
        // Capture BTC price at publish time
        var btcPrice: Double?
        do {
            let candles = try await CoinbaseCandle.fetch(pair: "BTC-USD", granularity: "ONE_HOUR", limit: 1)
            btcPrice = candles.last?.close
        } catch {
            logWarning("Failed to fetch BTC price at publish: \(error)", category: .network)
        }

        let published: Broadcast
        do {
            published = try await broadcastService.publishBroadcast(id: broadcast.id, btcPrice: btcPrice)
        } catch {
            print("🚨 VM PUBLISH SERVICE ERROR: \(error)")
            throw error
        }

        if let index = broadcasts.firstIndex(where: { $0.id == broadcast.id }) {
            broadcasts[index] = published
        }

        // Send push notification to target audience
        await notificationService.sendBroadcastNotification(for: published, audience: published.targetAudience)

        logInfo("Published broadcast: \(published.id), BTC: \(btcPrice.map { String(format: "$%.0f", $0) } ?? "n/a")", category: .data)
    }

    /// Archive a broadcast
    func archiveBroadcast(_ broadcast: Broadcast) async throws {
        let archived = try await broadcastService.archiveBroadcast(id: broadcast.id)

        if let index = broadcasts.firstIndex(where: { $0.id == broadcast.id }) {
            broadcasts[index] = archived
        }

        logInfo("Archived broadcast: \(archived.id)", category: .data)
    }

    // MARK: - Read Tracking

    /// Mark a broadcast as read by a user
    func markAsRead(broadcastId: UUID, userId: UUID) async throws {
        try await broadcastService.markAsRead(broadcastId: broadcastId, userId: userId)

        // Update unread count
        await updateUnreadCount(for: userId)
    }

    /// Mark all published broadcasts as read for a user
    func markAllAsRead(userId: UUID) async {
        do {
            try await broadcastService.markAllAsRead(userId: userId)
            unreadCount = 0
        } catch {
            logError("Failed to mark all as read: \(error)", category: .data)
        }
    }

    // MARK: - View Tracking

    /// Increment the total view count for a broadcast (fire-and-forget)
    func incrementViewCount(broadcastId: UUID) {
        Task {
            do {
                try await broadcastService.incrementViewCount(broadcastId: broadcastId)
            } catch {
                logError("Failed to increment view count: \(error)", category: .data)
            }
        }
    }

    // MARK: - Analytics

    /// Load aggregated analytics for a given period
    func loadAnalytics(periodDays: Int) async {
        do {
            let summary = try await broadcastService.fetchAnalyticsSummary(periodDays: periodDays)
            analyticsSummary = summary
        } catch {
            logDebug("RPC analytics unavailable, computing locally: \(error)", category: .data)
            analyticsSummary = computeLocalAnalytics(periodDays: periodDays)
        }
    }

    /// Compute analytics from already-loaded broadcasts when the DB function isn't available
    private func computeLocalAnalytics(periodDays: Int) -> BroadcastAnalyticsSummary {
        let periodStart: Date
        if periodDays <= 0 {
            periodStart = .distantPast
        } else {
            periodStart = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? .distantPast
        }

        let filtered = published.filter { broadcast in
            let date = broadcast.publishedAt ?? broadcast.createdAt
            return date >= periodStart
        }

        let totalViews = filtered.compactMap(\.viewCount).reduce(0, +)
        let totalReactions = filtered.compactMap(\.reactionCount).reduce(0, +)
        let count = filtered.count
        let topBroadcast = filtered.max { ($0.viewCount ?? 0) < ($1.viewCount ?? 0) }

        return BroadcastAnalyticsSummary(
            totalBroadcasts: count,
            totalViews: totalViews,
            totalReactions: totalReactions,
            avgViewsPerBroadcast: count > 0 ? Double(totalViews) / Double(count) : 0.0,
            avgReactionsPerBroadcast: count > 0 ? Double(totalReactions) / Double(count) : 0.0,
            topPerformingBroadcastId: topBroadcast?.id,
            mostUsedReaction: nil,
            periodStart: periodStart,
            periodEnd: Date()
        )
    }

    // MARK: - File Upload

    /// Upload audio file for a broadcast
    func uploadAudio(data: Data, for broadcastId: UUID) async throws -> URL {
        let url = try await broadcastService.uploadAudio(data: data, for: broadcastId)
        logInfo("Uploaded audio for broadcast \(broadcastId)", category: .data)
        return url
    }

    /// Upload image for a broadcast
    func uploadImage(data: Data, for broadcastId: UUID) async throws -> URL {
        let url = try await broadcastService.uploadImage(data: data, for: broadcastId)
        logInfo("Uploaded image for broadcast \(broadcastId)", category: .data)
        return url
    }

    // MARK: - Reactions

    /// Toggle a reaction on a broadcast
    func toggleReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws {
        // Check if user already reacted with this emoji
        let summary = try await broadcastService.fetchReactionSummary(for: broadcastId, userId: userId)
        let hasReacted = summary.first(where: { $0.emoji == emoji })?.hasUserReacted ?? false

        if hasReacted {
            try await broadcastService.removeReaction(broadcastId: broadcastId, userId: userId, emoji: emoji)
            logInfo("Removed reaction \(emoji) from broadcast \(broadcastId)", category: .data)
        } else {
            try await broadcastService.addReaction(broadcastId: broadcastId, userId: userId, emoji: emoji)
            logInfo("Added reaction \(emoji) to broadcast \(broadcastId)", category: .data)
        }
    }

    /// Fetch reaction summary for a broadcast
    func fetchReactionSummary(for broadcastId: UUID, userId: UUID) async throws -> [ReactionSummary] {
        return try await broadcastService.fetchReactionSummary(for: broadcastId, userId: userId)
    }

    // MARK: - Read Status

    /// Check if a broadcast has been read
    func isRead(_ broadcastId: UUID) -> Bool {
        readBroadcastIds.contains(broadcastId)
    }

    /// Load which broadcasts the user has read
    func loadReadStatus(userId: UUID) async {
        do {
            readBroadcastIds = try await broadcastService.fetchReadBroadcastIds(userId: userId)
        } catch {
            logError("Failed to load read status: \(error)", category: .data)
        }
    }

    // MARK: - Quick React

    /// Load which broadcasts the user has hearted
    func loadUserHearts(userId: UUID) async {
        do {
            userHeartedBroadcastIds = try await broadcastService.fetchUserReactedBroadcastIds(userId: userId, emoji: "❤️")
        } catch {
            logError("Failed to load user hearts: \(error)", category: .data)
        }
    }

    /// Quick toggle heart from the card (optimistic UI)
    func quickToggleHeart(broadcastId: UUID, userId: UUID) async {
        let wasHearted = userHeartedBroadcastIds.contains(broadcastId)

        // Optimistic update
        if wasHearted {
            userHeartedBroadcastIds.remove(broadcastId)
            if let idx = broadcasts.firstIndex(where: { $0.id == broadcastId }) {
                broadcasts[idx].reactionCount = max(0, (broadcasts[idx].reactionCount ?? 1) - 1)
            }
        } else {
            userHeartedBroadcastIds.insert(broadcastId)
            if let idx = broadcasts.firstIndex(where: { $0.id == broadcastId }) {
                broadcasts[idx].reactionCount = (broadcasts[idx].reactionCount ?? 0) + 1
            }
        }

        do {
            try await toggleReaction(broadcastId: broadcastId, userId: userId, emoji: "❤️")
        } catch {
            // Revert on failure
            if wasHearted {
                userHeartedBroadcastIds.insert(broadcastId)
            } else {
                userHeartedBroadcastIds.remove(broadcastId)
            }
            logError("Failed to toggle heart: \(error)", category: .data)
        }
    }

    // MARK: - Bookmarks

    /// Load bookmarked broadcast IDs for current user
    func loadBookmarks(userId: UUID) async {
        do {
            bookmarkedBroadcastIds = try await broadcastService.fetchBookmarkedBroadcastIds(userId: userId)
        } catch {
            logError("Failed to load bookmarks: \(error)", category: .data)
        }
    }

    /// Check if a broadcast is bookmarked
    func isBookmarked(_ broadcastId: UUID) -> Bool {
        bookmarkedBroadcastIds.contains(broadcastId)
    }

    /// Toggle bookmark with optimistic UI
    func toggleBookmark(broadcastId: UUID, userId: UUID) async {
        let wasBookmarked = bookmarkedBroadcastIds.contains(broadcastId)

        // Optimistic update
        if wasBookmarked {
            bookmarkedBroadcastIds.remove(broadcastId)
        } else {
            bookmarkedBroadcastIds.insert(broadcastId)
        }

        do {
            if wasBookmarked {
                try await broadcastService.removeBookmark(broadcastId: broadcastId, userId: userId)
            } else {
                try await broadcastService.addBookmark(broadcastId: broadcastId, userId: userId)
            }
        } catch {
            // Revert on failure
            if wasBookmarked {
                bookmarkedBroadcastIds.insert(broadcastId)
            } else {
                bookmarkedBroadcastIds.remove(broadcastId)
            }
            logError("Failed to toggle bookmark: \(error)", category: .data)
        }
    }

    // MARK: - Pinning

    /// Toggle pin on a broadcast (admin only)
    func togglePin(_ broadcast: Broadcast) async throws {
        let newPinned = !broadcast.isPinned
        try await broadcastService.setPinned(broadcastId: broadcast.id, isPinned: newPinned)

        // Update local state
        for i in broadcasts.indices {
            if broadcasts[i].id == broadcast.id {
                broadcasts[i].isPinned = newPinned
            } else if newPinned {
                broadcasts[i].isPinned = false
            }
        }
    }
}
