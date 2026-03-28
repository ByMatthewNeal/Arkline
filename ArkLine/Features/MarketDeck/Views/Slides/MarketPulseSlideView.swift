import SwiftUI

struct MarketPulseSlideView: View {
    let data: MarketPulseSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    /// Show only the big four: BTC, ETH, SOL, BNB
    private var topAssets: [AssetWeeklyData] {
        let priority = ["BTC", "ETH", "SOL", "BNB"]
        return priority.compactMap { symbol in
            data.assets.first { $0.symbol == symbol }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(topAssets) { asset in
                    assetTile(asset)
                }
            }
        }
    }

    @ViewBuilder
    private func assetTile(_ asset: AssetWeeklyData) -> some View {
        let change = asset.weekChange ?? 0
        let isPositive = change >= 0

        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text(asset.symbol)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text(String(format: "%+.1f%%", change))
                    .font(AppFonts.interFont(size: 11, weight: .semibold))
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                    .padding(.horizontal, ArkSpacing.xs)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            (isPositive ? AppColors.success : AppColors.error).opacity(0.15)
                        )
                    )
            }

            Text((asset.weekClose ?? 0).asCurrency)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            if let sparkline = asset.sparkline, sparkline.count >= 2 {
                SparklineChart(
                    data: sparkline,
                    isPositive: isPositive,
                    lineWidth: 1.5
                )
                .frame(height: 30)
            }
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }
}
