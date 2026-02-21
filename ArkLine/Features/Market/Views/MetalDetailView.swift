import SwiftUI
import Charts

struct MetalDetailView: View {
    let asset: MetalAsset
    @State private var selectedTimeframe: StockChartTimeframe = .month
    @State private var chartData: [PricePoint] = []
    @State private var isLoadingChart = false
    @State private var chartAnimationId = UUID()
    @State private var week52High: Double?
    @State private var week52Low: Double?
    @State private var technicalAnalysis: TechnicalAnalysis?
    @State private var isLoadingTA = false
    @State private var multiTimeframeTrends: [AnalysisTimeframe: TrendAnalysis] = [:]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var chartIsPositive: Bool {
        guard let first = chartData.first?.price, let last = chartData.last?.price else {
            return isPositive
        }
        return last >= first
    }

    /// FMP commodity futures symbol for historical chart data
    private var futuresSymbol: String {
        switch asset.symbol.uppercased() {
        case "XAU": return "GCUSD"
        case "XAG": return "SIUSD"
        case "XPT": return "PLUSD"
        case "XPD": return "PAUSD"
        default: return "GCUSD"
        }
    }

    private var metalGradientColors: (Color, Color) {
        switch asset.symbol.uppercased() {
        case "XAU": return (Color(hex: "F59E0B"), Color(hex: "D97706"))
        case "XAG": return (Color(hex: "94A3B8"), Color(hex: "64748B"))
        case "XPT": return (Color(hex: "E2E8F0"), Color(hex: "94A3B8"))
        case "XPD": return (Color(hex: "A78BFA"), Color(hex: "7C3AED"))
        default: return (Color(hex: "F59E0B"), Color(hex: "D97706"))
        }
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                DetailHeaderGradient(
                    primaryColor: metalGradientColors.0,
                    secondaryColor: metalGradientColors.1
                )

                VStack(spacing: 24) {
                    // Header
                    MetalDetailHeader(asset: asset)

                    // Price
                    VStack(alignment: .leading, spacing: 8) {
                    Text(asset.currentPrice.asCurrency)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .contentTransition(.numericText())

                    HStack(spacing: 8) {
                        if asset.priceChange24h != 0 {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.caption)

                            Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                                .font(.subheadline)
                                .contentTransition(.numericText())
                        } else {
                            Text("Price per \(asset.unit)")
                                .font(.subheadline)
                        }
                    }
                    .foregroundColor(asset.priceChange24h != 0 ? (isPositive ? AppColors.success : AppColors.error) : AppColors.textSecondary)
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

                    StockTimeframeSelector(selected: $selectedTimeframe)

                    // Futures data note
                    Text("Chart: \(futuresSymbol) futures data")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.3), value: chartAnimationId)

                // Technical Analysis
                if technicalAnalysis != nil || isLoadingTA {
                    MetalTechnicalAnalysisSection(
                        analysis: technicalAnalysis,
                        multiTimeframeTrends: multiTimeframeTrends,
                        isLoading: isLoadingTA,
                        colorScheme: colorScheme
                    )
                    .padding(.horizontal, 20)
                }

                // Key Levels
                if week52High != nil || week52Low != nil {
                    MetalKeyLevelsSection(
                        asset: asset,
                        week52High: week52High,
                        week52Low: week52Low
                    )
                    .padding(.horizontal, 20)
                }

                // Stats
                MetalStatsSection(asset: asset)
                    .padding(.horizontal, 20)

                // Market Context
                MetalMarketContextSection(asset: asset)
                    .padding(.horizontal, 20)

                // About
                MetalAboutSection(asset: asset)
                    .padding(.horizontal, 20)

