import SwiftUI
import Charts

// MARK: - Data Models

struct ReturnPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let returnPct: Double
}

struct CoinScreenerData: Identifiable {
    let id: String
    let symbol: String
    let color: Color
    let returnSeries: [ReturnPoint]
    let totalReturn: Double
    let vsBTC: Double?
}

// MARK: - Curated Coin List

private struct ScreenerCoin {
    let id: String      // CoinGecko ID
    let symbol: String  // Display symbol
}

private let curatedCoins: [ScreenerCoin] = [
    ScreenerCoin(id: "hyperliquid", symbol: "HYPE"),
    ScreenerCoin(id: "bitcoin-cash", symbol: "BCH"),
    ScreenerCoin(id: "zcash", symbol: "ZEC"),
    ScreenerCoin(id: "dogecoin", symbol: "DOGE"),
    ScreenerCoin(id: "bittensor", symbol: "TAO"),
    ScreenerCoin(id: "ripple", symbol: "XRP"),
    ScreenerCoin(id: "bitcoin", symbol: "BTC"),
    ScreenerCoin(id: "avalanche-2", symbol: "AVAX"),
    ScreenerCoin(id: "binancecoin", symbol: "BNB"),
    ScreenerCoin(id: "chainlink", symbol: "LINK"),
    ScreenerCoin(id: "solana", symbol: "SOL"),
    ScreenerCoin(id: "ethereum", symbol: "ETH"),
    ScreenerCoin(id: "sui", symbol: "SUI"),
    ScreenerCoin(id: "ondo-finance", symbol: "ONDO"),
    ScreenerCoin(id: "render-token", symbol: "RNDR"),
]

// MARK: - Altcoin Screener Section

