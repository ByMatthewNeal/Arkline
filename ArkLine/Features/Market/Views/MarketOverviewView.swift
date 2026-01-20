import SwiftUI

struct MarketOverviewView: View {
    @State private var viewModel = MarketViewModel()
    @State private var sentimentViewModel = SentimentViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Tab Selector
                    MarketTabSelector(selectedTab: $viewModel.selectedTab)
                        .padding(.horizontal, 20)

                    // Content based on selected tab
                    switch viewModel.selectedTab {
                    case .overview:
                        OverviewContent(viewModel: viewModel, sentimentViewModel: sentimentViewModel)
                    case .sentiment:
                        SentimentContent(viewModel: sentimentViewModel)
                    case .assets:
                        AssetsContent(viewModel: viewModel)
                    case .news:
                        NewsContent(viewModel: viewModel)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .background(Color(hex: "0F0F0F"))
            .navigationTitle("Market")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white)
                    }
                }
            }
            #endif
            .refreshable {
                await viewModel.refresh()
                await sentimentViewModel.refresh()
            }
        }
    }
}

// MARK: - Market Tab Selector
struct MarketTabSelector: View {
    @Binding var selectedTab: MarketTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MarketTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : Color(hex: "A1A1AA"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color(hex: "6366F1") : Color.clear)
                        .cornerRadius(20)
                }
            }
        }
        .padding(4)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(24)
    }
}

// MARK: - Overview Content
struct OverviewContent: View {
    @Bindable var viewModel: MarketViewModel
    @Bindable var sentimentViewModel: SentimentViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Market Stats
            MarketStatsCard(
                marketCap: viewModel.totalMarketCap,
                volume: viewModel.total24hVolume,
                btcDominance: viewModel.btcDominance,
                change: viewModel.marketCapChange24h
            )
            .padding(.horizontal, 20)

            // Fear & Greed Quick View
            if let fearGreed = sentimentViewModel.fearGreedIndex {
                NavigationLink(destination: FearGreedDetailView()) {
                    CompactFearGreedCard(index: fearGreed)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            }

            // Trending Assets
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Trending", action: { viewModel.selectedTab = .assets })
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.trendingAssets) { asset in
                            TrendingAssetCard(asset: asset)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Top Gainers
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Top Gainers", action: nil)
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(viewModel.topGainers.prefix(3)) { asset in
                        AssetRowView(asset: asset)
                    }
                }
                .padding(.horizontal, 20)
            }

            // Top Losers
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Top Losers", action: nil)
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(viewModel.topLosers.prefix(3)) { asset in
                        AssetRowView(asset: asset)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Sentiment Content
struct SentimentContent: View {
    @Bindable var viewModel: SentimentViewModel

    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(viewModel.sentimentCards) { card in
                    NavigationLink(destination: sentimentDetailView(for: card.id)) {
                        SentimentCard(data: card)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func sentimentDetailView(for id: String) -> some View {
        switch id {
        case "fear_greed":
            FearGreedDetailView()
        case "btc_dominance":
            BTCDominanceDetailView()
        case "etf_flow":
            ETFNetFlowDetailView()
        case "funding_rate":
            FundingRateDetailView()
        case "liquidations":
            LiquidationDetailView()
        case "altcoin_season":
            AltcoinSeasonDetailView()
        default:
            EmptyView()
        }
    }
}

// MARK: - Assets Content
struct AssetsContent: View {
    @Bindable var viewModel: MarketViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            SearchBar(text: $viewModel.searchText, placeholder: "Search assets...")
                .padding(.horizontal, 20)

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AssetCategoryFilter.allCases, id: \.self) { category in
                        CategoryChip(
                            title: category.rawValue,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Asset List
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredAssets) { asset in
                    NavigationLink(destination: AssetDetailView(asset: asset)) {
                        AssetRowView(asset: asset)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - News Content
struct NewsContent: View {
    @Bindable var viewModel: MarketViewModel

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.newsItems) { news in
                NewsCard(news: news)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Supporting Views
struct MarketStatsCard: View {
    let marketCap: Double
    let volume: Double
    let btcDominance: Double
    let change: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                StatColumn(label: "Market Cap", value: marketCap.asCurrencyCompact, change: change)
                Divider().frame(height: 40).background(Color(hex: "2A2A2A"))
                StatColumn(label: "24h Volume", value: volume.asCurrencyCompact, change: nil)
                Divider().frame(height: 40).background(Color(hex: "2A2A2A"))
                StatColumn(label: "BTC Dom.", value: String(format: "%.1f%%", btcDominance), change: nil)
            }
        }
        .padding(16)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    let change: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(Color(hex: "A1A1AA"))

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            if let change = change {
                Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")%")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? Color(hex: "22C55E") : Color(hex: "EF4444"))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactFearGreedCard: View {
    let index: FearGreedIndex

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fear & Greed Index")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "A1A1AA"))

                HStack(spacing: 8) {
                    Text("\(index.value)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text(index.level.rawValue)
                        .font(.caption)
                        .foregroundColor(Color(hex: index.level.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: index.level.color).opacity(0.2))
                        .cornerRadius(8)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Color(hex: "A1A1AA"))
        }
        .padding(16)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(12)
    }
}

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }
        }
    }
}

struct TrendingAssetCard: View {
    let asset: CryptoAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asset.symbol.uppercased())
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                    .font(.caption)
                    .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
            }

            Text(asset.currentPrice.asCurrency)
                .font(.subheadline)
                .foregroundColor(Color(hex: "A1A1AA"))
        }
        .padding(16)
        .frame(width: 140)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(12)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(hex: "A1A1AA"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "6366F1") : Color(hex: "1F1F1F"))
                .cornerRadius(20)
        }
    }
}

// MARK: - Placeholder Detail Views
struct BTCDominanceDetailView: View {
    var body: some View {
        Text("BTC Dominance Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

struct ETFNetFlowDetailView: View {
    var body: some View {
        Text("ETF Net Flow Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

struct FundingRateDetailView: View {
    var body: some View {
        Text("Funding Rate Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

struct LiquidationDetailView: View {
    var body: some View {
        Text("Liquidation Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

struct AltcoinSeasonDetailView: View {
    var body: some View {
        Text("Altcoin Season Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

#Preview {
    MarketOverviewView()
}
