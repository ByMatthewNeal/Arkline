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
    @State private var isLoading = false
    @State private var selectedPoint: SupplyProfitData?

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

                    // Historical Chart
                    if !historyData.isEmpty {
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

    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Historical Trend")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
                if let point = selectedPoint {
                    Text("\(point.date): \(point.formattedValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            SupplyInProfitChart(
                history: historyData,
                colorScheme: colorScheme,
                selectedPoint: $selectedPoint
            )
            .frame(height: 200)
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
                let history = try await service.fetchSupplyInProfitHistory(days: 90)
                await MainActor.run {
                    // Reverse to get oldest first for charting
                    self.historyData = history.reversed()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
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