                // Trading Insight
                MetalTradingInsightSection(asset: asset)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationBarBackButtonHidden()
        .enableSwipeBack()
        .task {
            async let chartTask: () = loadChart()
            async let techTask: () = loadTechnicalAnalysis()
            _ = await (chartTask, techTask)
        }
        .refreshable {
            async let chartTask: () = loadChart()
            async let techTask: () = loadTechnicalAnalysis()
            _ = await (chartTask, techTask)
        }
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

    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            let prices = try await FMPService.shared.fetchHistoricalPrices(
                symbol: futuresSymbol,
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

            // Calculate 52-week high/low from 1Y data
            if selectedTimeframe == .year || week52High == nil {
                let yearPrices = try await FMPService.shared.fetchHistoricalPrices(
                    symbol: futuresSymbol,
                    limit: 252
                )
                if !yearPrices.isEmpty {
                    week52High = yearPrices.map(\.high).max()
                    week52Low = yearPrices.map(\.low).min()
                }
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = []
            }
        }
    }

    private func loadTechnicalAnalysis() async {
        guard ["XAU", "XAG"].contains(asset.symbol.uppercased()) else { return }

        isLoadingTA = true
        defer { isLoadingTA = false }

        do {
            let analysis = try await MetalTechnicalAnalysisService.shared
                .fetchTechnicalAnalysis(
                    metalSymbol: asset.symbol,
                    currentPrice: asset.currentPrice
                )
            technicalAnalysis = analysis

            // Derive multi-timeframe trends
            let dailyTrend = analysis.trend
            let weeklyTrend = deriveWeeklyTrend(from: dailyTrend, sma: analysis.smaAnalysis)
            let monthlyTrend = deriveMonthlyTrend(from: dailyTrend, sma: analysis.smaAnalysis)
            multiTimeframeTrends = [
                .daily: dailyTrend,
                .weekly: weeklyTrend,
                .monthly: monthlyTrend
            ]
        } catch {
            logWarning("Metal TA error: \(error.localizedDescription)", category: .network)
        }
    }

    private func deriveWeeklyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        let direction: AssetTrendDirection
        if sma.above50SMA && sma.above200SMA {
            direction = daily.direction == .strongUptrend ? .strongUptrend : .uptrend
        } else if !sma.above50SMA && !sma.above200SMA {
            direction = daily.direction == .strongDowntrend ? .strongDowntrend : .downtrend
        } else {
            direction = .sideways
        }
        return TrendAnalysis(
            direction: direction,
            strength: daily.strength,
            daysInTrend: daily.daysInTrend * 7,
            higherHighs: daily.higherHighs,
            higherLows: daily.higherLows
        )
    }

    private func deriveMonthlyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        let direction: AssetTrendDirection
        if sma.above200SMA && sma.goldenCross { direction = .strongUptrend }
        else if sma.above200SMA { direction = .uptrend }
        else if !sma.above200SMA && sma.deathCross { direction = .strongDowntrend }
        else if !sma.above200SMA { direction = .downtrend }
        else { direction = .sideways }

        return TrendAnalysis(
            direction: direction,
            strength: sma.above200SMA == sma.above50SMA ? .strong : .moderate,
            daysInTrend: daily.daysInTrend * 30,
            higherHighs: sma.above200SMA,
            higherLows: sma.above200SMA
        )
    }
}

// MARK: - Metal Technical Analysis Section
struct MetalTechnicalAnalysisSection: View {
    let analysis: TechnicalAnalysis?
    let multiTimeframeTrends: [AnalysisTimeframe: TrendAnalysis]
    let isLoading: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing trend data...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 24)
            } else if let analysis = analysis {
                // Trend + Valuation gauges
                DualScoreCard(
                    trendScore: analysis.trendScore,
                    opportunityScore: analysis.opportunityScore,
                    colorScheme: colorScheme
                )

                // Market Outlook (short/long term)
                MarketOutlookCard(
                    sentiment: analysis.sentiment,
                    colorScheme: colorScheme
                )

                // RSI gauge
                RSIIndicatorCard(
                    rsi: analysis.rsi,
                    colorScheme: colorScheme
                )

                // Multi-timeframe trend overview
                MultiTimeframeTrendCard(
                    trends: multiTimeframeTrends,
                    isLoading: false,
                    colorScheme: colorScheme
                )

                // Key Levels (SMA positions)
                KeyLevelsCard(
                    sma: analysis.smaAnalysis,
                    currentPrice: analysis.currentPrice,
                    colorScheme: colorScheme
                )

                // Price Position (Bollinger Bands)
                PricePositionCard(
                    bollinger: analysis.bollingerBands.daily,
                    colorScheme: colorScheme
                )
            }
        }
    }
}

// MARK: - Metal Detail Header
struct MetalDetailHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColors(for: asset.symbol),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(metalElementSymbol(for: asset.symbol))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

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

            // Unit Badge
            Text("per \(asset.unit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }

    private func metalElementSymbol(for symbol: String) -> String {
        switch symbol.uppercased() {
        case "XAU": return "Au"
        case "XAG": return "Ag"
        case "XPT": return "Pt"
        case "XPD": return "Pd"
        default: return String(symbol.prefix(2))
        }
    }

    private func iconColors(for symbol: String) -> [Color] {
        switch symbol.uppercased() {
        case "XAU": return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        case "XAG": return [Color(hex: "94A3B8"), Color(hex: "64748B")]
        case "XPT": return [Color(hex: "E2E8F0"), Color(hex: "94A3B8")]
        case "XPD": return [Color(hex: "A78BFA"), Color(hex: "7C3AED")]
        default: return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        }
    }
}

