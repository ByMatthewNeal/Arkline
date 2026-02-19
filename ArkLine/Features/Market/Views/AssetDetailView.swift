import SwiftUI
import Charts
import Kingfisher

struct AssetDetailView: View {
    let asset: CryptoAsset
    @State private var selectedTimeframe: ChartTimeframe = .day
    @State private var isFavorite = false
    @State private var chartData: [PricePoint] = []
    @State private var isLoadingChart = false
    @State private var chartAnimationId = UUID()
    @State private var showShareCard = false
    @State private var shareIconImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var chartIsPositive: Bool {
        guard let first = chartData.first?.price, let last = chartData.last?.price else {
            return isPositive
        }
        return last >= first
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                DetailHeaderGradient(
                    primaryColor: Color(hex: "6366F1"),
                    secondaryColor: Color(hex: "8B5CF6")
                )

                VStack(spacing: 24) {
                    // Header
                    AssetDetailHeader(asset: asset, isFavorite: $isFavorite)

                    // Price
                    VStack(alignment: .leading, spacing: 8) {
                        Text(asset.currentPrice.asCurrency)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .contentTransition(.numericText())

                        HStack(spacing: 8) {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.caption)

                            Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                                .font(.subheadline)
                                .contentTransition(.numericText())
                        }
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Chart
                    VStack(spacing: 16) {
                        AssetPriceChart(
                            data: chartData,
                            isPositive: chartIsPositive,
                            isLoading: isLoadingChart
                        )
                        .frame(height: 200)
                        .id(chartAnimationId)
                        .transition(.opacity)

                        // Timeframe Selector
                        TimeframeSelector(selected: $selectedTimeframe)
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.3), value: chartAnimationId)

                    // Stats
                    AssetStatsSection(asset: asset)
                        .padding(.horizontal, 20)

                    // About
                    AboutSection(asset: asset)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .background(AppColors.background(colorScheme))
        .refreshable { await loadChart() }
        .navigationBarBackButtonHidden()
        .task { await loadChart() }
        .onChange(of: selectedTimeframe) { _, _ in
            Task { await loadChart() }
        }
        .onAppear {
            loadFavoriteState()
            Task { await AnalyticsService.shared.trackScreenView("coin_detail", coin: asset.id) }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showShareCard = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    Button(action: { toggleFavorite() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? Color(hex: "F59E0B") : AppColors.textPrimary(colorScheme))
                    }
                }
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardSheet(title: "Share \(asset.symbol.uppercased())", cardHeight: 420) { showBranding, showTimestamp in
                AssetShareCardContent(asset: asset, iconImage: shareIconImage)
            }
            .task {
                shareIconImage = await ShareCardIconLoader.loadIcon(from: asset.iconUrl)
            }
        }
        #endif
    }

    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            let chart = try await marketService.fetchCoinMarketChart(
                id: asset.id,
                currency: "usd",
                days: selectedTimeframe.days
            )
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = chart.priceHistory
            }
        } catch {
            // Fall back to 7d sparkline if available
            if let sparkline = asset.sparklinePrices, !sparkline.isEmpty {
                let now = Date()
                let interval = (7.0 * 24 * 3600) / Double(sparkline.count)
                withAnimation(.easeInOut(duration: 0.3)) {
                    chartAnimationId = UUID()
                    chartData = sparkline.enumerated().map { index, price in
                        PricePoint(
                            date: now.addingTimeInterval(-Double(sparkline.count - 1 - index) * interval),
                            price: price
                        )
                    }
                }
            }
        }
    }

    private func loadFavoriteState() {
        isFavorite = FavoritesStore.shared.isFavorite(asset.id)
    }

    private func toggleFavorite() {
        Haptics.medium()
        isFavorite.toggle()
        FavoritesStore.shared.setFavorite(asset.id, isFavorite: isFavorite)
    }
}

// MARK: - Chart Timeframe
enum ChartTimeframe: String, CaseIterable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "ALL"

    var days: Int {
        switch self {
        case .hour: return 1      // CoinGecko minimum is 1 day; gives 5-min intervals
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .all: return 1825    // ~5 years
        }
    }
}

// MARK: - Asset Price Chart
struct AssetPriceChart: View {
    let data: [PricePoint]
    let isPositive: Bool
    let isLoading: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var lineColor: Color {
        isPositive ? AppColors.success : AppColors.error
    }

    var body: some View {
        if isLoading && data.isEmpty {
            SkeletonChartView()
        } else if data.isEmpty {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground(colorScheme))
                .overlay(
                    Text("No chart data")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                )
        } else {
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(lineColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.3), lineColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(price.asCryptoPrice)
                                .font(.system(size: 9))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground(colorScheme))
            )
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(.gray)
                }
            }
        }
    }
}

// MARK: - Asset Detail Header
struct AssetDetailHeader: View {
    let asset: CryptoAsset
    @Binding var isFavorite: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            KFImage(URL(string: asset.iconUrl ?? ""))
                .resizable()
                .placeholder {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text(asset.symbol.prefix(1))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Rank Badge
            Text("#\(asset.marketCapRank ?? 0)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.divider(colorScheme))
                .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Timeframe Selector
struct TimeframeSelector: View {
    @Binding var selected: ChartTimeframe
    @Namespace private var timeframeAnimation
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ChartTimeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = timeframe
                    }
                }) {
                    Text(timeframe.rawValue)
                        .font(AppFonts.caption12Medium)
                        .fontWeight(selected == timeframe ? .semibold : .regular)
                        .foregroundColor(selected == timeframe ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selected == timeframe {
                                Capsule()
                                    .fill(AppColors.accent)
                                    .matchedGeometryEffect(id: "cryptoTimeframe", in: timeframeAnimation)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }
}

// MARK: - Asset Stats Section
struct AssetStatsSection: View {
    let asset: CryptoAsset
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                StatRow(label: "Market Cap", value: (asset.marketCap ?? 0).asCurrencyCompact)
                StatRow(label: "Market Cap Rank", value: "#\(asset.marketCapRank ?? 0)")
                StatRow(label: "24h High", value: (asset.high24h ?? 0).asCurrency)
                StatRow(label: "24h Low", value: (asset.low24h ?? 0).asCurrency)
                StatRow(label: "24h Volume", value: (asset.totalVolume ?? 0).asCurrencyCompact)
                StatRow(label: "Circulating Supply", value: "\((asset.circulatingSupply ?? 0).formattedCompact) \(asset.symbol.uppercased())")
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    let asset: CryptoAsset
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(asset.name)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Text(assetDescription)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(isExpanded ? nil : 3)

                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "Show Less" : "Read More")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private var assetDescription: String {
        switch asset.id {
        case "bitcoin":
            return "Bitcoin is a decentralized cryptocurrency originally described in a 2008 whitepaper by a person, or group of people, using the alias Satoshi Nakamoto. It was launched soon after, in January 2009. Bitcoin is a peer-to-peer online currency, meaning that all transactions happen directly between equal, independent network participants."
        case "ethereum":
            return "Ethereum is a decentralized open-source blockchain system that features its own cryptocurrency, Ether. ETH works as a platform for numerous other cryptocurrencies, as well as for the execution of decentralized smart contracts."
        default:
            return "A cryptocurrency asset available for trading on major exchanges worldwide."
        }
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(
            asset: CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: nil,
                marketCap: 1324500000000,
                marketCapRank: 1
            )
        )
    }
}
