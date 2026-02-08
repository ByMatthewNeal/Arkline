import SwiftUI
import Charts

// MARK: - Risk Level Widget (Home Screen)
/// Compact widget for displaying Asset Risk Level on the Home screen
struct RiskLevelWidget: View {
    let riskLevel: ITCRiskLevel?
    var coinSymbol: String = "BTC"
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
            RiskLevelChartView(initialCoin: RiskCoin(rawValue: coinSymbol) ?? .btc)
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private func contentView(risk: ITCRiskLevel) -> some View {
        HStack(spacing: size == .compact ? 12 : 16) {
            // Latest Value Display
            VStack(alignment: .leading, spacing: size == .compact ? 4 : 8) {
                HStack(spacing: 6) {
                    Text("\(coinSymbol) Risk Level")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                }

                // Large colored risk value
                Text(String(format: "%.3f", risk.riskLevel))
                    .font(.system(size: size == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(RiskColors.color(for: risk.riskLevel))

                // Risk category badge with colored dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(RiskColors.color(for: risk.riskLevel))
                        .frame(width: 8, height: 8)

                    Text(RiskColors.category(for: risk.riskLevel))
                        .font(size == .compact ? .caption : .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))
                }

                if size == .expanded {
                    Text("intothecryptoverse.com")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))
                }
            }

            Spacer()

