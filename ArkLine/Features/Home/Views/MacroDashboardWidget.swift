import SwiftUI

// MARK: - Macro Dashboard Widget
/// Professional hedge-fund style widget combining VIX, DXY, and Global M2
struct MacroDashboardWidget: View {
    let vixData: VIXData?
    let dxyData: DXYData?
    let liquidityData: GlobalLiquidityChanges?
    var netLiquidityData: NetLiquidityChanges? = nil
    var globalLiquidityIndex: GlobalLiquidityIndex? = nil
    var vixHistory: [VIXData] = []
    var dxyHistory: [DXYData] = []
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]
    var regime: MarketRegime = .noData
    var quadrant: MacroRegimeQuadrant? = nil
    var size: WidgetSize = .standard

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var regimeManager = RegimeChangeManager.shared
    @ObservedObject private var alertManager = ExtremeMoveAlertManager.shared
    @State private var showingDetail = false
    @State private var showPaywall = false
    @State private var isPulsing = false
    @Environment(\.scenePhase) private var scenePhase

    /// Whether any indicator has an extreme z-score
    private var hasExtremeMove: Bool {
        macroZScores.values.contains { $0.isExtreme }
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    private var subtleBackground: Color {
        colorScheme == .dark ? Color(hex: "242424") : Color(hex: "F5F5F7")
    }

    // MARK: - Correlation Strength Calculations
    /// VIX correlation with crypto (inverse relationship)
    private var vixCorrelation: CorrelationStrength {
        guard let vix = vixData?.value else { return .weak }
        // VIX has strong inverse correlation during high volatility
        if vix > 30 { return .veryStrong }
        if vix > 25 { return .strong }
        if vix > 18 { return .moderate }
        return .weak
    }

    /// DXY correlation with crypto (inverse relationship)
    private var dxyCorrelation: CorrelationStrength {
        guard let change = dxyData?.changePercent else { return .weak }
        // DXY correlation strengthens during significant moves
        let absChange = abs(change)
        if absChange > 0.8 { return .veryStrong }
        if absChange > 0.5 { return .strong }
        if absChange > 0.2 { return .moderate }
        return .weak
    }

    /// M2 correlation with crypto (positive relationship with lag)
    private var m2Correlation: CorrelationStrength {
        guard let m2 = liquidityData else { return .weak }
        // M2 has strong long-term correlation
        let absChange = abs(m2.monthlyChange)
        if absChange > 2.0 { return .veryStrong }
        if absChange > 1.0 { return .strong }
        if absChange > 0.5 { return .moderate }
        return .weak
    }

    // MARK: - Signals (indicator-level labels, shown in expanded mode)
    private var vixSignal: (color: Color, label: String) {
        guard let vix = vixData?.value else { return (.secondary, "--") }
        if vix < 20 { return (AppColors.success, "Bullish") }
        if vix < 25 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    private var dxySignal: (color: Color, label: String) {
        guard let dxy = dxyData?.value else { return (.secondary, "--") }
        if dxy < 100 { return (AppColors.success, "Bullish") }
        if dxy < 105 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    private var m2Signal: (color: Color, label: String) {
        guard let m2 = liquidityData else { return (.secondary, "--") }
        if m2.monthlyChange > 0 { return (AppColors.success, "Bullish") }
        if m2.monthlyChange > -1.0 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    // MARK: - Crypto Signal Mappings
    /// VIX → crypto (inverse): low VIX = bullish for crypto
    private var vixCryptoSignal: (color: Color, label: String) {
        guard let vix = vixData?.value else { return (.secondary, "--") }
        if vix < 20 { return (AppColors.success, "Bullish") }
        if vix < 25 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    /// DXY → crypto (inverse): weak dollar environment = bullish for crypto
    /// Uses absolute level rather than daily change for investing relevance
    private var dxyCryptoSignal: (color: Color, label: String) {
        guard let dxy = dxyData?.value else { return (.secondary, "--") }
        if dxy < 100 { return (AppColors.success, "Bullish") }
        if dxy < 105 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    /// M2 → crypto (positive): expanding liquidity = bullish for crypto
    private var m2CryptoSignal: (color: Color, label: String) {
        guard let m2 = liquidityData else { return (.secondary, "--") }
        if m2.monthlyChange > 0 { return (AppColors.success, "Bullish") }
        if m2.monthlyChange > -1.0 { return (AppColors.warning, "Neutral") }
        return (AppColors.error, "Bearish")
    }

    // MARK: - Liquidity Signals (uses Global CB Liquidity when available, falls back to Net Liq)
    private var liqLabel: String {
        globalLiquidityIndex != nil ? "CB Liq" : "Net Liq"
    }

    private var liqValue: String {
        if let gli = globalLiquidityIndex {
            return String(format: "%.1fT", gli.compositeLiquidityT)
        }
        return netLiquidityData.map { formatLiquidity($0.current) } ?? "--"
    }

    private var liqChange: Double? {
        if let gli = globalLiquidityIndex {
            return gli.changes.monthly
        }
        return netLiquidityData?.weeklyChange
    }

    private var netLiqSignal: (color: Color, label: String) {
        if let gli = globalLiquidityIndex {
            switch gli.signal {
            case "expanding": return (AppColors.success, "Bullish")
            case "contracting": return (AppColors.error, "Bearish")
            default: return (AppColors.warning, "Neutral")
            }
        }
        guard let nl = netLiquidityData else { return (.secondary, "--") }
        if nl.weeklyChange > 0.5 { return (AppColors.success, "Bullish") }
        if nl.weeklyChange < -0.5 { return (AppColors.error, "Bearish") }
        return (AppColors.warning, "Neutral")
    }

    private var netLiqCryptoSignal: (color: Color, label: String) {
        netLiqSignal  // Same as indicator signal (positive correlation)
    }

    private var netLiqCorrelation: CorrelationStrength {
        if let gli = globalLiquidityIndex {
            let absChange = abs(gli.monthlyChange)
            if absChange > 2.0 { return .veryStrong }
            if absChange > 1.0 { return .strong }
            if absChange > 0.5 { return .moderate }
            return .weak
        }
        guard let nl = netLiquidityData else { return .weak }
        let absChange = abs(nl.weeklyChange)
        if absChange > 2.0 { return .veryStrong }
        if absChange > 1.0 { return .strong }
        if absChange > 0.5 { return .moderate }
        return .weak
    }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "%.1fT", value / 1_000_000_000_000)
        }
        return String(format: "%.0fB", value / 1_000_000_000)
    }

    // MARK: - Sparkline Data
    private var vixSparkline: [CGFloat] {
        guard let vix = vixData?.value else { return [] }
        return SparklineGenerator.vixSparkline(
            history: vixHistory.isEmpty ? nil : vixHistory,
            current: vix,
            seed: Int(Date().timeIntervalSince1970 / 86400)
        )
    }

    private var dxySparkline: [CGFloat] {
        guard let dxy = dxyData?.value else { return [] }
        return SparklineGenerator.dxySparkline(
            history: dxyHistory.isEmpty ? nil : dxyHistory,
            current: dxy,
            seed: Int(Date().timeIntervalSince1970 / 86400)
        )
    }

    private var m2Sparkline: [CGFloat] {
        guard let m2 = liquidityData else { return [] }
        return SparklineGenerator.m2Sparkline(
            history: m2.history,
            current: m2.current,
            monthlyChange: m2.monthlyChange
        )
    }

    private var netLiqSparkline: [CGFloat] {
        guard let nl = netLiquidityData else { return [] }
        return SparklineGenerator.m2Sparkline(
            history: nl.history,
            current: nl.current,
            monthlyChange: nl.weeklyChange
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header outside the card (matches Core section style)
            Text("Macro")
                .font(size == .compact ? .subheadline : .title3)
                .foregroundColor(textPrimary)

            Button(action: { showingDetail = true }) {
                VStack(spacing: 0) {
                    // Live indicator row
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.success)
                                .frame(width: 6, height: 6)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(textPrimary.opacity(0.4))
                        }
                    }
                    .padding(.bottom, size == .compact ? 8 : 12)

                    // Three-column indicator grid with correlation strength and sparklines
                HStack(spacing: 0) {
                    MacroIndicatorColumn(
                        label: "VIX",
                        value: vixData.map { String(format: "%.1f", $0.value) } ?? "--",
                        change: nil,
                        signal: vixSignal,
                        cryptoSignal: vixCryptoSignal,
                        correlation: vixCorrelation,
                        sparklineData: vixSparkline,
                        size: size,
                        zScoreData: macroZScores[.vix]
                    )

                    Rectangle()
                        .fill(textPrimary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    MacroIndicatorColumn(
                        label: "DXY",
                        value: dxyData.map { String(format: "%.1f", $0.value) } ?? "--",
                        change: dxyData?.changePercent,
                        signal: dxySignal,
                        cryptoSignal: dxyCryptoSignal,
                        correlation: dxyCorrelation,
                        sparklineData: dxySparkline,
                        size: size,
                        zScoreData: macroZScores[.dxy]
                    )

                    Rectangle()
                        .fill(textPrimary.opacity(0.08))
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    MacroIndicatorColumn(
                        label: liqLabel,
                        value: liqValue,
                        change: liqChange,
                        signal: netLiqSignal,
                        cryptoSignal: netLiqCryptoSignal,
                        correlation: netLiqCorrelation,
                        sparklineData: netLiqSparkline,
                        size: size,
                        zScoreData: macroZScores[.netLiquidity]
                    )
                }
                .padding(.vertical, size == .compact ? 8 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(subtleBackground)
                )

                // Market Regime Summary
                if size != .compact {
                    let displayColor = quadrant?.color ?? regime.color
                    let displayLabel = quadrant?.rawValue ?? regime.rawValue
                    let displayDesc = quadrant?.description ?? regime.description
                    HStack(spacing: 8) {
                        // Pulsing regime indicator
                        ZStack {
                            Circle()
                                .fill(displayColor.opacity(0.3))
                                .frame(width: 16, height: 16)
                                .scaleEffect(isPulsing ? 1.3 : 1.0)
                                .opacity(isPulsing ? 0 : 0.5)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)

                            Circle()
                                .fill(displayColor)
                                .frame(width: 8, height: 8)
                        }
                        .onAppear { isPulsing = true }

                        Text(displayLabel)
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundColor(displayColor)

                        Text(displayDesc)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                    .padding(.top, 12)
                }

                // Expanded: Correlation insight
                if size == .expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                            .background(textPrimary.opacity(0.08))
                            .padding(.vertical, 8)

                        Text("CORRELATION INSIGHT")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.4))
                            .tracking(1)

                        Text(correlationInsight)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .lineLimit(2)
                    }
                }
            }
            .padding(size == .compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 18)
                    .fill(cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 18)
                    .stroke(textPrimary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Macro Dashboard, \(quadrant?.rawValue ?? regime.rawValue), \(quadrant?.description ?? regime.description)")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            if appState.isPro {
                MacroDashboardDetailView(
                    vixData: vixData,
                    dxyData: dxyData,
                    liquidityData: liquidityData,
                    netLiquidityData: netLiquidityData,
                    globalLiquidityIndex: globalLiquidityIndex,
                    regime: regime,
                    quadrant: quadrant,
                    vixCorrelation: vixCorrelation,
                    dxyCorrelation: dxyCorrelation,
                    m2Correlation: m2Correlation,
                    macroZScores: macroZScores
                )
            } else {
                PaywallView(feature: .macroDetail)
            }
        }
        .alert("Market Regime Changed", isPresented: $regimeManager.showRegimeChangeAlert) {
            Button("View Details") {
                regimeManager.dismissAlert()
                showingDetail = true
            }
            Button("Dismiss", role: .cancel) {
                regimeManager.dismissAlert()
            }
        } message: {
            if let info = regimeManager.regimeChangeInfo {
                Text("Macro conditions shifted from \(info.from.rawValue) to \(info.to.rawValue). \(info.to.description)")
            }
        }
        .onAppear {
            regimeManager.checkRegimeChange(newRegime: regime)
        }
        .onChange(of: regime) { _, newRegime in
            regimeManager.checkRegimeChange(newRegime: newRegime)
        }
        .onChange(of: scenePhase) { _, phase in
            isPulsing = (phase == .active)
        }
        } // Close outer VStack
    }

    private var correlationInsight: String {
        // Dynamic insight based on current correlations
        let strongCorrelations = [vixCorrelation, dxyCorrelation, m2Correlation, netLiqCorrelation].filter { $0.rawValue >= 3 }

        if strongCorrelations.count >= 2 {
            return "Multiple indicators showing strong correlation. High conviction environment for macro-driven moves."
        }

        switch regime {
        case .riskOn:
            return "Low volatility and expanding liquidity historically favor crypto appreciation."
        case .riskOff:
            return "Elevated VIX and dollar strength typically pressure risk assets."
        case .mixed:
            return "Mixed signals suggest range-bound conditions. Monitor for regime shift."
        case .noData:
            return "Insufficient data to determine market regime."
        }
    }
}

