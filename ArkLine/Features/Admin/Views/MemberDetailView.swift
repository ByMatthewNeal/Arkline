import SwiftUI

struct MemberDetailView: View {
    let member: AdminMember
    @Bindable var viewModel: MemberManagementViewModel
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    profileSection
                    subscriptionSection
                    paymentHistorySection
                    actionsSection
                }
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle(member.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadPaymentHistory(for: member)
        }
        // Cancel alert
        .alert("Cancel Subscription", isPresented: $viewModel.showCancelAlert) {
            Button("Cancel at Period End") {
                Task { await viewModel.cancelSubscription(for: member, atPeriodEnd: true) }
            }
            Button("Cancel Immediately", role: .destructive) {
                Task { await viewModel.cancelSubscription(for: member, atPeriodEnd: false) }
            }
            Button("Nevermind", role: .cancel) {}
        } message: {
            Text("How should this subscription be canceled?")
        }
        // Pause alert
        .alert(member.subscription?.isPaused == true ? "Resume Subscription" : "Pause Subscription",
               isPresented: $viewModel.showPauseAlert) {
            Button(member.subscription?.isPaused == true ? "Resume" : "Pause") {
                let shouldPause = !(member.subscription?.isPaused ?? false)
                Task { await viewModel.pauseSubscription(for: member, pause: shouldPause) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(member.subscription?.isPaused == true
                 ? "This will resume billing for this member."
                 : "This will stop billing until you resume it.")
        }
        // Change plan alert
        .alert("Change Plan", isPresented: $viewModel.showChangePlanAlert) {
            let currentPlan = member.subscription?.plan ?? "monthly"
            let newPlan = currentPlan == "monthly" ? "annual" : "monthly"
            Button("Switch to \(newPlan.capitalized)") {
                Task { await viewModel.changePlan(for: member, to: newPlan) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will prorate the charge for the new plan.")
        }
        // Deactivate alert
        .alert(member.isActive ? "Deactivate Account" : "Reactivate Account",
               isPresented: $viewModel.showDeactivateAlert) {
            Button(member.isActive ? "Deactivate" : "Reactivate", role: member.isActive ? .destructive : .none) {
                Task { await viewModel.toggleAccountActive(for: member) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(member.isActive
                 ? "This will prevent this user from accessing the app."
                 : "This will restore access for this user.")
        }
        // Refund alert
        .alert("Issue Refund", isPresented: $viewModel.showRefundAlert) {
            Button("Refund \(viewModel.selectedPayment?.formattedAmount ?? "")", role: .destructive) {
                if let payment = viewModel.selectedPayment {
                    Task { await viewModel.refundPayment(payment) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will issue a full refund to the customer's payment method.")
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(spacing: ArkSpacing.md) {
            // Avatar
            Text(member.initials)
                .font(AppFonts.title24)
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(AppColors.accent.opacity(0.8))
                .clipShape(Circle())

            // Name & email
            VStack(spacing: 4) {
                HStack(spacing: ArkSpacing.xs) {
                    Text(member.displayName)
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if !member.isActive {
                        Text("INACTIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.error.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                Text(member.email)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)

                Text("Member since \(member.createdAt.formatted(.dateTime.month().year()))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.lg)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Subscription")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let sub = member.subscription {
                VStack(spacing: ArkSpacing.sm) {
                    detailRow("Plan", value: sub.plan.capitalized)
                    detailRow("Status", value: sub.status.capitalized)

                    if let end = sub.currentPeriodEnd {
                        detailRow("Period End", value: end.formatted(.dateTime.month().day().year()))
                    }

                    if let trial = sub.trialEnd {
                        detailRow("Trial End", value: trial.formatted(.dateTime.month().day().year()))
                    }
                }
                .padding(ArkSpacing.md)
                .glassCard(cornerRadius: 12)
            } else {
                Text("No active subscription")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(ArkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 12)
            }
        }
    }

    // MARK: - Payment History

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Payment History")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if viewModel.isLoadingPayments {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(ArkSpacing.lg)
            } else if viewModel.paymentHistory.isEmpty {
                Text("No payments found")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(ArkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.paymentHistory) { payment in
                        Button {
                            viewModel.selectedPayment = payment
                            viewModel.showRefundAlert = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(payment.formattedAmount)
                                        .font(AppFonts.body14Medium)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))
                                    Text(payment.date.formatted(.dateTime.month().day().year()))
                                        .font(AppFonts.caption12)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Text(payment.status.capitalized)
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(payment.status == "succeeded" ? AppColors.success : AppColors.warning)

                                if payment.refunded {
                                    Text("Refunded")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(AppColors.error)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.error.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, ArkSpacing.sm)
                            .padding(.horizontal, ArkSpacing.md)
                        }

                        if payment.id != viewModel.paymentHistory.last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
                .glassCard(cornerRadius: 12)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Actions")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: ArkSpacing.sm) {
                if member.subscription != nil {
                    // Pause / Resume
                    let isPaused = member.subscription?.isPaused ?? false
                    actionButton(
                        title: isPaused ? "Resume Subscription" : "Pause Subscription",
                        icon: isPaused ? "play.fill" : "pause.fill",
                        color: AppColors.warning
                    ) {
                        viewModel.showPauseAlert = true
                    }

                    // Change Plan
                    let currentPlan = member.subscription?.plan ?? "monthly"
                    actionButton(
                        title: "Switch to \(currentPlan == "monthly" ? "Annual" : "Monthly")",
                        icon: "arrow.triangle.2.circlepath",
                        color: AppColors.accent
                    ) {
                        viewModel.showChangePlanAlert = true
                    }

                    // Cancel
                    actionButton(
                        title: "Cancel Subscription",
                        icon: "xmark.circle.fill",
                        color: AppColors.error
                    ) {
                        viewModel.showCancelAlert = true
                    }
                }

                // Deactivate / Reactivate
                actionButton(
                    title: member.isActive ? "Deactivate Account" : "Reactivate Account",
                    icon: member.isActive ? "person.slash" : "person.badge.plus",
                    color: member.isActive ? AppColors.error : AppColors.success
                ) {
                    viewModel.showDeactivateAlert = true
                }
            }

            if viewModel.isPerformingAction {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(ArkSpacing.sm)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(ArkSpacing.md)
            .glassCard(cornerRadius: 12)
        }
        .disabled(viewModel.isPerformingAction)
    }
}