            // Mini gauge
            RiskGauge(
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
                Text("\(coinSymbol) Risk Level")
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

// MARK: - Legacy Alias for backward compatibility
typealias ITCRiskWidget = RiskLevelWidget

// MARK: - Risk Gauge
/// Circular gauge showing the risk level with gradient coloring
struct RiskGauge: View {
    let riskLevel: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
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

// Legacy alias
typealias ITCRiskGauge = RiskGauge

// MARK: - Risk Colors (6-Tier System)
/// Provides colors based on 6-tier risk level thresholds
struct RiskColors {
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

// Legacy alias for backward compatibility
typealias ITCRiskColors = RiskColors

// MARK: - Time Range for Chart
enum RiskTimeRange: String, CaseIterable {
    case all = "All"
    case oneYear = "1Y"
    case ninetyDays = "90D"
    case thirtyDays = "30D"
    case sevenDays = "7D"

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

// Legacy alias
typealias ITCTimeRange = RiskTimeRange

// MARK: - Supported Coins for Risk Level
enum RiskCoin: String, CaseIterable {
    case btc = "BTC"
    case eth = "ETH"
    case sol = "SOL"
    case bnb = "BNB"
    case sui = "SUI"
    case uni = "UNI"
    case ondo = "ONDO"
    case render = "RENDER"

    var displayName: String {
        AssetRiskConfig.forCoin(rawValue)?.displayName ?? rawValue
    }

    var icon: String {
        switch self {
        case .btc: return "bitcoinsign.circle.fill"
        case .eth: return "e.circle.fill"
        case .sol: return "s.circle.fill"
        case .bnb: return "b.circle.fill"
        case .sui: return "s.circle.fill"
        case .uni: return "u.circle.fill"
        case .ondo: return "o.circle.fill"
        case .render: return "r.circle.fill"
        }
    }
}

// Legacy alias
typealias ITCCoin = RiskCoin

// MARK: - Risk Level Chart View (Full Screen Detail)
struct RiskLevelChartView: View {
    // Initial coin to display (defaults to BTC)
    var initialCoin: RiskCoin = .btc

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SentimentViewModel()
    @State private var selectedTimeRange: RiskTimeRange = .thirtyDays
    @State private var selectedCoin: RiskCoin = .btc
    @State private var showCoinPicker = false
    @State private var hasInitialized = false

    // Interactive chart state
    @State private var selectedDate: Date?
    @State private var enhancedRiskHistory: [RiskHistoryPoint] = []
    @State private var isLoadingHistory = false

    // Multi-factor risk state
    @State private var multiFactorRisk: MultiFactorRiskPoint?
    @State private var isLoadingMultiFactor = false
    @State private var showFactorBreakdown = true
    @State private var showConfidenceInfo = false
    @State private var showInfoSheet = false
    @State private var showChart = true
    @State private var showFullscreenChart = false

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

    // Get current risk level - prioritize live-calculated multi-factor risk
    private var currentRiskLevel: ITCRiskLevel? {
        // First try multi-factor risk (live calculation with today's price)
        if let mfRisk = multiFactorRisk {
            return ITCRiskLevel(from: mfRisk.toRiskHistoryPoint())
        }
        // Fall back to viewModel's live-calculated risk levels
        if let level = viewModel.riskLevels[selectedCoin.rawValue] {
            return level
        }
        // Fall back to enhanced history
        if let latest = enhancedRiskHistory.last {
            return ITCRiskLevel(from: latest)
        }
        return nil
    }

    // Get regression-only risk level (single-factor, shown on home page)
    private var regressionOnlyRiskLevel: ITCRiskLevel? {
        if let level = viewModel.riskLevels[selectedCoin.rawValue] {
            return level
        }
        if let latest = enhancedRiskHistory.last {
            return ITCRiskLevel(from: latest)
        }
        return nil
    }

    // Get history based on selected coin (legacy format for compatibility)
    private var riskHistory: [ITCRiskLevel] {
        if !enhancedRiskHistory.isEmpty {
            return enhancedRiskHistory.map { ITCRiskLevel(from: $0) }
        }
        return viewModel.riskHistories[selectedCoin.rawValue] ?? []
    }

    // Filter history based on time range
    private var filteredHistory: [ITCRiskLevel] {
        guard let days = selectedTimeRange.days else { return riskHistory }
        return Array(riskHistory.suffix(days))
    }

    // Filter enhanced history based on time range
    private var filteredEnhancedHistory: [RiskHistoryPoint] {
        guard let days = selectedTimeRange.days else { return enhancedRiskHistory }
        return Array(enhancedRiskHistory.suffix(days))
    }

    // Selected point from enhanced history
    private var selectedPoint: RiskHistoryPoint? {
        guard let selectedDate = selectedDate else { return nil }
        return filteredEnhancedHistory.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    // Format date as "January 23, 2026"
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMMM d, yyyy"

        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        return dateString
    }

    // Load enhanced risk history for selected coin
    // Always fetch at least 30 days so short ranges (7D) have data to display
    private func loadEnhancedHistory() {
        isLoadingHistory = true
        Task {
            let fetchDays: Int? = if let days = selectedTimeRange.days {
                max(days, 30)
            } else {
                nil
            }
            let history = await viewModel.fetchEnhancedRiskHistory(
                coin: selectedCoin.rawValue,
                days: fetchDays
            )
            await MainActor.run {
                self.enhancedRiskHistory = history
                self.isLoadingHistory = false
            }
        }
    }

    // Load multi-factor risk for selected coin
    private func loadMultiFactorRisk() {
        isLoadingMultiFactor = true
        Task {
            let risk = await viewModel.fetchMultiFactorRisk(coin: selectedCoin.rawValue)
            await MainActor.run {
                self.multiFactorRisk = risk
                self.isLoadingMultiFactor = false
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MeshGradientBackground()
                if isDarkMode { BrushEffectOverlay() }

                ScrollView {
                    VStack(spacing: ArkSpacing.xl) {
                        // Coin Selector (Dropdown style)
                        coinDropdown
                            .padding(.top, ArkSpacing.md)

                        // Time Range Picker
                        timeRangePicker

                        // Chart Area
                        chartSection

                        // Latest Value Section
                        latestValueSection

                        // Multi-Factor Breakdown Section
                        factorBreakdownSection

                        // Risk Legend (6-tier)
                        riskLegendSection

                        // Attribution (smaller)
                        attributionCard

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                }
            }
            .navigationTitle("\(selectedCoin.rawValue) Risk Level")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showInfoSheet = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                RiskLevelInfoSheet()
            }
            .fullScreenCover(isPresented: $showFullscreenChart) {
                RiskChartFullscreenView(
                    history: riskHistory,
                    enhancedHistory: enhancedRiskHistory,
                    timeRange: $selectedTimeRange,
                    coinName: selectedCoin.rawValue
                )
            }
            #endif
            .onAppear {
                if !hasInitialized {
                    selectedCoin = initialCoin
                    hasInitialized = true
                }
                loadEnhancedHistory()
                loadMultiFactorRisk()
            }
            .onChange(of: selectedCoin) { _, _ in
                selectedDate = nil
                loadEnhancedHistory()
                loadMultiFactorRisk()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                selectedDate = nil
                loadEnhancedHistory()
            }
        }
    }

    // MARK: - Coin Dropdown
    private var coinDropdown: some View {
        Menu {
            ForEach(RiskCoin.allCases, id: \.self) { coin in
                Button(action: { selectedCoin = coin }) {
                    HStack {
                        Text(coin.displayName)
                        Text("(\(coin.rawValue))")
                            .foregroundColor(.secondary)
                        if selectedCoin == coin {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: selectedCoin.icon)
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(selectedCoin.displayName)
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        // Loading indicator when switching coins
                        if isLoadingHistory || isLoadingMultiFactor {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        }
                    }
                    Text(isLoadingHistory ? "Loading data..." : "Tap to change asset")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(textSecondary)
            }
            .padding(ArkSpacing.md)
            .glassCard(cornerRadius: ArkSpacing.Radius.md)
        }
    }

    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        HStack(spacing: ArkSpacing.xs) {
            ForEach(RiskTimeRange.allCases, id: \.self) { range in
                Button(action: { selectedTimeRange = range }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(
                            selectedTimeRange == range
                                ? (colorScheme == .dark ? .white : .white)
                                : textPrimary
                        )
                        .frame(maxWidth: .infinity)
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
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filteredHistory.isEmpty && !isLoadingHistory {
                VStack(spacing: ArkSpacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(textSecondary.opacity(0.5))

                    Text("Loading \(selectedCoin.displayName) data...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else if isLoadingHistory {
                VStack(spacing: ArkSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Calculating \(selectedCoin.displayName) risk levels...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Tappable header to collapse/expand
                    Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showChart.toggle() } }) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Risk Level")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)
                                .textCase(.uppercase)
                                .tracking(0.8)

                            Spacer()

                            if showChart {
                                if selectedDate != nil {
                                    Button(action: { selectedDate = nil }) {
                                        Text("Reset")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(AppColors.accent)
                                    }
                                }

                                Button(action: { showFullscreenChart = true }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5))
                                        .frame(width: 28, height: 28)
                                        .background(
                                            Circle()
                                                .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                                        )
                                }
                            }

                            HStack(spacing: 4) {
                                Text(showChart ? "Hide" : "Show")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: showChart ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                            )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.top, ArkSpacing.md)
                    .padding(.bottom, showChart ? ArkSpacing.sm : ArkSpacing.md)

                    if showChart {
                        // Tooltip overlay
                        if let point = selectedPoint {
                            RiskTooltipView(
                                date: point.date,
                                riskLevel: point.riskLevel,
                                price: point.price,
                                fairValue: point.fairValue
                            )
                            .padding(.horizontal, ArkSpacing.md)
                            .padding(.bottom, ArkSpacing.sm)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.easeOut(duration: 0.15), value: selectedDate)
                        }

                        // Chart
                        RiskLevelChart(
                            history: filteredHistory,
                            timeRange: selectedTimeRange,
                            colorScheme: colorScheme,
                            enhancedHistory: filteredEnhancedHistory,
                            selectedDate: $selectedDate
                        )
                        .frame(height: 280)
                        .padding(.horizontal, 4)

                        // Hint for touch interaction (only show when no point selected)
                        if selectedDate == nil {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw")
                                    .font(.system(size: 11))
                                Text("Touch chart to explore historical values")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(textSecondary.opacity(0.7))
                            .padding(.top, 4)
                            .padding(.bottom, ArkSpacing.sm)
                        } else {
                            Spacer().frame(height: ArkSpacing.md)
                        }
                    }
                }
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            }
        }
    }

    // MARK: - Latest Value Section
    private var latestValueSection: some View {
        VStack(spacing: ArkSpacing.md) {
            HStack(spacing: 6) {
                Text(multiFactorRisk != nil
                     ? "Multi-Factor \(selectedCoin.rawValue) Risk"
                     : "Regression \(selectedCoin.rawValue) Risk")
                    .font(.callout)
                    .foregroundColor(textSecondary.opacity(0.85))

                if isLoadingMultiFactor {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }

            if let risk = currentRiskLevel {
                VStack(spacing: ArkSpacing.xs) {
                    // Large colored value
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))

                    // Category with dot
                    HStack(spacing: ArkSpacing.xs) {
                        Circle()
                            .fill(RiskColors.color(for: risk.riskLevel))
                            .frame(width: 12, height: 12)

                        Text(RiskColors.category(for: risk.riskLevel))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(RiskColors.color(for: risk.riskLevel))
                    }

                    // Date in new format
                    Text("As of \(formatDate(risk.date))")
                        .font(.footnote)
                        .foregroundColor(textSecondary.opacity(0.85))

                    // Comparison callout: regression-only vs multi-factor
                    if let regRisk = regressionOnlyRiskLevel,
                       multiFactorRisk != nil {
                        regressionComparisonBanner(
                            regressionValue: regRisk.riskLevel,
                            compositeValue: risk.riskLevel
                        )
                    }
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

    // MARK: - Regression Comparison Banner
    private func regressionComparisonBanner(regressionValue: Double, compositeValue: Double) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            // Divider
            Rectangle()
                .fill(textSecondary.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.top, ArkSpacing.sm)

            // Comparison row
            HStack(spacing: ArkSpacing.md) {
                // Regression-only value
                VStack(spacing: 4) {
                    Text("Regression Only")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textSecondary.opacity(0.85))

                    Text(String(format: "%.3f", regressionValue))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(RiskColors.color(for: regressionValue))

                    Text(RiskColors.category(for: regressionValue))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(RiskColors.color(for: regressionValue))
                }
                .frame(maxWidth: .infinity)

                // Arrow separator
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary.opacity(0.6))

                // Composite value
                VStack(spacing: 4) {
                    Text("7-Factor Composite")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textSecondary.opacity(0.85))

                    Text(String(format: "%.3f", compositeValue))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(RiskColors.color(for: compositeValue))

                    Text(RiskColors.category(for: compositeValue))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(RiskColors.color(for: compositeValue))
                }
                .frame(maxWidth: .infinity)
            }

            // Explanation text
            Text("The home page shows regression risk (1 factor). This view combines 7 indicators for a broader assessment.")
                .font(.system(size: 13))
                .foregroundColor(textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.sm)
        }
    }

