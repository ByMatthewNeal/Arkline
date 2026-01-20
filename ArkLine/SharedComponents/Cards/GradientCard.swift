import SwiftUI

// MARK: - Gradient Card
struct GradientCard<Content: View>: View {
    let content: () -> Content
    var gradientColors: [Color] = [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16

    init(
        gradientColors: [Color] = [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing,
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.gradientColors = gradientColors
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Accent Card (with border gradient)
struct AccentCard<Content: View>: View {
    let content: () -> Content
    var backgroundColor: Color = Color(hex: "1F1F1F")
    var borderColors: [Color] = [Color(hex: "6366F1"), Color(hex: "8B5CF6")]
    var borderWidth: CGFloat = 1.5
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16

    init(
        backgroundColor: Color = Color(hex: "1F1F1F"),
        borderColors: [Color] = [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
        borderWidth: CGFloat = 1.5,
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.borderColors = borderColors
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: borderColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
    }
}

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let content: () -> Content
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 16

    init(
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        GradientCard {
            VStack(alignment: .leading) {
                Text("Gradient Card")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Beautiful gradient background")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        AccentCard {
            VStack(alignment: .leading) {
                Text("Accent Card")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Card with gradient border")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        GlassCard {
            VStack(alignment: .leading) {
                Text("Glass Card")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Frosted glass effect")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
