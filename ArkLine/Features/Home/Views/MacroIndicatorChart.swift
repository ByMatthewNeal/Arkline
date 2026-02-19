import SwiftUI
import Charts

// MARK: - Macro Chart Time Range
enum MacroChartTimeRange: String, CaseIterable {
    case daily = "D"
    case threeDays = "3D"
    case weekly = "W"
    case monthly = "M"

    var days: Int {
        switch self {
        case .daily: return 7
        case .threeDays: return 30
        case .weekly: return 90
        case .monthly: return 365
        }
    }
}

// MARK: - Chart Data Point
struct MacroChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Macro Indicator Chart
struct MacroIndicatorChart: View {
    let data: [MacroChartPoint]
    let lineColor: Color
    let valueFormatter: (Double) -> String
    @Binding var selectedTimeRange: MacroChartTimeRange
    @Binding var selectedDate: Date?
    let isLoading: Bool

    // Optional overlay (e.g. BTC price on M2 chart)
    var overlayData: [MacroChartPoint]? = nil
    var overlayColor: Color = .orange
    var overlayLabel: String = "BTC"
    var overlayValueFormatter: ((Double) -> String)? = nil
    var primaryLabel: String = ""

    @Environment(\.colorScheme) var colorScheme
    @Namespace private var macroTimeframeAnimation

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var hasOverlay: Bool {
        guard let overlay = overlayData else { return false }
        return !overlay.isEmpty
    }

    private var selectedPoint: MacroChartPoint? {
        guard let selectedDate = selectedDate else { return nil }
        let source = hasOverlay ? normalizedPrimary : data
        return source.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    /// Find the closest original (non-normalized) data point for tooltip display
    private var selectedOriginalPoint: MacroChartPoint? {
        guard let selectedDate = selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var selectedOverlayPoint: MacroChartPoint? {
        guard let selectedDate = selectedDate, let overlay = overlayData else { return nil }
        return overlay.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var periodChange: Double? {
        guard data.count >= 2,
              let first = data.first,
              let last = data.last,
              first.value != 0 else { return nil }
        return ((last.value - first.value) / first.value) * 100
    }

    // MARK: - Normalization (for overlay mode)

    private func normalize(_ points: [MacroChartPoint]) -> [MacroChartPoint] {
        let values = points.map(\.value)
        guard let minVal = values.min(), let maxVal = values.max(), maxVal > minVal else { return points }
        return points.map { MacroChartPoint(date: $0.date, value: ($0.value - minVal) / (maxVal - minVal)) }
    }

    private var normalizedPrimary: [MacroChartPoint] {
        normalize(data)
    }

    private var normalizedOverlay: [MacroChartPoint] {
        guard let overlay = overlayData else { return [] }
        return normalize(overlay)
    }

    private var chartData: [MacroChartPoint] {
        hasOverlay ? normalizedPrimary : data
    }

    private var yDomain: ClosedRange<Double> {
        if hasOverlay {
            return -0.05...1.05 // Normalized range with padding
        }
        guard let minVal = data.map(\.value).min(),
              let maxVal = data.map(\.value).max() else {
            return 0...1
        }
        let padding = (maxVal - minVal) * 0.1
        return (minVal - padding)...(maxVal + padding)
    }

    private var xAxisLabelCount: Int {
        switch selectedTimeRange {
        case .daily: return 4
        case .threeDays: return 5
        case .weekly: return 4
        case .monthly: return 6
        }
    }

    private func formatLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .daily: formatter.dateFormat = "EEE"
        case .threeDays: formatter.dateFormat = "MMM d"
        case .weekly: formatter.dateFormat = "MMM"
        case .monthly: formatter.dateFormat = "MMM yy"
        }
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Time range picker
            timeRangePicker

            // Value summary with period change
            if hasOverlay {
                overlayTooltip
            } else if let point = selectedPoint {
                HStack(spacing: 8) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Text(valueFormatter(point.value))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(lineColor)

                    if let change = periodChange {
                        Text(String(format: "%+.1f%%", change))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            } else if !data.isEmpty, let last = data.last {
                HStack(spacing: 8) {
                    Text(valueFormatter(last.value))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary)

                    if let change = periodChange {
                        Text(String(format: "%+.1f%%", change))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }

                    Text(selectedTimeRange.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            // Chart
            if isLoading {
                SkeletonChartView()
            } else if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Text("No data available")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            } else if hasOverlay {
                overlayChartView
                    .frame(height: 200)
                    .clipped()
                    .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
            } else {
                chartView
                    .frame(height: 200)
                    .clipped()
                    .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
            }

            // Legend (only in overlay mode)
            if hasOverlay {
                chartLegend
            }
        }
    }

    // MARK: - Overlay Tooltip
    private var overlayTooltip: some View {
        Group {
            if let primaryPt = selectedOriginalPoint {
                HStack(spacing: 12) {
                    Text(primaryPt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    // Primary value
                    HStack(spacing: 4) {
                        Circle().fill(lineColor).frame(width: 6, height: 6)
                        Text(valueFormatter(primaryPt.value))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(lineColor)
                    }

                    // Overlay value
                    if let overlayPt = selectedOverlayPoint,
                       let formatter = overlayValueFormatter {
                        HStack(spacing: 4) {
                            Circle().fill(overlayColor).frame(width: 6, height: 6)
                            Text(formatter(overlayPt.value))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(overlayColor)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Chart Legend
    private var chartLegend: some View {
        HStack(spacing: 16) {
            if !primaryLabel.isEmpty {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(lineColor)
                        .frame(width: 12, height: 3)
                    Text(primaryLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.6))
                }
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(overlayColor)
                    .frame(width: 12, height: 3)
                Text(overlayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        HStack(spacing: ArkSpacing.xs) {
            ForEach(MacroChartTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTimeRange = range
                        selectedDate = nil
                    }
                }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(
                            selectedTimeRange == range ? .white : textPrimary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ArkSpacing.sm)
                        .background {
                            if selectedTimeRange == range {
                                RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                    .fill(AppColors.accent)
                                    .matchedGeometryEffect(id: "macroTimeframe", in: macroTimeframeAnimation)
                            } else {
                                RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Overlay Chart View (normalized dual-line)
    private var overlayChartView: some View {
        Chart {
            // Selection crosshair
            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.15)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))
            }

            // Primary line (M2)
            ForEach(normalizedPrimary) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Series", "Primary")
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            // Overlay line (BTC)
            ForEach(normalizedOverlay) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Series", "Overlay")
                )
                .foregroundStyle(overlayColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .chartYAxis(.hidden)
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
                .overlay {
                    ChartLogoWatermark()
                }
        }
    }

    // MARK: - Single-Series Chart View
    private var chartView: some View {
        Chart {
            // Selection crosshair
            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.25)
                            : Color.black.opacity(0.15)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5))

                RuleMark(y: .value("Value", point.value))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.08)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
            }

            // Area fill
            ForEach(data) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.15), lineColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.linear)
            }

            // Line
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)
            }

            // Selected point indicator
            if let point = selectedPoint {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor.opacity(0.3))
                .symbolSize(120)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(50)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(Color.white)
                .symbolSize(14)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(
                        colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.black.opacity(0.06)
                    )
                AxisValueLabel(anchor: .leading) {
                    if let v = value.as(Double.self) {
                        Text(valueFormatter(v))
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
                .overlay {
                    ChartLogoWatermark()
                }
        }
    }
}
