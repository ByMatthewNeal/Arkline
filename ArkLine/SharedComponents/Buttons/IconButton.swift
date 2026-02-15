import SwiftUI

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: IconButtonSize = .medium
    var style: IconButtonStyle = .default
    var badge: Int? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(style.foregroundColor(colorScheme))
                    .frame(width: size.buttonSize, height: size.buttonSize)
                    .background(style.backgroundColor(colorScheme))
                    .cornerRadius(size.cornerRadius)

                if let badge = badge, badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(AppColors.error)
                        .cornerRadius(8)
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

// MARK: - Icon Button Size
enum IconButtonSize {
    case small
    case medium
    case large

    var buttonSize: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 40
        case .large: return 48
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 22
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
}

// MARK: - Icon Button Style
enum IconButtonStyle {
    case `default`
    case primary
    case destructive
    case ghost

    func foregroundColor(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .default: return AppColors.textPrimary(colorScheme)
        case .primary: return .white
        case .destructive: return .white
        case .ghost: return AppColors.textSecondary
        }
    }

    func backgroundColor(_ colorScheme: ColorScheme) -> Color {
        switch self {
        case .default: return AppColors.cardBackground(colorScheme)
        case .primary: return AppColors.accent
        case .destructive: return AppColors.error
        case .ghost: return .clear
        }
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 16) {
        IconButton(icon: "bell.fill", action: {})
        IconButton(icon: "gear", action: {}, style: .primary)
        IconButton(icon: "trash", action: {}, style: .destructive)
        IconButton(icon: "ellipsis", action: {}, style: .ghost)
        IconButton(icon: "bell.fill", action: {}, badge: 5)
    }
    .padding()
    .background(AppColors.background(.dark))
}
