import SwiftUI

// MARK: - Favorites Section
struct FavoritesSection: View {
    let assets: [CryptoAsset]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardWidth: CGFloat {
        switch size {
        case .compact: return 90
        case .standard: return 120
        case .expanded: return 150
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                Text("Favorites")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Button(action: { }) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: size == .compact ? 8 : 12) {
                    ForEach(assets) { asset in
                        GlassFavoriteCard(asset: asset, size: size)
                            .frame(width: cardWidth)
                    }
                }
            }
        }
    }
}

// MARK: - Glass Favorite Card
struct GlassFavoriteCard: View {
    let asset: CryptoAsset
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var symbolFontSize: CGFloat {
        switch size {
        case .compact: return 11
        case .standard: return 14
        case .expanded: return 16
        }
    }

    private var priceFontSize: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 16
        case .expanded: return 18
        }
    }

    private var changeFontSize: CGFloat {
        switch size {
        case .compact: return 10
        case .standard: return 12
        case .expanded: return 13
        }
    }

    private var cardPadding: CGFloat {
        switch size {
        case .compact: return 10
        case .standard: return 14
        case .expanded: return 16
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 6 : 12) {
            if size == .compact {
                // Compact: stacked layout
                Text(asset.symbol.uppercased())
                    .font(.system(size: symbolFontSize, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(asset.currentPrice.asCurrency)
                    .font(.system(size: priceFontSize, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.8))

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.1f")%")
                    .font(.system(size: changeFontSize, weight: .semibold))
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            } else {
                // Standard/Expanded: original layout
                HStack {
                    Text(asset.symbol.uppercased())
                        .font(.system(size: symbolFontSize, weight: .bold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.1f")%")
                        .font(.system(size: changeFontSize, weight: .semibold))
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }

                Text(asset.currentPrice.asCurrency)
                    .font(.system(size: priceFontSize, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.8))

                if size == .expanded {
                    // Add asset name for expanded view
                    Text(asset.name)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
