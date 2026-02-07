import SwiftUI
import Charts

// MARK: - Macro Chart Time Range
enum MacroChartTimeRange: String, CaseIterable {
    case sevenDays = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
    case oneYear = "1Y"

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .oneYear: return 365
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

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var selectedPoint: MacroChartPoint? {
        guard let selectedDate = selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var yDomain: ClosedRange<Double> {
        guard let minVal = data.map(\.value).min(),
              let maxVal = data.map(\.value).max() else {
            return 0...1
        }
        let padding = (maxVal - minVal) * 0.1
        return (minVal - padding)...(maxVal + padding)
    }

    private var xAxisLabelCount: Int {
        switch selectedTimeRange {
        case .sevenDays: return 4
        case .thirtyDays: return 5
        case .ninetyDays: return 4
        case .oneYear: return 6
        }
    }

    private func formatLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case .sevenDays: formatter.dateFormat = "EEE"
        case .thirtyDays: formatter.dateFormat = "MMM d"
        case .ninetyDays: formatter.dateFormat = "MMM"
        case .oneYear: formatter.dateFormat = "MMM yy"
        }
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Time range picker
            timeRangePicker

            // Tooltip
            if let point = selectedPoint {
                HStack(spacing: 8) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Text(valueFormatter(point.value))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(lineColor)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }

            // Chart
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
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
            } else {
                chartView
                    .frame(height: 200)
            }
        }
    }

    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        HStack(spacing: ArkSpacing.xs) {
            ForEach(MacroChartTimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedTimeRange = range
                    selectedDate = nil
                }) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTimeRange == range ? .semibold : .regular)
                        .foregroundColor(
                            selectedTimeRange == range ? .white : textPrimary
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

    // MARK: - Chart View
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
                .interpolationMethod(.catmullRom)
            }

            // Line
            ForEach(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
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
        }
    }
}
