import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var icon: String? = nil
    var size: ButtonSize = .large

    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                Haptics.light()
                action()
            }
        }) {
            HStack(spacing: ArkSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: size.iconSize, weight: .semibold))
                    }
                    Text(title)
                        .font(size.font)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .foregroundColor(.white)
            .background(AppColors.accent)  // blue-500
            .cornerRadius(ArkSpacing.Radius.button)
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Button Size
enum ButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return ArkSpacing.ButtonHeight.small
        case .medium: return ArkSpacing.ButtonHeight.medium
        case .large: return ArkSpacing.ButtonHeight.large
        }
    }

    var font: Font {
        switch self {
        case .small: return ArkFonts.footnote
        case .medium: return ArkFonts.subheadline
        case .large: return ArkFonts.body
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Continue", action: {})

        PrimaryButton(title: "Loading...", action: {}, isLoading: true)

        PrimaryButton(title: "Disabled", action: {}, isDisabled: true)

        PrimaryButton(title: "With Icon", action: {}, icon: "arrow.right")

        PrimaryButton(title: "Small", action: {}, size: .small)
    }
    .padding()
    .background(AppColors.background(.dark))
}
