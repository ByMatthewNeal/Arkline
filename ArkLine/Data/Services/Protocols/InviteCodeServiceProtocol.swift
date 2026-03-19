import Foundation

// MARK: - Invite Code Service Protocol

/// Protocol defining operations for the invite code system.
protocol InviteCodeServiceProtocol {
    /// Validates an invite code (checks existence, unused, unexpired, unrevoked).
    /// Returns the code if valid, nil otherwise.
    func validateCode(_ code: String) async throws -> InviteCode?

    /// Redeems an invite code for a user (marks it as used).
    func redeemCode(_ code: String, userId: UUID) async throws

    /// Creates a new invite code (admin only).
    func createCode(
        createdBy: UUID,
        expirationDays: Int,
        recipientName: String?,
        note: String?,
        email: String?,
        trialDays: Int?
    ) async throws -> InviteCode

    /// Fetches all invite codes (admin only).
    func fetchAllCodes() async throws -> [InviteCode]

    /// Revokes an invite code (admin only).
    func revokeCode(id: UUID) async throws

    /// Deletes an invite code (admin only).
    func deleteCode(id: UUID) async throws

    /// Updates an invite code's editable fields (admin only).
    func updateCode(id: UUID, recipientName: String?, note: String?, email: String?) async throws

    /// Fetches the user's existing referral code, if any.
    func fetchReferralCode(for userId: UUID) async throws -> InviteCode?

    /// Creates a referral code for the user.
    func createReferralCode(for userId: UUID) async throws -> InviteCode

    /// Counts how many of the user's referral codes have been redeemed.
    func fetchReferralCount(for userId: UUID) async throws -> Int
}

// MARK: - Default Parameters

extension InviteCodeServiceProtocol {
    func createCode(
        createdBy: UUID,
        expirationDays: Int,
        recipientName: String?,
        note: String?
    ) async throws -> InviteCode {
        try await createCode(
            createdBy: createdBy,
            expirationDays: expirationDays,
            recipientName: recipientName,
            note: note,
            email: nil,
            trialDays: nil
        )
    }
}
