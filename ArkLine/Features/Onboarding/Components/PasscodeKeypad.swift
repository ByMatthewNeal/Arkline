import SwiftUI

// MARK: - Passcode Keypad
/// Numeric keypad for passcode entry with design system styling
struct PasscodeKeypad: View {
    @Binding var code: String
    var length: Int = 6
    var title: String = "Enter Passcode"
    var onComplete: ((String) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.xxl) {
            // Title
            if !title.isEmpty {
                Text(title)
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            // Passcode dots
            HStack(spacing: ArkSpacing.md) {
                ForEach(0..<length, id: \.self) { index in
                    PasscodeDot(
                        isFilled: index < code.count,
                        colorScheme: colorScheme
                    )
                }
            }

            // Numeric keypad
            VStack(spacing: ArkSpacing.md) {
                // Rows 1-3
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: ArkSpacing.xl) {
                        ForEach(1..<4, id: \.self) { col in
                            let number = row * 3 + col
                            OnboardingKeypadButton(
                                label: "\(number)",
                                colorScheme: colorScheme
                            ) {
                                appendDigit("\(number)")
                            }
                        }
                    }
                }

                // Bottom row: empty, 0, delete
                HStack(spacing: ArkSpacing.xl) {
                    // Empty placeholder
                    Color.clear
                        .frame(width: 72, height: 72)

                    // Zero
                    OnboardingKeypadButton(
                        label: "0",
                        colorScheme: colorScheme
                    ) {
                        appendDigit("0")
                    }

                    // Delete button
                    OnboardingKeypadButton(
                        icon: "delete.left.fill",
                        colorScheme: colorScheme
                    ) {
                        deleteDigit()
                    }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard code.count < length else { return }
        code += digit

        Haptics.light()

        if code.count == length {
            onComplete?(code)
        }
    }

    private func deleteDigit() {
        guard !code.isEmpty else { return }
        code.removeLast()

        Haptics.light()
    }
}

// MARK: - Passcode Dot
struct PasscodeDot: View {
    let isFilled: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Circle()
            .fill(isFilled ? AppColors.fillPrimary : AppColors.divider(colorScheme))
            .frame(width: 16, height: 16)
            .animation(.easeInOut(duration: 0.15), value: isFilled)
    }
}

// MARK: - Onboarding Keypad Button
struct OnboardingKeypadButton: View {
    var label: String? = nil
    var icon: String? = nil
    let colorScheme: ColorScheme
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                Circle()
                    .fill(AppColors.cardBackground(colorScheme))
                    .frame(width: 72, height: 72)

                // Border
                Circle()
                    .stroke(AppColors.divider(colorScheme), lineWidth: ArkSpacing.Border.thin)
                    .frame(width: 72, height: 72)

                // Content
                if let label = label {
                    Text(label)
                        .font(AppFonts.title30)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview
#Preview {
    VStack {
        OnboardingProgressBar(progress: 0.5)
            .padding()

        PasscodeKeypad(code: .constant("12"))
    }
    .background(Color(hex: "0F0F0F"))
}
