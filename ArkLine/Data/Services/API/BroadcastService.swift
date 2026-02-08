import Foundation

// MARK: - Broadcast Service

/// Real API implementation of BroadcastServiceProtocol.
/// Uses Supabase for broadcast data storage.
final class BroadcastService: BroadcastServiceProtocol {

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Fetch Operations

    func fetchAllBroadcasts() async throws -> [Broadcast] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured, returning empty broadcasts", category: .network)
            return []
        }

        let broadcasts: [Broadcast] = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return broadcasts
    }

    func fetchPublishedBroadcasts(for userId: UUID, limit: Int, offset: Int) async throws -> [Broadcast] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured, returning empty broadcasts", category: .network)
            return []
        }

        // Fetch published broadcasts
        // RLS policies handle audience filtering on the server
        let broadcasts: [Broadcast] = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .select()
            .eq("status", value: BroadcastStatus.published.rawValue)
            .order("published_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return broadcasts
    }

    func fetchBroadcast(id: UUID) async throws -> Broadcast {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let broadcasts: [Broadcast] = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let broadcast = broadcasts.first else {
            throw AppError.notFound
        }

        return broadcast
    }

    func fetchBroadcasts(byStatus status: BroadcastStatus) async throws -> [Broadcast] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured, returning empty broadcasts", category: .network)
            return []
        }

        let broadcasts: [Broadcast] = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .select()
            .eq("status", value: status.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value

        return broadcasts
    }

    // MARK: - Create/Update Operations

    func createBroadcast(_ broadcast: Broadcast) async throws -> Broadcast {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let created: Broadcast = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .insert(broadcast)
            .select()
            .single()
            .execute()
            .value

        logInfo("Created broadcast: \(created.id)", category: .data)
        return created
    }

    func updateBroadcast(_ broadcast: Broadcast) async throws -> Broadcast {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let updated: Broadcast = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .update(broadcast)
            .eq("id", value: broadcast.id.uuidString)
            .select()
            .single()
            .execute()
            .value

        logInfo("Updated broadcast: \(updated.id)", category: .data)
        return updated
    }

    func deleteBroadcast(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        logInfo("Deleted broadcast: \(id)", category: .data)
    }

    func publishBroadcast(id: UUID) async throws -> Broadcast {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        // Atomic update — no fetch-modify-update race
        let updated: Broadcast = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .update(PublishUpdate(status: BroadcastStatus.published.rawValue, publishedAt: Date()))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        logInfo("Published broadcast: \(updated.id)", category: .data)
        return updated
    }

    func archiveBroadcast(id: UUID) async throws -> Broadcast {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        // Atomic update — no fetch-modify-update race
        let updated: Broadcast = try await supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .update(StatusUpdate(status: BroadcastStatus.archived.rawValue))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        logInfo("Archived broadcast: \(updated.id)", category: .data)
        return updated
    }

    // MARK: - Read Tracking

    func markAsRead(broadcastId: UUID, userId: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let readRecord = BroadcastRead(
            id: UUID(),
            broadcastId: broadcastId,
            userId: userId,
            readAt: Date()
        )

        // Upsert to handle duplicate reads gracefully
        try await supabase.database
            .from(SupabaseTable.broadcastReads.rawValue)
            .upsert(readRecord)
            .execute()

        logInfo("Marked broadcast \(broadcastId) as read by \(userId)", category: .data)
    }

    func hasBeenRead(broadcastId: UUID, userId: UUID) async throws -> Bool {
        guard supabase.isConfigured else {
            return false
        }

        let reads: [BroadcastRead] = try await supabase.database
            .from(SupabaseTable.broadcastReads.rawValue)
            .select()
            .eq("broadcast_id", value: broadcastId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return !reads.isEmpty
    }

    func unreadCount(for userId: UUID) async throws -> Int {
        guard supabase.isConfigured else {
            return 0
        }

        // Two lightweight queries instead of N+1
        struct IdRow: Codable { let id: UUID }
        struct BroadcastIdRow: Codable {
            let broadcastId: UUID
            enum CodingKeys: String, CodingKey { case broadcastId = "broadcast_id" }
        }

        async let publishedTask: [IdRow] = supabase.database
            .from(SupabaseTable.broadcasts.rawValue)
            .select("id")
            .eq("status", value: BroadcastStatus.published.rawValue)
            .execute()
            .value

        async let readTask: [BroadcastIdRow] = supabase.database
            .from(SupabaseTable.broadcastReads.rawValue)
            .select("broadcast_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let (publishedIds, readIds) = try await (publishedTask, readTask)
        let readSet = Set(readIds.map { $0.broadcastId })
        return publishedIds.filter { !readSet.contains($0.id) }.count
    }

    // MARK: - File Upload

    func uploadAudio(data: Data, for broadcastId: UUID) async throws -> URL {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let fileName = "\(broadcastId.uuidString)/audio_\(Date().timeIntervalSince1970).m4a"
        _ = try await supabase.storage
            .from(SupabaseBucket.broadcastMedia.rawValue)
            .upload(
                path: fileName,
                file: data,
                options: .init(contentType: "audio/m4a")
            )

        let publicURL = try supabase.storage
            .from(SupabaseBucket.broadcastMedia.rawValue)
            .getPublicURL(path: fileName)

        logInfo("Uploaded audio for broadcast \(broadcastId): \(publicURL)", category: .data)
        return publicURL
    }

    func uploadImage(data: Data, for broadcastId: UUID) async throws -> URL {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let fileName = "\(broadcastId.uuidString)/image_\(Date().timeIntervalSince1970).jpg"
        _ = try await supabase.storage
            .from(SupabaseBucket.broadcastMedia.rawValue)
            .upload(
                path: fileName,
                file: data,
                options: .init(contentType: "image/jpeg")
            )

        let publicURL = try supabase.storage
            .from(SupabaseBucket.broadcastMedia.rawValue)
            .getPublicURL(path: fileName)

        logInfo("Uploaded image for broadcast \(broadcastId): \(publicURL)", category: .data)
        return publicURL
    }

    func deleteFile(at url: URL) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        // Extract path from URL
        let path = url.lastPathComponent
        try await supabase.storage
            .from(SupabaseBucket.broadcastMedia.rawValue)
            .remove(paths: [path])

        logInfo("Deleted file at: \(url)", category: .data)
    }

    // MARK: - Reactions

    func addReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let reaction = BroadcastReaction(
            broadcastId: broadcastId,
            userId: userId,
            emoji: emoji
        )

        // Upsert to handle toggling reactions
        try await supabase.database
            .from(SupabaseTable.broadcastReactions.rawValue)
            .upsert(reaction)
            .execute()

        logInfo("Added reaction \(emoji) to broadcast \(broadcastId) by \(userId)", category: .data)
    }

    func removeReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        try await supabase.database
            .from(SupabaseTable.broadcastReactions.rawValue)
            .delete()
            .eq("broadcast_id", value: broadcastId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .eq("emoji", value: emoji)
            .execute()

        logInfo("Removed reaction \(emoji) from broadcast \(broadcastId) by \(userId)", category: .data)
    }

    func fetchReactions(for broadcastId: UUID) async throws -> [BroadcastReaction] {
        guard supabase.isConfigured else {
            return []
        }

        let reactions: [BroadcastReaction] = try await supabase.database
            .from(SupabaseTable.broadcastReactions.rawValue)
            .select()
            .eq("broadcast_id", value: broadcastId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        return reactions
    }

    func fetchReactionSummary(for broadcastId: UUID, userId: UUID) async throws -> [ReactionSummary] {
        guard supabase.isConfigured else {
            return []
        }

        // Fetch all reactions for this broadcast
        let reactions = try await fetchReactions(for: broadcastId)

        // Group by emoji and count
        var emojiCounts: [String: Int] = [:]
        var userReactions: Set<String> = []

        for reaction in reactions {
            emojiCounts[reaction.emoji, default: 0] += 1
            if reaction.userId == userId {
                userReactions.insert(reaction.emoji)
            }
        }

        // Convert to ReactionSummary array
        let summaries = emojiCounts.map { emoji, count in
            ReactionSummary(
                emoji: emoji,
                count: count,
                hasUserReacted: userReactions.contains(emoji)
            )
        }.sorted { $0.count > $1.count }

        return summaries
    }
}

// MARK: - Atomic Update Structs

private struct PublishUpdate: Encodable {
    let status: String
    let publishedAt: Date
    enum CodingKeys: String, CodingKey {
        case status
        case publishedAt = "published_at"
    }
}

private struct StatusUpdate: Encodable {
    let status: String
}

// MARK: - AppError Extension

extension AppError {
    static let supabaseNotConfigured = AppError.custom(message: "Supabase is not configured")
}
