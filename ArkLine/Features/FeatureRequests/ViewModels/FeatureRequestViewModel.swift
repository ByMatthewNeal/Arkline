import Foundation

// MARK: - Feature Request View Model

@MainActor
@Observable
final class FeatureRequestViewModel {
    // MARK: - State

    var requests: [FeatureRequest] = []
    var isLoading = false
    var errorMessage: String?
    var selectedFilter: FeatureStatus? = nil

    // MARK: - Service

    private let service = FeatureRequestService()

    // MARK: - Filtered Requests

    var filteredRequests: [FeatureRequest] {
        guard let filter = selectedFilter else {
            return requests.sorted { lhs, rhs in
                // Sort by priority first (critical first), then by date
                let lhsPriority = lhs.priority?.sortOrder ?? 99
                let rhsPriority = rhs.priority?.sortOrder ?? 99
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return lhs.createdAt > rhs.createdAt
            }
        }
        return requests.filter { $0.status == filter }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var pendingRequests: [FeatureRequest] {
        requests.filter { $0.status == .pending }
    }

    var reviewingRequests: [FeatureRequest] {
        requests.filter { $0.status == .reviewing }
    }

    var approvedRequests: [FeatureRequest] {
        requests.filter { $0.status == .approved }
    }

    var rejectedRequests: [FeatureRequest] {
        requests.filter { $0.status == .rejected }
    }

    var implementedRequests: [FeatureRequest] {
        requests.filter { $0.status == .implemented }
    }

    // MARK: - Stats

    var totalCount: Int { requests.count }
    var pendingCount: Int { pendingRequests.count }
    var approvedCount: Int { approvedRequests.count }
    var implementedCount: Int { implementedRequests.count }

    // MARK: - Load Requests

    func loadRequests() async {
        isLoading = true
        errorMessage = nil

        do {
            requests = try await service.fetchAllRequests()
            logInfo("Loaded \(requests.count) feature requests", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Load feature requests", category: .data)
        }

        isLoading = false
    }

    // MARK: - Update Request

    func updateStatus(for request: FeatureRequest, to status: FeatureStatus) async {
        var updatedRequest = request
        updatedRequest.status = status
        updatedRequest.reviewedAt = Date()
        updatedRequest.reviewedBy = SupabaseAuthManager.shared.currentUserId

        do {
            try await service.updateRequest(updatedRequest)

            // Update local state
            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = updatedRequest
            }

            logInfo("Updated request status to \(status.rawValue)", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Update request status", category: .data)
        }
    }

    func updatePriority(for request: FeatureRequest, to priority: FeaturePriority) async {
        var updatedRequest = request
        updatedRequest.priority = priority

        do {
            try await service.updateRequest(updatedRequest)

            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = updatedRequest
            }

            logInfo("Updated request priority to \(priority.rawValue)", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Update request priority", category: .data)
        }
    }

    func updateAdminNotes(for request: FeatureRequest, notes: String) async {
        var updatedRequest = request
        updatedRequest.adminNotes = notes.isEmpty ? nil : notes

        do {
            try await service.updateRequest(updatedRequest)

            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = updatedRequest
            }

            logInfo("Updated admin notes", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Update admin notes", category: .data)
        }
    }

    func saveRequest(_ request: FeatureRequest) async {
        do {
            try await service.updateRequest(request)

            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = request
            }

            logInfo("Saved request changes", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Save request", category: .data)
        }
    }

    // MARK: - Delete Request

    func deleteRequest(_ request: FeatureRequest) async {
        do {
            try await service.deleteRequest(id: request.id)
            requests.removeAll { $0.id == request.id }
            logInfo("Deleted request: \(request.title)", category: .data)
        } catch {
            errorMessage = AppError.from(error).userMessage
            logError(error, context: "Delete request", category: .data)
        }
    }

    // MARK: - AI Analysis

    func analyzeImportance(for request: FeatureRequest) async -> String {
        // Generate AI analysis of the feature request importance
        let analysis = """
        **Priority Assessment for: \(request.title)**

        **Category:** \(request.category.displayName)

        **Analysis:**
        Based on the request description, this feature would:
        - Impact: Moderate user experience improvement
        - Feasibility: Requires \(estimateFeasibility(request))
        - Alignment: \(assessAlignment(request))

        **Recommendation:** \(generateRecommendation(request))
        """

        // Update the request with AI analysis
        var updatedRequest = request
        updatedRequest.aiAnalysis = analysis

        do {
            try await service.updateRequest(updatedRequest)
            if let index = requests.firstIndex(where: { $0.id == request.id }) {
                requests[index] = updatedRequest
            }
        } catch {
            logError(error, context: "Save AI analysis", category: .data)
        }

        return analysis
    }

    private func estimateFeasibility(_ request: FeatureRequest) -> String {
        switch request.category {
        case .ui: return "minimal development effort"
        case .portfolio, .market: return "moderate backend changes"
        case .alerts: return "notification system integration"
        case .social: return "significant architectural changes"
        case .performance: return "optimization work"
        case .other: return "further scoping needed"
        }
    }

    private func assessAlignment(_ request: FeatureRequest) -> String {
        switch request.category {
        case .portfolio, .market: return "Core feature - high alignment with app goals"
        case .alerts: return "User engagement feature - good alignment"
        case .ui: return "UX improvement - enhances existing features"
        case .social: return "Community feature - expansion opportunity"
        case .performance: return "Technical improvement - foundation work"
        case .other: return "Needs evaluation for strategic fit"
        }
    }

    private func generateRecommendation(_ request: FeatureRequest) -> String {
        let descLength = request.description.count
        if descLength < 50 {
            return "Request needs more detail before evaluation"
        } else if request.category == .portfolio || request.category == .market {
            return "Consider for next sprint - core functionality"
        } else if request.category == .ui {
            return "Quick win - can be addressed in polish phase"
        } else {
            return "Add to backlog for future consideration"
        }
    }
}
