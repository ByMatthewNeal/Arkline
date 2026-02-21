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

// MARK: - Time Range

enum ScreenerTimeRange: String, CaseIterable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"

    var days: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        case .ninetyDays: 90
        }
    }

    var columnLabel: String {
        "\(rawValue) %"
    }
}

// MARK: - Curated Coin List

private struct ScreenerCoin {
    let id: String
    let symbol: String
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
    @State private var highlightedCoinId: String?
    @State private var timeRange: ScreenerTimeRange = .thirtyDays
    @State private var showFullscreen = false

    // Per-range cache
    @State private var dataCache: [ScreenerTimeRange: (data: [CoinScreenerData], fetchedAt: Date)] = [:]

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    private let cacheTTL: TimeInterval = 600

    static let screenerColors: [Color] = [
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

                Spacer()

                // Time range picker
                timeRangePicker

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

                    rankedTable
                        .padding(.horizontal, 20)
                }
            }
        }
        .task {
            await loadIfNeeded()
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            AltcoinScreenerFullscreenView(
                screenData: screenData,
                timeRange: $timeRange,
                onTimeRangeChange: { newRange in
                    Task { await switchTimeRange(to: newRange) }
                }
            )
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 4) {
            ForEach(ScreenerTimeRange.allCases, id: \.self) { range in
                Button {
                    Task { await switchTimeRange(to: range) }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(timeRange == range ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            timeRange == range
                                ? AppColors.accent
                                : AppColors.accent.opacity(0.08)
                        )
                        .cornerRadius(6)
                }
            }
        }
    }

    private func switchTimeRange(to newRange: ScreenerTimeRange) async {
        guard newRange != timeRange else { return }

        // Clear interaction state
        withAnimation(.easeOut(duration: 0.15)) {
            selectedDate = nil
            highlightedCoinId = nil
            timeRange = newRange
        }

        // Check cache
        if let cached = dataCache[newRange],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            withAnimation(.easeOut(duration: 0.2)) {
                screenData = cached.data
            }
            return
        }

        await loadData()
    }

    // MARK: - Chart

    private var screenerChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            screenerTooltip

            AltcoinScreenerChartContent(
                screenData: screenData,
                selectedDate: $selectedDate,
                highlightedCoinId: $highlightedCoinId,
                colorScheme: colorScheme,
                chartHeight: 280,
                onExpandTap: { showFullscreen = true }
            )

            endpointLabels
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    @ViewBuilder
    private var screenerTooltip: some View {
        if let highlightedCoinId,
           let coin = screenData.first(where: { $0.id == highlightedCoinId }) {
            HStack(spacing: 8) {
                Circle().fill(coin.color).frame(width: 8, height: 8)
                Text(coin.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textPrimary)
                Text(String(format: "%+.2f%%", coin.totalReturn))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                if let vs = coin.vsBTC {
                    Text("vs BTC \(String(format: "%+.1f%%", vs))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(vs >= 0 ? AppColors.success.opacity(0.7) : AppColors.error.opacity(0.7))
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.highlightedCoinId = nil
                        self.selectedDate = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 4)
            .transition(.opacity)
        } else if let selectedDate, case let nearest = nearestPoints(for: selectedDate), !nearest.isEmpty {
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
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 28, alignment: .center)
                Text("Symbol")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(timeRange.columnLabel)
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

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, coin in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if highlightedCoinId == coin.id {
                            highlightedCoinId = nil
                        } else {
                            highlightedCoinId = coin.id
                        }
                    }
                } label: {
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Circle().fill(coin.color).frame(width: 8, height: 8)
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(textPrimary.opacity(0.6))
                        }
                        .frame(width: 28, alignment: .center)

                        Text(coin.symbol)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "%+.2f%%", coin.totalReturn))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                            .frame(width: 80, alignment: .trailing)

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
                    .background(
                        highlightedCoinId == coin.id
                            ? coin.color.opacity(0.1)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
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
        if let cached = dataCache[timeRange],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            screenData = cached.data
            isLoading = false
            return
        }
        await loadData()
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            let chartResults = try await fetchChartsThrottled(for: curatedCoins, days: timeRange.days)

            guard !chartResults.isEmpty else {
                errorMessage = "No coin data available"
                isLoading = false
                return
            }

            let btcReturn = chartResults.first { $0.symbol == "BTC" }?.totalReturn ?? 0

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
            dataCache[timeRange] = (data: result, fetchedAt: Date())
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

    private func fetchChartsThrottled(for coins: [ScreenerCoin], days: Int) async throws -> [ChartResult] {
        try await withThrowingTaskGroup(of: ChartResult?.self) { group in
            var results: [ChartResult] = []
            var index = 0

            for coin in coins {
                group.addTask { [index] in
                    if index >= 3 {
                        try await Task.sleep(nanoseconds: UInt64(index / 3) * 500_000_000)
                    }
                    do {
                        let chart = try await marketService.fetchCoinMarketChart(
                            id: coin.id, currency: "usd", days: days
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
                        return nil
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
    @Binding var highlightedCoinId: String?
    let colorScheme: ColorScheme
    var chartHeight: CGFloat? = 280
    var onExpandTap: (() -> Void)?

    private func nearestCoin(atDate date: Date, yValue: Double) -> CoinScreenerData? {
        var closest: CoinScreenerData?
        var closestDist = Double.infinity

        for coin in screenData {
            guard let nearestPoint = coin.returnSeries.min(by: {
                abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
            }) else { continue }

            let dist = abs(nearestPoint.returnPct - yValue)
            if dist < closestDist {
                closestDist = dist
                closest = coin
            }
        }
        return closest
    }

    var body: some View {
        Chart {
            RuleMark(y: .value("Baseline", 0))
                .foregroundStyle(
                    colorScheme == .dark
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.1)
                )
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [5, 4]))

            if let selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.15)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            ForEach(screenData) { coin in
                let isHighlighted = highlightedCoinId == nil || highlightedCoinId == coin.id
                let lineWidth: CGFloat = highlightedCoinId == coin.id ? 3.0 : (highlightedCoinId == nil ? 1.8 : 0.8)
                let opacity: Double = isHighlighted ? 1.0 : 0.15

                ForEach(coin.returnSeries) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Return", point.returnPct),
                        series: .value("Coin", coin.symbol)
                    )
                    .foregroundStyle(coin.color.opacity(opacity))
                    .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                }
            }

            if let highlightedCoinId,
               let coin = screenData.first(where: { $0.id == highlightedCoinId }),
               let selectedDate,
               let nearest = coin.returnSeries.min(by: {
                   abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
               }) {
                PointMark(x: .value("Date", nearest.date), y: .value("Return", nearest.returnPct))
                    .foregroundStyle(coin.color.opacity(0.3))
                    .symbolSize(100)
                PointMark(x: .value("Date", nearest.date), y: .value("Return", nearest.returnPct))
                    .foregroundStyle(coin.color)
                    .symbolSize(40)
                PointMark(x: .value("Date", nearest.date), y: .value("Return", nearest.returnPct))
                    .foregroundStyle(Color.white)
                    .symbolSize(12)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let date: Date = proxy.value(atX: value.location.x),
                                      let returnVal: Double = proxy.value(atY: value.location.y) else { return }
                                selectedDate = date
                                if let nearest = nearestCoin(atDate: date, yValue: returnVal) {
                                    withAnimation(.easeOut(duration: 0.15)) {
                                        highlightedCoinId = nearest.id
                                    }
                                }
                            }
                            .onEnded { _ in }
                    )
                    .onTapGesture(count: 2) {
                        onExpandTap?()
                    }
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            if highlightedCoinId != nil {
                                highlightedCoinId = nil
                                selectedDate = nil
                            } else {
                                onExpandTap?()
                            }
                        }
                    }
            }
        }
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
        .frame(height: chartHeight ?? nil)
        .frame(maxHeight: chartHeight == nil ? .infinity : nil)
        .clipped()
    }
}

