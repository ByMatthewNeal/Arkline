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
    @EnvironmentObject var appState: AppState

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
                        onClear: onClearLeft,
                        chartPalette: appState.chartColorPalette
                    )
                } else {
                    EmptyPortfolioSlot(
                        title: "Select Portfolio",
                        isLoading: isLoadingLeft,
                        onTap: onSelectLeft
                    )
                }

                // VS Divider (minimal)
                Text("vs")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 20)

                // Right Portfolio
                if let right = rightSnapshot {
                    PortfolioSnapshotCardView(
                        snapshot: right,
                        onClear: onClearRight,
                        chartPalette: appState.chartColorPalette
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
            VStack(spacing: ArkSpacing.sm) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.accent.opacity(0.5))

                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.md)
                    .strokeBorder(
                        AppColors.textTertiary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 1, dash: [6])
                    )
            )
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
