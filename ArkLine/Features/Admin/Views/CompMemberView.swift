import SwiftUI

// MARK: - Comp Member (Admin)
//
// Give a person free access by email — forever or for a set number of days — and
// remove it. Calls the `grant-comp` edge function, which writes/updates an active
// source='comp' subscription row. Access is gated by is_user_subscribed, so a
// timed comp auto-expires when its end date passes; removing cancels it at once.

struct CompMemberView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = CompMemberViewModel()

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    Text("Give a member free access. They need to have signed up in the app first (entered their email and verified it), then enter that email here.")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    field("Email") {
                        TextField("name@example.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(ArkSpacing.md)
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(ArkSpacing.Radius.md)
                    }

                    field("Tier") {
                        Picker("Tier", selection: $viewModel.tier) {
                            Text("Founding ($39.99)").tag("founding")
                            Text("Standard ($69.99)").tag("standard")
                        }
                        .pickerStyle(.segmented)
                    }

                    field("Duration") {
                        Picker("Duration", selection: $viewModel.durationDays) {
                            Text("Forever").tag(0)
                            Text("7 days").tag(7)
                            Text("14 days").tag(14)
                            Text("30 days").tag(30)
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        Task { await viewModel.grant() }
                    } label: {
                        actionLabel(
                            icon: "gift.fill",
                            title: viewModel.isLoading ? "Working…" : "Grant Comp",
                            enabled: viewModel.canSubmit,
                            destructive: false
                        )
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isLoading)

                    Button {
                        Task { await viewModel.remove() }
                    } label: {
                        actionLabel(
                            icon: "xmark.circle.fill",
                            title: "Remove Comp",
                            enabled: viewModel.canSubmit,
                            destructive: true
                        )
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isLoading)

                    if let result = viewModel.resultMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: viewModel.resultIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(viewModel.resultIsError ? AppColors.warning : AppColors.success)
                            Text(result)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }
                        .padding(ArkSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((viewModel.resultIsError ? AppColors.warning : AppColors.success).opacity(0.1))
                        .cornerRadius(ArkSpacing.Radius.md)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.vertical, ArkSpacing.lg)
            }
        }
        .navigationTitle("Comp a Member")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text(label)
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
            content()
        }
    }

    private func actionLabel(icon: String, title: String, enabled: Bool, destructive: Bool) -> some View {
        let tint = destructive ? AppColors.error : AppColors.accent
        return HStack {
            Image(systemName: icon)
            Text(title).font(AppFonts.body14Medium)
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.md)
        .background(enabled ? tint.opacity(destructive ? 0.12 : 1.0) : AppColors.fillSecondary(colorScheme))
        .foregroundColor(enabled ? (destructive ? AppColors.error : .white) : AppColors.textTertiary)
        .cornerRadius(ArkSpacing.Radius.md)
    }
}

// MARK: - View Model

@MainActor
@Observable
final class CompMemberViewModel {
    var email = ""
    var tier = "founding"
    var durationDays = 0   // 0 = forever
    var isLoading = false
    var resultMessage: String?
    var resultIsError = false

    var canSubmit: Bool { email.contains("@") && email.contains(".") }

    private struct GrantCompRequest: Encodable {
        let email: String
        let tier: String
        let plan: String
        let days: Int
        let revoke: Bool
    }
    private struct GrantCompResponse: Decodable {
        let ok: Bool?
        let message: String?
        let error: String?
    }

    func grant() async { await call(revoke: false) }
    func remove() async { await call(revoke: true) }

    private func call(revoke: Bool) async {
        guard canSubmit else { return }
        isLoading = true
        resultMessage = nil
        defer { isLoading = false }

        do {
            let response: GrantCompResponse = try await SupabaseManager.shared.functions.invoke(
                "grant-comp",
                options: .init(body: GrantCompRequest(
                    email: email.trimmingCharacters(in: .whitespaces),
                    tier: tier,
                    plan: "monthly",
                    days: durationDays,
                    revoke: revoke
                ))
            )
            if response.ok == true {
                resultIsError = false
                resultMessage = response.message ?? (revoke ? "Comp removed." : "Comp granted.")
                Haptics.success()
                if !revoke { email = "" }
            } else {
                resultIsError = true
                resultMessage = response.message ?? response.error ?? "Could not complete."
                Haptics.error()
            }
        } catch {
            resultIsError = true
            resultMessage = AppError.from(error).userMessage
            logError("grant-comp failed: \(error)", category: .network)
            Haptics.error()
        }
    }
}
