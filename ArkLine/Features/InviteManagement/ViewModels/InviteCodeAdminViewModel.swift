import Foundation

// MARK: - Invite Code Filter

enum InviteCodeFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case used = "Used"
    case expired = "Expired"
    case revoked = "Revoked"
}

// MARK: - Invite Code Admin View Model

@MainActor
@Observable
class InviteCodeAdminViewModel {
    // MARK: - State
    var codes: [InviteCode] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Create Form State
    var recipientName = ""
    var note = ""
    var expirationDays = 7
    var isCreating = false
    var lastCreatedCode: InviteCode?

    // MARK: - Filter
    var selectedFilter: InviteCodeFilter = .all

    // MARK: - Service
    private let service: InviteCodeServiceProtocol

    init(service: InviteCodeServiceProtocol = InviteCodeService()) {
        self.service = service
    }

    // MARK: - Filtered Codes

    var filteredCodes: [InviteCode] {
        switch selectedFilter {
        case .all: return codes
        case .active: return codes.filter { $0.isValid }
        case .used: return codes.filter { $0.isUsed }
        case .expired: return codes.filter { $0.isExpired && !$0.isUsed && !$0.isRevoked }
        case .revoked: return codes.filter { $0.isRevoked }
        }
    }

    // MARK: - Stats

    var activeCodes: Int { codes.filter { $0.isValid }.count }
    var usedCodes: Int { codes.filter { $0.isUsed }.count }
    var revokedCodes: Int { codes.filter { $0.isRevoked }.count }

    // MARK: - Load Codes

    func loadCodes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            codes = try await service.fetchAllCodes()
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Create Code

    func createCode(createdBy: UUID) async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let newCode = try await service.createCode(
                createdBy: createdBy,
                expirationDays: expirationDays,
                recipientName: recipientName.nilIfEmpty,
                note: note.nilIfEmpty
            )
            codes.insert(newCode, at: 0)
            lastCreatedCode = newCode
            recipientName = ""
            note = ""
            expirationDays = 7
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Revoke Code

    func revokeCode(_ code: InviteCode) async {
        do {
            try await service.revokeCode(id: code.id)
            if let index = codes.firstIndex(where: { $0.id == code.id }) {
                codes[index].isRevoked = true
            }
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Delete Code

    func deleteCode(_ code: InviteCode) async {
        do {
            try await service.deleteCode(id: code.id)
            codes.removeAll { $0.id == code.id }
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }
}
