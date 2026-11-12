import SwiftUI
import Kingfisher
import Charts

// MARK: - Asset Technical Detail Sheet
/// Shows detailed technical analysis for an asset including trend, SMAs, and Bollinger Bands
struct AssetTechnicalDetailSheet: View {
    let asset: CryptoAsset
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var technicalAnalysis: TechnicalAnalysis?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Multi-timeframe trend data
    @State private var multiTimeframeTrends: [AnalysisTimeframe: TrendAnalysis] = [:]
    @State private var isLoadingMultiTimeframe = false

    // Share functionality
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private let technicalAnalysisService = ServiceContainer.shared.technicalAnalysisService

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            Group {
                ScrollView {
                    shareableContent
                }
                .background(AppColors.background(colorScheme).ignoresSafeArea())
            }
            .navigationTitle(asset.symbol.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appState.isPro || asset.symbol.uppercased() == "BTC" {
                        Button {
                            captureAndShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(technicalAnalysis == nil)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if appState.isPro || asset.symbol.uppercased() == "BTC" {
                    await fetchTechnicalAnalysis()
                    await fetchMultiTimeframeTrends()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - Shareable Content
    private var shareableContent: some View {
        VStack(spacing: ArkSpacing.xl) {
            // Asset header
            AssetHeaderSection(asset: asset, colorScheme: colorScheme)

                    if isLoading {
                        // Loading state
                        VStack(spacing: ArkSpacing.md) {
                            ProgressView()
                            Text("Analyzing \(asset.name)...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Calculating RSI, SMAs, Bollinger Bands & trend")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        }
                        .padding(.top, 40)
                    } else if let error = errorMessage {
                        // Error state
                        VStack(spacing: ArkSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.warning)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await fetchTechnicalAnalysis() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 40)
                    } else if let analysis = technicalAnalysis {
                        // Investment Insight - dynamic summary + educational guide
                        InvestmentInsightCard(analysis: analysis, colorScheme: colorScheme)

                        // Hero: Dual Scores - Trend direction + Entry opportunity
                        DualScoreCard(trendScore: analysis.trendScore, opportunityScore: analysis.opportunityScore, colorScheme: colorScheme)

                        // Market Outlook - Short term & Long term sentiment
                        MarketOutlookCard(sentiment: analysis.sentiment, colorScheme: colorScheme)

                        // RSI Indicator
                        RSIIndicatorCard(rsi: analysis.rsi, colorScheme: colorScheme)

                        // Multi-timeframe trend summary (clean, minimal)
                        MultiTimeframeTrendCard(
                            trends: multiTimeframeTrends,
                            isLoading: isLoadingMultiTimeframe,
                            colorScheme: colorScheme
                        )

                        // Bull Market Support Bands
                        BullMarketBandsCard(bands: analysis.bullMarketBands, colorScheme: colorScheme)

                        // Key Levels - simplified SMA with signal
                        KeyLevelsCard(sma: analysis.smaAnalysis, currentPrice: analysis.currentPrice, colorScheme: colorScheme)

                        // Price Position - simplified Bollinger
                        PricePositionCard(bollinger: analysis.bollingerBands.daily, colorScheme: colorScheme)

                        // Support & Resistance - algorithmic levels on a mini chart.
                        // v1: major crypto only, where candle history is deepest.
                        if ["BTC", "ETH", "SOL"].contains(asset.symbol.uppercased()),
                           let levels = analysis.keyLevels, levels.hasLevels {
                            SupportResistanceCard(levels: levels, colorScheme: colorScheme)
                        }
                    }

                    Spacer(minLength: ArkSpacing.xxl)
                }
                .padding(.horizontal)
    }

    // MARK: - Share Methods

    private func captureAndShare() {
        let renderer = ImageRenderer(content:
            shareableContent
                .frame(width: UIScreen.main.bounds.width)
                .padding(.vertical, ArkSpacing.lg)
                .background(AppColors.background(colorScheme))
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }

    // MARK: - Private Methods

    private func fetchTechnicalAnalysis() async {
        isLoading = true
        errorMessage = nil

        do {
            let symbol = TaapiSymbolMapper.symbol(for: asset)
            let exchange = TaapiSymbolMapper.exchange(for: asset)

            let analysis = try await withTimeout(seconds: 10) { [technicalAnalysisService] in
                try await technicalAnalysisService.fetchTechnicalAnalysis(
                    symbol: symbol,
                    exchange: exchange,
                    interval: .daily
                )
            }

            // Archive technicals (fire-and-forget)
            Task { await MarketDataCollector.shared.recordTechnicals(analysis) }

            await MainActor.run {
                self.technicalAnalysis = analysis
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                // Fallback to generated data on error
                self.technicalAnalysis = TechnicalAnalysisGenerator.generate(for: asset)
                self.isLoading = false
            }
        }
    }

    private func fetchMultiTimeframeTrends() async {
        // Use the already-fetched daily analysis to derive all trends
        // This avoids extra API calls since weekly/monthly trends are generally
        // consistent with daily in strong trends
        guard let analysis = technicalAnalysis else {
            await MainActor.run {
                self.isLoadingMultiTimeframe = false
            }
            return
        }

        let dailyTrend = analysis.trend

        // Derive weekly and monthly trends from daily
        // In strong trends, all timeframes usually align
        // In weaker trends, longer timeframes may be more neutral
        let weeklyTrend = deriveWeeklyTrend(from: dailyTrend, sma: analysis.smaAnalysis)
        let monthlyTrend = deriveMonthlyTrend(from: dailyTrend, sma: analysis.smaAnalysis)

        await MainActor.run {
            self.multiTimeframeTrends = [
                .daily: dailyTrend,
                .weekly: weeklyTrend,
                .monthly: monthlyTrend
            ]
            self.isLoadingMultiTimeframe = false
        }
    }

    /// Derive weekly trend from daily analysis (slightly more conservative)
    private func deriveWeeklyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        // Weekly trend considers 50 and 200 SMA more heavily
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

    /// Derive monthly trend from daily analysis (most conservative, uses 200 SMA)
    private func deriveMonthlyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        // Monthly trend primarily based on 200 SMA
        let direction: AssetTrendDirection
        if sma.above200SMA && sma.goldenCross {
            direction = .strongUptrend
        } else if sma.above200SMA {
            direction = .uptrend
        } else if !sma.above200SMA && sma.deathCross {
            direction = .strongDowntrend
        } else if !sma.above200SMA {
            direction = .downtrend
        } else {
            direction = .sideways
        }

        return TrendAnalysis(
            direction: direction,
            strength: sma.above200SMA == sma.above50SMA ? .strong : .moderate,
            daysInTrend: daily.daysInTrend * 30,
            higherHighs: sma.above200SMA,
            higherLows: sma.above200SMA
        )
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Investment Insight Card
private struct InvestmentInsightCard: View {
    let analysis: TechnicalAnalysis
    let colorScheme: ColorScheme
    @State private var showGuide = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Investment Insight")
                .font(.subheadline.bold())
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(generateInsight())
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup("Understanding the Indicators", isExpanded: $showGuide) {
                VStack(alignment: .leading, spacing: ArkSpacing.md) {
                    guideRow(title: "Trend Score", description: "Measures price direction and momentum on a 0-100 scale using moving average alignment and trend strength. Scores above 60 indicate a healthy uptrend; below 40 suggests bearish pressure.")
                    guideRow(title: "Valuation Score", description: "Gauges how attractive the current entry point is (0-100). Higher scores mean price is oversold or near support, a potentially better value. Lower scores suggest price is extended.")
                    guideRow(title: "RSI (Relative Strength Index)", description: "A momentum oscillator ranging from 0-100. Readings below 30 indicate oversold conditions (potential buy zone), while above 70 signals overbought territory (potential sell zone). Mid-range values suggest neutral momentum.")
                    guideRow(title: "Market Outlook", description: "Compares short-term and long-term sentiment. When both align bullish or bearish, conviction is higher. Divergence between timeframes often signals a trend transition.")

                    Text("This is not financial advice. Always do your own research.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .padding(.top, ArkSpacing.xs)
                }
                .padding(.top, ArkSpacing.sm)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private func guideRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.footnote.bold())
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text(description)
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func generateInsight() -> String {
        let trend = analysis.trendScore
        let valuation = analysis.opportunityScore
        let rsiZone = analysis.rsi.zone
        let shortTerm = analysis.sentiment.shortTerm
        let bands = analysis.bullMarketBands.position

        // Oversold opportunity
        if rsiZone == .oversold || (valuation >= 70 && trend >= 40) {
            return "Oversold conditions, historically a zone where bounces have formed, though the trend hasn't confirmed a turn yet."
        }

        // Overbought with strong trend
        if rsiZone == .overbought && trend >= 60 {
            return "Trend is strong but price is stretched here, historically a spot where pullbacks have been more common."
        }

        // Bullish aligned
        if trend >= 60 && valuation >= 50 && (shortTerm == .bullish || shortTerm == .stronglyBullish) {
            return "Momentum and valuation are both constructive, trend support and sentiment are aligned to the upside."
        }

        // Bearish aligned
        if trend <= 40 && valuation <= 40 && (shortTerm == .bearish || shortTerm == .stronglyBearish) {
            return "Indicators are tilting cautious, trend, valuation, and sentiment are aligned to the downside for now."
        }

        // Above support bands with decent trend
        if bands == .aboveBoth && trend >= 50 {
            return "Price is holding above bull market support bands, the broader trend remains constructive."
        }

        // Below support bands
        if bands == .belowBoth && trend <= 50 {
            return "Price has broken below bull market support bands. Risk is elevated until support is reclaimed."
        }

        // Default: mixed/neutral
        return "Signals are mixed, no clear trend alignment right now."
    }
}

// MARK: - Preview
#Preview {
    AssetTechnicalDetailSheet(
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
    .preferredColorScheme(.dark)
}

// MARK: - Support & Resistance Card
/// Algorithmic support/resistance levels drawn on a compact price chart, with a
/// list of the nearest levels and an honest "guides, not guarantees" note.
struct SupportResistanceCard: View {
    let levels: KeyLevels
    let colorScheme: ColorScheme
    var title: String = "Support & Resistance"
    var subtitle: String = "Where price has reacted before"

    @State private var showExpanded = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    /// The single level drawn ON THE CHART per side: just the nearest resistance
    /// and nearest support. The chart's job is to show PRICE with one clean
    /// ceiling and one clean floor for context — the full ladder of levels lives
    /// in the rows below, where stacking them is fine.
    private var chartResistances: [KeyLevel] {
        Array(levels.resistances
            .sorted { abs($0.price - levels.currentPrice) < abs($1.price - levels.currentPrice) }
            .prefix(1))
    }
    private var chartSupports: [KeyLevel] {
        Array(levels.supports
            .sorted { abs($0.price - levels.currentPrice) < abs($1.price - levels.currentPrice) }
            .prefix(1))
    }

    /// Full price history drawn on the chart — let price be the star. With only
    /// one line per side there's no crowding to zoom away from, so showing the
    /// whole run gives the context the two reference lines are read against.
    private var chartSeries: [SRPricePoint] {
        levels.series
    }

    private var yBounds: (min: Double, max: Double) {
        // Bound the y-range to only the recent price slice and the levels we draw,
        // not the full history or every level. This is what lets the near lines
        // breathe: without it, old lows keep the chart zoomed out and the nearby
        // lines stay compressed together.
        var prices = chartSeries.map(\.close)
        prices += chartSupports.map(\.price)
        prices += chartResistances.map(\.price)
        prices.append(levels.currentPrice)
        let lo = prices.min() ?? 0
        let hi = prices.max() ?? 1
        let pad = max((hi - lo) * 0.06, hi * 0.005)
        return (lo - pad, hi + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            chart
                .overlay(alignment: .topTrailing) { expandHint }
                .contentShape(Rectangle())
                .onTapGesture { showExpanded = true }

            if !levels.resistances.isEmpty {
                groupHeader("RESISTANCE", color: AppColors.error)
                ForEach(levels.resistances) { levelRow($0) }
            }
            if !levels.supports.isEmpty {
                groupHeader("SUPPORT", color: AppColors.success)
                ForEach(levels.supports) { levelRow($0) }
            }

            Text("Algorithmic levels from price history and volume. Guides, not guarantees, the market doesn't owe them respect.")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
        .sheet(isPresented: $showExpanded) {
            SupportResistanceExpandedView(
                levels: levels,
                title: title,
                subtitle: subtitle,
                colorScheme: colorScheme
            )
        }
    }

    /// Small affordance so the tap-to-expand is discoverable.
    private var expandHint: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppColors.textTertiary)
            .padding(6)
            .background(Circle().fill(AppColors.textTertiary.opacity(0.10)))
            .padding(6)
    }

    private var chart: some View {
        let bounds = yBounds
        return Chart {
            ForEach(chartSeries) { p in
                LineMark(x: .value("Date", p.date), y: .value("Price", p.close))
                    .foregroundStyle(AppColors.accent.opacity(0.85))
                    .interpolationMethod(.catmullRom)
            }
            ForEach(chartResistances) { lvl in
                RuleMark(y: .value("Resistance", lvl.price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColors.error.opacity(0.55))
            }
            ForEach(chartSupports) { lvl in
                RuleMark(y: .value("Support", lvl.price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColors.success.opacity(0.55))
            }
            RuleMark(y: .value("Now", levels.currentPrice))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(AppColors.textSecondary.opacity(0.35))
        }
        .chartYScale(domain: bounds.min...bounds.max)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.asCryptoPrice)
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .frame(height: 150)
    }

    private func groupHeader(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.top, 2)
    }

    private func levelRow(_ lvl: KeyLevel) -> some View {
        let pct = levels.currentPrice > 0 ? (lvl.price - levels.currentPrice) / levels.currentPrice * 100 : 0
        let color = lvl.kind == .support ? AppColors.success : AppColors.error
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(lvl.price.asCryptoPrice)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)
            Text(String(format: "%@%.1f%%", pct >= 0 ? "+" : "", pct))
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(lvl.strength.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(color.opacity(0.12)))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Expanded, inspectable S/R chart
//
// Opened by tapping the compact card chart. Full-height, so every level can be
// drawn AND labeled without crowding, plus drag-to-inspect: drag a finger across
// the chart to read the exact price and date at any point. The level math and
// data are identical to the card — this view just has the room to show it all.
struct SupportResistanceExpandedView: View {
    let levels: KeyLevels
    var title: String = "Support & Resistance"
    var subtitle: String = "Where price has reacted before"
    let colorScheme: ColorScheme

    @Environment(\.dismiss) private var dismiss
    @State private var selected: SRPricePoint?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var yBounds: (min: Double, max: Double) {
        var prices = levels.series.map(\.close)
        prices += levels.supports.map(\.price)
        prices += levels.resistances.map(\.price)
        prices.append(levels.currentPrice)
        let lo = prices.min() ?? 0
        let hi = prices.max() ?? 1
        let pad = max((hi - lo) * 0.05, hi * 0.004)
        return (lo - pad, hi + pad)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title3.bold())
                            .foregroundColor(textPrimary)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    chart.frame(height: 360)
                    readout
                    legend

                    Text("Algorithmic levels from price history and volume. Guides, not guarantees, the market doesn't owe them respect.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(ArkSpacing.md)
            }
            .navigationTitle("Support & Resistance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Chart

    private var chart: some View {
        let bounds = yBounds
        return Chart {
            ForEach(levels.series) { p in
                LineMark(x: .value("Date", p.date), y: .value("Price", p.close))
                    .foregroundStyle(AppColors.accent.opacity(0.9))
                    .interpolationMethod(.catmullRom)
            }
            ForEach(levels.resistances) { lvl in
                RuleMark(y: .value("Resistance", lvl.price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColors.error.opacity(0.5))
                    .annotation(position: .top, alignment: .leading, spacing: 1) {
                        levelTag(lvl.price, color: AppColors.error)
                    }
            }
            ForEach(levels.supports) { lvl in
                RuleMark(y: .value("Support", lvl.price))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(AppColors.success.opacity(0.5))
                    .annotation(position: .bottom, alignment: .leading, spacing: 1) {
                        levelTag(lvl.price, color: AppColors.success)
                    }
            }
            RuleMark(y: .value("Now", nowPrice))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))

            if let now = levels.series.last {
                // Live price: a pulsing dot pinned to the END OF THE PRICE LINE
                // (now.close), so the dot, the "Now" line and the tag all sit
                // exactly on the line tip instead of floating a hair off it.
                PointMark(x: .value("Date", now.date), y: .value("Price", now.close))
                    .symbolSize(0)
                    .annotation(position: .overlay, spacing: 0) {
                        PulsingDot(color: AppColors.accent)
                    }
                PointMark(x: .value("Date", now.date), y: .value("Price", now.close))
                    .symbolSize(0)
                    .annotation(position: .leading, spacing: 6) {
                        nowTag
                    }
            }

            if let sel = selected {
                RuleMark(x: .value("Date", sel.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                PointMark(x: .value("Date", sel.date), y: .value("Price", sel.close))
                    .foregroundStyle(AppColors.accent)
                    .symbolSize(70)
            }
        }
        .chartYScale(domain: bounds.min...bounds.max)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(compactPrice(price))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                guard let date = proxy.value(atX: x, as: Date.self) else { return }
                                selected = nearestPoint(to: date)
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
    }

    private func nearestPoint(to date: Date) -> SRPricePoint? {
        levels.series.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: Readout (drag-to-inspect)

    private var readout: some View {
        HStack {
            if let sel = selected {
                Text(sel.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(sel.close.asCryptoPrice)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(textPrimary)
            } else {
                Image(systemName: "hand.draw")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                Text("Drag across the chart to read price and date")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
            }
        }
        .frame(height: 22)
    }

    // MARK: Legend (all levels)

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !levels.resistances.isEmpty {
                legendHeader("RESISTANCE", color: AppColors.error)
                ForEach(levels.resistances) { legendRow($0) }
            }
            if !levels.supports.isEmpty {
                legendHeader("SUPPORT", color: AppColors.success)
                ForEach(levels.supports) { legendRow($0) }
            }
        }
    }

    private func legendHeader(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.top, 2)
    }

    private func legendRow(_ lvl: KeyLevel) -> some View {
        let color = lvl.kind == .support ? AppColors.success : AppColors.error
        let pct = (lvl.price - levels.currentPrice) / levels.currentPrice * 100
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(lvl.price.asCryptoPrice)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)
            Text(String(format: "%@%.1f%%", pct >= 0 ? "+" : "", pct))
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(lvl.strength.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(color.opacity(0.12)))
        }
        .padding(.vertical, 3)
    }

    // MARK: Formatting

    private func levelTag(_ price: Double, color: Color) -> some View {
        Text(compactPrice(price))
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    /// The price the "Now" marker sits at: the end of the drawn price line, so
    /// the dot/line/tag all land on the line tip. Falls back to current price.
    private var nowPrice: Double { levels.series.last?.close ?? levels.currentPrice }

    private var nowTag: some View {
        Text("Now · \(compactPrice(nowPrice))")
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(AppColors.textSecondary.opacity(0.14)))
    }

    /// Short label for axis ticks and on-line tags (e.g. $86.4k, $2.8k, $120).
    private func compactPrice(_ v: Double) -> String {
        if v >= 1000 { return String(format: "$%.1fk", v / 1000) }
        return String(format: "$%.0f", v)
    }
}

/// A live-price marker: a solid core dot with a soft ring that expands and fades
/// on a loop, so "now" reads as alive rather than just another point.
private struct PulsingDot: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.35))
                .frame(width: 14, height: 14)
                .scaleEffect(animate ? 2.0 : 1.0)
                .opacity(animate ? 0.0 : 0.5)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}
