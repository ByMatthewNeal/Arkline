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

// MARK: - Altcoin Screener Section

struct AltcoinScreenerSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var screenData: [CoinScreenerData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDate: Date?
    @State private var lastFetchedAt: Date?

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    private let cacheTTL: TimeInterval = 600 // 10 minutes

    private let screenerColors: [Color] = [
        .pink, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .brown, .red
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
            .frame(height: 280)
            .clipped()

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
            // Chart skeleton
            SkeletonView(height: 280, cornerRadius: 16)

            // Table skeleton
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

    private struct TooltipCoin: Identifiable {
        let id: String
        let symbol: String
        let color: Color
        let returnPct: Double
    }

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
            // 1. Fetch top coins list
            let assets = try await marketService.fetchCryptoAssets(page: 1, perPage: 12)
            guard !assets.isEmpty else {
                errorMessage = "No coin data available"
                isLoading = false
                return
            }

            // 2. Fetch 30-day charts in parallel (throttled to 3 concurrent)
            let chartResults = try await fetchChartsThrottled(for: assets)

            // 3. Find BTC return for "vs BTC" column
            let btcReturn = chartResults.first { $0.symbol.uppercased() == "BTC" }?.totalReturn ?? 0

            // 4. Assign colors and build screen data
            var result: [CoinScreenerData] = []
            for (index, item) in chartResults.enumerated() {
                let color = screenerColors[index % screenerColors.count]
                let vsBTC: Double? = item.symbol.uppercased() == "BTC" ? nil : item.totalReturn - btcReturn
                result.append(CoinScreenerData(
                    id: item.id,
                    symbol: item.symbol.uppercased(),
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

    private func fetchChartsThrottled(for assets: [CryptoAsset]) async throws -> [ChartResult] {
        try await withThrowingTaskGroup(of: ChartResult?.self) { group in
            // Semaphore-like behavior: add tasks in batches of 3
            var results: [ChartResult] = []
            var index = 0

            for asset in assets {
                group.addTask { [index] in
                    // Stagger requests to avoid rate limiting
                    if index >= 3 {
                        try await Task.sleep(nanoseconds: UInt64(index / 3) * 500_000_000)
                    }
                    do {
                        let chart = try await marketService.fetchCoinMarketChart(
                            id: asset.id, currency: "usd", days: 30
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
                            id: asset.id,
                            symbol: asset.symbol,
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

// MARK: - Preview

#Preview {
    ScrollView {
        AltcoinScreenerSection()
    }
    .background(Color(hex: "0F0F0F"))
}
