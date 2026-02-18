import Foundation

// MARK: - Subscription Model

/// Represents a Stripe subscription record from the `subscriptions` table.
struct Subscription: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let plan: String
    let status: String
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let trialEnd: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, plan, status
        case userId = "user_id"
        case stripeCustomerId = "stripe_customer_id"
        case stripeSubscriptionId = "stripe_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case trialEnd = "trial_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    // MARK: - Computed Properties

    var isActive: Bool { status == "active" }
    var isTrialing: Bool { status == "trialing" }
    var isCanceled: Bool { status == "canceled" }
    var isPastDue: Bool { status == "past_due" }

    var planDisplayName: String {
        plan == "annual" ? "Annual" : "Monthly"
    }

    var daysUntilPeriodEnd: Int? {
        guard let end = currentPeriodEnd else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: end).day
    }

    var daysUntilTrialEnd: Int? {
        guard let end = trialEnd else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: end).day
    }
}
