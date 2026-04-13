import SwiftUI
import Kingfisher

// MARK: - Favorites Section (Home Widget)
struct FavoritesSection: View {
    let assets: [CryptoAsset]
    var allCryptoAssets: [CryptoAsset] = []
    var size: WidgetSize = .standard
    @State private var showFavoritePicker = false
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
                    Button { showFavoritePicker = true } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            if assets.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(assets) { asset in
                            FavoriteAssetLink(asset: asset, size: size)
                            .accessibilityAddTraits(.isButton)
                            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
                            .contextMenu {
                                Button(role: .destructive) {
                                    Haptics.medium()
                                    FavoritesStore.shared.setFavorite(asset.id, isFavorite: false)
                                } label: {
                                    Label("Remove from Favorites", systemImage: "star.slash")
                                }
                            } preview: {
                                FavoriteAssetCard(
                                    asset: asset,
                                    isExpanded: size == .expanded,
                                    isCompact: size == .compact
                                )
                            }
                        }
                    }
                }
                .clipped()
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .arkShadow(ArkSpacing.Shadow.card)
        .sheet(isPresented: $showFavoritePicker) {
            FavoritePickerSheet(allCryptoAssets: allCryptoAssets)
        }
    }

    private var emptyState: some View {
        Button {
            Haptics.selection()
            showFavoritePicker = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Favorites")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(textPrimary)

                    Text("Pick coins and stocks to track here")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.3))
            }
            .padding(.vertical, size == .compact ? 4 : 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorite Asset Card
// MARK: - Favorite Asset Link (routes stocks vs crypto)
private struct FavoriteAssetLink: View {
    let asset: CryptoAsset
    let size: WidgetSize

    private var isStock: Bool { AssetRiskConfig.forStock(asset.symbol) != nil }

    private var stockAsset: StockAsset {
        StockAsset(
            id: asset.id,
            symbol: asset.symbol,
            name: asset.name,
            currentPrice: asset.currentPrice,
            priceChange24h: asset.priceChange24h,
            priceChangePercentage24h: asset.priceChangePercentage24h,
            iconUrl: asset.iconUrl
        )
    }

    var body: some View {
        Group {
            if isStock {
                NavigationLink(destination: StockDetailView(asset: stockAsset)) {
                    cardView
                }
            } else {
                NavigationLink(destination: AssetDetailView(asset: asset)) {
                    cardView
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(.isButton)
    }

    private var cardView: some View {
        FavoriteAssetCard(
            asset: asset,
            isExpanded: size == .expanded,
            isCompact: size == .compact
        )
    }
}

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

// MARK: - Favorite Picker Sheet

struct FavoritePickerSheet: View {
    let allCryptoAssets: [CryptoAsset]
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var displayCryptoAssets: [CryptoAsset] {
        let assets = allCryptoAssets
        if searchText.isEmpty { return assets }
        return assets.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var displayStockAssets: [AssetRiskConfig] {
        let stocks = AssetRiskConfig.stockConfigs
        if searchText.isEmpty { return stocks }
        return stocks.filter {
            $0.assetId.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var hasResults: Bool {
        !displayCryptoAssets.isEmpty || !displayStockAssets.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary.opacity(0.4))

                        TextField("Search coins or stocks...", text: $searchText)
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if !hasResults {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 30))
                                .foregroundColor(textPrimary.opacity(0.2))
                            Text("No results")
                                .font(.subheadline)
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                        .padding(.top, 40)
                        Spacer()
                    } else {
                        ScrollView {
                            // Stocks section
                            if !displayStockAssets.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("STOCKS")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textPrimary.opacity(0.4))
                                        .tracking(1)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)

                                    LazyVStack(spacing: 0) {
                                        ForEach(displayStockAssets, id: \.assetId) { config in
                                            FavoriteStockPickerRow(config: config)
                                        }
                                    }
                                    .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                                    .cornerRadius(16)
                                    .padding(.horizontal, 16)
                                }
                                .padding(.bottom, 16)
                            }

                            // Crypto section
                            if !displayCryptoAssets.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("CRYPTO")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(textPrimary.opacity(0.4))
                                        .tracking(1)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 8)

                                    LazyVStack(spacing: 0) {
                                        ForEach(displayCryptoAssets) { asset in
                                            FavoritePickerRow(asset: asset)
                                        }
                                    }
                                    .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                                    .cornerRadius(16)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

private struct FavoritePickerRow: View {
    let asset: CryptoAsset
    @Environment(\.colorScheme) var colorScheme
    @State private var isFavorite: Bool

    init(asset: CryptoAsset) {
        self.asset = asset
        self._isFavorite = State(initialValue: FavoritesStore.shared.isFavorite(asset.id))
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        Button {
            Haptics.medium()
            isFavorite.toggle()
            FavoritesStore.shared.setFavorite(asset.id, isFavorite: isFavorite)
        } label: {
            HStack(spacing: 12) {
                // Logo
                if let iconUrl = asset.iconUrl, let url = URL(string: iconUrl) {
                    KFImage(url)
                        .resizable()
                        .placeholder {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(asset.symbol.prefix(1))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.accent)
                                )
                        }
                        .fade(duration: 0.2)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(asset.symbol.prefix(1))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.accent)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.symbol.uppercased())
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(asset.name)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Spacer()

                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18))
                    .foregroundColor(isFavorite ? AppColors.accent : textPrimary.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)

        Divider().padding(.leading, 64)
    }
}

private struct FavoriteStockPickerRow: View {
    let config: AssetRiskConfig
    @Environment(\.colorScheme) var colorScheme
    @State private var isFavorite: Bool

    init(config: AssetRiskConfig) {
        self.config = config
        self._isFavorite = State(initialValue: FavoritesStore.shared.isFavorite(config.assetId))
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        Button {
            Haptics.medium()
            isFavorite.toggle()
            FavoritesStore.shared.setFavorite(config.assetId, isFavorite: isFavorite)
        } label: {
            HStack(spacing: 12) {
                if let logoURL = config.logoURL {
                    KFImage(logoURL)
                        .resizable()
                        .placeholder {
                            Circle()
                                .fill(Color(hex: "3B82F6").opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(config.assetId.prefix(1))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "3B82F6"))
                                )
                        }
                        .fade(duration: 0.2)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(hex: "3B82F6").opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(config.assetId.prefix(1))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(hex: "3B82F6"))
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.assetId)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(config.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Spacer()

                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 18))
                    .foregroundColor(isFavorite ? AppColors.accent : textPrimary.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)

        Divider().padding(.leading, 64)
    }
}
