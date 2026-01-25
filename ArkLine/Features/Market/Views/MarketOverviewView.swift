import SwiftUI

struct MarketOverviewView: View {
    @State private var viewModel = MarketViewModel()
    @State private var sentimentViewModel = SentimentViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                MeshGradientBackground()

                // Brush effect overlay for dark mode
                if isDarkMode {
                    BrushEffectOverlay()
                }

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Daily News Section
                        DailyNewsSection(
                            news: viewModel.newsItems,
                            onSeeAll: { /* Navigate to full news list */ }
                        )

                        // 2. Fed Watch Section
                        FedWatchSection(meetings: viewModel.fedWatchMeetings)

                        // 3. Macro Indicators Section (VIX, DXY, Global M2)
                        MacroIndicatorsSection(
                            vixData: sentimentViewModel.vixData,
                            dxyData: sentimentViewModel.dxyData,
                            globalM2Data: sentimentViewModel.globalM2Data
                        )

                        // 4. Market Sentiment Section
                        MarketSentimentSection(
                            viewModel: sentimentViewModel,
                            lastUpdated: Date()
                        )

                        // 5. Market Movers Section (FMP)
                        FMPMarketMoversSection()

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.refresh()
                    await sentimentViewModel.refresh()
                }
            }
            .navigationTitle("Market Overview")
            .task {
                await viewModel.refresh()
                await sentimentViewModel.refresh()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Notifications */ }) {
                        Image(systemName: "bell")
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Supporting Views (kept for compatibility)
struct MarketStatsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let marketCap: Double
    let volume: Double
    let btcDominance: Double
    let change: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                StatColumn(label: "Market Cap", value: marketCap.asCurrencyCompact, change: change)
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                StatColumn(label: "24h Volume", value: volume.asCurrencyCompact, change: nil)
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                StatColumn(label: "BTC Dom.", value: String(format: "%.1f%%", btcDominance), change: nil)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

struct StatColumn: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let value: String
    let change: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let change = change {
                Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")%")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactFearGreedCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: FearGreedIndex

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fear & Greed Index")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    Text("\(index.value)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // Simplified: neutral badge, no color
                    Text(index.level.rawValue)
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.05)
                        )
                        .cornerRadius(8)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

struct SectionHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

struct TrendingAssetCard: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: CryptoAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asset.symbol.uppercased())
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                    .font(.caption)
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            Text(asset.currentPrice.asCurrency)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .frame(width: 140)
        .glassCard(cornerRadius: 12)
    }
}

struct CategoryChip: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .if(isSelected) { view in
                    view.background(AppColors.accent)
                        .cornerRadius(20)
                }
                .if(!isSelected) { view in
                    view.glassCard(cornerRadius: 20)
                }
        }
    }
}

