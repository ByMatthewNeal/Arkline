import Foundation

// MARK: - Feature Request Service Protocol

protocol FeatureRequestServiceProtocol {
    func fetchAllRequests() async throws -> [FeatureRequest]
    func fetchRequests(byStatus status: FeatureStatus) async throws -> [FeatureRequest]
    func fetchMyRequests(userId: UUID) async throws -> [FeatureRequest]
    func createRequest(_ request: FeatureRequest) async throws -> FeatureRequest
    func updateRequest(_ request: FeatureRequest) async throws
    func deleteRequest(id: UUID) async throws
}

// MARK: - Feature Request Service

/// Service for managing feature requests via Supabase
final class FeatureRequestService: FeatureRequestServiceProtocol {
    private let supabase = SupabaseManager.shared

    // MARK: - Fetch All Requests (Admin)

    func fetchAllRequests() async throws -> [FeatureRequest] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let requests: [FeatureRequest] = try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(requests.count) feature requests", category: .network)
            return requests
        } catch {
            logError(error, context: "Fetch all feature requests", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Fetch Requests by Status

    func fetchRequests(byStatus status: FeatureStatus) async throws -> [FeatureRequest] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let requests: [FeatureRequest] = try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .select()
                .eq("status", value: status.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value

            return requests
        } catch {
            logError(error, context: "Fetch feature requests by status", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Fetch My Requests (User)

    func fetchMyRequests(userId: UUID) async throws -> [FeatureRequest] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let requests: [FeatureRequest] = try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .select()
                .eq("author_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            return requests
        } catch {
            logError(error, context: "Fetch user's feature requests", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Create Request

    func createRequest(_ request: FeatureRequest) async throws -> FeatureRequest {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let createdRequests: [FeatureRequest] = try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .insert(request)
                .select()
                .execute()
                .value

            guard let created = createdRequests.first else {
                throw AppError.custom(message: "Failed to create feature request")
            }

            logInfo("Created feature request: \(created.title)", category: .network)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create feature request", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Update Request (Admin)

    func updateRequest(_ request: FeatureRequest) async throws {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .update(request)
                .eq("id", value: request.id.uuidString)
                .execute()

            logInfo("Updated feature request: \(request.title)", category: .network)
        } catch {
            logError(error, context: "Update feature request", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Delete Request (Admin)

    func deleteRequest(id: UUID) async throws {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.featureRequests.rawValue)
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            logInfo("Deleted feature request: \(id)", category: .network)
        } catch {
            logError(error, context: "Delete feature request", category: .network)
            throw AppError.networkError(underlying: error)
        }
    }
}
