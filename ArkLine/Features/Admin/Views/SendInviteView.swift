import SwiftUI

struct SendInviteView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SendInviteViewModel()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    modePicker
                    formSection

                    if viewModel.inviteMode == .payment || viewModel.inviteMode == .trial {
                        planPicker
                    }

                    if viewModel.inviteMode == .trial {
                        trialInfoCard
                    }

                    sendButton
                    resultSection
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Send Invite")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Invite Mode", selection: $viewModel.inviteMode) {
            ForEach(InviteMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: ArkSpacing.sm) {
            CustomTextField(
                placeholder: "Email address",
                text: $viewModel.email,
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never
            )

            CustomTextField(
                placeholder: "Name (optional)",
                text: $viewModel.recipientName,
                icon: "person.fill"
            )

            CustomTextField(
                placeholder: "Note (optional)",
                text: $viewModel.note,
                icon: "note.text"
            )
        }
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Select Plan")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ArkSpacing.xs) {
                ForEach(StripePlan.allCases) { plan in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedPlan = plan
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(plan.shortName)
                                .font(AppFonts.caption12Medium)
                            Text(plan.price)
                                .font(AppFonts.caption12)
                                .opacity(0.7)
                        }
                        .foregroundColor(
                            viewModel.selectedPlan == plan
                            ? .white
                            : AppColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(
                            viewModel.selectedPlan == plan
                            ? AppColors.accent
                            : AppColors.cardBackground(colorScheme)
                        )
                        .cornerRadius(ArkSpacing.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                .stroke(
                                    viewModel.selectedPlan == plan
                                    ? Color.clear
                                    : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        PrimaryButton(
            title: sendButtonTitle,
            action: { Task { await viewModel.sendInvite() } },
            isLoading: viewModel.isSending,
            isDisabled: !viewModel.canSend,
            icon: viewModel.inviteMode == .comped ? "paperplane.fill" : "link"
        )
    }

    private var sendButtonTitle: String {
        switch viewModel.inviteMode {
        case .payment: return "Create Checkout Link"
        case .trial: return "Create Trial Link"
        case .comped: return "Send Comped Invite"
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.state {
        case .successPayment(let url):
            successPaymentView(url, isTrial: false)
        case .successTrial(let url):
            successPaymentView(url, isTrial: true)
        case .successComped(let code):
            successCompedView(code)
        case .error(let message):
            Text(message)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.error)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    private var trialInfoCard: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.accent)

            Text("7-day free trial. Card collected upfront. Auto-converts to paid on day 8.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(ArkSpacing.md)
        .background(AppColors.accent.opacity(0.1))
        .cornerRadius(ArkSpacing.Radius.sm)
    }

    private func successPaymentView(_ url: String, isTrial: Bool) -> some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.success)

            Text(isTrial ? "7-day trial link created!" : "Checkout link created!")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(url)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)

            VStack(spacing: ArkSpacing.sm) {
                PrimaryButton(
                    title: "Share Link",
                    action: { viewModel.shareCheckoutLink() },
                    icon: "square.and.arrow.up"
                )

                SecondaryButton(
                    title: "Send Another",
                    action: { viewModel.reset() },
                    icon: "plus"
                )
            }
        }
        .padding(ArkSpacing.lg)
        .glassCard(cornerRadius: 16)
    }

    private func successCompedView(_ code: String) -> some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.success)

            Text("Comped invite sent!")
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(code)
                .font(AppFonts.number24)
                .foregroundColor(AppColors.accent)
                .padding(.vertical, ArkSpacing.xs)

            if let qr = QRCodeGenerator.generate(for: code, size: 160) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(ArkSpacing.sm)
                    .background(Color.white)
                    .cornerRadius(ArkSpacing.Radius.sm)
            }

            Text("Email sent to \(viewModel.email)")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: ArkSpacing.sm) {
                PrimaryButton(
                    title: "Share Code",
                    action: { viewModel.shareCompedCode() },
                    icon: "square.and.arrow.up"
                )

                SecondaryButton(
                    title: "Send Another",
                    action: { viewModel.reset() },
                    icon: "plus"
                )
            }
        }
        .padding(ArkSpacing.lg)
        .glassCard(cornerRadius: 16)
    }
}

#Preview {
    NavigationStack {
        SendInviteView()
            .environmentObject(AppState())
    }
}
