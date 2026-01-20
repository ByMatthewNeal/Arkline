import SwiftUI

// MARK: - Holding Row (Full)
struct HoldingRow: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            CoinIconView(symbol: holding.symbol, size: 44)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.symbol.uppercased())
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(holding.name)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Value & P/L
            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentValue.asCurrency)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10))

                    Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: "%.2f")%")
                        .font(AppFonts.caption12)
                }
                .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Holding Row (Compact)
struct HoldingRowCompact: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding

    var body: some View {
        HStack(spacing: 12) {
            CoinIconView(symbol: holding.symbol, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol.uppercased())
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(holding.quantity, specifier: "%.4f") • \((holding.currentPrice ?? 0).asCurrency)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValue.asCurrency)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: "%.2f")%")
                    .font(AppFonts.caption12)
                    .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }
}

// MARK: - Coin Icon View
struct CoinIconView: View {
    @Environment(\.colorScheme) var colorScheme
    let symbol: String
    let size: CGFloat
    var iconUrl: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.fillSecondary(colorScheme))

            if let iconUrl = iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    symbolInitials
                }
                .frame(width: size * 0.6, height: size * 0.6)
            } else {
                symbolInitials
            }
        }
        .frame(width: size, height: size)
    }

    private var symbolInitials: some View {
        Text(symbol.prefix(2).uppercased())
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundColor(AppColors.accent)
    }
}

#Preview {
    VStack(spacing: 12) {
        HoldingRow(holding: PortfolioHolding(
            portfolioId: UUID(),
            assetType: "crypto",
            symbol: "BTC",
            name: "Bitcoin",
            quantity: 0.5,
            averageBuyPrice: 45000
        ).withLiveData(currentPrice: 67500, change24h: 2.5))

        HoldingRowCompact(holding: PortfolioHolding(
            portfolioId: UUID(),
            assetType: "crypto",
            symbol: "ETH",
            name: "Ethereum",
            quantity: 3.2,
            averageBuyPrice: 2800
        ).withLiveData(currentPrice: 3450, change24h: -1.2))
    }
    .padding()
    .background(AppColors.background(.dark))
}
