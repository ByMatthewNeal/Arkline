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
                        }

                        Text(regime.description)
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .multilineTextAlignment(.center)

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

                                Text("Get notified when conditions shift")
                                    .font(.system(size: 12))
                                    .foregroundColor(textPrimary.opacity(0.5))
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

// MARK: - Signal Key Row
struct SignalKeyRow: View {
    let signal: String
    let color: Color
    let meaning: String
    let description: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(signal)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(color)

                    Text(meaning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Correlation Detail Row
struct CorrelationDetailRow: View {
    let indicator: String
    let strength: CorrelationStrength
    let relationship: String
    let explanation: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(indicator)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(relationship)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(textPrimary.opacity(0.08))
                        )
                }

                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                CorrelationBars(strength: strength)

                Text(strength.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(14)
    }
}

// MARK: - Macro Detail Row
struct MacroDetailRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let value: String
    let change: Double?
    let interpretation: String
    let correlation: CorrelationStrength
    var zScoreData: MacroZScoreData?

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)

                // Pulsing indicator for extreme moves
                if let zScore = zScoreData, zScore.isExtreme {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 10, height: 10)
                        .offset(x: 16, y: -16)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    CorrelationBars(strength: correlation)

                    // Z-Score badge
                    if let zScore = zScoreData {
                        ZScoreIndicator(zScore: zScore.zScore.zScore, size: .small)
                    }
                }

                Text(interpretation)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                if let change = change {
                    Text(String(format: "%+.2f%%", change))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
    }
}

// MARK: - Threshold Row
struct ThresholdRow: View {
    let indicator: String
    let bullish: String
    let bearish: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            Text(indicator)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                    Text(bullish)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.7))
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                    Text(bearish)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Z-Score Analysis Row
/// Detailed z-score breakdown for statistical analysis section
struct ZScoreAnalysisRow: View {
    let zScoreData: MacroZScoreData

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with indicator and z-score badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(zScoreData.indicator.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)

                        ZScoreIndicator(zScore: zScoreData.zScore.zScore, size: .medium)

                        if zScoreData.isExtreme {
                            PulsingExtremeIndicator(isActive: true, color: AppColors.error)
                        }
                    }

                    // Market implication inline
                    HStack(spacing: 4) {
                        Image(systemName: zScoreData.marketImplication.iconName)
                            .font(.system(size: 10))
                        Text(zScoreData.marketImplication.description)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(zScoreData.marketImplication.color)
                }

                Spacer()

                // Current value
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedValue)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary)

                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            // Simplified stats - 2 columns for cleaner look
            HStack(spacing: 12) {
                // Mean & Std Dev
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mean:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.zScore.mean))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    HStack {
                        Text("Std Dev:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.zScore.standardDeviation))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 40).background(textPrimary.opacity(0.1))

                // SD Bands
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("+2σ:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.sdBands.plus2SD))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                    HStack {
                        Text("-2σ:")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.5))
                        Spacer()
                        Text(formatStatValue(zScoreData.sdBands.minus2SD))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(textPrimary.opacity(0.04))
            )

            // Only show rarity for significant moves (|z| >= 2)
            if zScoreData.isSignificant, let rarity = zScoreData.zScore.rarity, rarity > 1 {
                HStack {
                    Spacer()
                    Text("Occurs ~1 in \(rarity) observations")
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
        }
        .padding(14)
    }

    private var formattedValue: String {
        formatForIndicator(zScoreData.currentValue)
    }

    /// Format a value appropriately for this indicator type
    private func formatStatValue(_ value: Double) -> String {
        formatForIndicator(value)
    }

    /// Format value based on indicator type
    private func formatForIndicator(_ value: Double) -> String {
        switch zScoreData.indicator {
        case .vix:
            return String(format: "%.2f", value)
        case .dxy:
            return String(format: "%.2f", value)
        case .m2:
            return formatLargeNumber(value)
        }
    }

    /// Format large numbers (trillions/billions) for M2
    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "%.2fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "%.1fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Stat Box
/// Small stat display box for z-score analysis
struct StatBox: View {
    let label: String
    let value: String

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Asset Impact Row
/// Shows how a macro indicator affects different asset classes
struct AssetImpactRow: View {
    let indicator: String
    let currentValue: Double?
    let impacts: [(asset: String, impact: (signal: String, description: String, color: Color), icon: String)]

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Indicator header
            HStack {
                Text(indicator)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)

                if let value = currentValue {
                    Text(indicator == "DXY" ? String(format: "%.1f", value) : String(format: "%.1f", value))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Spacer()
            }

            // Asset impacts
            HStack(spacing: 16) {
                ForEach(impacts, id: \.asset) { item in
                    HStack(spacing: 8) {
                        // Asset icon
                        ZStack {
                            Circle()
                                .fill(item.impact.color.opacity(0.15))
                                .frame(width: 28, height: 28)

                            if item.asset == "BTC" {
                                Image(systemName: "bitcoinsign")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(item.impact.color)
                            } else {
                                // Gold circle
                                Circle()
                                    .fill(Color(hex: "FFD700"))
                                    .frame(width: 12, height: 12)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(item.asset)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(textPrimary)

                                Text(item.impact.signal)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(item.impact.color)
                            }

                            Text(item.impact.description)
                                .font(.system(size: 9))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - Learn More Row (Simplified Detail View)
struct LearnMoreRow: View {
    let color: Color
    let label: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// MARK: - Simple Indicator Row (Simplified Detail View)
struct SimpleIndicatorRow: View {
    let icon: String
    let title: String
    let value: String
    var change: Double? = nil
    let status: String
    let statusColor: Color
    var isExpanded: Bool = false

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            // Title
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textPrimary)

            Spacer()

            // Value and change
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)

                    if let change = change {
                        Text(String(format: "%+.1f%%", change))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }

                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(14)
    }
}