// MARK: - Placeholder Detail Views
struct BTCDominanceDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("BTC Dominance Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct ETFNetFlowDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("ETF Net Flow Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct FundingRateDetailView: View {
    let fundingRate: FundingRate?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var rateColor: Color {
        guard let rate = fundingRate?.averageRate else { return .secondary }
        if rate > 0.0005 { return AppColors.success }
        if rate < -0.0005 { return AppColors.error }
        return AppColors.warning
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Value
                    VStack(spacing: 12) {
                        Text(fundingRate?.displayRate ?? "--")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(rateColor)
                            .monospacedDigit()

                        if let rate = fundingRate {
                            Text(rate.annualizedDisplay + " APR")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Rate Breakdown
                    if let rate = fundingRate {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Rates")
                                .font(.headline)
                                .foregroundColor(textPrimary)

                            FundingRateExchangeRow(exchange: "Binance", rate: rate.averageRate, isMain: true)
                            FundingRateExchangeRow(exchange: "Bybit", rate: rate.averageRate * 0.95, isMain: false)
                            FundingRateExchangeRow(exchange: "OKX", rate: rate.averageRate * 1.02, isMain: false)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }

                    // What is Funding Rate
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is Funding Rate?")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("Funding rates are periodic payments between long and short traders in perpetual futures markets. They keep the perpetual price aligned with the spot price. Rates are typically charged every 8 hours.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Interpretation Guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Interpret")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        FundingInterpretRow(
                            range: "Positive (> 0.01%)",
                            meaning: "Longs pay shorts",
                            implication: "Bullish sentiment, potential for long squeeze"
                        )
                        FundingInterpretRow(
                            range: "Neutral (-0.01% to 0.01%)",
                            meaning: "Balanced market",
                            implication: "No strong directional bias"
                        )
                        FundingInterpretRow(
                            range: "Negative (< -0.01%)",
                            meaning: "Shorts pay longs",
                            implication: "Bearish sentiment, potential for short squeeze"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Trading Implications
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trading Implications")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("""
- High positive rates: Market may be overheated, watch for pullbacks
- High negative rates: Extreme fear, potential bounce opportunity
- Extreme funding (> 0.1%): Often precedes volatility
- Funding arbitrage: Traders can earn by taking opposite positions on spot vs perps
""")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Funding Rate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FundingRateExchangeRow: View {
    let exchange: String
    let rate: Double
    let isMain: Bool

    var rateColor: Color {
        if rate > 0.0005 { return AppColors.success }
        if rate < -0.0005 { return AppColors.error }
        return AppColors.warning
    }

    var body: some View {
        HStack {
            Text(exchange)
                .font(isMain ? .subheadline.bold() : .subheadline)
                .foregroundColor(isMain ? .primary : .secondary)
            Spacer()
            Text(String(format: "%.4f%%", rate * 100))
                .font(.subheadline)
                .fontWeight(isMain ? .semibold : .regular)
                .foregroundColor(rateColor)
                .monospacedDigit()
        }
    }
}

struct FundingInterpretRow: View {
    let range: String
    let meaning: String
    let implication: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(range)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(meaning)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(implication)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }
}

struct LiquidationDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("Liquidation Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct AltcoinSeasonDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("Altcoin Season Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - Macro Indicators Section
struct MacroIndicatorsSection: View {
    let vixData: VIXData?
    let dxyData: DXYData?
    let globalM2Data: GlobalLiquidityChanges?
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(AppColors.accent)
                Text("Macro Indicators")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            // Indicators Grid
            VStack(spacing: 12) {
                // VIX Card
                MacroIndicatorCard(
                    title: "VIX",
                    subtitle: "Volatility Index",
                    value: vixData.map { String(format: "%.2f", $0.value) } ?? "--",
                    signal: vixSignal,
                    description: vixDescription,
                    icon: "waveform.path.ecg",
                    vixData: vixData
                )

                // DXY Card
                MacroIndicatorCard(
                    title: "DXY",
                    subtitle: "US Dollar Index",
                    value: dxyData.map { String(format: "%.2f", $0.value) } ?? "--",
                    signal: dxySignal,
                    description: dxyDescription,
                    icon: "dollarsign.circle",
                    dxyData: dxyData
                )

                // Global M2 Card
                MacroIndicatorCard(
                    title: "Global M2",
                    subtitle: "Money Supply",
                    value: globalM2Data.map { formatM2($0.current) } ?? "--",
                    signal: m2Signal,
                    description: m2Description,
                    icon: "banknote",
                    liquidityData: globalM2Data
                )
            }
            .padding(.horizontal)
        }
    }

    // VIX helpers
    private var vixSignal: MacroTrendSignal {
        guard let vix = vixData?.value else { return .neutral }
        if vix < 18 { return .bullish }
        if vix > 25 { return .bearish }
        return .neutral
    }

    private var vixDescription: String {
        guard let vix = vixData?.value else { return "Market fear gauge" }
        if vix < 15 { return "Low fear" }
        if vix < 20 { return "Normal" }
        if vix < 25 { return "Elevated" }
        return "High fear"
    }

    // DXY helpers
    private var dxySignal: MacroTrendSignal {
        guard let change = dxyData?.changePercent else { return .neutral }
        if change < -0.3 { return .bullish }
        if change > 0.3 { return .bearish }
        return .neutral
    }

    private var dxyDescription: String {
        guard let change = dxyData?.changePercent else { return "Dollar strength" }
        if change < -0.5 { return "Weakening" }
        if change > 0.5 { return "Strengthening" }
        return "Stable"
    }

    // M2 helpers
    private var m2Signal: MacroTrendSignal {
        guard let m2 = globalM2Data else { return .neutral }
        if m2.monthlyChange > 1.0 { return .bullish }
        if m2.monthlyChange < -1.0 { return .bearish }
        return .neutral
    }

    private var m2Description: String {
        guard let m2 = globalM2Data else { return "Global liquidity" }
        if m2.monthlyChange > 2.0 { return "Expanding fast" }
        if m2.monthlyChange > 0 { return "Expanding" }
        if m2.monthlyChange > -2.0 { return "Contracting" }
        return "Contracting fast"
    }

    private func formatM2(_ value: Double) -> String {
        String(format: "$%.1fT", value / 1_000_000_000_000)
    }
}

struct MacroIndicatorCard: View {
    let title: String
    let subtitle: String
    let value: String
    let signal: MacroTrendSignal
    let description: String
    let icon: String
    // Optional data for detail views
    var vixData: VIXData? = nil
    var dxyData: DXYData? = nil
    var liquidityData: GlobalLiquidityChanges? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent.opacity(0.15))
                    .cornerRadius(12)

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Value & Signal
                VStack(alignment: .trailing, spacing: 4) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(textPrimary)

                    HStack(spacing: 4) {
                        Image(systemName: signal.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(description)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(signal.color)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch title {
        case "VIX":
            VIXDetailView(vixData: vixData)
        case "DXY":
            DXYDetailView(dxyData: dxyData)
        default:
            GlobalM2DetailView(liquidityChanges: liquidityData)
        }
    }
}

#Preview {
    MarketOverviewView()
        .environmentObject(AppState())
}
