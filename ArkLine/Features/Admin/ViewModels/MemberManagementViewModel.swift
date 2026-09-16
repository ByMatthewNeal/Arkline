import SwiftUI

@MainActor
@Observable
class MemberManagementViewModel {
    // MARK: - State
    var members: [AdminMember] = []
    var metrics: AdminMetrics?
    var paymentHistory: [PaymentRecord] = []

    var isLoading = false
    var isLoadingMetrics = false
    var isLoadingPayments = false
    var isPerformingAction = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Filters
    var searchText = ""
    var statusFilter: MemberStatusFilter = .all

    // MARK: - Confirmation Alerts
    var showCancelAlert = false
    var showPauseAlert = false
    var showChangePlanAlert = false
    var showDeactivateAlert = false
    var showRefundAlert = false
    var selectedPayment: PaymentRecord?
    var actionMember: AdminMember?

    // MARK: - Service
    private let service: AdminServiceProtocol

    init(service: AdminServiceProtocol = AdminService()) {
        self.service = service
    }

    // MARK: - Filter Enum

    // Free-era filters: growth/engagement buckets, not billing states. Resolved
    // client-side from each member's activityStatus (join date + last session).
    enum MemberStatusFilter: String, CaseIterable {
        case all = "All"
        case new = "New"
        case active = "Active"
        case dormant = "Dormant"
    }

    // MARK: - Computed

    var filteredMembers: [AdminMember] {
        var result = members
        switch statusFilter {
        case .all: break
        case .new: result = result.filter { $0.activityStatus == .new }
        case .active: result = result.filter { $0.activityStatus == .active }
        case .dormant: result = result.filter { $0.activityStatus == .dormant }
        }
        guard !searchText.isEmpty else { return result }
        let query = searchText.lowercased()
        return result.filter {
            $0.email.lowercased().contains(query) ||
            ($0.username?.lowercased().contains(query) ?? false) ||
            ($0.fullName?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Load Data

    func loadMembers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            // Fetch all members; the growth/engagement filters are applied
            // client-side from each member's activityStatus.
            let response = try await service.fetchMembers(
                search: nil,
                status: nil,
                page: 1
            )
            members = response.members
        } catch {
            errorMessage = "Failed to load members"
            logError(error, context: "Load Members", category: .network)
        }
    }

    func loadMetrics() async {
        isLoadingMetrics = true
        defer { isLoadingMetrics = false }
        do {
            metrics = try await service.fetchMetrics()
        } catch {
            logError(error, context: "Load Metrics", category: .network)
        }
    }

    func loadPaymentHistory(for member: AdminMember) async {
        guard let customerId = member.subscription?.stripeCustomerId else {
            paymentHistory = []
            return
        }
        isLoadingPayments = true
        defer { isLoadingPayments = false }
        do {
            paymentHistory = try await service.fetchPaymentHistory(customerId: customerId)
        } catch {
            logError(error, context: "Load Payment History", category: .network)
            paymentHistory = []
        }
    }

    // MARK: - Actions

    func cancelSubscription(for member: AdminMember, atPeriodEnd: Bool) async {
        guard let subId = member.subscription?.stripeSubscriptionId else { return }
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }
        do {
            try await service.cancelSubscription(stripeSubscriptionId: subId, atPeriodEnd: atPeriodEnd)
            successMessage = atPeriodEnd ? "Subscription will cancel at period end" : "Subscription canceled"
            await loadMembers()
        } catch {
            errorMessage = "Failed to cancel subscription"
            logError(error, context: "Cancel Subscription", category: .network)
        }
    }

    func pauseSubscription(for member: AdminMember, pause: Bool) async {
        guard let subId = member.subscription?.stripeSubscriptionId else { return }
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }
        do {
            try await service.pauseSubscription(stripeSubscriptionId: subId, pause: pause)
            successMessage = pause ? "Subscription paused" : "Subscription resumed"
            await loadMembers()
        } catch {
            errorMessage = pause ? "Failed to pause subscription" : "Failed to resume subscription"
            logError(error, context: "Pause Subscription", category: .network)
        }
    }

    func changePlan(for member: AdminMember, to plan: String) async {
        guard let subId = member.subscription?.stripeSubscriptionId else { return }
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }
        do {
            try await service.updateSubscription(stripeSubscriptionId: subId, newPlan: plan)
            successMessage = "Plan changed to \(plan)"
            await loadMembers()
        } catch {
            errorMessage = "Failed to change plan"
            logError(error, context: "Change Plan", category: .network)
        }
    }

    func refundPayment(_ payment: PaymentRecord) async {
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }
        do {
            try await service.refundPayment(paymentIntentId: payment.id, amount: nil, reason: "requested_by_customer")
            successMessage = "Refund issued for \(payment.formattedAmount)"
        } catch {
            errorMessage = "Failed to issue refund"
            logError(error, context: "Refund Payment", category: .network)
        }
    }

    func toggleAccountActive(for member: AdminMember) async {
        isPerformingAction = true
        errorMessage = nil
        defer { isPerformingAction = false }
        do {
            try await service.deactivateAccount(userId: member.id, isActive: !member.isActive)
            successMessage = member.isActive ? "Account deactivated" : "Account reactivated"
            await loadMembers()
        } catch {
            errorMessage = "Failed to update account status"
            logError(error, context: "Toggle Account Active", category: .network)
        }
    }

    func clearSuccess() {
        successMessage = nil
    }
}
