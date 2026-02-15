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

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        LoadingView(message: "Loading...")

        SkeletonCard()

        SkeletonList(itemCount: 3)
    }
    .background(AppColors.background(.dark))
}