    // MARK: - Factor Breakdown Section
    @ViewBuilder
    private var factorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            // Toggle header
            Button(action: { withAnimation { showFactorBreakdown.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)

                    Text("Multi-Factor Analysis")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Spacer()

                    if isLoadingMultiFactor {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let risk = multiFactorRisk {
                        HStack(spacing: 4) {
                            Text("\(risk.availableFactorCount)/\(RiskFactorType.allCases.count)")
                                .font(.footnote)
                                .foregroundColor(textSecondary.opacity(0.85))

                            Image(systemName: showFactorBreakdown ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary.opacity(0.85))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showFactorBreakdown {
                if isLoadingMultiFactor {
                    HStack {
                        Spacer()
                        VStack(spacing: ArkSpacing.sm) {
                            ProgressView()
                            Text("Loading factor data...")
                                .font(.footnote)
                                .foregroundColor(textSecondary.opacity(0.85))
                        }
                        Spacer()
                    }
                    .padding(.vertical, ArkSpacing.lg)
                } else if let risk = multiFactorRisk {
                    // Factor breakdown content
                    RiskFactorBreakdownView(multiFactorRisk: risk)
                } else {
                    // Error state
                    VStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(textSecondary.opacity(0.5))

                        Text("Unable to load factor data")
                            .font(.footnote)
                            .foregroundColor(textSecondary.opacity(0.85))

                        Button("Retry") {
                            loadMultiFactorRisk()
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.lg)
                }
            }
        }
        .padding(ArkSpacing.md)
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
                    color: RiskColors.veryLowRisk
                )

                RiskLevelLegendRow(
                    range: "0.20 - 0.40",
                    category: "Low Risk",
                    description: "Still favorable accumulation, attractive for multi-year investors",
                    color: RiskColors.lowRisk
                )

                RiskLevelLegendRow(
                    range: "0.40 - 0.55",
                    category: "Neutral",
                    description: "Mid-cycle territory, neither strong buy nor sell",
                    color: RiskColors.neutral
                )

                RiskLevelLegendRow(
                    range: "0.55 - 0.70",
                    category: "Elevated Risk",
                    description: "Late-cycle behavior, higher probability of corrections",
                    color: RiskColors.elevatedRisk
                )

                RiskLevelLegendRow(
                    range: "0.70 - 0.90",
                    category: "High Risk",
                    description: "Historically blow-off-top region, major cycle tops occur here",
                    color: RiskColors.highRisk
                )

                RiskLevelLegendRow(
                    range: "0.90 - 1.00",
                    category: "Extreme Risk",
                    description: "Historically where macro tops happen, smart-money distribution",
                    color: RiskColors.extremeRisk
                )
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Attribution Card (Subtle)
    private var attributionCard: some View {
        HStack(spacing: ArkSpacing.xs) {
            Image(systemName: "function")
                .font(.system(size: 10))
                .foregroundColor(textSecondary.opacity(0.5))

            Text("Risk calculated via logarithmic regression")
                .font(.system(size: 11))
                .foregroundColor(textSecondary.opacity(0.5))

            Spacer()

            // Confidence indicator with tooltip
            if let config = AssetRiskConfig.forCoin(selectedCoin.rawValue) {
                Button(action: { showConfidenceInfo.toggle() }) {
                    HStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<9, id: \.self) { index in
                                Circle()
                                    .fill(index < config.confidenceLevel
                                        ? AppColors.accent.opacity(0.7)
                                        : textSecondary.opacity(0.2))
                                    .frame(width: 4, height: 4)
                            }
                        }

                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(textSecondary.opacity(0.4))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showConfidenceInfo, arrowEdge: .bottom) {
                    ConfidenceInfoPopover(
                        config: config,
                        colorScheme: colorScheme
                    )
                }
            }
        }
        .padding(.horizontal, ArkSpacing.md)
        .padding(.vertical, ArkSpacing.sm)
    }
}

// MARK: - Risk Level Info Sheet
struct RiskLevelInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // What is it
                    infoSection(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "What is the Risk Level?",
                        body: "The Risk Level is a score from 0.00 to 1.00 that measures where an asset sits in its market cycle. It uses logarithmic regression on historical price data to determine whether the current price is relatively cheap or expensive compared to its long-term trend."
                    )

