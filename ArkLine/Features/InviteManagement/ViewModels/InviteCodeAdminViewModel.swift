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
    var recipientEmail = ""
    var note = ""
    var expirationDays = 7
    var trialDays: Int? = nil
    var isCreating = false
    var lastCreatedCode: InviteCode?

    // MARK: - Filter
    var selectedFilter: InviteCodeFilter = .all

    // MARK: - Service
    private let service: InviteCodeServiceProtocol
    private static let cacheKey = "arkline_cached_invite_codes"

    init(service: InviteCodeServiceProtocol = InviteCodeService()) {
        self.service = service
        loadFromLocalCache()
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
            saveToLocalCache()
        } catch {
            // If fetch fails and we have no codes, keep the cached ones
            if codes.isEmpty {
                loadFromLocalCache()
            }
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
                note: note.nilIfEmpty,
                email: recipientEmail.nilIfEmpty,
                trialDays: trialDays
            )
            codes.insert(newCode, at: 0)
            lastCreatedCode = newCode
            saveToLocalCache()
            recipientName = ""
            recipientEmail = ""
            note = ""
            expirationDays = 7
            trialDays = nil
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Update Code

    func updateCode(_ code: InviteCode, recipientName: String?, note: String?, email: String?) async {
        do {
            try await service.updateCode(id: code.id, recipientName: recipientName, note: note, email: email)
            if let index = codes.firstIndex(where: { $0.id == code.id }) {
                codes[index].recipientName = recipientName
                codes[index].note = note
                codes[index].email = email
            }
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
                saveToLocalCache()
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
            saveToLocalCache()
        } catch {
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Local Cache

    private func saveToLocalCache() {
        do {
            let data = try JSONEncoder().encode(codes)
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        } catch {
            logWarning("Failed to cache invite codes: \(error.localizedDescription)", category: .data)
        }
    }

    private func loadFromLocalCache() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode([InviteCode].self, from: data) else { return }
        if codes.isEmpty {
            codes = cached
        }
    }
}
