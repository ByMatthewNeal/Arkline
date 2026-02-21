import SwiftUI

// MARK: - Macro Dashboard Detail View
struct MacroDashboardDetailView: View {
    let vixData: VIXData?
    let dxyData: DXYData?
    let liquidityData: GlobalLiquidityChanges?
    let regime: MarketRegime
    let vixCorrelation: CorrelationStrength
    let dxyCorrelation: CorrelationStrength
    let m2Correlation: CorrelationStrength
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var regimeManager = RegimeChangeManager.shared
    @StateObject private var alertManager = ExtremeMoveAlertManager.shared

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7")
    }

    @State private var showLearnMore = false
    @State private var expandedIndicator: MacroIndicatorType? = nil
    @State private var macroTimeRange: MacroChartTimeRange = .threeDays
    @State private var macroSelectedDate: Date? = nil
    @State private var vixHistory: [VIXData] = []
    @State private var dxyHistory: [DXYData] = []
    @State private var isLoadingChart = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Regime Card
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(regime.color)
                                .frame(width: 12, height: 12)

                            Text(regime.rawValue)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(regime.color)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }

                        Text(regime.description)
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)

                        // Last change info
                        if let lastChange = regimeManager.lastRegimeChange {
                            Text("Since \(lastChange.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12))
                                .foregroundColor(textPrimary.opacity(0.4))
                        }

                        // Learn more expandable
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showLearnMore.toggle() } }) {
                            HStack(spacing: 4) {
                                Text("What does this mean?")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: showLearnMore ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(AppColors.accent)
                        }
                        .padding(.top, 4)

                        if showLearnMore {
                            VStack(alignment: .leading, spacing: 8) {
                                LearnMoreRow(color: AppColors.success, label: "RISK-ON", text: "Low volatility, weak dollar, expanding liquidity")
                                LearnMoreRow(color: AppColors.warning, label: "MIXED", text: "Conflicting signals across indicators")
                                LearnMoreRow(color: AppColors.error, label: "RISK-OFF", text: "High volatility, strong dollar, or tightening liquidity")
                            }
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )

                    // Simplified Indicators
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CURRENT VALUES")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            // VIX
                            Button(action: { toggleIndicator(.vix) }) {
                                SimpleIndicatorRow(
                                    icon: "waveform.path.ecg",
                                    title: "VIX",
                                    value: vixData.map { String(format: "%.1f", $0.value) } ?? "--",
                                    status: vixStatus,
                                    statusColor: vixStatusColor,
                                    isExpanded: expandedIndicator == .vix
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            if expandedIndicator == .vix {
                                MacroIndicatorChart(
                                    data: vixChartData,
                                    lineColor: vixStatusColor,
                                    valueFormatter: { String(format: "%.1f", $0) },
                                    selectedTimeRange: $macroTimeRange,
                                    selectedDate: $macroSelectedDate,
                                    isLoading: isLoadingChart
                                )
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Divider().background(textPrimary.opacity(0.08))

                            // DXY
                            Button(action: { toggleIndicator(.dxy) }) {
                                SimpleIndicatorRow(
                                    icon: "dollarsign.circle",
                                    title: "DXY",
                                    value: dxyData.map { String(format: "%.1f", $0.value) } ?? "--",
                                    change: dxyData?.changePercent,
                                    status: dxyStatus,
                                    statusColor: dxyStatusColor,
                                    isExpanded: expandedIndicator == .dxy
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            if expandedIndicator == .dxy {
                                MacroIndicatorChart(
                                    data: dxyChartData,
                                    lineColor: dxyStatusColor,
                                    valueFormatter: { String(format: "%.1f", $0) },
                                    selectedTimeRange: $macroTimeRange,
                                    selectedDate: $macroSelectedDate,
                                    isLoading: isLoadingChart
                                )
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Divider().background(textPrimary.opacity(0.08))

                            // Global M2
                            Button(action: { toggleIndicator(.m2) }) {
                                SimpleIndicatorRow(
                                    icon: "banknote",
                                    title: "Global M2",
                                    value: liquidityData.map { formatLiquidity($0.current) } ?? "--",
                                    change: liquidityData?.monthlyChange,
                                    status: m2Status,
                                    statusColor: m2StatusColor,
                                    isExpanded: expandedIndicator == .m2
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            if expandedIndicator == .m2 {
                                MacroIndicatorChart(
                                    data: m2ChartData,
                                    lineColor: m2StatusColor,
                                    valueFormatter: { value in
                                        if value >= 1_000_000_000_000 {
                                            return String(format: "$%.1fT", value / 1_000_000_000_000)
                                        }
                                        return String(format: "$%.0fB", value / 1_000_000_000)
                                    },
                                    selectedTimeRange: $macroTimeRange,
                                    selectedDate: $macroSelectedDate,
                                    isLoading: false
                                )
                                .padding(.horizontal, 14)

                                // Economies info note
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(textPrimary.opacity(0.35))
                                    Text("Aggregates US, China, Eurozone, Japan & UK M2 supply converted to USD")
                                        .font(.system(size: 10))
                                        .foregroundColor(textPrimary.opacity(0.35))
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Alerts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALERTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Regime Change Alerts")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text("Get notified when conditions shift")
                                    .font(.system(size: 12))
                                    .foregroundColor(textPrimary.opacity(0.5))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { regimeManager.notificationsEnabled },
                                set: { newValue in
                                    regimeManager.notificationsEnabled = newValue
                                    if newValue {
                                        regimeManager.requestNotificationPermissions()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(AppColors.accent)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Investment Insight
                    MacroInsightCard(
                        regime: regime,
                        vixData: vixData,
                        dxyData: dxyData,
                        liquidityData: liquidityData,
                        colorScheme: colorScheme
                    )

                    Spacer(minLength: 40)
                }
                .padding(16)
            }
            .background(sheetBackground)
            .navigationTitle("Macro Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var vixInterpretation: String {
        guard let vix = vixData?.value else { return "No data" }
        if vix < 15 { return "Complacency - markets calm" }
        if vix < 20 { return "Normal conditions" }
        if vix < 25 { return "Elevated uncertainty" }
        return "High fear - potential capitulation"
    }

    private var dxyInterpretation: String {
        guard let change = dxyData?.changePercent else { return "No data" }
        if change < -0.3 { return "Dollar weakening - bullish for crypto" }
        if change > 0.3 { return "Dollar strengthening - headwind for risk" }
        return "Dollar stable"
    }

    private var m2Interpretation: String {
        guard let m2 = liquidityData else { return "No data" }
        if m2.monthlyChange > 1.0 { return "Liquidity expanding rapidly" }
        if m2.monthlyChange > 0 { return "Gradual liquidity growth" }
        if m2.monthlyChange > -1.0 { return "Liquidity flat to declining" }
        return "Liquidity contracting"
    }

    // MARK: - Z-Score Enhanced Interpretations

    private var vixZScoreInterpretation: String {
        if let zScore = macroZScores[.vix] {
            if zScore.isExtreme {
                return zScore.zScore.zScore > 0
                    ? "Extreme fear (\(zScore.zScore.formatted)) - potential capitulation"
                    : "Extreme complacency (\(zScore.zScore.formatted)) - caution advised"
            } else if zScore.isSignificant {
                return zScore.zScore.zScore > 0
                    ? "Elevated uncertainty (\(zScore.zScore.formatted))"
                    : "Low volatility (\(zScore.zScore.formatted)) - risk-on"
            }
        }
        return vixInterpretation
    }

    private var dxyZScoreInterpretation: String {
        if let zScore = macroZScores[.dxy] {
            if zScore.isExtreme {
                return zScore.zScore.zScore > 0
                    ? "Extreme dollar strength (\(zScore.zScore.formatted)) - headwind"
                    : "Extreme dollar weakness (\(zScore.zScore.formatted)) - bullish"
            } else if zScore.isSignificant {
                return zScore.zScore.zScore > 0
                    ? "Dollar strengthening (\(zScore.zScore.formatted))"
                    : "Dollar weakening (\(zScore.zScore.formatted)) - favorable"
            }
        }
        return dxyInterpretation
    }

    private var m2ZScoreInterpretation: String {
        if let zScore = macroZScores[.m2] {
            if zScore.isExtreme {
                return zScore.zScore.zScore > 0
                    ? "Rapid expansion (\(zScore.zScore.formatted)) - bullish lag"
                    : "Severe contraction (\(zScore.zScore.formatted)) - headwind"
            } else if zScore.isSignificant {
                return zScore.zScore.zScore > 0
                    ? "Above-average growth (\(zScore.zScore.formatted))"
                    : "Below-average growth (\(zScore.zScore.formatted))"
            }
        }
        return m2Interpretation
    }

    // MARK: - Chart Expand/Collapse

    private func toggleIndicator(_ type: MacroIndicatorType) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedIndicator == type {
                expandedIndicator = nil
                macroSelectedDate = nil
            } else {
                expandedIndicator = type
                macroSelectedDate = nil
                loadHistoryIfNeeded(for: type)
            }
        }
    }

    private func loadHistoryIfNeeded(for type: MacroIndicatorType) {
        switch type {
        case .vix:
            guard vixHistory.isEmpty else { return }
            loadVIXHistory()
        case .dxy:
            guard dxyHistory.isEmpty else { return }
            loadDXYHistory()
        case .m2:
            break // Already available in liquidityData.history
        }
    }

    private func loadVIXHistory() {
        isLoadingChart = true
        Task {
            do {
                let history = try await ServiceContainer.shared.vixService.fetchVIXHistory(days: 365)
                await MainActor.run {
                    self.vixHistory = history
                    self.isLoadingChart = false
                }
            } catch {
                await MainActor.run { self.isLoadingChart = false }
            }
        }
    }

    private func loadDXYHistory() {
        isLoadingChart = true
        Task {
            do {
                let history = try await ServiceContainer.shared.dxyService.fetchDXYHistory(days: 365)
                await MainActor.run {
                    self.dxyHistory = history
                    self.isLoadingChart = false
                }
            } catch {
                await MainActor.run { self.isLoadingChart = false }
            }
        }
    }

    // MARK: - Chart Data

    /// Date cutoff for a given time range
    private func dateCutoff(for range: MacroChartTimeRange) -> Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: Date()) ?? Date()
    }


    private var vixChartData: [MacroChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = dateCutoff(for: macroTimeRange)
        return vixHistory.reversed().compactMap { item -> MacroChartPoint? in
            guard let date = formatter.date(from: item.date), date >= cutoff else { return nil }
            return MacroChartPoint(date: date, value: item.value)
        }
    }

    private var dxyChartData: [MacroChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = dateCutoff(for: macroTimeRange)
        return dxyHistory.reversed().compactMap { item -> MacroChartPoint? in
            guard let date = formatter.date(from: item.date), date >= cutoff else { return nil }
            return MacroChartPoint(date: date, value: item.value)
        }
    }

    private var m2ChartData: [MacroChartPoint] {
        guard let history = liquidityData?.history else { return [] }
        let points = history.map { MacroChartPoint(date: $0.date, value: $0.value) }
        // M2 data is monthly — date filtering leaves too few points for short ranges.
        // Use count-based suffix mapped to each time range.
        let count: Int
        switch macroTimeRange {
        case .daily: count = 2
        case .threeDays: count = 3
        case .weekly: count = 4
        case .monthly: count = 13
        }
        return Array(points.suffix(count))
    }

    // MARK: - Simplified Status Properties

    private var vixStatus: String {
        guard let vix = vixData?.value else { return "No data" }
        if vix < 15 { return "Low" }
        if vix < 20 { return "Normal" }
        if vix < 25 { return "Elevated" }
        return "High"
    }

    private var vixStatusColor: Color {
        guard let vix = vixData?.value else { return .secondary }
        if vix < 15 { return AppColors.success }
        if vix < 20 { return Color(hex: "3B82F6") }
        if vix < 25 { return AppColors.warning }
        return AppColors.error
    }

    private var dxyStatus: String {
        guard let change = dxyData?.changePercent else { return "No data" }
        if change < -0.3 { return "Weakening" }
        if change > 0.3 { return "Strengthening" }
        return "Stable"
    }

    private var dxyStatusColor: Color {
        guard let change = dxyData?.changePercent else { return .secondary }
        if change < -0.3 { return AppColors.success }
        if change > 0.3 { return AppColors.error }
        return AppColors.warning
    }

    private var m2Status: String {
        guard let m2 = liquidityData else { return "No data" }
        if m2.monthlyChange > 1.0 { return "Expanding" }
        if m2.monthlyChange > 0 { return "Growing" }
        if m2.monthlyChange > -1.0 { return "Flat" }
        return "Contracting"
    }

    private var m2StatusColor: Color {
        guard let m2 = liquidityData else { return .secondary }
        if m2.monthlyChange > 0.5 { return AppColors.success }
        if m2.monthlyChange > -0.5 { return AppColors.warning }
        return AppColors.error
    }

    // MARK: - Asset Impact Interpretations

    /// VIX impact on BTC - inverse correlation, especially during spikes
    private var vixBtcImpact: (signal: String, description: String, color: Color) {
        guard let vix = vixData?.value else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // Historical: VIX spikes (>30) often precede or coincide with BTC drawdowns
        // VIX < 15 typically aligns with risk-on rallies
        if vix > 35 {
            return ("Bearish", "Extreme fear often triggers crypto selloffs", AppColors.error)
        } else if vix > 25 {
            return ("Cautious", "Elevated volatility pressures risk assets", AppColors.warning)
        } else if vix < 15 {
            return ("Bullish", "Low fear supports risk-on positioning", AppColors.success)
        }
        return ("Neutral", "Normal volatility regime", AppColors.textSecondary)
    }

    /// VIX impact on Gold - mixed relationship
    private var vixGoldImpact: (signal: String, description: String, color: Color) {
        guard let vix = vixData?.value else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // Gold benefits from fear but relationship is complex
        if vix > 35 {
            return ("Bullish", "Flight to safety supports gold", AppColors.success)
        } else if vix > 25 {
            return ("Bullish", "Uncertainty drives safe-haven demand", AppColors.success)
        } else if vix < 15 {
            return ("Neutral", "Risk-on may rotate away from gold", AppColors.warning)
        }
        return ("Neutral", "Normal regime for gold", AppColors.textSecondary)
    }

    /// DXY impact on BTC - inverse correlation
    private var dxyBtcImpact: (signal: String, description: String, color: Color) {
        guard let dxy = dxyData?.value else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // Historical: Strong dollar (DXY > 105) pressures BTC
        // Weak dollar (DXY < 100) often coincides with BTC rallies
        if dxy > 105 {
            return ("Bearish", "Strong dollar headwind for crypto", AppColors.error)
        } else if dxy > 100 {
            return ("Cautious", "Dollar strength may cap upside", AppColors.warning)
        } else if dxy < 97 {
            return ("Bullish", "Weak dollar historically bullish for BTC", AppColors.success)
        }
        return ("Neutral", "Dollar in neutral range", AppColors.textSecondary)
    }

    /// DXY impact on Gold - inverse correlation
    private var dxyGoldImpact: (signal: String, description: String, color: Color) {
        guard let dxy = dxyData?.value else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // Gold priced in USD, so inverse relationship
        if dxy > 105 {
            return ("Bearish", "Strong dollar pressures gold prices", AppColors.error)
        } else if dxy > 100 {
            return ("Cautious", "Dollar strength limits gold upside", AppColors.warning)
        } else if dxy < 97 {
            return ("Bullish", "Weak dollar supports gold rally", AppColors.success)
        }
        return ("Neutral", "Dollar in neutral range", AppColors.textSecondary)
    }

    /// M2 impact on BTC - positive correlation with 2-3 month lag
    private var m2BtcImpact: (signal: String, description: String, color: Color) {
        guard let m2 = liquidityData else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // BTC follows global liquidity with ~2-3 month lag
        // Expansion historically bullish, contraction bearish
        if m2.monthlyChange > 1.0 {
            return ("Bullish", "Liquidity expansion favors BTC (2-3mo lag)", AppColors.success)
        } else if m2.monthlyChange > 0 {
            return ("Neutral", "Modest growth - supportive backdrop", AppColors.textSecondary)
        } else if m2.monthlyChange > -1.0 {
            return ("Cautious", "Flat liquidity may limit upside", AppColors.warning)
        }
        return ("Bearish", "Liquidity contraction headwind for crypto", AppColors.error)
    }

    /// M2 impact on Gold - positive correlation
    private var m2GoldImpact: (signal: String, description: String, color: Color) {
        guard let m2 = liquidityData else {
            return ("Neutral", "Awaiting data", AppColors.textSecondary)
        }
        // Gold benefits from monetary expansion (inflation hedge)
        if m2.monthlyChange > 1.0 {
            return ("Bullish", "Money printing historically bullish for gold", AppColors.success)
        } else if m2.monthlyChange > 0 {
            return ("Neutral", "Gradual expansion supportive", AppColors.textSecondary)
        } else if m2.monthlyChange > -1.0 {
            return ("Neutral", "Flat liquidity - gold holds value", AppColors.textSecondary)
        }
        return ("Cautious", "Tightening may pressure gold near-term", AppColors.warning)
    }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1fT", value / 1_000_000_000_000)
        }
        return String(format: "$%.0fB", value / 1_000_000_000)
    }
}

// MARK: - Macro Insight Card
private struct MacroInsightCard: View {
    let regime: MarketRegime
    let vixData: VIXData?
    let dxyData: DXYData?
    let liquidityData: GlobalLiquidityChanges?
    let colorScheme: ColorScheme
    @State private var showGuide = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

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
                    guideRow(title: "VIX (Volatility Index)", description: "Measures expected market volatility. Below 15 signals complacency and a risk-on environment. Above 25 indicates elevated fear, which often pressures crypto and risk assets. Spikes above 35 can signal capitulation and potential bottoming.")
                    guideRow(title: "DXY (US Dollar Index)", description: "Tracks the US dollar against a basket of major currencies. A weakening dollar (below ~100) is historically bullish for crypto and commodities, while a strengthening dollar (above ~105) creates headwinds for risk assets.")
                    guideRow(title: "Global M2 (Money Supply)", description: "Aggregates money supply from the US, China, Eurozone, Japan & UK. Expanding M2 increases liquidity in financial markets and tends to flow into risk assets like BTC with a 2-3 month lag. Contraction signals tighter conditions.")
                    guideRow(title: "Market Regime", description: "Combines all three indicators into a single signal. Risk-On means favorable conditions across the board. Risk-Off means multiple headwinds. Mixed means conflicting signals — patience is warranted.")

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
                .fill(cardBackground)
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
        let vix = vixData?.value
        let dxyChange = dxyData?.changePercent
        let m2Change = liquidityData?.monthlyChange

        // Risk-on with strong conviction
        if regime == .riskOn {
            if let v = vix, v < 15 {
                return "Macro conditions are strongly favorable — low volatility, a cooperative dollar, and expanding liquidity create a supportive backdrop for risk assets. Historically these periods align with sustained crypto rallies."
            }
            return "Macro indicators are aligned to the upside. Low fear, a weakening or stable dollar, and growing liquidity favor accumulation of risk assets like BTC."
        }

        // Risk-off with strong conviction
        if regime == .riskOff {
            if let v = vix, v > 35 {
                return "Extreme fear across markets with a strong dollar and tightening liquidity. These conditions historically precede further drawdowns, but extreme readings can also mark capitulation. Caution is warranted."
            }
            return "Multiple macro headwinds are present — elevated volatility, dollar strength, or contracting liquidity. Consider reducing risk exposure or waiting for conditions to stabilize before adding positions."
        }

        // Mixed — try to identify the dominant factor
        if let v = vix, v > 25 {
            return "Volatility is elevated while other indicators remain mixed. Fear-driven markets tend to be choppy — risk management and smaller position sizes are prudent until the VIX settles below 20."
        }

        if let change = dxyChange, change > 0.3 {
            return "The dollar is strengthening while other conditions are neutral. Dollar headwinds can cap upside for crypto — monitor for a reversal in DXY before adding significant exposure."
        }

        if let m2 = m2Change, m2 < -0.5 {
            return "Liquidity is contracting while other signals are mixed. Tightening money supply tends to weigh on risk assets with a lag. Watch for M2 to stabilize before turning aggressive."
        }

        return "Macro signals are mixed — no clear directional bias. A wait-and-see approach is reasonable until indicators converge toward a clearer risk-on or risk-off regime."
    }
}