                    // How to use it
                    infoSection(
                        icon: "lightbulb",
                        title: "How to Use It",
                        body: """
                        Use the risk level to guide your investment decisions:

                        \u{2022} Low risk (below 0.40) suggests the asset is undervalued relative to its historical trend — a potentially good time to accumulate.

                        \u{2022} Neutral (0.40 - 0.55) means the asset is fairly priced. Neither a strong buy nor sell signal.

                        \u{2022} High risk (above 0.70) indicates the asset may be overheated. Consider taking profits or reducing exposure.
                        """
                    )

                    // Why it matters
                    infoSection(
                        icon: "exclamationmark.shield",
                        title: "Why It Matters",
                        body: "Markets move in cycles. Buying when risk is low and being cautious when risk is high has historically led to better outcomes. This tool helps you avoid buying tops and missing bottoms by providing an objective, data-driven perspective on market conditions."
                    )

                    // Multi-factor
                    infoSection(
                        icon: "slider.horizontal.3",
                        title: "Multi-Factor Analysis",
                        body: "The Multi-Factor Risk score combines multiple on-chain and technical indicators — including logarithmic regression, MVRV ratio, NUPL, and Puell Multiple — to produce a more robust signal than any single metric alone. Each factor is weighted based on its historical reliability."
                    )

