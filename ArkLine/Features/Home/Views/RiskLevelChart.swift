import SwiftUI
import Charts

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
        let raw: [(date: Date, risk: Double, price: Double?, fairValue: Double?)]
        if let enhanced = enhancedHistory {
            raw = enhanced.map { (date: $0.date, risk: $0.riskLevel, price: $0.price, fairValue: $0.fairValue) }
        } else {
            raw = history.compactMap { level in
                guard let date = RiskDateFormatters.iso.date(from: level.date) else { return nil }
                return (date: date, risk: level.riskLevel, price: level.price, fairValue: level.fairValue)
            }
        }
        return downsampled(raw)
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
        let formatter: DateFormatter = switch timeRange {
        case .sevenDays: RiskDateFormatters.sevenDay
        case .thirtyDays: RiskDateFormatters.thirtyDay
        case .ninetyDays, .oneYear: RiskDateFormatters.month
        case .all: RiskDateFormatters.monthYear
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
        let data = chartData
        let nearest = selectedDate.flatMap { nearestByDate(in: data, to: $0) { $0.date } }
        let lineCol = RiskColors.color(for: data.last?.risk ?? 0.5)

        Chart {
            // Subtle threshold lines instead of colored bands
            ForEach(thresholds, id: \.value) { threshold in
                RuleMark(y: .value("Threshold", threshold.value))
                    .foregroundStyle(threshold.color.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            // Selection crosshair
            if let point = nearest {
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
            ForEach(data, id: \.date) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            lineCol.opacity(0.15),
                            lineCol.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Primary line — smooth, weighted
            ForEach(data, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Risk", point.risk)
                )
                .foregroundStyle(lineCol)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            // Selected point — polished indicator
            if let point = nearest {
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
                                if let date: Date = proxy.value(atX: x),
                                   let closest = nearestByDate(in: data, to: date, dateOf: { $0.date }) {
                                    selectedDate = closest.date
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
        return nearestByDate(in: enhancedHistory, to: selectedDate, dateOf: \.date)
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

// MARK: - Chart Data Downsampling
/// Uniformly downsample an array to at most maxPoints, preserving first and last elements.
/// Reduces Swift Charts mark count from thousands to ~250 for smooth drag interaction.
func downsampled<T>(_ items: [T], maxPoints: Int = 250) -> [T] {
    guard items.count > maxPoints, maxPoints >= 2 else { return items }
    var result = [items[0]]
    let step = Double(items.count - 1) / Double(maxPoints - 1)
    for i in 1..<(maxPoints - 1) {
        result.append(items[Int(Double(i) * step)])
    }
    result.append(items[items.count - 1])
    return result
}

// MARK: - Binary Search for Nearest Date
/// O(log n) lookup for the nearest element to a target date in a sorted-by-date array
func nearestByDate<T>(in items: [T], to target: Date, dateOf: (T) -> Date) -> T? {
    guard !items.isEmpty else { return nil }
    var low = 0, high = items.count - 1
    while low < high {
        let mid = (low + high) / 2
        if dateOf(items[mid]) < target { low = mid + 1 } else { high = mid }
    }
    guard low > 0 else { return items[0] }
    let before = items[low - 1], after = items[min(low, items.count - 1)]
    return abs(dateOf(before).timeIntervalSince(target)) <= abs(dateOf(after).timeIntervalSince(target)) ? before : after
}
