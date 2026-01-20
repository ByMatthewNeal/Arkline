import SwiftUI
import LocalAuthentication

struct FaceIDPromptView: View {
    @Bindable var viewModel: AuthViewModel
    var onUsePasscode: () -> Void

    @State private var animateIcon = false

    private var biometricIcon: String {
        switch viewModel.biometricType {
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

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Biometric Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "6366F1").opacity(0.1))
                        .frame(width: 160, height: 160)
                        .scaleEffect(animateIcon ? 1.1 : 1.0)

                    Image(systemName: biometricIcon)
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateIcon ? 1.05 : 1.0)
                }

                VStack(spacing: 8) {
                    Text("\(viewModel.biometricName)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Tap to unlock with \(viewModel.biometricName)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                        .padding(.top, 8)
                }

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.authenticateWithBiometrics()
                    }) {
                        HStack(spacing: 12) {
                            if viewModel.authState == .authenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: biometricIcon)
                                    .font(.system(size: 20))
                            }

                            Text("Unlock with \(viewModel.biometricName)")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .disabled(viewModel.authState == .authenticating)

                    Button(action: onUsePasscode) {
                        Text("Use Passcode Instead")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            startAnimation()
            // Auto-trigger biometric auth
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.authenticateWithBiometrics()
            }
        }
    }

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 2)
            .repeatForever(autoreverses: true)
        ) {
            animateIcon = true
        }
    }
}

#Preview {
    FaceIDPromptView(
        viewModel: AuthViewModel(),
        onUsePasscode: { }
    )
}