                    // Chart interaction
                    infoSection(
                        icon: "hand.tap",
                        title: "Interacting with the Chart",
                        body: "Tap and drag on the chart to explore historical risk levels at specific dates. Use the time range buttons (7D, 30D, 90D, 1Y, All) to zoom in or out. You can also switch between coins using the coin selector at the top."
                    )
                }
                .padding(20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("About Risk Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func infoSection(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.headline)
                    .foregroundColor(textPrimary)
            }

            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Confidence Info Popover
/// Explains the data confidence indicator
struct ConfidenceInfoPopover: View {
    let config: AssetRiskConfig
    let colorScheme: ColorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var confidenceDescription: String {
        switch config.confidenceLevel {
        case 9:
            return "Highest confidence. Over 15 years of price data provides excellent regression accuracy."
        case 8:
            return "Very high confidence. Nearly a decade of data ensures reliable fair value estimates."
        case 7:
            return "High confidence. Multiple market cycles covered for solid regression modeling."
        case 6:
            return "Good confidence. Several years of data, though fewer complete cycles than BTC/ETH."
        case 5:
            return "Moderate confidence. Limited historical data may affect accuracy during unusual conditions."
        default:
            return "Lower confidence. Newer asset with limited price history for regression analysis."
        }
    }

    private var yearsOfData: String {
        let days = Calendar.current.dateComponents([.day], from: config.originDate, to: Date()).day ?? 0
        let years = Double(days) / 365.25
        return String(format: "%.1f", years)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)

                Text("Data Confidence")
                    .font(.headline)
                    .foregroundColor(textPrimary)
            }

            Divider()

            // Confidence level visual
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(config.displayName) Confidence:")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)

                    Spacer()

                    Text("\(config.confidenceLevel)/9")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                }

                // Confidence bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent)
                            .frame(width: geometry.size.width * (Double(config.confidenceLevel) / 9.0))
                    }
                }
                .frame(height: 6)
            }

            // Description
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Stats
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Data since:")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Spacer()
                    Text(config.originDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)
                }

                HStack {
                    Text("Years of data:")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                    Spacer()
                    Text("\(yearsOfData) years")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 280)
        .background(colorScheme == .dark ? Color(hex: "1C1C1E") : Color.white)
    }
}

