import SwiftUI
import Kingfisher

// MARK: - Embedded Portfolio Widget

/// Widget for displaying portfolio showcases within broadcast content
struct EmbeddedPortfolioWidget: View {
    let attachment: BroadcastPortfolioAttachment
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: "square.split.2x1")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)

                Text(attachment.isComparison ? "Portfolio Comparison" : "Portfolio Snapshot")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Privacy badge
                HStack(spacing: 2) {
                    Image(systemName: attachment.privacyLevel.icon)
                        .font(.caption2)
                    Text(attachment.privacyLevel.displayName)
                        .font(.system(size: 9))
                }
                .foregroundColor(AppColors.textTertiary)
            }

            // Content
            if let imageURL = attachment.renderedImageURL {
                // Show pre-rendered image
                KFImage(imageURL)
                    .resizable()
                    .placeholder { fallbackView }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(ArkSpacing.sm)
            } else {
                // Show compact inline view from snapshot data
                compactSnapshotView
            }

            // Caption
            if let caption = attachment.caption, !caption.isEmpty {
                Text(caption)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .italic()
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Compact Snapshot View

    private var compactSnapshotView: some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            // Left snapshot
            if let left = attachment.leftSnapshot {
                CompactSnapshotCard(snapshot: left)
            }

            // VS divider (if comparison)
            if attachment.isComparison {
                VStack {
                    Spacer()
                    Text("VS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
                .frame(width: 24)
            }

            // Right snapshot
            if let right = attachment.rightSnapshot {
                CompactSnapshotCard(snapshot: right)
            }
        }
    }

    // MARK: - Fallback View

    private var fallbackView: some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: "photo")
                .font(.title2)
                .foregroundColor(AppColors.textTertiary)

            Text("Portfolio image unavailable")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(AppColors.cardBackground(colorScheme).opacity(0.5))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Compact Snapshot Card

private struct CompactSnapshotCard: View {
    let snapshot: PortfolioSnapshot
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            // Name
            Text(snapshot.portfolioName)
                .font(ArkFonts.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(1)

            // Value or masked
            if let value = snapshot.totalValue {
                Text(value.asCurrency)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle()
                            .fill(AppColors.textSecondary.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
            }

            // Performance
            if let perf = snapshot.profitLossPercentage {
                HStack(spacing: 2) {
                    Image(systemName: perf >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.1f%%", perf))
                        .font(ArkFonts.caption)
                }
                .foregroundColor(perf >= 0 ? AppColors.success : AppColors.error)
            }

            // Asset count
            Text("\(snapshot.assetCount) assets")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ArkSpacing.sm)
        .background(AppColors.cardBackground(colorScheme).opacity(0.5))
        .cornerRadius(ArkSpacing.xs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Single portfolio
        EmbeddedPortfolioWidget(
            attachment: BroadcastPortfolioAttachment(
                leftSnapshot: PortfolioSnapshot(
                    id: UUID(),
                    portfolioId: UUID(),
                    portfolioName: "Crypto Portfolio",
                    snapshotDate: Date(),
                    privacyLevel: .percentageOnly,
                    totalValue: nil,
                    totalCost: nil,
                    totalProfitLoss: nil,
                    profitLossPercentage: 25.5,
                    dayChange: nil,
                    dayChangePercentage: 1.2,
                    holdings: [],
                    allocations: [],
                    assetCount: 5,
                    primaryAssetType: "crypto"
                ),
                privacyLevel: .percentageOnly,
                caption: "My crypto holdings are looking strong!"
            )
        )

        // Comparison
        EmbeddedPortfolioWidget(
            attachment: BroadcastPortfolioAttachment(
                leftSnapshot: PortfolioSnapshot(
                    id: UUID(),
                    portfolioId: UUID(),
                    portfolioName: "Crypto",
                    snapshotDate: Date(),
                    privacyLevel: .performanceOnly,
                    totalValue: nil,
                    totalCost: nil,
                    totalProfitLoss: nil,
                    profitLossPercentage: 25.5,
                    dayChange: nil,
                    dayChangePercentage: nil,
                    holdings: [],
                    allocations: [],
                    assetCount: 5,
                    primaryAssetType: "crypto"
                ),
                rightSnapshot: PortfolioSnapshot(
                    id: UUID(),
                    portfolioId: UUID(),
                    portfolioName: "Stocks",
                    snapshotDate: Date(),
                    privacyLevel: .performanceOnly,
                    totalValue: nil,
                    totalCost: nil,
                    totalProfitLoss: nil,
                    profitLossPercentage: 12.3,
                    dayChange: nil,
                    dayChangePercentage: nil,
                    holdings: [],
                    allocations: [],
                    assetCount: 8,
                    primaryAssetType: "stock"
                ),
                privacyLevel: .performanceOnly,
                caption: "Crypto vs Stocks this quarter"
            )
        )
    }
    .padding()
    .background(Color.black)
}
