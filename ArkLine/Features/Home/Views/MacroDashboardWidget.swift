import SwiftUI
import UserNotifications

// MARK: - Market Regime
/// Synthesized market conditions based on macro indicators
enum MarketRegime: String, Codable {
    case riskOn = "RISK-ON"
    case riskOff = "RISK-OFF"
    case mixed = "MIXED"
    case noData = "NO DATA"

    var description: String {
        switch self {
        case .riskOn:
            return "Favorable conditions for risk assets"
        case .riskOff:
            return "Defensive positioning recommended"
        case .mixed:
            return "Conflicting signals across indicators"
        case .noData:
            return "Awaiting market data"
        }
    }

    var color: Color {
        switch self {
        case .riskOn: return AppColors.success
        case .riskOff: return AppColors.error
        case .mixed: return AppColors.warning
        case .noData: return AppColors.textSecondary
        }
    }

    var notificationTitle: String {
        switch self {
        case .riskOn: return "Market Regime: RISK-ON"
        case .riskOff: return "Market Regime: RISK-OFF"
        case .mixed: return "Market Regime: MIXED"
        case .noData: return "Market Data Unavailable"
        }
    }

    var notificationBody: String {
        switch self {
        case .riskOn:
            return "Macro conditions have shifted bullish. Low volatility and expanding liquidity favor risk assets."
        case .riskOff:
            return "Macro conditions have shifted bearish. Elevated VIX and dollar strength may pressure crypto."
        case .mixed:
            return "Macro signals are now conflicting. Consider reducing position sizes until clarity emerges."
        case .noData:
            return "Unable to determine market conditions."
        }
    }
}

// MARK: - Correlation Strength
/// Represents how strongly an indicator correlates with crypto
enum CorrelationStrength: Int, CaseIterable {
    case weak = 1
    case moderate = 2
    case strong = 3
    case veryStrong = 4

    var label: String {
        switch self {
        case .weak: return "Weak"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        case .veryStrong: return "Very Strong"
        }
    }

    var description: String {
        switch self {
        case .weak: return "Historical correlation currently weak"
        case .moderate: return "Moderate historical correlation"
        case .strong: return "Strong historical correlation"
        case .veryStrong: return "Very strong correlation observed"
        }
    }
}

// MARK: - Regime Change Manager
/// Manages regime state persistence and change detection
class RegimeChangeManager: ObservableObject {
    static let shared = RegimeChangeManager()

    private let regimeKey = "arkline_last_market_regime"
    private let lastChangeKey = "arkline_last_regime_change"
    private let notificationsEnabledKey = "arkline_regime_notifications_enabled"

    @Published var showRegimeChangeAlert = false
    @Published var regimeChangeInfo: (from: MarketRegime, to: MarketRegime)?

    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: notificationsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey) }
    }

    var lastKnownRegime: MarketRegime? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: regimeKey) else { return nil }
            return MarketRegime(rawValue: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: regimeKey)
        }
    }

    var lastRegimeChange: Date? {
        get { UserDefaults.standard.object(forKey: lastChangeKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastChangeKey) }
    }

    private init() {
        // Default to notifications enabled
        if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
            notificationsEnabled = true
        }
    }

    /// Check if regime has changed and handle accordingly
    func checkRegimeChange(newRegime: MarketRegime) {
        // Skip if no data
        guard newRegime != .noData else { return }

        // Get previous regime
        let previousRegime = lastKnownRegime

        // Check if this is a meaningful change
        if let previous = previousRegime, previous != newRegime {
            // Regime has changed
            regimeChangeInfo = (from: previous, to: newRegime)

            // Update stored regime
            lastKnownRegime = newRegime
            lastRegimeChange = Date()

            // Trigger notifications if enabled
            if notificationsEnabled {
                showRegimeChangeAlert = true
                scheduleLocalNotification(for: newRegime, from: previous)
            }

            logInfo("Market regime changed from \(previous.rawValue) to \(newRegime.rawValue)", category: .data)
        } else if previousRegime == nil {
            // First time seeing a regime, just store it
            lastKnownRegime = newRegime
            lastRegimeChange = Date()
        }
    }

    /// Schedule a local push notification for regime change
    private func scheduleLocalNotification(for newRegime: MarketRegime, from oldRegime: MarketRegime) {
        let content = UNMutableNotificationContent()
        content.title = newRegime.notificationTitle
        content.body = newRegime.notificationBody
        content.sound = .default
        content.badge = 1

        // Add category for actionable notifications
        content.categoryIdentifier = "REGIME_CHANGE"

        // Deliver immediately (with slight delay for system processing)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "regime_change_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logError("Failed to schedule regime change notification: \(error)", category: .data)
            } else {
                logInfo("Regime change notification scheduled", category: .data)
            }
        }
    }

    /// Request notification permissions
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                logInfo("Notification permissions granted", category: .data)
            } else if let error = error {
                logError("Notification permission error: \(error)", category: .data)
            }
        }
    }

    /// Clear the alert state
    func dismissAlert() {
        showRegimeChangeAlert = false
        regimeChangeInfo = nil
    }
}

