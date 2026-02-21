import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @EnvironmentObject var appState: AppState
    @State private var showPasscodeEntry = false
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            AppColors.background(colorScheme)
                .ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.surface(colorScheme),
                    AppColors.background(colorScheme)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and Welcome
                VStack(spacing: ArkSpacing.xl) {
                    // Logo with glow
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.fillPrimary.opacity(0.3),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 180, height: 180)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .opacity(isAnimating ? 1 : 0.6)

                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.fillPrimary, AppColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: ArkSpacing.xs) {
                        Text("Welcome back")
                            .font(AppFonts.title32)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("Sign in to continue")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Authentication Options
                VStack(spacing: ArkSpacing.md) {
                    if viewModel.canUseBiometrics && viewModel.showFaceID {
                        FaceIDButton(viewModel: viewModel)
                    }

                    PasscodeButton {
                        showPasscodeEntry = true
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showPasscodeEntry) {
            PasscodeEntryView(viewModel: viewModel)
        }
        #else
        .sheet(isPresented: $showPasscodeEntry) {
            PasscodeEntryView(viewModel: viewModel)
        }
        #endif
        .onAppear {
            // Start glow animation
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }

            // Auto-trigger Face ID if available, enabled, and not returning from sign-out
            if viewModel.canUseBiometrics && viewModel.showFaceID && !appState.didJustSignOut {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.authenticateWithBiometrics()
                }
            }
            appState.didJustSignOut = false
        }
    }
}

// MARK: - Face ID Button
struct FaceIDButton: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        Button(action: {
            viewModel.authenticateWithBiometrics()
        }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.biometricType == .faceID ? "faceid" : "touchid")
                    .font(.system(size: 24))

                Text("Sign in with \(viewModel.biometricName)")
                    .font(AppFonts.title16)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [AppColors.fillPrimary, AppColors.accentLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(ArkSpacing.Radius.lg)
        }
        .disabled(viewModel.authState == .authenticating)
        .opacity(viewModel.authState == .authenticating ? 0.6 : 1)
        .accessibilityLabel("Sign in with \(viewModel.biometricName)")
    }
}

// MARK: - Passcode Button
struct PasscodeButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 20))

                Text("Use Passcode")
                    .font(AppFonts.title16)
            }
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AppColors.surface(colorScheme))
            .cornerRadius(ArkSpacing.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.lg)
                    .stroke(AppColors.divider(colorScheme), lineWidth: 1)
            )
        }
        .accessibilityLabel("Use Passcode")
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
        .environmentObject(AppState())
}

#Preview("Light Mode") {
    LoginView(viewModel: AuthViewModel())
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