// Legacy alias
typealias ITCRiskChartView = RiskLevelChartView

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

// MARK: - Risk Level Chart (Swift Charts) - Interactive with touch selection
struct RiskLevelChart: View {
    let history: [ITCRiskLevel]
    let timeRange: RiskTimeRange
    let colorScheme: ColorScheme

    var enhancedHistory: [RiskHistoryPoint]?
    @Binding var selectedDate: Date?

    // Backwards-compatible init
    init(history: [ITCRiskLevel], timeRange: RiskTimeRange, colorScheme: ColorScheme) {
        self.history = history
        self.timeRange = timeRange
        self.colorScheme = colorScheme
        self.enhancedHistory = nil
        self._selectedDate = .constant(nil)
    }

    // Init with selection support
    init(history: [ITCRiskLevel], timeRange: RiskTimeRange, colorScheme: ColorScheme, enhancedHistory: [RiskHistoryPoint]?, selectedDate: Binding<Date?>) {
        self.history = history
        self.timeRange = timeRange
        self.colorScheme = colorScheme
        self.enhancedHistory = enhancedHistory
        self._selectedDate = selectedDate
    }

    private var chartData: [(date: Date, risk: Double, price: Double?, fairValue: Double?)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let enhanced = enhancedHistory {
            return enhanced.map { (date: $0.date, risk: $0.riskLevel, price: $0.price, fairValue: $0.fairValue) }
        }
        return history.compactMap { level in
            guard let date = formatter.date(from: level.date) else { return nil }
            return (date: date, risk: level.riskLevel, price: level.price, fairValue: level.fairValue)
        }
    }

