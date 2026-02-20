import SwiftUI
import Kingfisher

// MARK: - Favorites Section (Home Widget)
struct FavoritesSection: View {
    let assets: [CryptoAsset]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: size == .compact ? 12 : 14))
                    .foregroundColor(AppColors.accent)

                Text("Favorites")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(textPrimary)

                Spacer()

                if !assets.isEmpty {
                    Text("\(assets.count)")
                        .font(.caption.bold())
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }

            if assets.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(assets) { asset in
                            NavigationLink(destination: AssetDetailView(asset: asset)) {
                                FavoriteAssetCard(
                                    asset: asset,
                                    isExpanded: size == .expanded,
                                    isCompact: size == .compact
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "star")
                .font(.system(size: 24))
                .foregroundColor(textPrimary.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Text("No favorites yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(textPrimary.opacity(0.6))

                Text("Browse Top Coins in the Market tab to add some")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.4))
            }
        }
        .padding(.vertical, size == .compact ? 4 : 8)
    }
}

// MARK: - Favorite Asset Card
struct FavoriteAssetCard: View {
    let asset: CryptoAsset
    var isExpanded: Bool = false
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardWidth: CGFloat {
        if isCompact { return 120 }
        if isExpanded { return 160 }
        return 140
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 10) {
            HStack {
                // Coin icon
                coinIcon
                Spacer()
                changeBadge
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(asset.symbol.uppercased())
                    .font(.system(size: isCompact ? 14 : (isExpanded ? 20 : 16), weight: .bold))
                    .foregroundColor(textPrimary)

                Text(asset.currentPrice.asCurrency)
                    .font(.system(size: isCompact ? 11 : (isExpanded ? 14 : 12)))
                    .foregroundColor(textPrimary.opacity(0.7))

                if isExpanded {
                    Text(asset.name)
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(isCompact ? 12 : (isExpanded ? 18 : 14))
        .frame(width: cardWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(asset.name), \(asset.currentPrice.asCurrency), \(isPositive ? "up" : "down") \(String(format: "%.1f", abs(asset.priceChangePercentage24h))) percent")
    }

    private var coinIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: isCompact ? 28 : (isExpanded ? 40 : 32),
                       height: isCompact ? 28 : (isExpanded ? 40 : 32))

            if let iconUrl = asset.iconUrl, let url = URL(string: iconUrl) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        Text(asset.symbol.prefix(1))
                            .font(.system(size: isCompact ? 10 : 12, weight: .bold))
                            .foregroundColor(AppColors.accent)
                    }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isCompact ? 18 : (isExpanded ? 28 : 22),
                           height: isCompact ? 18 : (isExpanded ? 28 : 22))
                    .clipShape(Circle())
            } else {
                Text(asset.symbol.prefix(1))
                    .font(.system(size: isCompact ? 10 : (isExpanded ? 16 : 12), weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    private var changeBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.system(size: isCompact ? 7 : (isExpanded ? 10 : 8), weight: .bold))
            Text("\(abs(asset.priceChangePercentage24h), specifier: "%.1f")%")
                .font(.system(size: isCompact ? 9 : (isExpanded ? 12 : 10), weight: .semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
    }
}
