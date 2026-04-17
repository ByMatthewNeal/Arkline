import SwiftUI

// MARK: - Invite Code View

/// Exclusive invite code entry screen shown between Welcome and Email steps.
/// Uses MeshGradientBackground for a premium feel matching the Welcome screen.
struct InviteCodeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isCodeFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var showRequestAccess = false
    @State private var showQRScanner = false

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Icon with glow
                VStack(spacing: ArkSpacing.xl) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppColors.fillPrimary.opacity(0.15),
                                        AppColors.fillPrimary.opacity(0)
                                    ],
                                    center: .center,
                                    startRadius: 60,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)

                        // Frosted glass circle
                        Circle()
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.3))
                            .frame(width: 160, height: 160)

                        // Circle border
                        Circle()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4), lineWidth: 1)
                            .frame(width: 160, height: 160)

                        // Logo (clipped to circle to hide corner marks in asset)
                        Image("ArkLineLogo")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.fillPrimary, AppColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: ArkSpacing.sm) {
                        Text("You're Early.")
                            .font(AppFonts.title30)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .multilineTextAlignment(.center)

                        Text("Arkline is invite-only. You're getting access to sentiment intelligence most investors don't know exists.")
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, ArkSpacing.md)
                    }
                }

                Spacer()
                    .frame(height: ArkSpacing.xxl)

                // Code input
                VStack(spacing: ArkSpacing.md) {
                    CustomTextField(
                        placeholder: "ARK-XXXXXX",
                        text: $viewModel.inviteCode,
                        icon: "ticket.fill",
                        errorMessage: viewModel.inviteCodeError
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isCodeFocused)

                    Button {
                        isCodeFocused = false
                        showQRScanner = true
                    } label: {
                        HStack(spacing: ArkSpacing.xs) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan QR Code")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)

                Spacer()

                // Bottom actions
                VStack(spacing: ArkSpacing.sm) {
                    PrimaryButton(
                        title: "Continue",
                        action: {
                            Task {
                                await viewModel.validateInviteCode()
                            }
                        },
                        isLoading: viewModel.isLoading,
                        isDisabled: !viewModel.isInviteCodeFormatValid
                    )

                    Button(action: { showRequestAccess = true }) {
                        Text("Don't have a code?")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, ArkSpacing.xxs)

                    #if DEBUG
                    Button(action: { viewModel.nextStep() }) {
                        Text("Skip (Dev Only)")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                    }
                    #endif
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        .navigationBarBackButtonHidden()
        .onboardingBackButton { viewModel.previousStep() }
        .onAppear { isCodeFocused = true }
        .sheet(isPresented: $showRequestAccess) {
            RequestAccessSheet()
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet { code in
                viewModel.inviteCode = code
                Task { await viewModel.validateInviteCode() }
            }
        }
    }
}

// MARK: - Request Access Sheet

/// Shown when a user doesn't have an invite code.
/// Conveys exclusivity without feeling like a paywall.
struct RequestAccessSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.xxl) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.fillPrimary, AppColors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: ArkSpacing.sm) {
                    Text("Invitation Required")
                        .font(AppFonts.title24)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("ArkLine is a curated financial intelligence platform. Access is currently limited to invited members.\n\nReach out to an existing member or contact us to request an invitation.")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, ArkSpacing.lg)
                }

                Spacer()

                SecondaryButton(
                    title: "Contact Us",
                    action: {
                        if let url = URL(string: "mailto:access@arkline.app") {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    },
                    icon: "envelope.fill"
                )
                .padding(.horizontal, ArkSpacing.xl)

                Button("Dismiss") { dismiss() }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, ArkSpacing.xxl)
            }
            .background(AppColors.background(colorScheme))
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InviteCodeView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
