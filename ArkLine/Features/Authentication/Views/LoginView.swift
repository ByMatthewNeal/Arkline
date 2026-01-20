import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var showPasscodeEntry = false

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and Welcome
                VStack(spacing: 24) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 8) {
                        Text("Welcome back")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)

                        Text("Sign in to continue")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                }

                Spacer()

                // Authentication Options
                VStack(spacing: 16) {
                    if viewModel.canUseBiometrics && viewModel.showFaceID {
                        FaceIDButton(viewModel: viewModel)
                    }

                    PasscodeButton {
                        showPasscodeEntry = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
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
            // Auto-trigger Face ID if available and enabled
            if viewModel.canUseBiometrics && viewModel.showFaceID {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.authenticateWithBiometrics()
                }
            }
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
        .opacity(viewModel.authState == .authenticating ? 0.6 : 1)
    }
}

// MARK: - Passcode Button
struct PasscodeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 20))

                Text("Use Passcode")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(hex: "1F1F1F"))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "2A2A2A"), lineWidth: 1)
            )
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
