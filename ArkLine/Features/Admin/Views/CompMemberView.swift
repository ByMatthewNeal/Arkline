import SwiftUI

// MARK: - Comp Member (Admin)
//
// Give a person free access by email. Calls the `grant-comp` edge function,
// which writes an active source='comp' subscription row — the same access gate
// (is_user_subscribed) that Stripe and Apple purchases use. Replaces the old
// comp-via-invite-code flow now that invite codes are retired.

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
                    Text("Give a member free access. They need to have signed up in the app first — then enter their email here.")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("Email")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textSecondary)
                        TextField("name@example.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(ArkSpacing.md)
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(ArkSpacing.Radius.md)
                    }

                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("Tier")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textSecondary)
                        Picker("Tier", selection: $viewModel.tier) {
                            Text("Founding ($39.99)").tag("founding")
                            Text("Standard ($69.99)").tag("standard")
                        }
                        .pickerStyle(.segmented)
                    }

                    Button {
                        Task { await viewModel.grant() }
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "gift.fill")
                            }
                            Text(viewModel.isLoading ? "Granting…" : "Grant Comp")
                                .font(AppFonts.body14Medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ArkSpacing.md)
                        .background(viewModel.canSubmit ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                        .foregroundColor(viewModel.canSubmit ? .white : AppColors.textTertiary)
                        .cornerRadius(ArkSpacing.Radius.md)
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
}

// MARK: - View Model

@MainActor
@Observable
final class CompMemberViewModel {
    var email = ""
    var tier = "founding"
    var isLoading = false
    var resultMessage: String?
    var resultIsError = false

    var canSubmit: Bool { email.contains("@") && email.contains(".") }

    private struct GrantCompRequest: Encodable {
        let email: String
        let tier: String
        let plan: String
    }
    private struct GrantCompResponse: Decodable {
        let ok: Bool?
        let message: String?
        let error: String?
    }

    func grant() async {
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
                    plan: "monthly"
                ))
            )
            if response.ok == true {
                resultIsError = false
                resultMessage = response.message ?? "Comp granted."
                Haptics.success()
                email = ""
            } else {
                // 200 with ok:false (e.g. account not found yet)
                resultIsError = true
                resultMessage = response.message ?? response.error ?? "Could not grant comp."
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
