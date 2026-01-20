import SwiftUI

// MARK: - Icon Button
struct IconButton: View {
    let icon: String
    let action: () -> Void
    var size: IconButtonSize = .medium
    var style: IconButtonStyle = .default
    var badge: Int? = nil

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(style.foregroundColor)
                    .frame(width: size.buttonSize, height: size.buttonSize)
                    .background(style.backgroundColor)
                    .cornerRadius(size.cornerRadius)

                if let badge = badge, badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(hex: "EF4444"))
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

    var foregroundColor: Color {
        switch self {
        case .default: return .white
        case .primary: return .white
        case .destructive: return .white
        case .ghost: return Color(hex: "A1A1AA")
        }
    }

    var backgroundColor: Color {
        switch self {
        case .default: return Color(hex: "1F1F1F")
        case .primary: return Color(hex: "6366F1")
        case .destructive: return Color(hex: "EF4444")
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
    .background(Color(hex: "0F0F0F"))
}
