import SwiftUI

// MARK: - Passcode Keypad
struct PasscodeKeypad: View {
    @Binding var code: String
    var length: Int = 6
    var title: String = "Enter Passcode"
    var onComplete: ((String) -> Void)? = nil

    var body: some View {
        VStack(spacing: 32) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Dots
            HStack(spacing: 16) {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .fill(index < code.count ? Color(hex: "6366F1") : Color(hex: "3A3A3A"))
                        .frame(width: 16, height: 16)
                        .animation(.easeInOut(duration: 0.15), value: code.count)
                }
            }

            // Keypad
            VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 24) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            OnboardingKeypadButton(number: "\(number)") {
                                appendDigit("\(number)")
                            }
                        }
                    }
                }

                // Bottom row: empty, 0, delete
                HStack(spacing: 24) {
                    // Empty space
                    Color.clear
                        .frame(width: 72, height: 72)

                    // 0
                    OnboardingKeypadButton(number: "0") {
                        appendDigit("0")
                    }

                    // Delete
                    Button(action: deleteDigit) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                    }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard code.count < length else { return }
        code += digit

        if code.count == length {
            onComplete?(code)
        }
    }

    private func deleteDigit() {
        guard !code.isEmpty else { return }
        code.removeLast()
    }
}

// MARK: - Keypad Button (Onboarding)
struct OnboardingKeypadButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 72, height: 72)
                .background(Color(hex: "1F1F1F"))
                .clipShape(Circle())
        }
    }
}

// MARK: - Onboarding Progress
struct OnboardingProgress: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(hex: "2A2A2A"))
                    .frame(height: 4)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        OnboardingProgress(progress: 0.5)
            .padding()

        PasscodeKeypad(code: .constant("12"))
    }
    .background(Color(hex: "0F0F0F"))
}
