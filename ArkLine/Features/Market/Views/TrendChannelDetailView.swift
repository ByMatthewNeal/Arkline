import SwiftUI

struct TrendChannelDetailView: View {
    let initialIndex: IndexSymbol
    @State private var viewModel = TrendChannelViewModel()
    @State private var showFullscreenChart = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Price header
                    priceHeader

                    // Selection tooltip
                    if viewModel.selectedDate != nil {
                        selectionTooltip
                    }

                    // Main chart
                    TrendChannelChart(
                        channelData: viewModel.channelData,
                        consolidationRanges: viewModel.consolidationRanges,
                        selectedDate: $viewModel.selectedDate,
                        isLoading: viewModel.isLoading
                    )
                    .frame(height: 300)

                    // RSI label
                    HStack {
                        Text("RSI (14)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        if let rsi = viewModel.rsiSeries.last {
                            Text(String(format: "%.1f", rsi.value))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(rsiColor(rsi.value))
                        }
                    }
                    .padding(.horizontal, 4)

                    // RSI subplot
                    RSIChartView(
                        rsiSeries: viewModel.rsiSeries,
                        divergences: viewModel.divergences,
                        selectedDate: $viewModel.selectedDate
                    )
                    .frame(height: 100)

                    // Time range picker
                    timeRangePicker

                    // Analysis card
                    if let channel = viewModel.channelData {
                        analysisCard(channel)
                    }

                    // Divergence alerts
                    if !viewModel.divergences.isEmpty {
                        divergenceSection
                    }

                    // How to read this chart
                    channelGuideCard

                    // RSI guide
                    rsiGuideCard

                    // Legend
                    legendCard

                    FinancialDisclaimer()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("\(initialIndex.displayName) Trend Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showFullscreenChart = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                        }
                        Button("Done") { dismiss() }
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .fullScreenCover(isPresented: $showFullscreenChart) {
                TrendChannelFullscreenView(viewModel: viewModel)
            }
            .task {
                viewModel.selectedIndex = initialIndex
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Price Header

    private var priceHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedIndex.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))

