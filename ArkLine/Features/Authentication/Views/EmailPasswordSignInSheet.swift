import SwiftUI

struct EmailPasswordSignInSheet: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var email = ""
    @State private var password = ""
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                if viewModel.passwordResetSent {
                    resetConfirmationView
                } else {
                    signInFormView
                }

                Spacer()
            }
            .padding(.horizontal, ArkSpacing.xl)
            .padding(.top, ArkSpacing.md)
            .background(AppColors.background(colorScheme))
            .navigationTitle(viewModel.passwordResetSent ? "Check your email" : "Sign in")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            viewModel.passwordSignInError = nil
            viewModel.passwordResetSent = false
            viewModel.passwordResetError = nil
            emailFocused = true
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sign In Form

    @ViewBuilder
    private var signInFormView: some View {
        Text("Enter your email and password to switch accounts.")
            .font(AppFonts.body14)
            .foregroundColor(AppColors.textSecondary)

        CustomTextField(
            placeholder: "Email",
            text: $email,
            icon: "envelope",
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never
        )
        .focused($emailFocused)

        CustomTextField(
            placeholder: "Password",
            text: $password,
            icon: "lock",
            isSecure: true,
            textContentType: .password
        )

        if let error = viewModel.passwordSignInError {
            Text(error)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.error)
        }

        if let error = viewModel.passwordResetError {
            Text(error)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.error)
        }

        Button {
            Task {
                await viewModel.signInWithPassword(email: email, password: password)
                if viewModel.isAuthenticated {
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isPasswordSignInLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                        .font(AppFonts.body14Bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(email.isEmpty || password.isEmpty ? AppColors.accent.opacity(0.4) : AppColors.accent)
            .cornerRadius(ArkSpacing.Radius.md)
        }
        .disabled(email.isEmpty || password.isEmpty || viewModel.isPasswordSignInLoading)

        Button {
            Task { await viewModel.sendPasswordReset(email: email) }
        } label: {
            Text("Forgot password?")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.accent)
        }
        .padding(.top, ArkSpacing.sm)
    }

    // MARK: - Reset Confirmation

    private var resetConfirmationView: some View {
        VStack(spacing: ArkSpacing.lg) {
            Image(systemName: "envelope.badge")
                .font(.system(size: 40))
                .foregroundColor(AppColors.accent)

            Text("We sent a password reset link to \(email). The link expires in 1 hour.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .font(AppFonts.body14Bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColors.accent)
                .cornerRadius(ArkSpacing.Radius.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, ArkSpacing.xl)
    }
}
