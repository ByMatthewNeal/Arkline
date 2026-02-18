import Foundation

// MARK: - Invite Code Model

/// Represents an invite code for the invite-only authentication flow.
/// Maps 1:1 to the `invite_codes` Supabase table.
struct InviteCode: Codable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let createdBy: UUID
    let createdAt: Date
    let expiresAt: Date
    var usedBy: UUID?
    var usedAt: Date?
    var recipientName: String?
    var note: String?
    var isRevoked: Bool
    var email: String?
    var paymentStatus: String
    var stripeCheckoutSessionId: String?
    var trialDays: Int?
    var tier: String?

    enum CodingKeys: String, CodingKey {
        case id, code, note, email
        case createdBy = "created_by"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case usedBy = "used_by"
        case usedAt = "used_at"
        case recipientName = "recipient_name"
        case isRevoked = "is_revoked"
        case paymentStatus = "payment_status"
        case stripeCheckoutSessionId = "stripe_checkout_session_id"
        case trialDays = "trial_days"
        case tier
    }

    // MARK: - Computed Properties

    var isUsed: Bool { usedBy != nil }

    var isExpired: Bool { expiresAt < Date() }

    var isValid: Bool { !isUsed && !isExpired && !isRevoked }

    var isPaid: Bool { paymentStatus == "paid" }

    var isFreeTrial: Bool { paymentStatus == "free_trial" }

    var isFounding: Bool { tier == "founding" }

    var statusLabel: String {
        if isRevoked { return "Revoked" }
        if isUsed { return "Used" }
        if isExpired { return "Expired" }
        return "Active"
    }

    // MARK: - Code Generation

    /// Generates a random invite code in `ARK-XXXXXX` format.
    /// Excludes ambiguous characters (0/O, 1/I).
    static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let random = (0..<6).map { _ in chars.randomElement()! }
        return "ARK-\(String(random))"
    }
}

// MARK: - Create Request

struct CreateInviteCodeRequest: Encodable {
    let code: String
    let createdBy: UUID
    let expiresAt: Date
    let recipientName: String?
    let note: String?
    let email: String?
    let paymentStatus: String
    let trialDays: Int?

    enum CodingKeys: String, CodingKey {
        case code, note, email
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case recipientName = "recipient_name"
        case paymentStatus = "payment_status"
        case trialDays = "trial_days"
    }
}

// MARK: - Redeem Request

struct RedeemInviteCodeRequest: Encodable {
    let usedBy: UUID
    let usedAt: Date

    enum CodingKeys: String, CodingKey {
        case usedBy = "used_by"
        case usedAt = "used_at"
    }
}

// MARK: - Revoke Request

struct RevokeInviteCodeRequest: Encodable {
    let isRevoked: Bool

    enum CodingKeys: String, CodingKey {
        case isRevoked = "is_revoked"
    }
}
