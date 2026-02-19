import SwiftUI

// MARK: - Empty State Style
enum EmptyStateStyle {
    case prominent  // Full-width, gradient glow — main content areas
    case compact    // Smaller, no glow — sheets, search results, pickers
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var appeared = false

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var style: EmptyStateStyle = .prominent

    private var iconCircleSize: CGFloat { style == .prominent ? 64 : 44 }
    private var symbolSize: CGFloat { style == .prominent ? 28 : 20 }
    private var spacing: CGFloat { style == .prominent ? 16 : 12 }
    private var titleFont: Font { style == .prominent ? AppFonts.title20 : AppFonts.title18SemiBold }
    private var outerPadding: CGFloat { style == .prominent ? 40 : 24 }

    var body: some View {
        VStack(spacing: spacing) {
            // Icon with gradient circle + optional glow
            ZStack {
                if style == .prominent {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppColors.glowPrimary.opacity(0.2), AppColors.glowPrimary.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 10)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentLight, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: iconCircleSize, height: iconCircleSize)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: symbolSize, weight: .medium))
                            .foregroundColor(.white)
                    )
            }

            Text(title)
                .font(titleFont)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(message)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .cornerRadius(ArkSpacing.Radius.sm)
                }
                .padding(.top, ArkSpacing.xxs)
            }
        }
        .padding(outerPadding)
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}
