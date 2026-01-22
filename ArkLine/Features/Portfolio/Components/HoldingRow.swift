import SwiftUI

// MARK: - Holding Row (Full)
struct HoldingRow: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding

    private var isRealEstate: Bool {
        holding.assetType == Constants.AssetType.realEstate.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            if isRealEstate {
                RealEstateIconView(size: 44)
            } else {
                CoinIconView(symbol: holding.symbol, size: 44)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(isRealEstate ? holding.symbol : holding.symbol.uppercased())
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Text(holding.name)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Value & P/L
            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentValue.asCurrency)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if isRealEstate {
                    // Show total P/L for real estate instead of 24h change
                    HStack(spacing: 4) {
                        Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))

                        Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: "%.1f")%")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))

                        Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: "%.2f")%")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
                }
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

    private var isRealEstate: Bool {
        holding.assetType == Constants.AssetType.realEstate.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            if isRealEstate {
                RealEstateIconView(size: 36)
            } else {
                CoinIconView(symbol: holding.symbol, size: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isRealEstate ? holding.symbol : holding.symbol.uppercased())
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                if isRealEstate {
                    Text(holding.name)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("\(holding.quantity, specifier: "%.4f") • \((holding.currentPrice ?? 0).asCurrency)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValue.asCurrency)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: isRealEstate ? "%.1f" : "%.2f")%")
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

// MARK: - Real Estate Icon View
struct RealEstateIconView: View {
    @Environment(\.colorScheme) var colorScheme
    let size: CGFloat

    // Real estate blue color from allocation
    private let realEstateColor = Color(hex: "3B82F6")

    var body: some View {
        ZStack {
            Circle()
                .fill(realEstateColor.opacity(0.15))

            Image(systemName: "house.fill")
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(realEstateColor)
        }
        .frame(width: size, height: size)
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