struct AltcoinScreenerSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var screenData: [CoinScreenerData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate: Date?
    @State private var lastFetchedAt: Date?
    @State private var showFullscreen = false

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    private let cacheTTL: TimeInterval = 600 // 10 minutes

    private static let screenerColors: [Color] = [
        .pink, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .brown, .red,
        .gray, Color(red: 1, green: 0.4, blue: 0.4), Color(red: 0.4, green: 0.8, blue: 1)
    ]

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text("Altcoin Screener")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                Text("30D")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.accent.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                if !screenData.isEmpty {
                    Button {
                        showFullscreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Content
            if let error = errorMessage {
                errorView(error)
                    .padding(.horizontal, 20)
            } else if isLoading {
                loadingView
                    .padding(.horizontal, 20)
            } else if screenData.isEmpty {
                emptyView
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 16) {
                    screenerChart
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            showFullscreen = true
                        }

                    rankedTable
                        .padding(.horizontal, 20)
                }
            }
        }
        .task {
            await loadIfNeeded()
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            AltcoinScreenerFullscreenView(screenData: screenData)
        }
    }

    // MARK: - Chart

    private var screenerChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tooltip
            if let selectedDate, case let nearest = nearestPoints(for: selectedDate), !nearest.isEmpty {
                HStack(spacing: 10) {
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    ForEach(nearest.prefix(3)) { coin in
                        HStack(spacing: 3) {
                            Circle().fill(coin.color).frame(width: 5, height: 5)
                            Text("\(coin.symbol) \(coin.returnPct, specifier: "%+.1f")%")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(coin.returnPct >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            AltcoinScreenerChartContent(
                screenData: screenData,
                selectedDate: $selectedDate,
                colorScheme: colorScheme,
                chartHeight: 280
            )

            // Endpoint labels (coin symbols at right edge)
            endpointLabels
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Endpoint Labels

    private var endpointLabels: some View {
        let sorted = screenData.sorted { $0.totalReturn > $1.totalReturn }
        return HStack(spacing: 6) {
            ForEach(sorted.prefix(6)) { coin in
                HStack(spacing: 3) {
                    Circle().fill(coin.color).frame(width: 6, height: 6)
                    Text(coin.symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(textPrimary.opacity(0.6))
                }
            }
            if sorted.count > 6 {
                Text("+\(sorted.count - 6)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Ranked Table

    private var rankedTable: some View {
        let sorted = screenData.sorted { $0.totalReturn > $1.totalReturn }

        return VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 28, alignment: .center)
                Text("Symbol")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("30D %")
                    .frame(width: 80, alignment: .trailing)
                Text("vs BTC")
                    .frame(width: 72, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()
                .background(AppColors.textSecondary.opacity(0.15))
                .padding(.horizontal, 14)

            // Data rows
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, coin in
                HStack(spacing: 0) {
                    // Rank with color dot
                    HStack(spacing: 4) {
                        Circle().fill(coin.color).frame(width: 8, height: 8)
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(textPrimary.opacity(0.6))
                    }
                    .frame(width: 28, alignment: .center)

                    // Symbol
                    Text(coin.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 30D change
                    Text(String(format: "%+.2f%%", coin.totalReturn))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                        .frame(width: 80, alignment: .trailing)

                    // vs BTC
                    if let vs = coin.vsBTC {
                        Text(String(format: "%+.2f%%", vs))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(vs >= 0 ? AppColors.success : AppColors.error)
                            .frame(width: 72, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
        }
        .glassCard(cornerRadius: 16)
    }

    // MARK: - States

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(AppColors.warning)
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await loadData() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Retry")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.accent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .glassCard(cornerRadius: 16)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            SkeletonView(height: 280, cornerRadius: 16)
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    SkeletonListItem()
                    if i < 5 {
                        Divider()
                            .background(AppColors.textSecondary.opacity(0.15))
                            .padding(.horizontal, 16)
                    }
                }
            }
            .glassCard(cornerRadius: 16)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
            Text("No screener data available")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Tooltip Helpers

    private func nearestPoints(for date: Date) -> [TooltipCoin] {
        screenData.compactMap { coin in
            guard let nearest = coin.returnSeries.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { return nil }
            return TooltipCoin(id: coin.id, symbol: coin.symbol, color: coin.color, returnPct: nearest.returnPct)
        }
        .sorted { abs($0.returnPct) > abs($1.returnPct) }
    }

    // MARK: - Data Loading

    private func loadIfNeeded() async {
        if let lastFetch = lastFetchedAt,
           Date().timeIntervalSince(lastFetch) < cacheTTL,
           !screenData.isEmpty {
            return
        }
        await loadData()
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let chartResults = try await fetchChartsThrottled(for: curatedCoins)

            guard !chartResults.isEmpty else {
                errorMessage = "No coin data available"
                isLoading = false
                return
            }

            // Find BTC return for "vs BTC" column
            let btcReturn = chartResults.first { $0.symbol == "BTC" }?.totalReturn ?? 0

            // Assign colors and build screen data
            var result: [CoinScreenerData] = []
            for (index, item) in chartResults.enumerated() {
                let color = Self.screenerColors[index % Self.screenerColors.count]
                let vsBTC: Double? = item.symbol == "BTC" ? nil : item.totalReturn - btcReturn
                result.append(CoinScreenerData(
                    id: item.id,
                    symbol: item.symbol,
                    color: color,
                    returnSeries: item.series,
                    totalReturn: item.totalReturn,
                    vsBTC: vsBTC
                ))
            }

            screenData = result
            lastFetchedAt = Date()
        } catch {
            if screenData.isEmpty {
                errorMessage = "Failed to load screener data"
            }
        }

        isLoading = false
    }

    private struct ChartResult {
        let id: String
        let symbol: String
        let series: [ReturnPoint]
        let totalReturn: Double
    }

    private func fetchChartsThrottled(for coins: [ScreenerCoin]) async throws -> [ChartResult] {
        try await withThrowingTaskGroup(of: ChartResult?.self) { group in
            var results: [ChartResult] = []
            var index = 0

            for coin in coins {
                group.addTask { [index] in
                    // Stagger requests to avoid rate limiting
                    if index >= 3 {
                        try await Task.sleep(nanoseconds: UInt64(index / 3) * 500_000_000)
                    }
                    do {
                        let chart = try await marketService.fetchCoinMarketChart(
                            id: coin.id, currency: "usd", days: 30
                        )
                        let history = chart.priceHistory
                        guard let firstPrice = history.first?.price, firstPrice > 0 else { return nil }

                        let series = history.map { point in
                            ReturnPoint(
                                date: point.date,
                                returnPct: ((point.price / firstPrice) - 1) * 100
                            )
                        }
                        let totalReturn = series.last?.returnPct ?? 0

                        return ChartResult(
                            id: coin.id,
                            symbol: coin.symbol,
                            series: series,
                            totalReturn: totalReturn
                        )
                    } catch {
                        return nil // Skip coins that fail
                    }
                }
                index += 1
            }

            for try await result in group {
                if let result { results.append(result) }
            }

            return results
        }
    }
}

// MARK: - Shared Tooltip Model

private struct TooltipCoin: Identifiable {
    let id: String
    let symbol: String
    let color: Color
    let returnPct: Double
}

// MARK: - Reusable Chart Content

private struct AltcoinScreenerChartContent: View {
    let screenData: [CoinScreenerData]
    @Binding var selectedDate: Date?
    let colorScheme: ColorScheme
    var chartHeight: CGFloat = 280

    var body: some View {
        Chart {
            // Baseline at 0%
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.1)
                )
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [5, 4]))

            // Selection crosshair
            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.15)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            // Lines for each coin
            ForEach(screenData) { coin in
                ForEach(coin.returnSeries) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Return", point.returnPct),
                        series: .value("Coin", coin.symbol)
                    )
                    .foregroundStyle(coin.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.06)
                    )
                AxisValueLabel(anchor: .leading) {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%+.0f%%", v))
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
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.04)
                            : Color.black.opacity(0.04)
                    )
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
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
                .overlay {
                    ChartLogoWatermark()
                }
        }
        .frame(height: chartHeight)
        .clipped()
    }
}

// MARK: - Fullscreen View

struct AltcoinScreenerFullscreenView: View {
    let screenData: [CoinScreenerData]

    @Environment(\.dismiss) var dismiss
    @State private var selectedDate: Date?

    private var selectedPoints: [TooltipCoin] {
        guard let selectedDate else { return [] }
        return screenData.compactMap { coin in
            guard let nearest = coin.returnSeries.min(by: {
                abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
            }) else { return nil }
            return TooltipCoin(id: coin.id, symbol: coin.symbol, color: coin.color, returnPct: nearest.returnPct)
        }
        .sorted { abs($0.returnPct) > abs($1.returnPct) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Altcoin Screener · 30D")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        if let selectedDate, !selectedPoints.isEmpty {
                            HStack(spacing: 8) {
                                Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))

                                ForEach(selectedPoints.prefix(4)) { coin in
                                    HStack(spacing: 3) {
                                        Circle().fill(coin.color).frame(width: 6, height: 6)
                                        Text("\(coin.symbol) \(coin.returnPct, specifier: "%+.1f")%")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundColor(coin.returnPct >= 0 ? AppColors.success : AppColors.error)
                                    }
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
                AltcoinScreenerChartContent(
                    screenData: screenData,
                    selectedDate: $selectedDate,
                    colorScheme: .dark,
                    chartHeight: .infinity
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity)

                // Legend row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(screenData.sorted { $0.totalReturn > $1.totalReturn }) { coin in
                            HStack(spacing: 4) {
                                Circle().fill(coin.color).frame(width: 7, height: 7)
                                Text(coin.symbol)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(String(format: "%+.1f%%", coin.totalReturn))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
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

// MARK: - Preview

#Preview {
    ScrollView {
        AltcoinScreenerSection()
    }
    .background(Color(hex: "0F0F0F"))
}
