import SwiftUI

// MARK: - Sign In View
struct SignInView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private enum Field {
        case email, password
    }

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "lock.circle.fill",
                        title: "Welcome back",
                        subtitle: "Sign in with your email and password"
                    )

                    // Input Fields
                    VStack(spacing: ArkSpacing.md) {
                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "Email address",
                            text: $viewModel.email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            errorMessage: nil
                        )
                        .focused($focusedField, equals: .email)
                        #else
                        CustomTextField(
                            placeholder: "Email address",
                            text: $viewModel.email,
                            icon: "envelope.fill",
                            errorMessage: nil
                        )
                        .focused($focusedField, equals: .email)
                        #endif

                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "Password",
                            text: $viewModel.password,
                            icon: "lock.fill",
                            isSecure: true,
                            textContentType: .password,
                            autocapitalization: .never,
                            errorMessage: viewModel.errorMessage
                        )
                        .focused($focusedField, equals: .password)
                        #else
                        CustomTextField(
                            placeholder: "Password",
                            text: $viewModel.password,
                            icon: "lock.fill",
                            isSecure: true,
                            errorMessage: viewModel.errorMessage
                        )
                        .focused($focusedField, equals: .password)
                        #endif

                        // Email code fallback link
                        Button {
                            viewModel.useEmailCodeFallback()
                        } label: {
                            Text("Use email code instead")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.top, ArkSpacing.xs)

                        // Forgot password link
                        Button {
                            Task { await viewModel.sendPasswordReset() }
                        } label: {
                            Text("Forgot password?")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.top, ArkSpacing.xs)

                        if let error = viewModel.passwordResetError {
                            Text(error)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.error)
                        }
                    }
                    .padding(.horizontal, ArkSpacing.xl)

                    // Reset confirmation
                    if viewModel.passwordResetSent {
                        VStack(spacing: ArkSpacing.lg) {
                            Image(systemName: "envelope.badge")
                                .font(.system(size: 40))
                                .foregroundColor(AppColors.accent)
                            Text("Check your email")
                                .font(AppFonts.title24)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Text("We sent a password reset link to \(viewModel.email). The link expires in 1 hour.")
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, ArkSpacing.xl)
                    }

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            if !viewModel.passwordResetSent {
                OnboardingBottomActions(
                    primaryTitle: "Sign In",
                    primaryAction: {
                        Task {
                            await viewModel.signInWithPassword()
                        }
                    },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isEmailValid || !viewModel.isPasswordValid,
                    errorMessage: viewModel.errorMessage
                )
            }
        }
        .onboardingBackButton { viewModel.previousStep() }
        .onAppear {
            focusedField = .email
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        SignInView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
