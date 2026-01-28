import Foundation

// MARK: - Broadcast Service Protocol

/// Protocol defining broadcast operations for the Broadcast Studio feature.
protocol BroadcastServiceProtocol {

    // MARK: - Fetch Operations

    /// Fetches all broadcasts (admin only - includes drafts)
    /// - Returns: Array of all Broadcast objects
    func fetchAllBroadcasts() async throws -> [Broadcast]

    /// Fetches published broadcasts for user feed
    /// - Parameters:
    ///   - userId: The user's ID for audience filtering
    ///   - limit: Maximum number of broadcasts to fetch
    ///   - offset: Offset for pagination
    /// - Returns: Array of published Broadcast objects
    func fetchPublishedBroadcasts(for userId: UUID, limit: Int, offset: Int) async throws -> [Broadcast]

    /// Fetches a single broadcast by ID
    /// - Parameter id: The broadcast ID
    /// - Returns: The Broadcast object if found
    func fetchBroadcast(id: UUID) async throws -> Broadcast

    /// Fetches broadcasts by status (admin only)
    /// - Parameter status: The status to filter by
    /// - Returns: Array of Broadcast objects matching the status
    func fetchBroadcasts(byStatus status: BroadcastStatus) async throws -> [Broadcast]

    // MARK: - Create/Update Operations

    /// Creates a new broadcast
    /// - Parameter broadcast: The Broadcast to create
    /// - Returns: The created Broadcast with server-assigned values
    func createBroadcast(_ broadcast: Broadcast) async throws -> Broadcast

    /// Updates an existing broadcast
    /// - Parameter broadcast: The Broadcast with updated values
    /// - Returns: The updated Broadcast
    func updateBroadcast(_ broadcast: Broadcast) async throws -> Broadcast

    /// Deletes a broadcast
    /// - Parameter id: The broadcast ID to delete
    func deleteBroadcast(id: UUID) async throws

    /// Publishes a broadcast
    /// - Parameter id: The broadcast ID to publish
    /// - Returns: The published Broadcast with updated status
    func publishBroadcast(id: UUID) async throws -> Broadcast

    /// Archives a broadcast
    /// - Parameter id: The broadcast ID to archive
    /// - Returns: The archived Broadcast
    func archiveBroadcast(id: UUID) async throws -> Broadcast

    // MARK: - Read Tracking

    /// Marks a broadcast as read by a user
    /// - Parameters:
    ///   - broadcastId: The broadcast ID
    ///   - userId: The user's ID
    func markAsRead(broadcastId: UUID, userId: UUID) async throws

    /// Checks if a broadcast has been read by a user
    /// - Parameters:
    ///   - broadcastId: The broadcast ID
    ///   - userId: The user's ID
    /// - Returns: True if the user has read the broadcast
    func hasBeenRead(broadcastId: UUID, userId: UUID) async throws -> Bool

    /// Fetches unread broadcast count for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Number of unread broadcasts
    func unreadCount(for userId: UUID) async throws -> Int

    // MARK: - File Upload

    /// Uploads an audio file for a broadcast
    /// - Parameters:
    ///   - data: The audio file data
    ///   - broadcastId: The broadcast ID
    /// - Returns: The URL of the uploaded audio file
    func uploadAudio(data: Data, for broadcastId: UUID) async throws -> URL

    /// Uploads an image for a broadcast
    /// - Parameters:
    ///   - data: The image data
    ///   - broadcastId: The broadcast ID
    /// - Returns: The URL of the uploaded image
    func uploadImage(data: Data, for broadcastId: UUID) async throws -> URL

    /// Deletes an uploaded file
    /// - Parameter url: The URL of the file to delete
    func deleteFile(at url: URL) async throws

    // MARK: - Reactions

    /// Adds a reaction to a broadcast
    /// - Parameters:
    ///   - broadcastId: The broadcast ID
    ///   - userId: The user's ID
    ///   - emoji: The reaction emoji
    func addReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws

    /// Removes a reaction from a broadcast
    /// - Parameters:
    ///   - broadcastId: The broadcast ID
    ///   - userId: The user's ID
    ///   - emoji: The reaction emoji to remove
    func removeReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws

    /// Fetches all reactions for a broadcast
    /// - Parameter broadcastId: The broadcast ID
    /// - Returns: Array of BroadcastReaction objects
    func fetchReactions(for broadcastId: UUID) async throws -> [BroadcastReaction]

    /// Fetches reaction summary for a broadcast (counts per emoji)
    /// - Parameters:
    ///   - broadcastId: The broadcast ID
    ///   - userId: Current user's ID to check if they reacted
    /// - Returns: Array of ReactionSummary objects
    func fetchReactionSummary(for broadcastId: UUID, userId: UUID) async throws -> [ReactionSummary]
}
