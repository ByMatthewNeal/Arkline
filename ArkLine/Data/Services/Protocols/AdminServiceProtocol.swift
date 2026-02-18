import Foundation

protocol AdminServiceProtocol {
    func fetchMembers(search: String?, status: String?, page: Int) async throws -> AdminMembersResponse
    func fetchMetrics() async throws -> AdminMetrics
    func fetchPaymentHistory(customerId: String) async throws -> [PaymentRecord]
    func cancelSubscription(stripeSubscriptionId: String, atPeriodEnd: Bool) async throws
    func pauseSubscription(stripeSubscriptionId: String, pause: Bool) async throws
    func updateSubscription(stripeSubscriptionId: String, newPlan: String) async throws
    func refundPayment(paymentIntentId: String, amount: Int?, reason: String?) async throws
    func deactivateAccount(userId: UUID, isActive: Bool) async throws
    func createCheckoutSession(email: String, recipientName: String?, note: String?, priceId: String) async throws -> CheckoutSessionResponse
    func createCompedInvite(email: String, recipientName: String?, note: String?, sendEmail: Bool, tier: String) async throws -> GenerateInviteResponse
}