    private var selectedPoint: (date: Date, risk: Double, price: Double?, fairValue: Double?)? {
        guard let selectedDate = selectedDate else { return nil }
        return chartData.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) })
    }

    private var latestRisk: Double {
        chartData.last?.risk ?? 0.5
    }

    private var lineColor: Color {
        RiskColors.color(for: latestRisk)
    }

    private var xAxisLabelCount: Int {
        switch timeRange {
        case .sevenDays: return 4
        case .thirtyDays: return 5
        case .ninetyDays: return 4
        case .oneYear: return 6
        case .all: return 5
        }
    }

    private func formatLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .sevenDays: formatter.dateFormat = "EEE"
        case .thirtyDays: formatter.dateFormat = "MMM d"
        case .ninetyDays, .oneYear: formatter.dateFormat = "MMM"
        case .all: formatter.dateFormat = "MMM yy"
        }
        return formatter.string(from: date)
    }

    // Threshold levels for subtle zone lines
    private let thresholds: [(value: Double, color: Color, label: String)] = [
        (0.20, RiskColors.lowRisk, "Low"),
        (0.40, RiskColors.neutral, ""),
        (0.55, RiskColors.elevatedRisk, ""),
        (0.70, RiskColors.highRisk, "High"),
        (0.90, RiskColors.extremeRisk, ""),
    ]

    var body: some View {
        Chart {
            // Subtle threshold lines instead of colored bands
            ForEach(thresholds, id: \.value) { threshold in
                RuleMark(y: .value("Threshold", threshold.value))
                    .foregroundStyle(threshold.color.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            // Selection crosshair
            if let point = selectedPoint {
                // Vertical line
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.15)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))

                // Horizontal line at risk value
                RuleMark(y: .value("Risk", point.risk))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.08)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
            }

            // Area fill — clean single gradient
            ForEach(chartData, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            lineColor.opacity(0.15),
                            lineColor.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Primary line — smooth, weighted
            ForEach(chartData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            // Selected point — polished indicator
            if let point = selectedPoint {
                // Outer glow
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(RiskColors.color(for: point.risk).opacity(0.3))
                .symbolSize(120)

                // Filled ring
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(RiskColors.color(for: point.risk))
                .symbolSize(50)

                // Inner white dot
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(Color.white)
                .symbolSize(14)
            }
        }
        .chartYScale(domain: 0...1)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x
                                if let date: Date = proxy.value(atX: x) {
                                    let closest = chartData.min { a, b in
                                        abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date))
                                    }
                                    if let closest {
                                        selectedDate = closest.date
                                    }
                                }
                            }
                            .onEnded { _ in }
                    )
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.50, 0.75, 1.0]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.06)
                    )
                AxisValueLabel(anchor: .leading) {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.2f", v))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.35)
                                    : Color.black.opacity(0.35)
                            )
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisLabelCount)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.04)
                            : Color.black.opacity(0.04)
                    )
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatLabel(for: date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.35)
                                    : Color.black.opacity(0.35)
                            )
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.02)
                        : Color.black.opacity(0.015)
                )
        }
    }
}

