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
            RiskLevelChartView()
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

// MARK: - Supported Coins for Risk Level (BTC, ETH, SOL only)
enum RiskCoin: String, CaseIterable {
    case btc = "BTC"
    case eth = "ETH"
    case sol = "SOL"

    var displayName: String {
        switch self {
        case .btc: return "Bitcoin"
        case .eth: return "Ethereum"
        case .sol: return "Solana"
        }
    }

    var icon: String {
        switch self {
        case .btc: return "bitcoinsign.circle.fill"
        case .eth: return "e.circle.fill"
        case .sol: return "s.circle.fill"
        }
    }
}

// Legacy alias
typealias ITCCoin = RiskCoin

// MARK: - Risk Level Chart View (Full Screen Detail)
struct RiskLevelChartView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SentimentViewModel()
    @State private var selectedTimeRange: RiskTimeRange = .thirtyDays
    @State private var selectedCoin: RiskCoin = .btc
    @State private var showCoinPicker = false

    // Interactive chart state
    @State private var selectedDate: Date?
    @State private var enhancedRiskHistory: [RiskHistoryPoint] = []
    @State private var isLoadingHistory = false

    // Multi-factor risk state
    @State private var multiFactorRisk: MultiFactorRiskPoint?
    @State private var isLoadingMultiFactor = false
    @State private var showFactorBreakdown = true
    @State private var showConfidenceInfo = false

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
        switch selectedCoin {
        case .btc: return viewModel.btcRiskLevel
        case .eth: return viewModel.ethRiskLevel
        case .sol:
            // SOL falls back to enhanced history if multi-factor not loaded
            if let latest = enhancedRiskHistory.last {
                return ITCRiskLevel(from: latest)
            }
            return nil
        }
    }

    // Get history based on selected coin (legacy format for compatibility)
    private var riskHistory: [ITCRiskLevel] {
        if !enhancedRiskHistory.isEmpty {
            return enhancedRiskHistory.map { ITCRiskLevel(from: $0) }
        }
        // Fall back to legacy BTC history only for BTC coin
        // ETH and SOL should rely on enhanced history
        if selectedCoin == .btc {
            return viewModel.btcRiskHistory
        }
        return []
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
    private func loadEnhancedHistory() {
        isLoadingHistory = true
        Task {
            let history = await viewModel.fetchEnhancedRiskHistory(
                coin: selectedCoin.rawValue,
                days: selectedTimeRange.days
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            #endif
            .onAppear {
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
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            if filteredHistory.isEmpty && !isLoadingHistory {
                // Placeholder when no data
                VStack(spacing: ArkSpacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(textSecondary.opacity(0.5))

                    Text("Loading \(selectedCoin.displayName) data...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else if isLoadingHistory {
                // Loading state
                VStack(spacing: ArkSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Calculating \(selectedCoin.displayName) risk levels...")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else {
                // Chart with Swift Charts - Interactive
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    HStack {
                        Text("\(selectedCoin.displayName) Risk Level")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Spacer()

                        // Show "Tap to explore" hint or current selection
                        if selectedDate == nil {
                            Text("Tap chart to explore")
                                .font(.caption)
                                .foregroundColor(textSecondary)
                        } else {
                            Button(action: { selectedDate = nil }) {
                                Text("Clear")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }

                    // Tooltip overlay (positioned above chart when point is selected)
                    if let point = selectedPoint {
                        RiskTooltipView(
                            date: point.date,
                            riskLevel: point.riskLevel,
                            price: point.price,
                            fairValue: point.fairValue
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeOut(duration: 0.15), value: selectedDate)
                    }

                    // Interactive chart
                    RiskLevelChart(
                        history: filteredHistory,
                        timeRange: selectedTimeRange,
                        colorScheme: colorScheme,
                        enhancedHistory: filteredEnhancedHistory,
                        selectedDate: $selectedDate
                    )
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
            Text("Current \(selectedCoin.rawValue) Risk")
                .font(.subheadline)
                .foregroundColor(textSecondary)

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
                            Text("\(risk.availableFactorCount)/6")
                                .font(.caption)
                                .foregroundColor(textSecondary)

                            Image(systemName: showFactorBreakdown ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(textSecondary)
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
                                .font(.caption)
                                .foregroundColor(textSecondary)
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
                            .font(.caption)
                            .foregroundColor(textSecondary)

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

    // Enhanced history with price data (optional)
    var enhancedHistory: [RiskHistoryPoint]?

    // Selection binding
    @Binding var selectedDate: Date?

    // Init without selection (backwards compatible)
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

    // Convert string dates to Date objects for proper charting
    private var chartData: [(date: Date, risk: Double, price: Double?, fairValue: Double?)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // If we have enhanced history, use it
        if let enhanced = enhancedHistory {
            return enhanced.map { point in
                (date: point.date, risk: point.riskLevel, price: point.price, fairValue: point.fairValue)
            }
        }

        // Otherwise use legacy history
        return history.compactMap { level in
            guard let date = formatter.date(from: level.date) else { return nil }
            return (date: date, risk: level.riskLevel, price: level.price, fairValue: level.fairValue)
        }
    }

    // Find closest point to selected date
    private var selectedPoint: (date: Date, risk: Double, price: Double?, fairValue: Double?)? {
        guard let selectedDate = selectedDate else { return nil }
        return chartData.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) })
    }

    // Determine X-axis label count based on time range
    private var xAxisLabelCount: Int {
        switch timeRange {
        case .sevenDays: return 4
        case .thirtyDays: return 5
        case .ninetyDays: return 4
        case .oneYear: return 6
        case .all: return 5
        }
    }

    // Format label based on time range
    private func formatLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .sevenDays:
            formatter.dateFormat = "EEE" // Mon, Tue, etc.
        case .thirtyDays:
            formatter.dateFormat = "MMM d" // Jan 15
        case .ninetyDays, .oneYear:
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        case .all:
            formatter.dateFormat = "MMM yy" // Jan 25
        }
        return formatter.string(from: date)
    }

    var body: some View {
        Chart {
            // Risk zone backgrounds
            RectangleMark(yStart: .value("Start", 0), yEnd: .value("End", 0.20))
                .foregroundStyle(RiskColors.veryLowRisk.opacity(0.08))

            RectangleMark(yStart: .value("Start", 0.20), yEnd: .value("End", 0.40))
                .foregroundStyle(RiskColors.lowRisk.opacity(0.08))

            RectangleMark(yStart: .value("Start", 0.40), yEnd: .value("End", 0.55))
                .foregroundStyle(RiskColors.neutral.opacity(0.08))

            RectangleMark(yStart: .value("Start", 0.55), yEnd: .value("End", 0.70))
                .foregroundStyle(RiskColors.elevatedRisk.opacity(0.08))

            RectangleMark(yStart: .value("Start", 0.70), yEnd: .value("End", 0.90))
                .foregroundStyle(RiskColors.highRisk.opacity(0.08))

            RectangleMark(yStart: .value("Start", 0.90), yEnd: .value("End", 1.0))
                .foregroundStyle(RiskColors.extremeRisk.opacity(0.08))

            // Selection rule mark (vertical line)
            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(RiskColors.color(for: point.risk).opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
            }

            // Area under the line
            ForEach(chartData, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            RiskColors.color(for: point.risk).opacity(0.3),
                            RiskColors.color(for: point.risk).opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Line connecting data points
            ForEach(chartData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white.opacity(0.6)
                        : Color.black.opacity(0.4)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Show points only for smaller datasets
            if chartData.count <= 30 {
                ForEach(chartData, id: \.date) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Risk", point.risk)
                    )
                    .foregroundStyle(RiskColors.color(for: point.risk))
                    .symbolSize(chartData.count > 15 ? 25 : 40)
                }
            }

            // Selected point marker (always visible when selected)
            if let point = selectedPoint {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(RiskColors.color(for: point.risk))
                .symbolSize(80)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(Color.white)
                .symbolSize(20)
            }
        }
        .chartYScale(domain: 0...1)
        .chartXSelection(value: $selectedDate)
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
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: xAxisLabelCount)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatLabel(for: date))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
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
            RiskLevelChartView()
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
