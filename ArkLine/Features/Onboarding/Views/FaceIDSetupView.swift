import SwiftUI
import LocalAuthentication

// MARK: - Face ID Setup View
struct FaceIDSetupView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""
    @Environment(\.colorScheme) private var colorScheme

    private var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "faceid"
        }
    }

    private var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Face ID"
        }
    }

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            VStack(spacing: ArkSpacing.xxl) {
                // Header with biometric icon
                VStack(spacing: ArkSpacing.sm) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.fillPrimary, AppColors.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, ArkSpacing.xs)

                    Text("Enable \(biometricName)")
                        .font(AppFonts.title30)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Use \(biometricName) for quick and secure access")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ArkSpacing.xl)
                }
                .padding(.top, ArkSpacing.xxxl)

                // Feature list
                VStack(spacing: ArkSpacing.md) {
                    BiometricFeatureRow(
                        icon: "bolt.fill",
                        title: "Quick Access",
                        description: "Unlock the app instantly",
                        colorScheme: colorScheme
                    )

                    BiometricFeatureRow(
                        icon: "lock.shield.fill",
                        title: "Secure",
                        description: "Your biometric data stays on device",
                        colorScheme: colorScheme
                    )

                    BiometricFeatureRow(
                        icon: "key.fill",
                        title: "Passcode Backup",
                        description: "Always use passcode as fallback",
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.top, ArkSpacing.md)

                Spacer()

                // Bottom buttons
                VStack(spacing: ArkSpacing.sm) {
                    // Error message from view model
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.error)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }

                    PrimaryButton(
                        title: "Enable \(biometricName)",
                        action: { authenticateWithBiometrics() },
                        isLoading: viewModel.isLoading,
                        isDisabled: viewModel.isLoading
                    )

                    Button(action: { viewModel.setupFaceID(enabled: false) }) {
                        Text("Skip for now")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        .onboardingBackButton { viewModel.previousStep() }
        .alert("Error", isPresented: $showingBiometricError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(biometricErrorMessage)
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Enable \(biometricName) for quick access"
            ) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        viewModel.setupFaceID(enabled: true)
                    } else if let authError = authError as? LAError {
                        switch authError.code {
                        case .userCancel:
                            break
                        case .userFallback:
                            viewModel.setupFaceID(enabled: false)
                        default:
                            biometricErrorMessage = authError.localizedDescription
                            showingBiometricError = true
                        }
                    }
                }
            }
        } else {
            biometricErrorMessage = error?.localizedDescription ?? "\(biometricName) is not available"
            showingBiometricError = true
        }
    }
}

// MARK: - Biometric Feature Row
struct BiometricFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.fillPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.fillPrimary.opacity(0.1))
                .cornerRadius(ArkSpacing.Radius.md)

            // Text
            VStack(alignment: .leading, spacing: ArkSpacing.xxxs) {
                Text(title)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(description)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.md)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        FaceIDSetupView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
