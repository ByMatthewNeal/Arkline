import Foundation

// MARK: - Admin Member (from admin-members Edge Function)

struct AdminMember: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let username: String?
    let fullName: String?
    let role: String
    let subscriptionStatus: String
    let isActive: Bool
    let createdAt: Date
    let subscriptions: [MemberSubscription]

    var subscription: MemberSubscription? { subscriptions.first }

    var displayName: String {
        fullName ?? username ?? email
    }

    var initials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var statusColor: String {
        switch subscriptionStatus {
        case "active": return "success"
        case "trialing": return "info"
        case "past_due": return "warning"
        case "canceled": return "error"
        case "paused": return "textSecondary"
        default: return "textTertiary"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, email, username, role, subscriptions
        case fullName = "full_name"
        case subscriptionStatus = "subscription_status"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    static func == (lhs: AdminMember, rhs: AdminMember) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Member Subscription

struct MemberSubscription: Codable, Equatable {
    let id: UUID
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let plan: String
    let status: String
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let trialEnd: Date?

    var isPaused: Bool { status == "paused" }

    enum CodingKeys: String, CodingKey {
        case id, plan, status
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case trialEnd = "trial_end"
    }
}

// MARK: - Admin Metrics

struct AdminMetrics: Codable, Equatable {
    let mrr: Double
    let arr: Double
    let totalMembers: Int
    let activeMembers: Int
    let trialingMembers: Int
    let canceledMembers: Int
    let pastDueMembers: Int
    let pausedMembers: Int
    let churnRate: Double
    let foundingMembers: Int

    enum CodingKeys: String, CodingKey {
        case mrr, arr
        case totalMembers = "total_members"
        case activeMembers = "active_members"
        case trialingMembers = "trialing_members"
        case canceledMembers = "canceled_members"
        case pastDueMembers = "past_due_members"
        case pausedMembers = "paused_members"
        case churnRate = "churn_rate"
        case foundingMembers = "founding_members"
    }
}

// MARK: - Payment Record

struct PaymentRecord: Codable, Identifiable, Equatable {
    let id: String
    let amount: Int
    let currency: String
    let status: String
    let created: Int
    let description: String?
    let refunded: Bool
    let refundAmount: Int

    var formattedAmount: String {
        let dollars = Double(amount) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(created))
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, status, created, description, refunded
        case refundAmount = "refund_amount"
    }
}

// MARK: - Request / Response DTOs

struct AdminMembersRequest: Encodable {
    let search: String?
    let status: String?
    let page: Int
    let per_page: Int
}

struct AdminMembersResponse: Decodable {
    let members: [AdminMember]
    let total: Int
    let page: Int
    let perPage: Int

    enum CodingKeys: String, CodingKey {
        case members, total, page
        case perPage = "per_page"
    }
}

struct CancelSubscriptionRequest: Encodable {
    let stripe_subscription_id: String
    let cancel_at_period_end: Bool
}

struct PauseSubscriptionRequest: Encodable {
    let stripe_subscription_id: String
    let pause: Bool
}

struct UpdateSubscriptionRequest: Encodable {
    let stripe_subscription_id: String
    let new_plan: String
}

struct RefundPaymentRequest: Encodable {
    let payment_intent_id: String
    let amount: Int?
    let reason: String?
}

struct PaymentHistoryRequest: Encodable {
    let customer_id: String
}

struct PaymentHistoryResponse: Decodable {
    let payments: [PaymentRecord]
}

struct AdminActionResponse: Decodable {
    let success: Bool
}

// MARK: - Checkout Session DTOs

struct CreateCheckoutSessionRequest: Encodable {
    let email: String
    let recipient_name: String?
    let note: String?
    let price_id: String
    let trial_days: Int?
}

struct CheckoutSessionResponse: Decodable {
    let success: Bool
    let checkoutUrl: String
    let inviteId: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case success, code
        case checkoutUrl = "checkout_url"
        case inviteId = "invite_id"
    }
}

// MARK: - Comped Invite DTOs

struct CreateCompedInviteRequest: Encodable {
    let email: String
    let recipient_name: String?
    let note: String?
    let comped: Bool
    let send_email: Bool
    let tier: String?
    let expiration_days: Int
}

struct GenerateInviteResponse: Decodable {
    let success: Bool
    let code: String
    let deepLink: String

    enum CodingKeys: String, CodingKey {
        case success, code
        case deepLink = "deep_link"
    }
}

// MARK: - Activate Subscription DTOs

struct ActivateSubscriptionRequest: Encodable {
    let invite_code: String
}

struct ActivateSubscriptionResponse: Decodable {
    let success: Bool
    let linked: Bool
    let status: String?
    let trialEnd: Date?

    enum CodingKeys: String, CodingKey {
        case success, linked, status
        case trialEnd = "trial_end"
    }
}
