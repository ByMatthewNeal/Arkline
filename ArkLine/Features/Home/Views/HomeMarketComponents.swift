import SwiftUI

// MARK: - Glass Fear & Greed Card
struct GlassFearGreedCard: View {
    let index: FearGreedIndex
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 100
        case .standard: return 160
        case .expanded: return 200
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 8
        case .standard: return 12
        case .expanded: return 16
        }
    }

    var body: some View {
        VStack(spacing: size == .compact ? 10 : 16) {
            HStack {
                Text("Fear & Greed Index")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text(index.level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            // Gauge - Simplified monochromatic
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06),
                        lineWidth: strokeWidth
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
                    .rotationEffect(.degrees(0))

                // Value arc - simple blue gradient
                Circle()
                    .trim(from: 0.25, to: 0.25 + (0.5 * Double(index.value) / 100))
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.6), AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
                    .rotationEffect(.degrees(0))

                // Center value
                VStack(spacing: size == .compact ? 2 : 4) {
                    Text("\(index.value)")
                        .font(.system(size: size == .compact ? 28 : (size == .expanded ? 56 : 48), weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)

                    Text("/ 100")
                        .font(size == .compact ? .system(size: 10) : .caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
            .padding(.vertical, size == .compact ? 4 : 8)

            if size == .expanded {
                Text("Yesterday: \(max(0, index.value - 3)) • Last week: \(max(0, index.value - 8))")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Home Market Movers Widget
struct HomeMarketMoversWidget: View {
    let btcPrice: Double
    let ethPrice: Double
    let btcChange: Double
    let ethChange: Double
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedAsset: CryptoAsset?

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Create CryptoAsset objects from available data for technical analysis
    private var btcAsset: CryptoAsset {
        CryptoAsset(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            currentPrice: btcPrice,
            priceChange24h: btcPrice * (btcChange / 100),
            priceChangePercentage24h: btcChange,
            iconUrl: nil,
            marketCap: 1_320_000_000_000,
            marketCapRank: 1
        )
    }

    private var ethAsset: CryptoAsset {
        CryptoAsset(
            id: "ethereum",
            symbol: "ETH",
            name: "Ethereum",
            currentPrice: ethPrice,
            priceChange24h: ethPrice * (ethChange / 100),
            priceChangePercentage24h: ethChange,
            iconUrl: nil,
            marketCap: 400_000_000_000,
            marketCapRank: 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            Text("Core")
                .font(size == .compact ? .subheadline : .headline)
                .foregroundColor(textPrimary)

            if size == .compact {
                // Compact: horizontal row
                HStack(spacing: 8) {
                    Button {
                        selectedAsset = btcAsset
                    } label: {
                        CompactCoinCard(symbol: "BTC", price: btcPrice, change: btcChange, accentColor: AppColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedAsset = ethAsset
                    } label: {
                        CompactCoinCard(symbol: "ETH", price: ethPrice, change: ethChange, accentColor: AppColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        selectedAsset = btcAsset
                    } label: {
                        GlassCoinCard(
                            symbol: "BTC",
                            name: "Bitcoin",
                            price: btcPrice,
                            change: btcChange,
                            icon: "bitcoinsign.circle.fill",
                            accentColor: AppColors.accent,
                            isExpanded: size == .expanded
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedAsset = ethAsset
                    } label: {
                        GlassCoinCard(
                            symbol: "ETH",
                            name: "Ethereum",
                            price: ethPrice,
                            change: ethChange,
                            icon: "diamond.fill",
                            accentColor: AppColors.accent,
                            isExpanded: size == .expanded
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .sheet(item: $selectedAsset) { asset in
            AssetTechnicalDetailSheet(asset: asset)
        }
    }
}

// MARK: - Compact Coin Card
struct CompactCoinCard: View {
    let symbol: String
    let price: Double
    let change: Double
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(symbol.prefix(1))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textPrimary)

                HStack(spacing: 2) {
                    Text(price.asCurrency)
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.7))

                    Text("\(isPositive ? "+" : "")\(change, specifier: "%.1f")%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Glass Coin Card
struct GlassCoinCard: View {
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let icon: String
    let accentColor: Color
    var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 16 : 12) {
            HStack {
                // Coin icon with glow
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.3))
                        .blur(radius: isExpanded ? 10 : 8)
                        .frame(width: isExpanded ? 44 : 36, height: isExpanded ? 44 : 36)

                    Image(systemName: icon)
                        .font(.system(size: isExpanded ? 24 : 20))
                        .foregroundColor(accentColor)
                }

                Spacer()

                // Change badge
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: isExpanded ? 12 : 10, weight: .bold))
                    Text("\(abs(change), specifier: "%.1f")%")
                        .font(.system(size: isExpanded ? 14 : 12, weight: .semibold))
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.system(size: isExpanded ? 22 : 18, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(price.asCurrency)
                    .font(.system(size: isExpanded ? 16 : 14))
                    .foregroundColor(textPrimary.opacity(0.7))

                if isExpanded {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
        }
        .padding(isExpanded ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 20 : 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