// MARK: - Fullscreen View

struct AltcoinScreenerFullscreenView: View {
    let screenData: [CoinScreenerData]
    @Binding var timeRange: ScreenerTimeRange
    var onTimeRangeChange: ((ScreenerTimeRange) -> Void)?

    @Environment(\.dismiss) var dismiss
    @State private var selectedDate: Date?
    @State private var highlightedCoinId: String?

    private var highlightedCoin: CoinScreenerData? {
        guard let highlightedCoinId else { return nil }
        return screenData.first { $0.id == highlightedCoinId }
    }

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
                        Text("Altcoin Screener · \(timeRange.rawValue)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        if let coin = highlightedCoin {
                            HStack(spacing: 6) {
                                Circle().fill(coin.color).frame(width: 8, height: 8)
                                Text(coin.symbol)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text(String(format: "%+.2f%%", coin.totalReturn))
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .foregroundColor(coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                                if let vs = coin.vsBTC {
                                    Text("·").foregroundColor(.white.opacity(0.4))
                                    Text("vs BTC \(String(format: "%+.1f%%", vs))")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(vs >= 0 ? AppColors.success.opacity(0.8) : AppColors.error.opacity(0.8))
                                }

                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        highlightedCoinId = nil
                                        selectedDate = nil
                                    }
                                } label: {
                                    Text("Clear")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        } else if let selectedDate, !selectedPoints.isEmpty {
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
                            Text("Drag on chart to explore · Tap a line to isolate")
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

                // Chart
                AltcoinScreenerChartContent(
                    screenData: screenData,
                    selectedDate: $selectedDate,
                    highlightedCoinId: $highlightedCoinId,
                    colorScheme: .dark,
                    chartHeight: nil
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity)

                // Bottom controls: time range + legend
                VStack(spacing: 10) {
                    // Time range picker
                    HStack(spacing: 8) {
                        ForEach(ScreenerTimeRange.allCases, id: \.self) { range in
                            Button {
                                selectedDate = nil
                                highlightedCoinId = nil
                                onTimeRangeChange?(range)
                            } label: {
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

                    // Legend row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(screenData.sorted { $0.totalReturn > $1.totalReturn }) { coin in
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        if highlightedCoinId == coin.id {
                                            highlightedCoinId = nil
                                        } else {
                                            highlightedCoinId = coin.id
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle().fill(coin.color).frame(width: 7, height: 7)
                                        Text(coin.symbol)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(
                                                highlightedCoinId == nil || highlightedCoinId == coin.id
                                                    ? .white.opacity(0.9)
                                                    : .white.opacity(0.3)
                                            )
                                        Text(String(format: "%+.1f%%", coin.totalReturn))
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(
                                                highlightedCoinId == nil || highlightedCoinId == coin.id
                                                    ? (coin.totalReturn >= 0 ? AppColors.success : AppColors.error)
                                                    : .white.opacity(0.2)
                                            )
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        highlightedCoinId == coin.id
                                            ? coin.color.opacity(0.2)
                                            : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
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
