import SwiftUI

struct PasscodeEntryView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var shake = false

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
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .frame(width: 40, height: 40)
                            .background(AppColors.surface(colorScheme))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.divider(colorScheme), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Dismiss")

                    Spacer()

                    if viewModel.canUseBiometrics {
                        Button(action: {
                            viewModel.authenticateWithBiometrics()
                        }) {
                            Image(systemName: viewModel.biometricType == .faceID ? "faceid" : "touchid")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.fillPrimary)
                                .frame(width: 40, height: 40)
                                .background(AppColors.fillPrimary.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Authenticate with \(viewModel.biometricName)")
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.top, ArkSpacing.md)

                VStack(spacing: ArkSpacing.xl) {
                    VStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.fillPrimary, AppColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .accessibilityHidden(true)

                        Text("Enter Passcode")
                            .font(AppFonts.title24)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        if viewModel.isLocked {
                            Text("Try again in \(viewModel.lockoutTimeRemaining)")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.error)
                        }
                    }
                    .padding(.top, ArkSpacing.xxl)

                    // Passcode Dots
                    PasscodeDots(
                        code: viewModel.passcode,
                        length: viewModel.passcodeLength,
                        shake: shake
                    )

                    if let error = viewModel.errorMessage, !viewModel.isLocked {
                        Text(error)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.error)
                            .transition(.opacity)
                    }

                    // Keypad
                    PasscodeKeypadGrid(
                        code: $viewModel.passcode,
                        maxLength: viewModel.passcodeLength,
                        disabled: viewModel.isLocked || viewModel.authState == .authenticating
                    )

                    Spacer()
                }
            }
        }
        .onChange(of: viewModel.passcode) { _, newValue in
            if newValue.count == viewModel.passcodeLength {
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .fill(index < code.count ? AppColors.fillPrimary : AppColors.divider(colorScheme))
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(code.count) of \(length) digits entered")
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppColors.surface(colorScheme))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(AppColors.divider(colorScheme), lineWidth: 1)
                    )

                if let title = title {
                    Text(title)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }
        }
        .buttonStyle(KeypadButtonStyle())
        .accessibilityLabel(title ?? (icon == "delete.left.fill" ? "Delete" : ""))
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

#Preview("Light Mode") {
    PasscodeEntryView(viewModel: AuthViewModel())
        .preferredColorScheme(.light)
}
