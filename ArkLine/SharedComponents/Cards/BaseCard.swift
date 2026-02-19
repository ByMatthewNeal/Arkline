import SwiftUI

// MARK: - Base Card
struct BaseCard<Content: View>: View {
    let content: () -> Content
    var backgroundColor: Color = AppColors.cardBackground(.dark)
    var cornerRadius: CGFloat = ArkSpacing.Radius.card
    var padding: CGFloat = ArkSpacing.Component.cardPadding
    var hasShadow: Bool = false

    init(
        backgroundColor: Color = AppColors.cardBackground(.dark),
        cornerRadius: CGFloat = ArkSpacing.Radius.card,
        padding: CGFloat = ArkSpacing.Component.cardPadding,
        hasShadow: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.hasShadow = hasShadow
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .arkShadow(ArkSpacing.Shadow.card)
    }
}

// MARK: - Tappable Card
struct TappableCard<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    var backgroundColor: Color = AppColors.cardBackground(.dark)
    var pressedBackgroundColor: Color = AppColors.divider(.dark)
    var cornerRadius: CGFloat = ArkSpacing.Radius.card
    var padding: CGFloat = ArkSpacing.Component.cardPadding

    @State private var isPressed = false

    init(
        backgroundColor: Color = AppColors.cardBackground(.dark),
        pressedBackgroundColor: Color = AppColors.divider(.dark),
        cornerRadius: CGFloat = ArkSpacing.Radius.card,
        padding: CGFloat = ArkSpacing.Component.cardPadding,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.action = action
        self.content = content
    }

    var body: some View {
        Button(action: action) {
            content()
                .padding(padding)
                .background(isPressed ? pressedBackgroundColor : backgroundColor)
                .cornerRadius(cornerRadius)
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.arkSpring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Section Card
struct SectionCard<Header: View, Content: View>: View {
    let header: () -> Header
    let content: () -> Content
    var backgroundColor: Color = AppColors.cardBackground(.dark)
    var headerSpacing: CGFloat = 12

    init(
        backgroundColor: Color = AppColors.cardBackground(.dark),
        headerSpacing: CGFloat = 12,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.headerSpacing = headerSpacing
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            header()
            content()
        }
        .padding(ArkSpacing.Component.cardPadding)
        .background(backgroundColor)
        .cornerRadius(ArkSpacing.Radius.card)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        BaseCard {
            VStack(alignment: .leading) {
                Text("Base Card")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("This is a simple base card")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        TappableCard(action: {}) {
            HStack {
                Text("Tappable Card")
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }

        SectionCard {
            Text("Section Header")
                .font(.headline)
                .foregroundColor(.white)
        } content: {
            Text("Section content goes here")
                .foregroundColor(.gray)
        }
    }
    .padding()
    .background(AppColors.background(.dark))
}
