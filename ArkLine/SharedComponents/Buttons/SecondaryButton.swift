import SwiftUI

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var icon: String? = nil
    var size: ButtonSize = .large
    var style: SecondaryButtonStyle = .outlined

    @Environment(\.colorScheme) private var colorScheme

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
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor(colorScheme)))
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
            .foregroundColor(style.foregroundColor(colorScheme))
            .background(style.backgroundColor(colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.button)
                    .stroke(style.borderColor, lineWidth: style.borderWidth)
            )
            .cornerRadius(ArkSpacing.Radius.button)
            .opacity(isDisabled ? 0.5 : 1)
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Secondary Button Style
enum SecondaryButtonStyle {
    case outlined
    case filled
    case ghost

    func foregroundColor(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .outlined: return AppColors.accent
        case .filled: return AppColors.textPrimary(colorScheme)
        case .ghost: return AppColors.textSecondary
        }
    }

    func backgroundColor(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .outlined: return .clear
        case .filled: return AppColors.cardBackground(colorScheme)
        case .ghost: return .clear
        }
    }

    var borderColor: Color {
        switch self {
        case .outlined: return AppColors.accent
        case .filled: return .clear
        case .ghost: return .clear
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .outlined: return 1.5
        case .filled, .ghost: return 0
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        SecondaryButton(title: "Outlined", action: {})

        SecondaryButton(title: "Filled", action: {}, style: .filled)

        SecondaryButton(title: "Ghost", action: {}, style: .ghost)

        SecondaryButton(title: "Loading", action: {}, isLoading: true)

        SecondaryButton(title: "With Icon", action: {}, icon: "plus")
    }
    .padding()
    .background(AppColors.background(.dark))
}