// MARK: - Macro Dashboard Widget
/// Professional hedge-fund style widget combining VIX, DXY, and Global M2
struct MacroDashboardWidget: View {
    let vixData: VIXData?
    let dxyData: DXYData?
    let liquidityData: GlobalLiquidityChanges?
    var macroZScores: [MacroIndicatorType: MacroZScoreData] = [:]
    var size: WidgetSize = .standard

    @Environment(\.colorScheme) var colorScheme
    @StateObject private var regimeManager = RegimeChangeManager.shared
    @StateObject private var alertManager = ExtremeMoveAlertManager.shared
    @State private var showingDetail = false
    @State private var isPulsing = false

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

    // MARK: - Market Regime Calculation
    private var marketRegime: MarketRegime {
        var bullishSignals = 0
        var bearishSignals = 0
        var totalSignals = 0

        if let vix = vixData {
            totalSignals += 1
            if vix.value < 18 { bullishSignals += 1 }
            else if vix.value > 25 { bearishSignals += 1 }
        }

        if let dxy = dxyData, let change = dxy.changePercent {
            totalSignals += 1
            if change < -0.2 { bullishSignals += 1 }
            else if change > 0.2 { bearishSignals += 1 }
        }

        if let m2 = liquidityData {
            totalSignals += 1
            if m2.monthlyChange > 0.5 { bullishSignals += 1 }
            else if m2.monthlyChange < -0.5 { bearishSignals += 1 }
        }

        guard totalSignals >= 2 else { return .noData }

        if bullishSignals >= 2 && bearishSignals == 0 { return .riskOn }
        if bearishSignals >= 2 && bullishSignals == 0 { return .riskOff }
        return .mixed
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

    // MARK: - Signals
    private var vixSignal: (color: Color, label: String) {
        guard let vix = vixData?.value else { return (.secondary, "--") }
        if vix < 15 { return (AppColors.success, "Low") }
        if vix < 20 { return (Color(hex: "4ADE80"), "Normal") }
        if vix < 25 { return (AppColors.warning, "Elevated") }
        return (AppColors.error, "High")
    }

    private var dxySignal: (color: Color, label: String) {
        guard let change = dxyData?.changePercent else { return (.secondary, "--") }
        if change < -0.3 { return (AppColors.success, "Weak") }
        if change > 0.3 { return (AppColors.error, "Strong") }
        return (AppColors.warning, "Stable")
    }

    private var m2Signal: (color: Color, label: String) {
        guard let m2 = liquidityData else { return (.secondary, "--") }
        if m2.monthlyChange > 1.0 { return (AppColors.success, "Expanding") }
        if m2.monthlyChange > 0 { return (Color(hex: "4ADE80"), "Growing") }
        if m2.monthlyChange > -1.0 { return (AppColors.warning, "Flat") }
        return (AppColors.error, "Contracting")
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
        return SparklineGenerator.vixSparkline(current: vix, seed: Int(Date().timeIntervalSince1970 / 86400))
    }

    private var dxySparkline: [CGFloat] {
        guard let dxy = dxyData?.value else { return [] }
        return SparklineGenerator.dxySparkline(current: dxy, seed: Int(Date().timeIntervalSince1970 / 86400))
    }

    private var m2Sparkline: [CGFloat] {
        guard let m2 = liquidityData else { return [] }
        return SparklineGenerator.m2Sparkline(
            history: m2.history,
            current: m2.current,
            monthlyChange: m2.monthlyChange
        )
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text("MACRO")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .tracking(1.5)

                    Spacer()

                    // Live indicator
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
                        label: "M2",
                        value: liquidityData.map { formatLiquidity($0.current) } ?? "--",
                        change: liquidityData?.monthlyChange,
                        signal: m2Signal,
                        correlation: m2Correlation,
                        sparklineData: m2Sparkline,
                        size: size,
                        zScoreData: macroZScores[.m2]
                    )
                }
                .padding(.vertical, size == .compact ? 8 : 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(subtleBackground)
                )

