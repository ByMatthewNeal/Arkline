import SwiftUI
import Charts

struct RSIChartView: View {
    let rsiSeries: [RSISeriesPoint]
    let divergences: [RSIDivergence]
    @Binding var selectedDate: Date?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if rsiSeries.isEmpty {
            emptyView
        } else {
            chartView
        }
    }

    private var chartView: some View {
        let nearest = selectedDate.flatMap { date in
            nearestRSI(to: date, in: rsiSeries)
        }

        return Chart {
            // Overbought zone fill (70-100) — subtle brand-tinted red
            RectangleMark(
                xStart: .value("Start", rsiSeries.first?.date ?? Date()),
                xEnd: .value("End", rsiSeries.last?.date ?? Date()),
                yStart: .value("OB Low", 70),
                yEnd: .value("OB High", 100)
            )
            .foregroundStyle(AppColors.error.opacity(0.08))

            // Oversold zone fill (0-30) — subtle brand-tinted green
            RectangleMark(
                xStart: .value("Start", rsiSeries.first?.date ?? Date()),
                xEnd: .value("End", rsiSeries.last?.date ?? Date()),
                yStart: .value("OS Low", 0),
                yEnd: .value("OS High", 30)
            )
            .foregroundStyle(AppColors.accent.opacity(0.06))

            // Reference lines
            RuleMark(y: .value("OB", 70))
                .foregroundStyle(AppColors.error.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            RuleMark(y: .value("Mid", 50))
                .foregroundStyle(Color.gray.opacity(0.15))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
            RuleMark(y: .value("OS", 30))
                .foregroundStyle(AppColors.success.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

            // RSI line — brand accent blue with subtle color shift at extremes
            ForEach(rsiSeries) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("RSI", point.value),
                    series: .value("Series", "rsi")
                )
                .foregroundStyle(AppColors.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }

            // Divergence trendlines
            ForEach(divergences) { div in
                // Start point
                PointMark(
                    x: .value("Date", div.startDate),
                    y: .value("RSI", div.rsiStart)
                )
                .foregroundStyle(div.type.color)
                .symbolSize(20)

                // End point
                PointMark(
                    x: .value("Date", div.endDate),
                    y: .value("RSI", div.rsiEnd)
                )
                .foregroundStyle(div.type.color)
                .symbolSize(20)

                // Connecting line
                LineMark(
                    x: .value("Date", div.startDate),
                    y: .value("RSI", div.rsiStart),
                    series: .value("Div", div.id.uuidString)
                )
                .foregroundStyle(div.type.color.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))

                LineMark(
                    x: .value("Date", div.endDate),
                    y: .value("RSI", div.rsiEnd),
                    series: .value("Div", div.id.uuidString)
                )
                .foregroundStyle(div.type.color.opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            }

            // Selection crosshair
            if let point = nearest {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(AppColors.accent.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 0.5))

                PointMark(x: .value("Date", point.date), y: .value("RSI", point.value))
                    .foregroundStyle(AppColors.accent.opacity(0.25))
                    .symbolSize(25)
                PointMark(x: .value("Date", point.date), y: .value("RSI", point.value))
                    .foregroundStyle(AppColors.accent)
                    .symbolSize(8)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [30, 50, 70]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 8))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .chartLegend(.hidden)
    }

    // MARK: - Helpers

    private func rsiColor(for value: Double) -> Color {
        if value >= 70 { return AppColors.error }
        if value <= 30 { return AppColors.success }
        return AppColors.accent
    }

    private func nearestRSI(to date: Date, in points: [RSISeriesPoint]) -> RSISeriesPoint? {
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

    private var emptyView: some View {
        HStack {
            Spacer()
            Text("RSI data unavailable")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
        .frame(height: 100)
    }
}
