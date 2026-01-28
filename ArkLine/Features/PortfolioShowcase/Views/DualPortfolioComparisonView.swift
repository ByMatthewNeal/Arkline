import SwiftUI

// MARK: - Dual Portfolio Comparison View

/// Side-by-side comparison of two portfolios
struct DualPortfolioComparisonView: View {
    let leftSnapshot: PortfolioSnapshot?
    let rightSnapshot: PortfolioSnapshot?
    let isLoadingLeft: Bool
    let isLoadingRight: Bool
    let onSelectLeft: () -> Void
    let onSelectRight: () -> Void
    let onClearLeft: () -> Void
    let onClearRight: () -> Void
    let onSwap: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Swap button (only when both selected)
            if leftSnapshot != nil && rightSnapshot != nil {
                Button(action: onSwap) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Swap")
                    }
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.accent)
                }
            }

            // Portfolio cards
            HStack(alignment: .top, spacing: ArkSpacing.sm) {
                // Left Portfolio
                if let left = leftSnapshot {
                    PortfolioSnapshotCardView(
                        snapshot: left,
                        onClear: onClearLeft
                    )
                } else {
                    EmptyPortfolioSlot(
                        title: "Select Portfolio",
                        isLoading: isLoadingLeft,
                        onTap: onSelectLeft
                    )
                }

                // VS Divider
                VStack {
                    Spacer()
                    Text("VS")
                        .font(ArkFonts.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.xs)
                    Spacer()
                }
                .frame(width: 40)

                // Right Portfolio
                if let right = rightSnapshot {
                    PortfolioSnapshotCardView(
                        snapshot: right,
                        onClear: onClearRight
                    )
                } else {
                    EmptyPortfolioSlot(
                        title: "Select Portfolio",
                        isLoading: isLoadingRight,
                        onTap: onSelectRight
                    )
                }
            }
        }
    }
}

// MARK: - Empty Portfolio Slot

struct EmptyPortfolioSlot: View {
    let title: String
    var isLoading: Bool = false
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: ArkSpacing.md) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: "plus.circle.dashed")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.accent.opacity(0.6))

                    Text(title)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 280)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.md)
                    .strokeBorder(
                        AppColors.accent.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            )
            .background(AppColors.cardBackground(colorScheme).opacity(0.5))
            .cornerRadius(ArkSpacing.md)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DualPortfolioComparisonView(
            leftSnapshot: nil,
            rightSnapshot: nil,
            isLoadingLeft: false,
            isLoadingRight: false,
            onSelectLeft: {},
            onSelectRight: {},
            onClearLeft: {},
            onClearRight: {},
            onSwap: {}
        )
    }
    .padding()
    .background(Color.black)
}