                // Market Regime Summary
                if size != .compact {
                    HStack(spacing: 8) {
                        // Pulsing regime indicator
                        ZStack {
                            Circle()
                                .fill(marketRegime.color.opacity(0.3))
                                .frame(width: 16, height: 16)
                                .scaleEffect(isPulsing ? 1.3 : 1.0)
                                .opacity(isPulsing ? 0 : 0.5)

                            Circle()
                                .fill(marketRegime.color)
                                .frame(width: 8, height: 8)
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }

                        Text(marketRegime.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundColor(marketRegime.color)

                        Text(marketRegime.description)
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
        .sheet(isPresented: $showingDetail) {
            MacroDashboardDetailView(
                vixData: vixData,
                dxyData: dxyData,
                liquidityData: liquidityData,
                regime: marketRegime,
                vixCorrelation: vixCorrelation,
                dxyCorrelation: dxyCorrelation,
                m2Correlation: m2Correlation,
                macroZScores: macroZScores
            )
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
            regimeManager.checkRegimeChange(newRegime: marketRegime)
        }
        .onChange(of: marketRegime) { _, newRegime in
            regimeManager.checkRegimeChange(newRegime: newRegime)
        }
    }

    private var correlationInsight: String {
        // Dynamic insight based on current correlations
        let strongCorrelations = [vixCorrelation, dxyCorrelation, m2Correlation].filter { $0.rawValue >= 3 }

        if strongCorrelations.count >= 2 {
            return "Multiple indicators showing strong correlation. High conviction environment for macro-driven moves."
        }

        switch marketRegime {
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
    let correlation: CorrelationStrength
    let sparklineData: [CGFloat]
    let size: WidgetSize
    var zScoreData: MacroZScoreData?

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var valueFontSize: CGFloat {
        switch size {
        case .compact: return 18
        case .standard: return 22
        case .expanded: return 26
        }
    }

    private var sparklineColor: Color {
        // Use signal color for sparkline
        signal.color.opacity(0.8)
    }

    var body: some View {
        VStack(spacing: size == .compact ? 4 : 6) {
            // Label with correlation bars and extreme indicator
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))

                if size != .compact {
                    CorrelationBars(strength: correlation)
                }

                // Pulsing indicator for extreme moves
                if let zScore = zScoreData, zScore.isExtreme {
                    PulsingExtremeIndicator(isActive: true, color: AppColors.error)
                }
            }

            // Value with z-score badge
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: valueFontSize, weight: .semibold, design: .default))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                if let zScore = zScoreData, size != .compact {
                    ZScoreIndicator(zScore: zScore.zScore.zScore, size: .small)
                } else if let change = change, size != .compact {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
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

            // Signal badge
            HStack(spacing: 4) {
                Circle()
                    .fill(signal.color)
                    .frame(width: 5, height: 5)

                Text(signal.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(signal.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sparkline View
/// Minimal trend line showing recent history with optional gradient fill
struct SparklineView: View {
    let data: [CGFloat]  // Normalized values 0-1
    let color: Color
    let height: CGFloat
    let showGradientFill: Bool

    init(data: [CGFloat], color: Color = .white, height: CGFloat = 14, showGradientFill: Bool = false) {
        self.data = data
        self.color = color
        self.height = height
        self.showGradientFill = showGradientFill
    }

    var body: some View {
        GeometryReader { geometry in
            if data.count >= 2 {
                let width = geometry.size.width
                let stepX = width / CGFloat(data.count - 1)

                ZStack {
                    // Gradient fill under the line
                    if showGradientFill {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height))

                            for (index, value) in data.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height - (value * height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }

                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // The line itself
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (value * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Sparkline Data Generator
/// Generates representative sparkline data when historical data isn't available
enum SparklineGenerator {

    /// Generate VIX sparkline (7 days)
    /// VIX typically mean-reverts around 15-20, with occasional spikes
    static func vixSparkline(current: Double, seed: Int = 0) -> [CGFloat] {
        srand48(seed)
        var data: [CGFloat] = []

        // Work backwards from current value
        var value = current
        for i in 0..<7 {
            // Normalize VIX to 0-1 scale (10-40 range)
            let normalized = CGFloat(max(0, min(1, (value - 10) / 30)))
            data.insert(normalized, at: 0)

            // Generate previous day with mean reversion toward 18
            let meanReversion = (18 - value) * 0.1
            let noise = (drand48() - 0.5) * 3
            value = max(10, min(40, value - meanReversion + noise))
        }

        return data
    }

    /// Generate DXY sparkline (7 days)
    /// DXY is typically stable with small movements (90-110 range)
    static func dxySparkline(current: Double, seed: Int = 0) -> [CGFloat] {
        srand48(seed)
        var data: [CGFloat] = []

        var value = current
        for i in 0..<7 {
            // Normalize DXY to 0-1 scale (95-115 range)
            let normalized = CGFloat(max(0, min(1, (value - 95) / 20)))
            data.insert(normalized, at: 0)

            // DXY moves slowly
            let noise = (drand48() - 0.5) * 0.8
            value = max(95, min(115, value + noise))
        }

        return data
    }

    /// Generate M2 sparkline from actual history or simulated
    static func m2Sparkline(history: [GlobalLiquidityData]?, current: Double, monthlyChange: Double) -> [CGFloat] {
        // Use actual history if available
        if let history = history, history.count >= 2 {
            let values = history.suffix(7).map { $0.value }
            let minVal = values.min() ?? current * 0.98
            let maxVal = values.max() ?? current * 1.02
            let range = max(maxVal - minVal, current * 0.01) // Avoid division by zero

            return values.map { CGFloat(($0 - minVal) / range) }
        }

        // Otherwise generate based on monthly trend
        var data: [CGFloat] = []
        let dailyChange = monthlyChange / 30.0
        var value = current

        srand48(Int(current) % 1000)

        for _ in 0..<7 {
            data.insert(0.5, at: 0) // Will normalize after
            let noise = (drand48() - 0.5) * 0.1
            value = value / (1 + (dailyChange + noise) / 100)
        }

        // Create trend line
        let trendUp = monthlyChange > 0
        return (0..<7).map { i in
            let progress = CGFloat(i) / 6.0
            let base: CGFloat = trendUp ? 0.3 : 0.7
            let trend: CGFloat = trendUp ? 0.4 : -0.4
            let noise = CGFloat(drand48() - 0.5) * 0.1
            return max(0, min(1, base + trend * progress + noise))
        }
    }
}

// MARK: - Correlation Strength Bars
/// Visual indicator showing correlation strength (like WiFi bars)
struct CorrelationBars: View {
    let strength: CorrelationStrength
    @Environment(\.colorScheme) var colorScheme

    private var activeColor: Color {
        switch strength {
        case .weak: return AppColors.textSecondary
        case .moderate: return AppColors.warning
        case .strong: return AppColors.accent
        case .veryStrong: return AppColors.success
        }
    }

    private var inactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
    }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= strength.rawValue ? activeColor : inactiveColor)
                    .frame(width: 2, height: CGFloat(bar * 2 + 2))
            }
        }
    }
}

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Regime Card
                    VStack(spacing: 16) {
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

                        // Last change info
                        if let lastChange = regimeManager.lastRegimeChange {
                            Text("Since \(lastChange.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12))
                                .foregroundColor(textPrimary.opacity(0.4))
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )

                    // Signal Key Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SIGNAL KEY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            SignalKeyRow(
                                signal: "RISK-ON",
                                color: AppColors.success,
                                meaning: "Favorable for crypto",
                                description: "Low volatility, weak dollar, expanding liquidity. Historically positive for Bitcoin."
                            )

                            Divider().background(textPrimary.opacity(0.08))

                            SignalKeyRow(
                                signal: "MIXED",
                                color: AppColors.warning,
                                meaning: "Conflicting signals",
                                description: "Indicators disagree. Consider smaller positions until clarity emerges."
                            )

                            Divider().background(textPrimary.opacity(0.08))

                            SignalKeyRow(
                                signal: "RISK-OFF",
                                color: AppColors.error,
                                meaning: "Caution advised",
                                description: "High volatility, strong dollar, or tightening liquidity. Defensive positioning recommended."
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Notification Toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALERTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Regime Change Notifications")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(textPrimary)

                                    Text("Get notified when market conditions shift")
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

                            Divider().background(textPrimary.opacity(0.08))

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("Extreme Move Alerts")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(textPrimary)

                                        Text("±3σ")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(AppColors.error))
                                    }

                                    Text("Alert when indicators hit statistical extremes")
                                        .font(.system(size: 12))
                                        .foregroundColor(textPrimary.opacity(0.5))
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { alertManager.extremeAlertsEnabled },
                                    set: { newValue in
                                        alertManager.extremeAlertsEnabled = newValue
                                        if newValue {
                                            alertManager.requestNotificationPermissions()
                                        }
                                    }
                                ))
                                .labelsHidden()
                                .tint(AppColors.accent)
                            }
                            .padding(16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Z-Score Analysis Section (only show if we have z-scores)
                    if !macroZScores.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("STATISTICAL ANALYSIS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .tracking(1.5)

                            VStack(spacing: 0) {
                                ForEach(Array(macroZScores.values.sorted { $0.indicator.rawValue < $1.indicator.rawValue })) { zScore in
                                    ZScoreAnalysisRow(zScoreData: zScore)

                                    if zScore.indicator != .m2 {
                                        Divider().background(textPrimary.opacity(0.08))
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackground)
                            )

                            Text("Z-scores measure how many standard deviations the current value is from the historical mean (90-day rolling window).")
                                .font(.system(size: 10))
                                .foregroundColor(textPrimary.opacity(0.4))
                                .padding(.top, 4)
                        }
                    }

                    // Correlation Strength Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CORRELATION STRENGTH")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            CorrelationDetailRow(
                                indicator: "VIX",
                                strength: vixCorrelation,
                                relationship: "Inverse",
                                explanation: "High VIX typically precedes crypto drawdowns"
                            )

                            Divider().background(textPrimary.opacity(0.08))

                            CorrelationDetailRow(
                                indicator: "DXY",
                                strength: dxyCorrelation,
                                relationship: "Inverse",
                                explanation: "Strong dollar pressures BTC denominated in USD"
                            )

                            Divider().background(textPrimary.opacity(0.08))

                            CorrelationDetailRow(
                                indicator: "Global M2",
                                strength: m2Correlation,
                                relationship: "Positive (lagged)",
                                explanation: "BTC follows M2 with ~2-3 month delay"
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Individual Indicators
                    VStack(alignment: .leading, spacing: 12) {
                        Text("INDICATORS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        MacroDetailRow(
                            icon: "waveform.path.ecg",
                            title: "VIX",
                            subtitle: "Volatility Index",
                            value: vixData.map { String(format: "%.2f", $0.value) } ?? "--",
                            change: nil,
                            interpretation: vixZScoreInterpretation,
                            correlation: vixCorrelation,
                            zScoreData: macroZScores[.vix]
                        )

                        MacroDetailRow(
                            icon: "dollarsign.circle",
                            title: "DXY",
                            subtitle: "US Dollar Index",
                            value: dxyData.map { String(format: "%.2f", $0.value) } ?? "--",
                            change: dxyData?.changePercent,
                            interpretation: dxyZScoreInterpretation,
                            correlation: dxyCorrelation,
                            zScoreData: macroZScores[.dxy]
                        )

                        MacroDetailRow(
                            icon: "banknote",
                            title: "Global M2",
                            subtitle: "Money Supply",
                            value: liquidityData.map { formatLiquidity($0.current) } ?? "--",
                            change: liquidityData?.monthlyChange,
                            interpretation: m2ZScoreInterpretation,
                            correlation: m2Correlation,
                            zScoreData: macroZScores[.m2]
                        )
                    }

                    // Regime Thresholds
                    VStack(alignment: .leading, spacing: 12) {
                        Text("REGIME THRESHOLDS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            ThresholdRow(indicator: "VIX", bullish: "< 18", bearish: "> 25")
                            Divider().background(textPrimary.opacity(0.08))
                            ThresholdRow(indicator: "DXY", bullish: "Falling", bearish: "Rising")
                            Divider().background(textPrimary.opacity(0.08))
                            ThresholdRow(indicator: "M2", bullish: "Growing", bearish: "Shrinking")
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )
                    }

                    // Asset Impact Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ASSET IMPACT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1.5)

                        VStack(spacing: 0) {
                            AssetImpactRow(
                                indicator: "VIX",
                                currentValue: vixData?.value,
                                impacts: [
                                    ("BTC", vixBtcImpact, "chart.line.downtrend.xyaxis"),
                                    ("Gold", vixGoldImpact, "circle.fill")
                                ]
                            )
                            Divider().background(textPrimary.opacity(0.08))
                            AssetImpactRow(
                                indicator: "DXY",
                                currentValue: dxyData?.value,
                                impacts: [
                                    ("BTC", dxyBtcImpact, "bitcoinsign.circle"),
                                    ("Gold", dxyGoldImpact, "circle.fill")
                                ]
                            )
                            Divider().background(textPrimary.opacity(0.08))
                            AssetImpactRow(
                                indicator: "M2",
                                currentValue: nil,
                                impacts: [
                                    ("BTC", m2BtcImpact, "bitcoinsign.circle"),
                                    ("Gold", m2GoldImpact, "circle.fill")
                                ]
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(cardBackground)
                        )

                        // Historical context note
                        Text("Based on historical correlations. Past performance does not guarantee future results.")
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.4))
                            .padding(.top, 4)
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

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        MacroDashboardWidget(
            vixData: VIXData(date: "2024-01-25", value: 16.5, open: 17.0, high: 17.5, low: 16.0, close: 16.5),
            dxyData: DXYData(date: "2024-01-25", value: 103.42, open: 103.5, high: 103.8, low: 103.1, close: 103.42, previousClose: 103.7),
            liquidityData: GlobalLiquidityChanges(current: 21_300_000_000_000, dailyChange: 0.1, weeklyChange: 0.3, monthlyChange: 1.2, yearlyChange: 4.5, history: []),
            size: .standard
        )

        MacroDashboardWidget(
            vixData: VIXData(date: "2024-01-25", value: 28.5, open: 27.0, high: 29.5, low: 26.0, close: 28.5),
            dxyData: DXYData(date: "2024-01-25", value: 105.42, open: 104.5, high: 105.8, low: 104.1, close: 105.42, previousClose: 104.7),
            liquidityData: GlobalLiquidityChanges(current: 20_100_000_000_000, dailyChange: -0.1, weeklyChange: -0.5, monthlyChange: -1.8, yearlyChange: -2.5, history: []),
            size: .expanded
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
