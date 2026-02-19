import SwiftUI
import Charts

struct TrendChannelChart: View {
    let channelData: LogRegressionChannelData?
    let consolidationRanges: [ConsolidationRange]
    @Binding var selectedDate: Date?
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme

    private var points: [LogRegressionPoint] {
        channelData?.points ?? []
    }

    var body: some View {
        if isLoading {
            loadingView
        } else if points.isEmpty {
            emptyView
        } else {
            chartContent
        }
    }

    private var chartContent: some View {
        Chart {
            backgroundZones
            channelBands
            channelLines
            priceLine
            selectionMarks
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.06))
                AxisValueLabel()
                    .foregroundStyle(AppColors.textSecondary)
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.gray.opacity(0.06))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatPrice(v))
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color.clear)
                .overlay { ChartLogoWatermark() }
        }
        .chartLegend(.hidden)
    }

    // MARK: - Chart Content Builders

    /// Full-height background columns colored by zone (green/yellow/red)
    /// This creates the TradingView-style colored background that makes
    /// bullish vs bearish periods immediately obvious
    @ChartContentBuilder
    private var backgroundZones: some ChartContent {
        let domain = yDomain
        ForEach(points) { point in
            RectangleMark(
                x: .value("Date", point.date),
                yStart: .value("Low", domain.lowerBound),
                yEnd: .value("High", domain.upperBound),
                width: 3
            )
            .foregroundStyle(zoneBackgroundColor(point.zone))
        }
    }

    /// Channel band fills between the regression lines
    @ChartContentBuilder
    private var channelBands: some ChartContent {
        ForEach(points) { point in
            // Full channel fill (light blue tint)
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Lower", point.lowerBand),
                yEnd: .value("Upper", point.upperBand)
            )
            .foregroundStyle(AppColors.accent.opacity(0.06))
        }
    }

    /// Channel boundary lines (upper, lower, fitted center)
    @ChartContentBuilder
    private var channelLines: some ChartContent {
        ForEach(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Upper", point.upperBand),
                series: .value("Series", "upper")
            )
            .foregroundStyle(AppColors.accent.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            LineMark(
                x: .value("Date", point.date),
                y: .value("Lower", point.lowerBand),
                series: .value("Series", "lower")
            )
            .foregroundStyle(AppColors.accent.opacity(0.6))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            LineMark(
                x: .value("Date", point.date),
                y: .value("Fitted", point.fittedPrice),
                series: .value("Series", "fitted")
            )
            .foregroundStyle(AppColors.accent.opacity(0.4))
            .lineStyle(StrokeStyle(lineWidth: 1))
        }
    }

    /// Price line — uses brand accent blue for on-brand consistency
    @ChartContentBuilder
    private var priceLine: some ChartContent {
        ForEach(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close),
                series: .value("Series", "price")
            )
            .foregroundStyle(AppColors.accent)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    /// Selection crosshair and point indicator
    @ChartContentBuilder
    private var selectionMarks: some ChartContent {
        if let date = selectedDate, let point = nearestPoint(to: date, in: points) {
            RuleMark(x: .value("Selected", point.date))
                .foregroundStyle(AppColors.accent.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.5))

            PointMark(x: .value("Date", point.date), y: .value("Price", point.close))
                .foregroundStyle(AppColors.accent.opacity(0.25))
                .symbolSize(100)
            PointMark(x: .value("Date", point.date), y: .value("Price", point.close))
                .foregroundStyle(AppColors.accent)
                .symbolSize(30)
        }
    }

    // MARK: - Zone Color Logic

    /// Returns a background color blending brand blue with green/red zone tinting.
    /// Value zones get a blue-green tint, overextended zones get a blue-red tint.
    private func zoneBackgroundColor(_ zone: TrendChannelZone) -> Color {
        let base = colorScheme == .dark ? 0.12 : 0.10
        switch zone {
        case .deepValue:
            return Color(hex: "22C55E").opacity(base * 1.2)
        case .value:
            return Color(hex: "3B82F6").opacity(base * 0.8)
        case .fair:
            return Color(hex: "3B82F6").opacity(base * 0.4)
        case .elevated:
            return Color(hex: "F59E0B").opacity(base * 0.7)
        case .overextended:
            return Color(hex: "DC2626").opacity(base * 1.1)
        }
    }

    // MARK: - Helpers

    private var yDomain: ClosedRange<Double> {
        guard !points.isEmpty else { return 0...100 }
        let allValues = points.flatMap { [$0.close, $0.upperBand, $0.lowerBand] }
        let minVal = (allValues.min() ?? 0) * 0.97
        let maxVal = (allValues.max() ?? 100) * 1.03
        return minVal...maxVal
    }

    private func formatPrice(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func nearestPoint(to date: Date, in points: [LogRegressionPoint]) -> LogRegressionPoint? {
        guard !points.isEmpty else { return nil }
        var lo = 0, hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        if lo > 0 {
            let before = points[lo - 1]
            let after = points[lo]
            return abs(before.date.timeIntervalSince(date)) < abs(after.date.timeIntervalSince(date)) ? before : after
        }
        return points[lo]
    }

    // MARK: - Placeholder Views

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 300)
    }

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No data available")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(height: 300)
    }
}
