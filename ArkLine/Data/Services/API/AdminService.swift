import Foundation

final class AdminService: AdminServiceProtocol {
    private let supabase = SupabaseManager.shared

    func fetchMembers(search: String?, status: String?, page: Int) async throws -> AdminMembersResponse {
        let request = AdminMembersRequest(
            search: search,
            status: status,
            page: page,
            per_page: 50
        )
        let response: AdminMembersResponse = try await supabase.functions.invoke(
            "admin-members",
            options: .init(body: request)
        )
        return response
    }

    func fetchMetrics() async throws -> AdminMetrics {
        let response: AdminMetrics = try await supabase.functions.invoke("get-admin-metrics")
        return response
    }

    func fetchPaymentHistory(customerId: String) async throws -> [PaymentRecord] {
        let request = PaymentHistoryRequest(customer_id: customerId)
        let response: PaymentHistoryResponse = try await supabase.functions.invoke(
            "get-payment-history",
            options: .init(body: request)
        )
        return response.payments
    }

    func cancelSubscription(stripeSubscriptionId: String, atPeriodEnd: Bool) async throws {
        let request = CancelSubscriptionRequest(
            stripe_subscription_id: stripeSubscriptionId,
            cancel_at_period_end: atPeriodEnd
        )
        let _: AdminActionResponse = try await supabase.functions.invoke(
            "cancel-subscription",
            options: .init(body: request)
        )
    }

    func pauseSubscription(stripeSubscriptionId: String, pause: Bool) async throws {
        let request = PauseSubscriptionRequest(
            stripe_subscription_id: stripeSubscriptionId,
            pause: pause
        )
        let _: AdminActionResponse = try await supabase.functions.invoke(
            "pause-subscription",
            options: .init(body: request)
        )
    }

    func updateSubscription(stripeSubscriptionId: String, newPlan: String) async throws {
        let request = UpdateSubscriptionRequest(
            stripe_subscription_id: stripeSubscriptionId,
            new_plan: newPlan
        )
        let _: AdminActionResponse = try await supabase.functions.invoke(
            "update-subscription",
            options: .init(body: request)
        )
    }

    func refundPayment(paymentIntentId: String, amount: Int?, reason: String?) async throws {
        let request = RefundPaymentRequest(
            payment_intent_id: paymentIntentId,
            amount: amount,
            reason: reason
        )
        let _: AdminActionResponse = try await supabase.functions.invoke(
            "refund-payment",
            options: .init(body: request)
        )
    }

    func deactivateAccount(userId: UUID, isActive: Bool) async throws {
        try await supabase.database
            .from(SupabaseTable.profiles.rawValue)
            .update(["is_active": isActive])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
