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

    /// Date-aware entitlement status, computed from the member's subscription rows
    /// rather than the stored `subscription_status` / `subscriptions.status` strings.
    ///
    /// Those stored strings go stale: a free trial that lapsed without converting
    /// can still read "trialing" (and the profile "active") because no webhook
    /// updated the row after the period ended — so the admin UI mislabels an
    /// expired member as Active/Trial. This recomputes from the period/trial dates
    /// so what admins see matches `is_user_subscribed()`, the real access gate.
    var effectiveStatus: EffectiveMemberStatus {
        let now = Date()
        guard !subscriptions.isEmpty else { return .none }

        // Currently entitled: an active/trialing row whose period hasn't ended.
        let validSub = subscriptions.first { s in
            (s.status == "active" || s.status == "trialing") &&
            (s.currentPeriodEnd == nil || s.currentPeriodEnd! > now)
        }
        if let valid = validSub {
            if valid.status == "trialing", let trial = valid.trialEnd, trial > now {
                return .trialing
            }
            return .active
        }

        // Not entitled now — categorize from the lapsed rows.
        if subscriptions.contains(where: { $0.status == "paused" }) { return .paused }
        if subscriptions.contains(where: { $0.status == "past_due" }) { return .pastDue }
        if subscriptions.contains(where: { $0.status == "canceled" }) { return .canceled }
        // An active/trialing row whose period already ended = expired (e.g. a
        // trial that ran out without a payment following).
        return .expired
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

// MARK: - Effective Member Status

/// Entitlement status derived from subscription dates (see `AdminMember.effectiveStatus`).
enum EffectiveMemberStatus {
    case active
    case trialing
    case pastDue
    case paused
    case canceled
    case expired
    case none

    /// Short badge text for the members list.
    var label: String {
        switch self {
        case .active: return "Active"
        case .trialing: return "Trial"
        case .pastDue: return "Past Due"
        case .paused: return "Paused"
        case .canceled: return "Canceled"
        case .expired: return "Expired"
        case .none: return "No Sub"
        }
    }

    /// Longer text for the member detail "Status" row.
    var detailLabel: String {
        switch self {
        case .trialing: return "Trialing"
        case .expired: return "Expired (trial/period ended)"
        default: return label
        }
    }

    /// Semantic color token — mapped to `AppColors` in the views.
    var colorName: String {
        switch self {
        case .active: return "success"
        case .trialing: return "info"
        case .pastDue: return "warning"
        case .paused: return "textSecondary"
        case .canceled: return "error"
        case .expired: return "warning"
        case .none: return "textTertiary"
        }
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
    /// Comped pipeline: comps pay $0 now but many convert later. Optional so older
    /// responses without these keys still decode. See get-admin-metrics.
    let compedActive: Int?
    let compedPotentialMrr: Double?
    let compedPotentialArr: Double?
    let totalMembers: Int
    let activeMembers: Int
    let trialingMembers: Int
    let canceledMembers: Int
    let pastDueMembers: Int
    let incompleteMembers: Int
    let churnRate: Double
    let foundingMembers: Int
    let foundingPending: Int
    let foundingRemaining: Int
    let foundingCap: Int
    let revenueBreakdown: RevenueBreakdown

    struct RevenueBreakdown: Codable, Equatable {
        let foundingMonthly: Int
        let foundingAnnual: Int
        let standardMonthly: Int
        let standardAnnual: Int

        enum CodingKeys: String, CodingKey {
            case foundingMonthly = "founding_monthly"
            case foundingAnnual = "founding_annual"
            case standardMonthly = "standard_monthly"
            case standardAnnual = "standard_annual"
        }
    }

    enum CodingKeys: String, CodingKey {
        case mrr, arr
        case compedActive = "comped_active"
        case compedPotentialMrr = "comped_potential_mrr"
        case compedPotentialArr = "comped_potential_arr"
        case totalMembers = "total_members"
        case activeMembers = "active_members"
        case trialingMembers = "trialing_members"
        case canceledMembers = "canceled_members"
        case pastDueMembers = "past_due_members"
        case incompleteMembers = "incomplete_members"
        case churnRate = "churn_rate"
        case foundingMembers = "founding_members"
        case foundingPending = "founding_pending"
        case foundingRemaining = "founding_remaining"
        case foundingCap = "founding_cap"
        case revenueBreakdown = "revenue_breakdown"
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
        return dollars.asCurrency
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
