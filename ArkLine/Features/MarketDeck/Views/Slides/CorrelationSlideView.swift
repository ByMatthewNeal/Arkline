import SwiftUI

struct CorrelationSlideView: View {
    let data: CorrelationSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            if let narrative = data.narrative, !narrative.isEmpty {
                Text(narrative)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(data.groups) { group in
                groupSection(group)
            }

            // Data context note
            Text("Prices reflect Friday close. Weekly change is Monday open → Friday close.")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, ArkSpacing.xs)
        }
    }

    @ViewBuilder
    private func groupSection(_ group: MarketGroupPerformance) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: groupIcon(group.group))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(groupColor(group.group))
                Text(group.group.uppercased())
                    .font(AppFonts.interFont(size: 11, weight: .semibold))
                    .foregroundColor(groupColor(group.group))
                    .tracking(1.2)

                Spacer()

                // Average direction indicator
                if let avg = averageChange(group.assets) {
                    HStack(spacing: 2) {
                        Image(systemName: avg >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.1f%%", avg))
                            .font(AppFonts.interFont(size: 10, weight: .semibold))
                    }
                    .foregroundColor(avg >= 0 ? AppColors.success : AppColors.error)
                }
            }

            // Asset tiles in a flowing layout
            let columns = [
                GridItem(.flexible(), spacing: ArkSpacing.xs),
                GridItem(.flexible(), spacing: ArkSpacing.xs)
            ]

            LazyVGrid(columns: columns, spacing: ArkSpacing.xs) {
                ForEach(group.assets) { asset in
                    assetTile(asset)
                }
            }
        }
    }

    @ViewBuilder
    private func assetTile(_ asset: CorrelationAsset) -> some View {
        let isPositive = (asset.weekChange ?? 0) >= 0

        HStack(spacing: ArkSpacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let price = asset.price {
                    Text(formatPrice(price, symbol: asset.symbol))
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let change = asset.weekChange {
                    Text(String(format: "%+.1f%%", change))
                        .font(AppFonts.interFont(size: 12, weight: .semibold))
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }

                if let signal = asset.signal {
                    Image(systemName: signalIcon(signal))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(signalColor(signal))
                }
            }
        }
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xs)
        .background(AppColors.textPrimary(colorScheme).opacity(0.04))
        .cornerRadius(ArkSpacing.Radius.sm)
    }

    // MARK: - Helpers

    private func averageChange(_ assets: [CorrelationAsset]) -> Double? {
        let changes = assets.compactMap(\.weekChange)
        guard !changes.isEmpty else { return nil }
        return changes.reduce(0, +) / Double(changes.count)
    }

    private func formatPrice(_ price: Double, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_US")

        switch symbol {
        case "BTC", "ETH":
            formatter.maximumFractionDigits = 0
        case "GOLD", "OIL", "SILVER", "COPPER":
            formatter.maximumFractionDigits = 2
        default:
            formatter.maximumFractionDigits = price >= 100 ? 0 : 2
        }

        return formatter.string(from: NSNumber(value: price)) ?? String(format: "$%.2f", price)
    }

    private func groupIcon(_ group: String) -> String {
        switch group.lowercased() {
        case "crypto": return "bitcoinsign.circle"
        case "equities": return "chart.line.uptrend.xyaxis"
        case "commodities": return "cube.fill"
        case "macro": return "gauge.with.dots.needle.50percent"
        default: return "circle"
        }
    }

    private func groupColor(_ group: String) -> Color {
        switch group.lowercased() {
        case "crypto": return AppColors.accent
        case "equities": return Color(hex: "84CC16")
        case "commodities": return AppColors.warning
        case "macro": return AppColors.textSecondary
        default: return AppColors.accent
        }
    }

    private func signalIcon(_ signal: String) -> String {
        switch signal.lowercased() {
        case "bullish": return "arrow.up.right"
        case "bearish": return "arrow.down.right"
        default: return "minus"
        }
    }

    private func signalColor(_ signal: String) -> Color {
        switch signal.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        default: return AppColors.textSecondary
        }
    }
}
