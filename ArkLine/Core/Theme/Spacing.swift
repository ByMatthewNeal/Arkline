import SwiftUI

// MARK: - App Spacing System
struct ArkSpacing {
    // MARK: - Base Spacing Values (4-point grid)
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
    static let xxxxl: CGFloat = 48

    // MARK: - Component Spacing
    struct Component {
        static let cardPadding: CGFloat = md
        static let cardSpacing: CGFloat = sm
        static let listItemPadding: CGFloat = md
        static let listItemSpacing: CGFloat = xs
        static let buttonPadding: CGFloat = md
        static let iconTextSpacing: CGFloat = xs
        static let sectionSpacing: CGFloat = xl
        static let groupSpacing: CGFloat = md
    }

    // MARK: - Layout Spacing
    struct Layout {
        static let screenPadding: CGFloat = md
        static let safeAreaBottom: CGFloat = 34
        static let tabBarHeight: CGFloat = 83
        static let navigationBarHeight: CGFloat = 44
        static let headerHeight: CGFloat = 56
    }

    // MARK: - Corner Radius
    struct Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999

        static let card: CGFloat = md
        static let button: CGFloat = sm
        static let input: CGFloat = sm
        static let sheet: CGFloat = xl
        static let avatar: CGFloat = full
    }

    // MARK: - Border Width
    struct Border {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
    }

    // MARK: - Shadow
    struct Shadow {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 4,
            x: 0,
            y: 2
        )

        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )

        static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 16,
            x: 0,
            y: 8
        )
    }

    // MARK: - Icon Sizes
    struct IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 48
    }

    // MARK: - Avatar Sizes
    struct AvatarSize {
        static let xs: CGFloat = 24
        static let sm: CGFloat = 32
        static let md: CGFloat = 40
        static let lg: CGFloat = 48
        static let xl: CGFloat = 64
        static let xxl: CGFloat = 80
        static let profile: CGFloat = 100
    }

    // MARK: - Button Heights
    struct ButtonHeight {
        static let small: CGFloat = 32
        static let medium: CGFloat = 44
        static let large: CGFloat = 52
    }

    // MARK: - Input Heights
    struct InputHeight {
        static let small: CGFloat = 36
        static let medium: CGFloat = 44
        static let large: CGFloat = 52
    }
}

// MARK: - Shadow Style
struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifier for Shadows
extension View {
    func arkShadow(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }

    func arkShadowSmall() -> some View {
        arkShadow(ArkSpacing.Shadow.small)
    }

    func arkShadowMedium() -> some View {
        arkShadow(ArkSpacing.Shadow.medium)
    }

    func arkShadowLarge() -> some View {
        arkShadow(ArkSpacing.Shadow.large)
    }
}

// MARK: - Convenience Padding Extensions
extension View {
    func arkPadding(_ edges: Edge.Set = .all, _ size: CGFloat = ArkSpacing.md) -> some View {
        padding(edges, size)
    }

    func arkHorizontalPadding(_ size: CGFloat = ArkSpacing.md) -> some View {
        padding(.horizontal, size)
    }

    func arkVerticalPadding(_ size: CGFloat = ArkSpacing.md) -> some View {
        padding(.vertical, size)
    }

    func arkScreenPadding() -> some View {
        padding(.horizontal, ArkSpacing.Layout.screenPadding)
    }

    func arkCardPadding() -> some View {
        padding(ArkSpacing.Component.cardPadding)
    }
}
