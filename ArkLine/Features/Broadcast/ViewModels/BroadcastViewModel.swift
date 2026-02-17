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
        let created = try await broadcastService.createBroadcast(broadcast)
        broadcasts.insert(created, at: 0)
        logInfo("Created broadcast: \(created.id)", category: .data)
    }

    /// Update an existing broadcast
    func updateBroadcast(_ broadcast: Broadcast) async throws {
        let updated = try await broadcastService.updateBroadcast(broadcast)

        if let index = broadcasts.firstIndex(where: { $0.id == broadcast.id }) {
            broadcasts[index] = updated
        }

        logInfo("Updated broadcast: \(updated.id)", category: .data)
    }

    /// Delete a broadcast
    func deleteBroadcast(_ broadcast: Broadcast) async throws {
        try await broadcastService.deleteBroadcast(id: broadcast.id)
        broadcasts.removeAll { $0.id == broadcast.id }
        logInfo("Deleted broadcast: \(broadcast.id)", category: .data)
    }

    /// Publish a broadcast
    func publishBroadcast(_ broadcast: Broadcast) async throws {
        let published = try await broadcastService.publishBroadcast(id: broadcast.id)

        if let index = broadcasts.firstIndex(where: { $0.id == broadcast.id }) {
            broadcasts[index] = published
        }

        // Send push notification to target audience
        await notificationService.sendBroadcastNotification(for: published, audience: published.targetAudience)

        logInfo("Published broadcast: \(published.id)", category: .data)
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
}