// MARK: - Fullscreen Risk Chart View
struct RiskChartFullscreenView: View {
    let history: [ITCRiskLevel]
    let enhancedHistory: [RiskHistoryPoint]
    @Binding var timeRange: RiskTimeRange
    let coinName: String

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedDate: Date?

    private var selectedPoint: RiskHistoryPoint? {
        guard let selectedDate else { return nil }
        return enhancedHistory.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var filteredHistory: [ITCRiskLevel] {
        guard let days = timeRange.days else { return history }
        return Array(history.suffix(days))
    }

    private var filteredEnhancedHistory: [RiskHistoryPoint] {
        guard let days = timeRange.days else { return enhancedHistory }
        return Array(enhancedHistory.suffix(days))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(coinName) Risk Level")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        if let point = selectedPoint {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(RiskColors.color(for: point.riskLevel))
                                    .frame(width: 8, height: 8)
                                Text(String(format: "%.3f", point.riskLevel))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(RiskColors.color(for: point.riskLevel))
                                Text(RiskColors.category(for: point.riskLevel))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(RiskColors.color(for: point.riskLevel))
                                Text("·")
                                    .foregroundColor(.white.opacity(0.4))
                                Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                                if point.price > 0 {
                                    Text("·")
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(point.price >= 1 ? String(format: "$%.0f", point.price) : String(format: "$%.4f", point.price))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        } else {
                            Text("Drag to explore")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    Button {
                        #if canImport(UIKit)
                        AppDelegate.orientationLock = .portrait
                        if let windowScene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene }).first {
                            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                        }
                        #endif
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Chart — fills remaining space
                RiskLevelChart(
                    history: filteredHistory,
                    timeRange: timeRange,
                    colorScheme: .dark,
                    enhancedHistory: filteredEnhancedHistory,
                    selectedDate: $selectedDate
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                // Time range picker
                HStack(spacing: 8) {
                    ForEach(RiskTimeRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedDate = nil
                            timeRange = range
                        }) {
                            Text(range.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(timeRange == range ? .white : .white.opacity(0.5))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(timeRange == range ? AppColors.accent : Color.white.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            #if canImport(UIKit)
            AppDelegate.orientationLock = .allButUpsideDown
            #endif
        }
        .onDisappear {
            #if canImport(UIKit)
            AppDelegate.orientationLock = .portrait
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            #endif
        }
    }
}

// Legacy chart alias
struct ITCRiskChart: View {
    let history: [ITCRiskLevel]
    let colorScheme: ColorScheme

    var body: some View {
        RiskLevelChart(history: history, timeRange: .thirtyDays, colorScheme: colorScheme)
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

// MARK: - Compact Risk Card (for Market Sentiment Grid)
struct RiskCard: View {
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
                    Text("\(coinSymbol) Risk Level")
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
                        // Value (3 decimal places)
                        Text(String(format: "%.3f", riskLevel.riskLevel))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(RiskColors.color(for: riskLevel.riskLevel))

                        // Category with dot
                        HStack(spacing: 4) {
                            Circle()
                                .fill(RiskColors.color(for: riskLevel.riskLevel))
                                .frame(width: 6, height: 6)

                            Text(RiskColors.category(for: riskLevel.riskLevel))
                                .font(.caption2)
                                .foregroundColor(RiskColors.color(for: riskLevel.riskLevel))
                        }
                    }

                    Spacer()

                    // Mini gauge
                    CompactRiskGauge(riskLevel: riskLevel.riskLevel, colorScheme: colorScheme)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView(initialCoin: RiskCoin(rawValue: coinSymbol) ?? .btc)
        }
    }
}

// Legacy alias
typealias ITCRiskCard = RiskCard

// MARK: - Compact Risk Gauge
struct CompactRiskGauge: View {
    let riskLevel: Double
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
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

// Legacy alias
typealias CompactITCGauge = CompactRiskGauge

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
