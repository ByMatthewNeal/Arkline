import SwiftUI
import LocalAuthentication

struct FaceIDSetupView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingError = false
    @State private var errorMessage = ""

    private var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        default:
            return "faceid"
        }
    }

    private var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Face ID"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: biometricIcon)
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 8)

                    Text("Enable \(biometricName)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Use \(biometricName) for quick and secure access")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "bolt.fill",
                        title: "Quick Access",
                        description: "Unlock the app instantly"
                    )

                    FeatureRow(
                        icon: "lock.shield.fill",
                        title: "Secure",
                        description: "Your biometric data stays on device"
                    )

                    FeatureRow(
                        icon: "key.fill",
                        title: "Passcode Backup",
                        description: "Always use passcode as fallback"
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()
            }

            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Enable \(biometricName)",
                    action: { authenticateWithBiometrics() }
                )

                Button(action: { viewModel.setupFaceID(enabled: false) }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "0F0F0F"))
        .navigationBarBackButtonHidden()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { viewModel.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
        #endif
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
                            errorMessage = authError.localizedDescription
                            showingError = true
                        }
                    }
                }
            }
        } else {
            errorMessage = error?.localizedDescription ?? "\(biometricName) is not available"
            showingError = true
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "6366F1"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "6366F1").opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }

            Spacer()
        }
        .padding(16)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        FaceIDSetupView(viewModel: OnboardingViewModel())
    }
}
