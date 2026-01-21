import SwiftUI

// MARK: - Base Card
struct BaseCard<Content: View>: View {
    let content: () -> Content
    var backgroundColor: Color = Color(hex: "1F1F1F")
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = ArkSpacing.Component.cardPadding
    var hasShadow: Bool = false

    init(
        backgroundColor: Color = Color(hex: "1F1F1F"),
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
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
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Tappable Card
struct TappableCard<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    var backgroundColor: Color = Color(hex: "1F1F1F")
    var pressedBackgroundColor: Color = Color(hex: "2A2A2A")
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16

    @State private var isPressed = false

    init(
        backgroundColor: Color = Color(hex: "1F1F1F"),
        pressedBackgroundColor: Color = Color(hex: "2A2A2A"),
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
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
    var backgroundColor: Color = Color(hex: "1F1F1F")
    var headerSpacing: CGFloat = 12

    init(
        backgroundColor: Color = Color(hex: "1F1F1F"),
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
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(16)
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
    .background(Color(hex: "0F0F0F"))
}
