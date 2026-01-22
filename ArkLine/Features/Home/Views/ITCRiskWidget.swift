import SwiftUI
import Charts

// MARK: - ITC Risk Level Widget (Home Screen)
/// Compact widget for displaying Into The Cryptoverse Risk Level on the Home screen
struct ITCRiskWidget: View {
    let riskLevel: ITCRiskLevel?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    // MARK: - Sizing
    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 50
        case .standard: return 70
        case .expanded: return 90
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 5
        case .standard: return 8
        case .expanded: return 10
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            Group {
                if let risk = riskLevel {
                    contentView(risk: risk)
                } else {
                    placeholderView
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ITCRiskChartView()
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private func contentView(risk: ITCRiskLevel) -> some View {
        HStack(spacing: size == .compact ? 12 : 16) {
            // Latest Value Display (ITC Style)
            VStack(alignment: .leading, spacing: size == .compact ? 4 : 8) {
                HStack(spacing: 6) {
                    Text("ITC Risk Level")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                }

                // Large colored risk value (ITC style)
                Text(String(format: "%.3f", risk.riskLevel))
                    .font(.system(size: size == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(ITCRiskColors.color(for: risk.riskLevel))

                // Risk category badge with colored dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(ITCRiskColors.color(for: risk.riskLevel))
                        .frame(width: 8, height: 8)

                    Text(ITCRiskColors.category(for: risk.riskLevel))
                        .font(size == .compact ? .caption : .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ITCRiskColors.color(for: risk.riskLevel))
                }

                if size != .compact {
                    Text("Powered by Into The Cryptoverse")
                        .font(.caption2)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }

            Spacer()

            // Mini gauge
            ITCRiskGauge(
                riskLevel: risk.riskLevel,
                size: gaugeSize,
                strokeWidth: strokeWidth,
                colorScheme: colorScheme
            )
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Placeholder View
    private var placeholderView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ITC Risk Level")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Text("--")
                    .font(.system(size: size == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary.opacity(0.3))

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            Spacer()

            // Skeleton gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: strokeWidth
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - ITC Risk Gauge
/// Circular gauge showing the risk level with gradient coloring
struct ITCRiskGauge: View {
    let riskLevel: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        ITCRiskColors.color(for: riskLevel)
    }

    private var riskColorLight: Color {
        riskColor.opacity(0.6)
    }

    private var displayValue: String {
        String(format: "%.2f", riskLevel)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: strokeWidth
                )
                .frame(width: size, height: size)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    LinearGradient(
                        colors: [riskColorLight, riskColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Subtle glow effect
            Circle()
                .fill(riskColor.opacity(0.2))
                .blur(radius: size * 0.15)
                .frame(width: size * 0.6, height: size * 0.6)

            // Risk level value (0.00 - 1.00 format)
            Text(displayValue)
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - ITC Risk Colors (6-Tier System)
/// Provides colors based on Into The Cryptoverse 6-tier risk level thresholds
struct ITCRiskColors {
    // 6-tier color palette matching ITC app
    static let veryLowRisk = Color(hex: "3B82F6")   // Blue
    static let lowRisk = Color(hex: "22C55E")       // Green
    static let neutral = Color(hex: "EAB308")       // Yellow
    static let elevatedRisk = Color(hex: "F97316") // Orange
    static let highRisk = Color(hex: "EF4444")      // Red
    static let extremeRisk = Color(hex: "991B1B")   // Maroon

    /// Returns the appropriate color for a given risk level (0.0 - 1.0) using 6-tier system
    static func color(for level: Double) -> Color {
        switch level {
        case 0..<0.20:
            return veryLowRisk
        case 0.20..<0.40:
            return lowRisk
        case 0.40..<0.55:
            return neutral
        case 0.55..<0.70:
            return elevatedRisk
        case 0.70..<0.90:
            return highRisk
        default:
            return extremeRisk
        }
    }

    /// Returns the category name for a given risk level using 6-tier system
    static func category(for level: Double) -> String {
        switch level {
        case 0..<0.20:
            return "Very Low Risk"
        case 0.20..<0.40:
            return "Low Risk"
        case 0.40..<0.55:
            return "Neutral"
        case 0.55..<0.70:
            return "Elevated Risk"
        case 0.70..<0.90:
            return "High Risk"
        default:
            return "Extreme Risk"
        }
    }

    /// Returns description for a given risk level
    static func description(for level: Double) -> String {
        switch level {
        case 0..<0.20:
            return "Deep value range, historically excellent accumulation zone"
        case 0.20..<0.40:
            return "Still favorable accumulation, attractive for multi-year investors"
        case 0.40..<0.55:
            return "Mid-cycle territory, neither strong buy nor sell"
        case 0.55..<0.70:
            return "Late-cycle behavior, higher probability of corrections"
        case 0.70..<0.90:
            return "Historically blow-off-top region, major cycle tops occur here"
        default:
            return "Historically where macro tops happen, smart-money distribution"
        }
    }

    /// Returns a gradient for the risk gauge
    static func gradient(for level: Double, colorScheme: ColorScheme) -> LinearGradient {
        let riskColor = self.color(for: level)
        return LinearGradient(
            colors: [riskColor.opacity(0.6), riskColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Legacy method for backward compatibility
    static func color(for level: Double, colorScheme: ColorScheme) -> Color {
        return color(for: level)
    }
}

// MARK: - Time Range for Chart
enum ITCTimeRange: String, CaseIterable {
    case all = "All"
    case oneYear = "1y"
    case ninetyDays = "90d"
    case thirtyDays = "30d"
    case sevenDays = "7d"

    var days: Int? {
        switch self {
        case .all: return nil
        case .oneYear: return 365
        case .ninetyDays: return 90
        case .thirtyDays: return 30
        case .sevenDays: return 7
        }
    }
}

// MARK: - Supported Coins
enum ITCCoin: String, CaseIterable {
    case btc = "BTC"
    case eth = "ETH"

    var displayName: String {
        switch self {
        case .btc: return "Bitcoin"
        case .eth: return "Ethereum"
        }
    }
}

// MARK: - ITC Risk Chart View (Full Screen Detail)
struct ITCRiskChartView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SentimentViewModel()
    @State private var selectedTimeRange: ITCTimeRange = .all
    @State private var selectedCoin: ITCCoin = .btc

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    // Get current risk level based on selected coin
    private var currentRiskLevel: ITCRiskLevel? {
        switch selectedCoin {
        case .btc: return viewModel.btcRiskLevel
        case .eth: return viewModel.ethRiskLevel
        }
    }

    // Get history based on selected coin (currently only BTC history is available)
    private var riskHistory: [ITCRiskLevel] {
        switch selectedCoin {
        case .btc: return viewModel.btcRiskHistory
        case .eth: return [] // ETH history not available yet
        }
    }

    // Filter history based on time range
    private var filteredHistory: [ITCRiskLevel] {
        guard let days = selectedTimeRange.days else { return riskHistory }
        return Array(riskHistory.suffix(days))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MeshGradientBackground()
                if isDarkMode { BrushEffectOverlay() }

                ScrollView {
                    VStack(spacing: ArkSpacing.xl) {
                        // Time Range Picker
                        timeRangePicker
                            .padding(.top, ArkSpacing.md)

                        // Coin Selector
                        coinSelector

                        // Chart Area
                        chartSection

                        // Latest Value Section
                        latestValueSection

                        // Risk Legend (6-tier)
                        riskLegendSection

                        // Attribution
                        attributionCard

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                }
            }
            .navigationTitle("Risk Level")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            #endif
        }
    }

    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ArkSpacing.xs) {
                ForEach(ITCTimeRange.allCases, id: \.self) { range in
                    Button(action: { selectedTimeRange = range }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                            .foregroundColor(
                                selectedTimeRange == range
                                    ? (colorScheme == .dark ? .white : .white)
                                    : textPrimary
                            )
                            .padding(.horizontal, ArkSpacing.md)
                            .padding(.vertical, ArkSpacing.sm)
                            .background(
                                selectedTimeRange == range
                                    ? AppColors.accent
                                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            )
                            .cornerRadius(ArkSpacing.Radius.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, ArkSpacing.xxs)
        }
    }

    // MARK: - Coin Selector
    private var coinSelector: some View {
        HStack(spacing: ArkSpacing.sm) {
            ForEach(ITCCoin.allCases, id: \.self) { coin in
                Button(action: { selectedCoin = coin }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: coin == .btc ? "bitcoinsign.circle.fill" : "e.circle.fill")
                            .font(.system(size: 16))

                        Text(coin.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(
                        selectedCoin == coin
                            ? (colorScheme == .dark ? .white : .white)
                            : textPrimary
                    )
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(
                        selectedCoin == coin
                            ? AppColors.accent
                            : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
                    .cornerRadius(ArkSpacing.Radius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            if filteredHistory.isEmpty {
                // Placeholder when no data
                VStack(spacing: ArkSpacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(textSecondary.opacity(0.5))

                    Text(selectedCoin == .eth ? "ETH history coming soon" : "Loading chart data...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else {
                // Chart with Swift Charts
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("\(selectedCoin.displayName) Risk Level")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    ITCRiskChart(history: filteredHistory, colorScheme: colorScheme)
                        .frame(height: 250)
                }
                .padding(ArkSpacing.md)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            }
        }
    }

    // MARK: - Latest Value Section
    private var latestValueSection: some View {
        VStack(spacing: ArkSpacing.md) {
            Text("Latest Value")
                .font(.subheadline)
                .foregroundColor(textSecondary)

            if let risk = currentRiskLevel {
                VStack(spacing: ArkSpacing.xs) {
                    // Large colored value
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(ITCRiskColors.color(for: risk.riskLevel))

                    // Category with dot
                    HStack(spacing: ArkSpacing.xs) {
                        Circle()
                            .fill(ITCRiskColors.color(for: risk.riskLevel))
                            .frame(width: 12, height: 12)

                        Text(ITCRiskColors.category(for: risk.riskLevel))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ITCRiskColors.color(for: risk.riskLevel))
                    }

                    // Date
                    Text("As of \(risk.date)")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.xl)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Risk Legend Section (6-tier)
    private var riskLegendSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Risk Level Guide")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(spacing: ArkSpacing.sm) {
                RiskLevelLegendRow(
                    range: "0.00 - 0.20",
                    category: "Very Low Risk",
                    description: "Deep value range, historically excellent accumulation zone",
                    color: ITCRiskColors.veryLowRisk
                )

                RiskLevelLegendRow(
                    range: "0.20 - 0.40",
                    category: "Low Risk",
                    description: "Still favorable accumulation, attractive for multi-year investors",
                    color: ITCRiskColors.lowRisk
                )

                RiskLevelLegendRow(
                    range: "0.40 - 0.55",
                    category: "Neutral",
                    description: "Mid-cycle territory, neither strong buy nor sell",
                    color: ITCRiskColors.neutral
                )

                RiskLevelLegendRow(
                    range: "0.55 - 0.70",
                    category: "Elevated Risk",
                    description: "Late-cycle behavior, higher probability of corrections",
                    color: ITCRiskColors.elevatedRisk
                )

                RiskLevelLegendRow(
                    range: "0.70 - 0.90",
                    category: "High Risk",
                    description: "Historically blow-off-top region, major cycle tops occur here",
                    color: ITCRiskColors.highRisk
                )

                RiskLevelLegendRow(
                    range: "0.90 - 1.00",
                    category: "Extreme Risk",
                    description: "Historically where macro tops happen, smart-money distribution",
                    color: ITCRiskColors.extremeRisk
                )
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Attribution Card
    private var attributionCard: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Powered by Into The Cryptoverse")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary)

                Text("intothecryptoverse.com")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.md)
    }
}

// MARK: - Risk Level Legend Row
struct RiskLevelLegendRow: View {
    let range: String
    let category: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ArkSpacing.xs) {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)

                    Text("(\(range))")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, ArkSpacing.xs)
    }
}

// MARK: - ITC Risk Chart (Swift Charts)
struct ITCRiskChart: View {
    let history: [ITCRiskLevel]
    let colorScheme: ColorScheme

    // Reference lines at standard Y-axis values
    private let referenceLines: [Double] = [0.25, 0.5, 0.75]

    var body: some View {
        Chart {
            // Horizontal reference lines (dashed)
            ForEach(referenceLines, id: \.self) { value in
                RuleMark(y: .value("Reference", value))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.1)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }

            // Risk zone backgrounds
            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0),
                yEnd: .value("End", 0.20)
            )
            .foregroundStyle(ITCRiskColors.veryLowRisk.opacity(0.08))

            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0.20),
                yEnd: .value("End", 0.40)
            )
            .foregroundStyle(ITCRiskColors.lowRisk.opacity(0.08))

            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0.40),
                yEnd: .value("End", 0.55)
            )
            .foregroundStyle(ITCRiskColors.neutral.opacity(0.08))

            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0.55),
                yEnd: .value("End", 0.70)
            )
            .foregroundStyle(ITCRiskColors.elevatedRisk.opacity(0.08))

            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0.70),
                yEnd: .value("End", 0.90)
            )
            .foregroundStyle(ITCRiskColors.highRisk.opacity(0.08))

            RectangleMark(
                xStart: nil,
                xEnd: nil,
                yStart: .value("Start", 0.90),
                yEnd: .value("End", 1.0)
            )
            .foregroundStyle(ITCRiskColors.extremeRisk.opacity(0.08))

            // Line connecting data points
            ForEach(Array(history.enumerated()), id: \.element.id) { index, dataPoint in
                if index > 0 {
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Risk", dataPoint.riskLevel)
                    )
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.3)
                            : Color.black.opacity(0.2)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }

            // Data points colored by risk level
            ForEach(history) { dataPoint in
                PointMark(
                    x: .value("Date", dataPoint.date),
                    y: .value("Risk", dataPoint.riskLevel)
                )
                .foregroundStyle(ITCRiskColors.color(for: dataPoint.riskLevel))
                .symbolSize(history.count > 90 ? 20 : 40)
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.1)
                    )
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.2f", doubleValue))
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let dateString = value.as(String.self) {
                        Text(formatDateLabel(dateString))
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func formatDateLabel(_ dateString: String) -> String {
        // Format: "2025-01-15" -> "Jan 15"
        let components = dateString.split(separator: "-")
        guard components.count >= 3 else { return dateString }

        let monthNum = Int(components[1]) ?? 1
        let day = components[2]

        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthName = months[safe: monthNum - 1] ?? "Jan"

        return "\(monthName) \(day)"
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Legacy ITCRiskDetailView (for backward compatibility)
struct ITCRiskDetailView: View {
    let riskLevel: ITCRiskLevel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    var body: some View {
        ITCRiskChartView()
    }
}

// MARK: - Compact ITC Risk Card (for Market Sentiment Grid)
struct ITCRiskCard: View {
    let riskLevel: ITCRiskLevel
    let coinSymbol: String
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(coinSymbol) Risk (ITC)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Value in ITC style (3 decimal places)
                        Text(String(format: "%.3f", riskLevel.riskLevel))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(ITCRiskColors.color(for: riskLevel.riskLevel))

                        // Category with dot
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ITCRiskColors.color(for: riskLevel.riskLevel))
                                .frame(width: 6, height: 6)

                            Text(ITCRiskColors.category(for: riskLevel.riskLevel))
                                .font(.caption2)
                                .foregroundColor(ITCRiskColors.color(for: riskLevel.riskLevel))
                        }
                    }

                    Spacer()

                    // Mini gauge
                    CompactITCGauge(riskLevel: riskLevel.riskLevel, colorScheme: colorScheme)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ITCRiskChartView()
        }
    }
}

// MARK: - Compact ITC Gauge
struct CompactITCGauge: View {
    let riskLevel: Double
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        ITCRiskColors.color(for: riskLevel)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: 6
                )
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(riskColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Previews
#Preview("ITC Risk Widget - Standard") {
    VStack(spacing: 20) {
        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.409
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.15
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.85
            ),
            size: .standard
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Widget - Compact") {
    ITCRiskWidget(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.409
        ),
        size: .compact
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Card") {
    ITCRiskCard(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.409
        ),
        coinSymbol: "BTC"
    )
    .frame(width: 180)
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Chart View") {
    ITCRiskChartView()
        .environmentObject(AppState())
}