// MARK: - Key Levels Section
struct MetalKeyLevelsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset
    let week52High: Double?
    let week52Low: Double?

    private var pricePosition: Double? {
        guard let high = week52High, let low = week52Low, high > low else { return nil }
        return (asset.currentPrice - low) / (high - low)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Levels")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                if let high = week52High {
                    StatRow(label: "52-Week High", value: high.asCurrency)
                }
                if let low = week52Low {
                    StatRow(label: "52-Week Low", value: low.asCurrency)
                }
                if let position = pricePosition {
                    HStack {
                        Text("52-Week Position")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.0f%%", position * 100))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    // Visual position bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.textSecondary.opacity(0.2))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.error, AppColors.warning, AppColors.success],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * min(max(position, 0), 1), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }
}

// MARK: - Metal Stats Section
struct MetalStatsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                StatRow(label: "Price per \(asset.unit)", value: asset.currentPrice.asCurrency)
                StatRow(label: "Currency", value: asset.currency)
                if asset.priceChange24h != 0 {
                    StatRow(label: "24h Change", value: String(format: "%+.2f%%", asset.priceChangePercentage24h))
                }
                if let timestamp = asset.timestamp {
                    StatRow(label: "Last Updated", value: timestamp.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }
}

// MARK: - Market Context Section
struct MetalMarketContextSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Market Context")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Text(marketContext)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private var marketContext: String {
        switch asset.symbol.uppercased() {
        case "XAU":
            return """
            Gold typically moves inversely to the US Dollar (DXY). When the dollar weakens, gold tends to rise as it becomes cheaper for foreign buyers.

            Rising gold prices often signal a risk-off environment — investors move capital from stocks and crypto into safe-haven assets. For crypto traders, sustained gold rallies can indicate macro uncertainty that may pressure risk assets like Bitcoin.

            Gold also responds strongly to real interest rates. When inflation outpaces bond yields, gold becomes more attractive as an inflation hedge.
            """
        case "XAG":
            return """
            Silver has a dual nature — it's both a precious metal (store of value) and an industrial commodity. About 50% of silver demand comes from industrial uses including electronics, solar panels, and EVs.

            Silver tends to be more volatile than gold, often amplifying gold's moves by 2-3x. The gold/silver ratio (currently gold price ÷ silver price) is a key indicator — ratios above 80 historically suggest silver is undervalued relative to gold.

            For crypto traders, silver's industrial demand ties it to economic growth expectations, making it a useful gauge of broader economic sentiment.
            """
        default:
            return "Precious metals serve as alternative stores of value and inflation hedges. Their prices are influenced by interest rates, currency movements, and geopolitical events."
        }
    }
}

// MARK: - Metal About Section
struct MetalAboutSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(asset.name)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Text(metalDescription)
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

    private var metalDescription: String {
        switch asset.symbol.uppercased() {
        case "XAU":
            return "Gold is a precious metal that has been used as a store of value for thousands of years. It is widely considered a safe-haven asset during times of economic uncertainty and inflation. Central banks hold gold as part of their reserves, and it remains a key component of diversified investment portfolios."
        case "XAG":
            return "Silver is both a precious metal and an industrial commodity. It has the highest electrical conductivity of any element, making it essential in electronics, solar panels, and medical applications. Silver often tracks gold prices but with higher volatility, offering leveraged exposure to precious metals."
        case "XPT":
            return "Platinum is a rare precious metal primarily used in catalytic converters for vehicles, jewelry, and industrial processes. It is approximately 30 times rarer than gold. Platinum prices are heavily influenced by automotive industry demand and mining supply from South Africa and Russia."
        case "XPD":
            return "Palladium is a rare precious metal used primarily in catalytic converters for gasoline-powered vehicles. It has seen significant price increases due to tightening emissions regulations worldwide. Russia and South Africa are the largest producers, making supply sensitive to geopolitical events."
        default:
            return "A precious metal commodity traded on global markets."
        }
    }
}

// MARK: - Trading Insight Section
struct MetalTradingInsightSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trading Insight")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Text(tradingInsight)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private var tradingInsight: String {
        switch asset.symbol.uppercased() {
        case "XAU":
            return """
            - Gold breaking all-time highs often signals macro regime changes
            - Central bank buying has been a major demand driver since 2022
            - Gold and Bitcoin sometimes compete as "digital gold" vs physical gold
            - Watch for divergence between gold and real yields (TIPS) for trade signals
            - Gold tends to outperform in the first year of Fed rate-cutting cycles
            """
        case "XAG":
            return """
            - Silver's higher volatility makes it attractive for momentum traders
            - The gold/silver ratio above 80 historically signals silver is cheap
            - Solar panel demand is a growing structural tailwind for silver
            - Silver often lags gold in early rallies then catches up aggressively
            - Physical silver supply is relatively constrained vs demand growth
            """
        default:
            return """
            - Precious metals provide portfolio diversification against equity risk
            - Monitor central bank policy and real interest rates for direction
            - Geopolitical events can cause rapid price spikes
            """
        }
    }
}