// MARK: - Macro Indicator Column (Updated with Correlation & Sparkline)
struct MacroIndicatorColumn: View {
    let label: String
    let value: String
    let change: Double?
    let signal: (color: Color, label: String)
    let cryptoSignal: (color: Color, label: String)
    let correlation: CorrelationStrength
    let sparklineData: [CGFloat]
    let size: WidgetSize
    var zScoreData: MacroZScoreData?

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sparklineColor: Color {
        cryptoSignal.color.opacity(0.8)
    }

    var body: some View {
        VStack(spacing: size == .compact ? 4 : 6) {
            // Label
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.5))

            // Crypto signal (primary visual)
            HStack(spacing: 4) {
                Circle()
                    .fill(cryptoSignal.color)
                    .frame(width: 6, height: 6)

                Text(cryptoSignal.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(cryptoSignal.color)
            }

            // Sparkline (only show in standard and expanded)
            if size != .compact && !sparklineData.isEmpty {
                SparklineView(
                    data: sparklineData,
                    color: sparklineColor,
                    height: size == .expanded ? 20 : 16,
                    showGradientFill: true
                )
                .frame(width: 65)
                .padding(.vertical, 2)
            }

            // Raw value (secondary, dimmed)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(textPrimary.opacity(0.5))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MacroDashboardWidget(
            vixData: VIXData(date: "2024-01-25", value: 16.5, open: 17.0, high: 17.5, low: 16.0, close: 16.5),
            dxyData: DXYData(date: "2024-01-25", value: 103.42, open: 103.5, high: 103.8, low: 103.1, close: 103.42, previousClose: 103.7),
            liquidityData: GlobalLiquidityChanges(current: 21_300_000_000_000, dailyChange: 0.1, weeklyChange: 0.3, monthlyChange: 1.2, yearlyChange: 4.5, history: []),
            regime: .riskOn,
            size: .standard
        )

        MacroDashboardWidget(
            vixData: VIXData(date: "2024-01-25", value: 28.5, open: 27.0, high: 29.5, low: 26.0, close: 28.5),
            dxyData: DXYData(date: "2024-01-25", value: 105.42, open: 104.5, high: 105.8, low: 104.1, close: 105.42, previousClose: 104.7),
            liquidityData: GlobalLiquidityChanges(current: 20_100_000_000_000, dailyChange: -0.1, weeklyChange: -0.5, monthlyChange: -1.8, yearlyChange: -2.5, history: []),
            regime: .mixed,
            size: .expanded
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
