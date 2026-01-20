import SwiftUI

struct PasscodeEntryView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var shake = false

    var body: some View {
        ZStack {
            Color(hex: "0F0F0F")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "1F1F1F"))
                            .clipShape(Circle())
                    }

                    Spacer()

                    if viewModel.canUseBiometrics {
                        Button(action: {
                            viewModel.authenticateWithBiometrics()
                        }) {
                            Image(systemName: viewModel.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "6366F1"))
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "6366F1").opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Enter Passcode")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        if viewModel.isLocked {
                            Text("Try again in \(viewModel.lockoutTimeRemaining)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "EF4444"))
                        }
                    }
                    .padding(.top, 40)

                    // Passcode Dots
                    PasscodeDots(
                        code: viewModel.passcode,
                        length: 6,
                        shake: shake
                    )

                    if let error = viewModel.errorMessage, !viewModel.isLocked {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                            .transition(.opacity)
                    }

                    // Keypad
                    PasscodeKeypadGrid(
                        code: $viewModel.passcode,
                        maxLength: 6,
                        disabled: viewModel.isLocked || viewModel.authState == .authenticating
                    )

                    Spacer()
                }
            }
        }
        .onChange(of: viewModel.passcode) { _, newValue in
            if newValue.count == 6 {
                viewModel.verifyPasscode()
            }
        }
        .onChange(of: viewModel.authState) { _, newState in
            if case .failed = newState {
                triggerShake()
            } else if case .authenticated = newState {
                dismiss()
            }
        }
    }

    private func triggerShake() {
        withAnimation(.default) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
        }
    }
}

// MARK: - Passcode Dots
struct PasscodeDots: View {
    let code: String
    let length: Int
    let shake: Bool

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .fill(index < code.count ? Color(hex: "6366F1") : Color(hex: "2A2A2A"))
                    .frame(width: 16, height: 16)
                    .scaleEffect(index < code.count ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2), value: code.count)
            }
        }
        .offset(x: shake ? -10 : 0)
        .animation(
            shake ? Animation.default.repeatCount(4, autoreverses: true).speed(6) : .default,
            value: shake
        )
    }
}

// MARK: - Passcode Keypad Grid
struct PasscodeKeypadGrid: View {
    @Binding var code: String
    let maxLength: Int
    var disabled: Bool = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...9, id: \.self) { number in
                KeypadButton(title: "\(number)") {
                    appendDigit("\(number)")
                }
                .disabled(disabled)
            }

            // Empty space
            Color.clear
                .frame(height: 72)

            // Zero
            KeypadButton(title: "0") {
                appendDigit("0")
            }
            .disabled(disabled)

            // Delete
            KeypadButton(icon: "delete.left.fill") {
                deleteLastDigit()
            }
            .disabled(disabled || code.isEmpty)
        }
        .padding(.horizontal, 48)
    }

    private func appendDigit(_ digit: String) {
        guard code.count < maxLength else { return }
        code += digit
    }

    private func deleteLastDigit() {
        guard !code.isEmpty else { return }
        code.removeLast()
    }
}

// MARK: - Keypad Button
struct KeypadButton: View {
    var title: String? = nil
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1F1F1F"))
                    .frame(width: 72, height: 72)

                if let title = title {
                    Text(title)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(KeypadButtonStyle())
    }
}

// MARK: - Keypad Button Style
struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    PasscodeEntryView(viewModel: AuthViewModel())
}
