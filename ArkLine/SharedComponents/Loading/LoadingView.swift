import SwiftUI

// MARK: - Loading View
struct LoadingView: View {
    var message: String? = nil
    var size: LoadingSize = .medium

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(size.scale)

            if let message = message {
                Text(message)
                    .font(size.font)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(colorScheme))
    }
}

enum LoadingSize {
    case small
    case medium
    case large

    var scale: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.5
        }
    }

    var font: Font {
        switch self {
        case .small: return .caption
        case .medium: return .subheadline
        case .large: return .body
        }
    }
}

// MARK: - Skeleton View
struct SkeletonView: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 4

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var baseColor: Color {
        AppColors.divider(colorScheme)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "E8E8E8")
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        baseColor,
                        highlightColor,
                        baseColor
                    ]),
                    startPoint: isAnimating ? .trailing : .leading,
                    endPoint: isAnimating ? .leading : .trailing
                )
            )
            .frame(height: height)
            .cornerRadius(cornerRadius)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(height: 16, cornerRadius: 4)
                .frame(width: 120)

            SkeletonView(height: 12, cornerRadius: 4)
                .frame(maxWidth: .infinity)

            SkeletonView(height: 12, cornerRadius: 4)
                .frame(width: 200)
        }
        .padding(16)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }
}

// MARK: - Skeleton List
struct SkeletonList: View {
    var itemCount: Int = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<itemCount, id: \.self) { _ in
                SkeletonListItem()
            }
        }
    }
}

struct SkeletonListItem: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(height: 40, cornerRadius: 20)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 14, cornerRadius: 4)
                    .frame(width: 100)

                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(width: 60)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                SkeletonView(height: 14, cornerRadius: 4)
                    .frame(width: 70)

                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(width: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Skeleton Chart View
struct SkeletonChartView: View {
    var height: CGFloat = 200

    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    private var baseColor: Color {
        AppColors.divider(colorScheme)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color(hex: "3A3A3A") : Color(hex: "E8E8E8")
    }

    var body: some View {
        ZStack {
            // Wave area fill
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.7))
                    path.addCurve(
                        to: CGPoint(x: w * 0.25, y: h * 0.4),
                        control1: CGPoint(x: w * 0.08, y: h * 0.65),
                        control2: CGPoint(x: w * 0.18, y: h * 0.35)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.55),
                        control1: CGPoint(x: w * 0.32, y: h * 0.45),
                        control2: CGPoint(x: w * 0.42, y: h * 0.6)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.75, y: h * 0.3),
                        control1: CGPoint(x: w * 0.58, y: h * 0.5),
                        control2: CGPoint(x: w * 0.68, y: h * 0.25)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.45),
                        control1: CGPoint(x: w * 0.82, y: h * 0.35),
                        control2: CGPoint(x: w * 0.92, y: h * 0.5)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [baseColor.opacity(0.6), baseColor.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Wave line stroke
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.7))
                    path.addCurve(
                        to: CGPoint(x: w * 0.25, y: h * 0.4),
                        control1: CGPoint(x: w * 0.08, y: h * 0.65),
                        control2: CGPoint(x: w * 0.18, y: h * 0.35)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.5, y: h * 0.55),
                        control1: CGPoint(x: w * 0.32, y: h * 0.45),
                        control2: CGPoint(x: w * 0.42, y: h * 0.6)
                    )
                    path.addCurve(
                        to: CGPoint(x: w * 0.75, y: h * 0.3),
                        control1: CGPoint(x: w * 0.58, y: h * 0.5),
                        control2: CGPoint(x: w * 0.68, y: h * 0.25)
                    )
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.45),
                        control1: CGPoint(x: w * 0.82, y: h * 0.35),
                        control2: CGPoint(x: w * 0.92, y: h * 0.5)
                    )
                }
                .stroke(baseColor, lineWidth: 2)
            }

            // Y-axis label placeholders
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 40) {
                        SkeletonView(height: 10, cornerRadius: 3)
                            .frame(width: 40)
                        SkeletonView(height: 10, cornerRadius: 3)
                            .frame(width: 35)
                        SkeletonView(height: 10, cornerRadius: 3)
                            .frame(width: 40)
                    }
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(height: height)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        LoadingView(message: "Loading...")

        SkeletonCard()

        SkeletonList(itemCount: 3)
    }
    .background(AppColors.background(.dark))
}