                if let price = viewModel.currentPrice {
                    Text(formatCurrency(price))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(colorScheme))
                        .monospacedDigit()
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let change = viewModel.priceChange {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2.bold())
                        Text(String(format: "%+.2f%%", change))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(change >= 0 ? AppColors.success : AppColors.error)
                }

                if let zone = viewModel.channelData?.currentZone {
                    Text(zone.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(zone.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(zone.color.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Selection Tooltip

    private var selectionTooltip: some View {
        Group {
            if let point = viewModel.selectedChannelPoint() {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(point.date))
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(formatCurrency(point.close))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.textPrimary(colorScheme))
                    }

                    Divider().frame(height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zone")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(point.zone.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(point.zone.color)
                    }

                    if let rsi = viewModel.selectedRSIPoint() {
                        Divider().frame(height: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RSI")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                            Text(String(format: "%.1f", rsi.value))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(rsiColor(rsi.value))
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                )
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TrendChannelTimeRange.allCases) { range in
                Button {
                    Task { await viewModel.switchTimeRange(range) }
                } label: {
                    Text(range.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.selectedTimeRange == range
                                ? Color.white
                                : AppColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTimeRange == range
                                ? AppColors.accent
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "F0F0F0"))
        )
    }

    // MARK: - Analysis Card

    private func analysisCard(_ channel: LogRegressionChannelData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppColors.accent)
                Text("Channel Analysis")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
            }

            // Current zone interpretation
            zoneInterpretation(channel.currentZone)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                analysisItem(
                    label: "Current Zone",
                    value: channel.currentZone.rawValue,
                    color: channel.currentZone.color
                )
                analysisItem(
                    label: "Signal",
                    value: channel.currentZone.signal,
                    color: channel.currentZone.color
                )
                analysisItem(
                    label: "Growth Rate",
                    value: String(format: "%.1f%% /yr", channel.annualizedGrowthRate * 100),
                    color: channel.annualizedGrowthRate > 0 ? AppColors.success : AppColors.error
                )
                analysisItem(
                    label: "R-Squared",
                    value: String(format: "%.3f", channel.rSquared),
                    color: channel.rSquared > 0.9 ? AppColors.success : AppColors.warning
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private func zoneInterpretation(_ zone: TrendChannelZone) -> some View {
        let message: String
        switch zone {
        case .deepValue:
            message = "Price is well below the long-term trend. Historically, periods like this have been strong buying opportunities."
        case .value:
            message = "Price is below the long-term average. This zone has historically offered favorable risk/reward for accumulation."
        case .fair:
            message = "Price is near the long-term trend line. The index is trading at fair value relative to its historical growth path."
        case .elevated:
            message = "Price is above the long-term average. Gains may be limited in the short term. Consider a more cautious approach."
        case .overextended:
            message = "Price is significantly above the long-term trend. Historically, these levels have preceded pullbacks or periods of consolidation."
        }

        return Text(message)
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func analysisItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Divergence Section

    private var divergenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(AppColors.warning)
                Text("RSI Divergences")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
            }

            Text("A divergence occurs when price and RSI move in opposite directions, often signaling a potential trend reversal.")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(viewModel.divergences) { div in
                HStack(spacing: 12) {
                    Image(systemName: div.type.icon)
                        .foregroundStyle(div.type.color)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(div.type.rawValue) Divergence")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.textPrimary(colorScheme))
                        Text("\(formatDate(div.startDate)) - \(formatDate(div.endDate))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(String(format: "RSI %.0f > %.0f", div.rsiStart, div.rsiEnd))
                        .font(.caption)
                        .foregroundStyle(div.type.color)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    // MARK: - Channel Guide

    private var channelGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book")
                    .foregroundStyle(AppColors.accent)
                Text("Understanding the Channel")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
            }

            VStack(alignment: .leading, spacing: 10) {
                guideRow(
                    icon: "arrow.up.right",
                    color: AppColors.accent,
                    title: "Trend Line",
                    text: "The center line represents the long-term growth trend using logarithmic regression. Price tends to revert toward this line over time."
                )

                guideRow(
                    icon: "arrow.up.and.down",
                    color: AppColors.accent.opacity(0.7),
                    title: "Channel Bands",
                    text: "The dashed upper and lower bands mark 2 standard deviations from the trend. Price rarely stays outside these boundaries for long."
                )

                guideRow(
                    icon: "paintpalette",
                    color: AppColors.success,
                    title: "Zone Colors",
                    text: "Green background = price is below trend (potential value). Red background = price is above trend (potentially overextended). Blue = near fair value."
                )

                guideRow(
                    icon: "chart.bar.fill",
                    color: AppColors.warning,
                    title: "R-Squared",
                    text: "Measures how well price follows the trend channel. Values above 0.90 indicate a strong, reliable trend. Lower values suggest the channel is less predictive."
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    // MARK: - RSI Guide

    private var rsiGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(AppColors.accent)
                Text("Reading the RSI")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
            }

            VStack(alignment: .leading, spacing: 10) {
                guideRow(
                    icon: "arrow.up",
                    color: AppColors.error,
                    title: "Above 70 — Overbought",
                    text: "Momentum is high. The index may be due for a pullback or a period of sideways consolidation."
                )

                guideRow(
                    icon: "minus",
                    color: AppColors.accent,
                    title: "30 to 70 — Neutral",
                    text: "Normal trading range. The RSI alone doesn't signal a strong directional bias in this zone."
                )

                guideRow(
                    icon: "arrow.down",
                    color: AppColors.success,
                    title: "Below 30 — Oversold",
                    text: "Momentum is low. Historically, these levels have preceded bounces or the start of new uptrends."
                )

                guideRow(
                    icon: "arrow.triangle.swap",
                    color: AppColors.warning,
                    title: "Divergences",
                    text: "When price makes a new high but RSI doesn't (bearish), or price makes a new low but RSI doesn't (bullish), it can warn of a trend reversal."
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private func guideRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Legend

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legend")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 16) {
                legendItem(color: AppColors.accent, label: "Price Line")
                legendItem(color: AppColors.success, label: "Value Zone")
                legendItem(color: AppColors.error, label: "Overextended")
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(AppColors.accent.opacity(0.6))
                        .frame(width: 16, height: 1)
                    Text("Channel Bounds")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(AppColors.accent.opacity(0.4))
                        .frame(width: 16, height: 1)
                    Text("Regression Fit")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Helpers

    private func rsiColor(_ value: Double) -> Color {
        if value >= 70 { return AppColors.error }
        if value <= 30 { return AppColors.success }
        return AppColors.accent
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if viewModel.selectedTimeRange == .fourHour {
            formatter.dateFormat = "MMM d, h:mm a"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Indexes Section for Market Overview

struct IndexesSection: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(AppColors.accent)
                Text("Indexes")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary(colorScheme))
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                IndexWidgetCard(index: .sp500)
                IndexWidgetCard(index: .nasdaq)
            }
            .padding(.horizontal)
        }
    }
}

struct IndexWidgetCard: View {
    let index: IndexSymbol
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var abbreviation: String {
        switch index {
        case .sp500: return "SPX"
        case .nasdaq: return "NDX"
        }
    }

    private var subtitle: String {
        switch index {
        case .sp500: return "Log regression trend channel"
        case .nasdaq: return "Log regression trend channel"
        }
    }

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 16) {
                // Text-based ticker badge (professional finance style)
                Text(abbreviation)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent.opacity(0.12))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(index.displayName)
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary(colorScheme))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            TrendChannelDetailView(initialIndex: index)
        }
    }
}
