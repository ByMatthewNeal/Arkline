import SwiftUI
import Charts
import Kingfisher

struct StockDetailView: View {
    let asset: StockAsset
    @State private var selectedTimeframe: StockChartTimeframe = .month
    @State private var chartData: [PricePoint] = []
    @State private var isLoadingChart = false
    @State private var chartAnimationId = UUID()
    @State private var profile: FMPCompanyProfile?
    @State private var isLoadingProfile = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var chartIsPositive: Bool {
        guard let first = chartData.first?.price, let last = chartData.last?.price else {
            return isPositive
        }
        return last >= first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                StockDetailHeader(asset: asset, profile: profile)

                // Price
                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.currentPrice.asCurrency)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: 8) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.caption)

                        Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                            .font(.subheadline)
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
                    StockTimeframeSelector(selected: $selectedTimeframe)
                }
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.3), value: chartAnimationId)

                // Stats
                StockStatsSection(asset: asset)
                    .padding(.horizontal, 20)

                // About
                if let profile = profile {
                    StockAboutSection(profile: profile)
                        .padding(.horizontal, 20)
                } else if isLoadingProfile {
                    SkeletonCard()
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .background(AppColors.background(colorScheme))
        .refreshable { await loadData() }
        .navigationBarBackButtonHidden()
        .task { await loadData() }
        .onChange(of: selectedTimeframe) { _, _ in
            Task { await loadChart() }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }
        }
        #endif
    }

    private func loadData() async {
        async let chartTask: () = loadChart()
        async let profileTask: () = loadProfile()
        _ = await (chartTask, profileTask)
    }

    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            let prices = try await FMPService.shared.fetchHistoricalPrices(
                symbol: asset.symbol,
                limit: selectedTimeframe.tradingDays
            )
            let newData = prices.compactMap { price in
                guard let date = price.dateValue else { return nil as PricePoint? }
                return PricePoint(date: date, price: price.close)
            }.sorted { $0.date < $1.date }
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = newData
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = []
            }
        }
    }

    private func loadProfile() async {
        guard profile == nil else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await FMPService.shared.fetchCompanyProfile(symbol: asset.symbol)
        } catch {
            // Profile is optional, fail silently
        }
    }
}

// MARK: - Stock Chart Timeframe
enum StockChartTimeframe: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "ALL"

    var tradingDays: Int {
        switch self {
        case .week: return 5
        case .month: return 22
        case .threeMonths: return 66
        case .year: return 252
        case .all: return 1260
        }
    }
}

// MARK: - Stock Timeframe Selector
struct StockTimeframeSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selected: StockChartTimeframe
    @Namespace private var timeframeAnimation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StockChartTimeframe.allCases, id: \.self) { timeframe in
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
                                    .matchedGeometryEffect(id: "stockTimeframe", in: timeframeAnimation)
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

// MARK: - Stock Detail Header
struct StockDetailHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: StockAsset
    let profile: FMPCompanyProfile?

    var body: some View {
        HStack(spacing: 12) {
            // Icon - use company logo if available
            if let imageUrl = profile?.image, let url = URL(string: imageUrl) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        stockIconPlaceholder
                    }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                stockIconPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Exchange Badge
            if let exchange = asset.exchange {
                Text(exchange)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
    }

    private var stockIconPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)

            Text(asset.symbol.prefix(1))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Stock Stats Section
struct StockStatsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: StockAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                if let marketCap = asset.marketCap, marketCap > 0 {
                    StatRow(label: "Market Cap", value: marketCap.asCurrencyCompact)
                }
                if let pe = asset.peRatio, pe > 0 {
                    StatRow(label: "P/E Ratio", value: String(format: "%.2f", pe))
                }
                if let volume = asset.volume, volume > 0 {
                    StatRow(label: "Volume", value: Double(volume).formattedCompact)
                }
                if let high = asset.high, high > 0 {
                    StatRow(label: "Day High", value: high.asCurrency)
                }
                if let low = asset.low, low > 0 {
                    StatRow(label: "Day Low", value: low.asCurrency)
                }
                if let high52 = asset.week52High, high52 > 0 {
                    StatRow(label: "52-Week High", value: high52.asCurrency)
                }
                if let low52 = asset.week52Low, low52 > 0 {
                    StatRow(label: "52-Week Low", value: low52.asCurrency)
                }
                if let prevClose = asset.previousClose, prevClose > 0 {
                    StatRow(label: "Previous Close", value: prevClose.asCurrency)
                }
                if let divYield = asset.dividendYield, divYield > 0 {
                    StatRow(label: "Dividend Yield", value: String(format: "%.2f%%", divYield))
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }
}

// MARK: - Stock About Section
struct StockAboutSection: View {
    @Environment(\.colorScheme) var colorScheme
    let profile: FMPCompanyProfile
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(profile.companyName)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                if let description = profile.description, !description.isEmpty {
                    Text(description)
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

                // Company details
                VStack(spacing: 8) {
                    if let sector = profile.sector, !sector.isEmpty {
                        companyDetailRow(label: "Sector", value: sector)
                    }
                    if let industry = profile.industry, !industry.isEmpty {
                        companyDetailRow(label: "Industry", value: industry)
                    }
                    if let ceo = profile.ceo, !ceo.isEmpty {
                        companyDetailRow(label: "CEO", value: ceo)
                    }
                    if let employees = profile.fullTimeEmployees, !employees.isEmpty {
                        companyDetailRow(label: "Employees", value: employees)
                    }
                    if let country = profile.country, !country.isEmpty {
                        companyDetailRow(label: "Country", value: country)
                    }
                    if let ipo = profile.ipoDate, !ipo.isEmpty {
                        companyDetailRow(label: "IPO Date", value: ipo)
                    }
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private func companyDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}
