import Foundation

// MARK: - Invite Code Service

/// Real implementation of InviteCodeServiceProtocol using Supabase.
final class InviteCodeService: InviteCodeServiceProtocol {

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Validate Code

    func validateCode(_ code: String) async throws -> InviteCode? {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return nil
        }

        let normalized = code.uppercased().trimmingCharacters(in: .whitespaces)

        let codes: [InviteCode] = try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .select()
            .eq("code", value: normalized)
            .limit(1)
            .execute()
            .value

        guard let inviteCode = codes.first, inviteCode.isValid else {
            return nil
        }

        return inviteCode
    }

    // MARK: - Redeem Code

    func redeemCode(_ code: String, userId: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.custom(message: "Service unavailable")
        }

        let normalized = code.uppercased().trimmingCharacters(in: .whitespaces)
        let request = RedeemInviteCodeRequest(usedBy: userId, usedAt: Date())

        try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .update(request)
            .eq("code", value: normalized)
            .execute()

        logInfo("Redeemed invite code: \(normalized) for user: \(userId)", category: .data)
    }

    // MARK: - Create Code (Admin)

    func createCode(
        createdBy: UUID,
        expirationDays: Int = 7,
        recipientName: String?,
        note: String?,
        email: String? = nil,
        trialDays: Int? = nil
    ) async throws -> InviteCode {
        guard supabase.isConfigured else {
            throw AppError.custom(message: "Service unavailable")
        }

        let paymentStatus: String = trialDays != nil ? "free_trial" : "none"

        let request = CreateInviteCodeRequest(
            code: InviteCode.generateCode(),
            createdBy: createdBy,
            expiresAt: Calendar.current.date(byAdding: .day, value: expirationDays, to: Date()) ?? Date(),
            recipientName: recipientName,
            note: note,
            email: email,
            paymentStatus: paymentStatus,
            trialDays: trialDays
        )

        let created: [InviteCode] = try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .insert(request)
            .select()
            .execute()
            .value

        guard let inviteCode = created.first else {
            throw AppError.custom(message: "Failed to create invite code")
        }

        logInfo("Created invite code: \(inviteCode.code)", category: .data)
        return inviteCode
    }

    // MARK: - Fetch All Codes (Admin)

    func fetchAllCodes() async throws -> [InviteCode] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        let codes: [InviteCode] = try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return codes
    }

    // MARK: - Revoke Code (Admin)

    func revokeCode(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.custom(message: "Service unavailable")
        }

        try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .update(RevokeInviteCodeRequest(isRevoked: true))
            .eq("id", value: id.uuidString)
            .execute()

        logInfo("Revoked invite code: \(id)", category: .data)
    }

    // MARK: - Delete Code (Admin)

    func deleteCode(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.custom(message: "Service unavailable")
        }

        try await supabase.database
            .from(SupabaseTable.inviteCodes.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()

        logInfo("Deleted invite code: \(id)", category: .data)
    }
}
