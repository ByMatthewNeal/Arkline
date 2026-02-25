import SwiftUI
import Charts

// MARK: - Supply in Profit Colors
struct SupplyProfitColors {
    static let buyZone = Color(hex: "22C55E")      // Green - excellent accumulation
    static let normal = Color(hex: "3B82F6")       // Blue - normal range
    static let elevated = Color(hex: "F97316")     // Orange - getting hot
    static let overheated = Color(hex: "EF4444")   // Red - potential top

    static func color(for value: Double) -> Color {
        switch value {
        case ..<50:
            return buyZone
        case 50..<85:
            return normal
        case 85..<97:
            return elevated
        default:
            return overheated
        }
    }
}

// MARK: - Supply Chart Time Range
enum SupplyChartTimeRange: String, CaseIterable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var days: Int? {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .all: return nil
        }
    }
}

// MARK: - Supply in Profit Widget
struct SupplyInProfitWidget: View {
    let supplyData: SupplyProfitData?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var signalColor: Color {
        guard let value = supplyData?.value else { return .secondary }
        return SupplyProfitColors.color(for: value)
    }

    private var levelDescription: String {
        supplyData?.signalDescription ?? "--"
    }

    private func formatDataDate(_ dateStr: String) -> String? {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = inputFormatter.date(from: dateStr) else { return nil }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        outputFormatter.timeZone = TimeZone(identifier: "UTC")
        return outputFormatter.string(from: date)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: size == .compact ? 6 : 10) {
                HStack(alignment: .center) {
                    Text("BTC Supply in Profit")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                Text(supplyData?.formattedValue ?? "--")
                    .font(.system(size: size == .compact ? 28 : 36, weight: .semibold, design: .default))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                HStack {
                    if let dateStr = supplyData?.date, let formattedDate = formatDataDate(dateStr) {
                        Text("As of \(formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("BTC supply in profit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(levelDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(signalColor)
                }
            }
            .padding(size == .compact ? 12 : 16)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BTC Supply in Profit, \(supplyData?.formattedValue ?? "loading"), \(levelDescription)")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            SupplyInProfitDetailView(supplyData: supplyData)
        }
    }
}

// MARK: - Supply in Profit Detail View
struct SupplyInProfitDetailView: View {
    let supplyData: SupplyProfitData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var historyData: [SupplyProfitData] = []
    @State private var btcPriceMap: [String: Double] = [:] // date string → BTC price
    @State private var isLoading = false
    @State private var selectedPoint: SupplyProfitData?
    @State private var selectedTimeRange: SupplyChartTimeRange = .oneYear

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var signalColor: Color {
        guard let value = supplyData?.value else { return .gray }
        return SupplyProfitColors.color(for: value)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Value
                    VStack(spacing: 16) {
                        Text(supplyData?.formattedValue ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        Text(supplyData?.signalDescription ?? "Loading...")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(signalColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(signalColor.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)

                    // Timeframe selector + Historical Chart
                    if !historyData.isEmpty {
                        timeRangeSelector
                        chartSection
                    } else if isLoading {
                        ProgressView()
                            .frame(height: 200)
                    }

                    // Explanation
                    MacroInfoSection(title: "What is BTC Supply in Profit?", content: """
BTC Supply in Profit shows the percentage of Bitcoin's total circulating supply that was last moved at a price lower than the current price. It represents the portion of all BTC that would be "in profit" if sold today.

Note: Data is updated daily with approximately a 30-day lag.
""")

                    // Level Guide
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Level Interpretation")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        SupplyLevelRow(range: "Below 50%", description: "Bottom zone - historically great buy", color: SupplyProfitColors.buyZone)
                        SupplyLevelRow(range: "50-85%", description: "Normal market conditions", color: SupplyProfitColors.normal)
                        SupplyLevelRow(range: "85-97%", description: "Elevated - late cycle territory", color: SupplyProfitColors.elevated)
                        SupplyLevelRow(range: "Above 97%", description: "Overheated - potential correction", color: SupplyProfitColors.overheated)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Impact
                    MacroInfoSection(title: "Trading Implications", content: """
• Below 50%: Historically rare and marks major bottoms (2015, 2018, 2022 lows)
• 50-85%: Normal bull/bear market conditions, price can move either direction
• Above 97%: Nearly everyone is in profit - watch for distribution and corrections
• Extreme readings often precede trend reversals
""")

                    // Attribution
                    Text("Source: Santiment")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("BTC Supply in Profit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadHistory() }
        }
    }

    private var filteredHistory: [SupplyProfitData] {
        guard let days = selectedTimeRange.days else { return historyData }
        // Use the latest data point as reference (not today) to account for Santiment's ~30 day lag
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let latestDate = historyData.last.flatMap { formatter.date(from: $0.date) } ?? Date()
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: latestDate) else {
            return historyData
        }
        return historyData.filter { point in
            guard let date = formatter.date(from: point.date) else { return false }
            return date >= cutoff
        }
    }

    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            ForEach(SupplyChartTimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeRange = range
                        selectedPoint = nil
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: selectedTimeRange == range ? .semibold : .regular))
                        .foregroundColor(selectedTimeRange == range ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedTimeRange == range ? AppColors.accent : Color(.systemGray5))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Historical Trend")
                        .font(.headline)
                        .foregroundColor(textPrimary)
                    Spacer()
                    if let point = selectedPoint {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(point.date): \(point.formattedValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let price = btcPrice(for: point.date) {
                                Text("BTC $\(Int(price).formatted())")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                }
            }

            SupplyInProfitChart(
                history: filteredHistory,
                colorScheme: colorScheme,
                selectedPoint: $selectedPoint
            )
            .frame(height: 200)
            .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func loadHistory() {
        isLoading = true
        Task {
            do {
                let service = ServiceContainer.shared.santimentService
                async let supplyTask = service.fetchSupplyInProfitHistory(days: 5000)
                async let btcTask = fetchBTCPriceHistory()

                let history = try await supplyTask
                let priceMap = await btcTask

                await MainActor.run {
                    self.historyData = history.reversed()
                    self.btcPriceMap = priceMap
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    /// Look up BTC price for a date, falling back to nearest available date (within 3 days)
    private func btcPrice(for dateString: String) -> Double? {
        if let exact = btcPriceMap[dateString] { return exact }
        // Try nearby dates (data might be off by a day)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: dateString) else { return nil }
        for offset in 1...3 {
            for dir in [-1, 1] {
                if let nearby = Calendar.current.date(byAdding: .day, value: offset * dir, to: date) {
                    let key = formatter.string(from: nearby)
                    if let price = btcPriceMap[key] { return price }
                }
            }
        }
        return nil
    }

    /// Fetch BTC price history from CoinGecko and build a date → price map
    private func fetchBTCPriceHistory() async -> [String: Double] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        // Try daily-granularity endpoint first (365 days = daily data points)
        if let map = await fetchBTCChart(days: 365, formatter: formatter), !map.isEmpty {
            return map
        }

        // Fallback: use cached market data for just the current price
        if let assets = try? await ServiceContainer.shared.marketService.fetchCryptoAssets(page: 1, perPage: 10),
           let btc = assets.first(where: { $0.symbol.lowercased() == "btc" }) {
            let today = formatter.string(from: Date())
            return [today: btc.currentPrice]
        }

        return [:]
    }

    private func fetchBTCChart(days: Int, formatter: DateFormatter) async -> [String: Double]? {
        do {
            let endpoint = CoinGeckoEndpoint.coinMarketChart(id: "bitcoin", currency: "usd", days: days)
            let chart: CoinGeckoMarketChart = try await NetworkManager.shared.request(endpoint)

            var map: [String: Double] = [:]
            for point in chart.prices {
                guard point.count >= 2 else { continue }
                let date = Date(timeIntervalSince1970: point[0] / 1000)
                let dateStr = formatter.string(from: date)
                map[dateStr] = point[1]
            }
            return map
        } catch {
            logWarning("BTC chart fetch failed (days=\(days)): \(error.localizedDescription)", category: .network)
            return nil
        }
    }
}

// MARK: - Supply Level Row
struct SupplyLevelRow: View {
    let range: String
    let description: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 90, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Supply in Profit Chart
struct SupplyInProfitChart: View {
    let history: [SupplyProfitData]
    let colorScheme: ColorScheme
    @Binding var selectedPoint: SupplyProfitData?

    private var chartData: [(date: Date, value: Double, original: SupplyProfitData)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        return history.compactMap { point in
            guard let date = formatter.date(from: point.date) else { return nil }
            return (date: date, value: point.value, original: point)
        }
    }

    private var lineColor: Color {
        colorScheme == .dark ? AppColors.accent : AppColors.accent
    }

    var body: some View {
        Chart {
            // Zone backgrounds - simplified to 3 zones for cleaner look
            RectangleMark(yStart: .value("Start", 0), yEnd: .value("End", 50))
                .foregroundStyle(SupplyProfitColors.buyZone.opacity(0.12))
            RectangleMark(yStart: .value("Start", 50), yEnd: .value("End", 85))
                .foregroundStyle(SupplyProfitColors.normal.opacity(0.08))
            RectangleMark(yStart: .value("Start", 85), yEnd: .value("End", 100))
                .foregroundStyle(SupplyProfitColors.overheated.opacity(0.12))

            // Area fill with accent color
            ForEach(chartData, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            lineColor.opacity(0.25),
                            lineColor.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }

            // Line with app accent color
            ForEach(chartData, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            // Selected point indicator
            if let selected = selectedPoint,
               let date = selected.dateObject {
                RuleMark(x: .value("Selected", date))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Date", date),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(60)
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.08)
                    )
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(String(format: "%.0f%%", doubleValue))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
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
                                    selectedPoint = closest?.original
                                }
                            }
                            .onEnded { _ in }
                    )
                    .onTapGesture { location in
                        if let date: Date = proxy.value(atX: location.x) {
                            let closest = chartData.min { a, b in
                                abs(a.date.timeIntervalSince(date)) < abs(b.date.timeIntervalSince(date))
                            }
                            if selectedPoint?.date == closest?.original.date {
                                selectedPoint = nil
                            } else {
                                selectedPoint = closest?.original
                            }
                        }
                    }
            }
        }
    }
}
