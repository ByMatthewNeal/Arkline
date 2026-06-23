import SwiftUI

// MARK: - Market Breadth Detail View
struct MarketBreadthDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var history: [MarketBreadthPoint] = []
    @State private var crossovers: [MarketBreadthPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRange: TimeRange = .threeMonths

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    enum TimeRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var days: Int {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && history.isEmpty {
                    // First load (or retry) in progress — show a spinner rather
                    // than collapsing to just the explanation card.
                    loadingState
                } else if history.isEmpty {
                    // Load finished but we have no data (transient failure) —
                    // surface it with a retry instead of failing silently.
                    errorState
                } else {
                    // Current status card
                    if let latest = history.last {
                        currentStatusCard(latest)
                    }

                    // Recent signals
                    if !crossovers.isEmpty {
                        recentSignals
                    }

                    // Chart section
                    if history.count >= 2 {
                        chartSection
                    }
                }

                // How it works (always available)
                howItWorks
            }
            .padding(.vertical)
        }
        .navigationTitle("Market Breadth")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.background(colorScheme))
        .task {
            await loadData()
        }
        .onChange(of: selectedRange) {
            Task { await loadData() }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        let service = ServiceContainer.shared.marketBreadthService

        // History drives the entire view, so fetch it on its own and never let a
        // failure in the secondary crossovers call discard it. One quick retry
        // absorbs transient network/session hiccups before we surface an error.
        do {
            history = try await service.fetchHistory(days: selectedRange.days)
        } catch {
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                history = try await service.fetchHistory(days: selectedRange.days)
            } catch {
                logWarning("MarketBreadthDetail history: \(error.localizedDescription)", category: .network)
                if history.isEmpty {
                    errorMessage = "Couldn't load market breadth. Check your connection and tap retry."
                }
            }
        }

        // Crossovers are supplementary — a failure here must not blank the view.
        do {
            crossovers = try await service.fetchRecentCrossovers(limit: 5)
        } catch {
            logWarning("MarketBreadthDetail crossovers: \(error.localizedDescription)", category: .network)
        }

        isLoading = false
    }

    // MARK: - Loading / Error States

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 60)
            Spacer()
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textTertiary)
            Text(errorMessage ?? "No market breadth data available yet.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
            Button {
                Task { await loadData() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - Current Status Card

    private func currentStatusCard(_ point: MarketBreadthPoint) -> some View {
        VStack(spacing: 14) {
            // Trend + EMA status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Trend")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text(point.trendDisplayText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(trendColor(point))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("EMA 12 (\(point.ema12Formatted))")
                        .font(.system(size: 11, weight: .medium))
                    Text("\(point.isBullish ? ">" : "<") EMA 21 (\(point.ema21Formatted))")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(trendColor(point))
            }

            // Breadth bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(textPrimary.opacity(0.08))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(breadthGradient(point.breadthPct))
                            .frame(width: geo.size.width * min(1, max(0, point.breadthPct / 100)))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(point.breadthFormatted) of tokens in uptrend")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(point.trendingTokens) / \(point.totalTokens)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(textPrimary)
                }
            }

            Divider().background(textPrimary.opacity(0.08))

            // Quick stats row
            HStack {
                quickStat(label: "Breadth", value: point.breadthFormatted, sub: point.zoneDescription)
                Spacer()
                quickStat(label: "Trending", value: "\(point.trendingTokens)", sub: "of \(point.totalTokens)")
                Spacer()
                quickStat(label: "BTC", value: point.btcPriceFormatted, sub: point.shortDateDisplay)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private func quickStat(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(textPrimary)
            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Recent Signals

    private var recentSignals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Signals")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(crossovers) { point in
                        HStack(spacing: 4) {
                            Image(systemName: point.isBullishCrossover ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                            Text("\(point.isBullishCrossover ? "bullish" : "bearish") (\(point.shortDateDisplay))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(point.isBullishCrossover ? AppColors.success : AppColors.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill((point.isBullishCrossover ? AppColors.success : AppColors.error).opacity(0.12))
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(spacing: 12) {
            // Time range picker
            HStack {
                timeRangePicker
                Spacer()
            }
            .padding(.horizontal)

            // Chart with proper insets for axis labels
            HStack(alignment: .top, spacing: 0) {
                // Left Y-axis (breadth %)
                yAxisColumn
                    .frame(width: 32)

                // Main chart area
                breadthChart
                    .frame(height: 240)

                // Right Y-axis (BTC price)
                btcAxisColumn
                    .frame(width: 36)
            }
            .padding(.horizontal, 8)

            // X-axis date labels
            xAxisDates
                .padding(.horizontal, 48)

            // Legend
            chartLegend
                .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(selectedRange == range ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            selectedRange == range
                                ? Capsule().fill(AppColors.accent)
                                : Capsule().fill(Color.clear)
                        )
                }
            }
        }
        .padding(3)
        .background(Capsule().fill(textPrimary.opacity(0.06)))
    }

    // MARK: - Chart

    private var breadthChart: some View {
        let breadthValues = history.map { $0.breadthPct }
        let ema12Values = history.compactMap { $0.ema12 }
        let ema21Values = history.compactMap { $0.ema21 }
        let btcValues = history.compactMap { $0.btcPrice }

        let minBreadth = max(0, (breadthValues.min() ?? 0) - 5)
        let maxBreadth = min(100, (breadthValues.max() ?? 100) + 5)
        let breadthRange = maxBreadth - minBreadth

        let minBtc = (btcValues.min() ?? 0) * 0.98
        let maxBtc = (btcValues.max() ?? 1) * 1.02
        let btcRange = maxBtc - minBtc

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 30% and 70% zone lines
                if breadthRange > 0 {
                    zoneLine(at: 30, min: minBreadth, range: breadthRange, height: h, width: w)
                    zoneLine(at: 70, min: minBreadth, range: breadthRange, height: h, width: w)
                }

                // Raw breadth line (light, thin)
                linePath(values: breadthValues, min: minBreadth, range: breadthRange, w: w, h: h)
                    .stroke(textPrimary.opacity(0.15), lineWidth: 1)

                // EMA 12 line (bold)
                if ema12Values.count == history.count {
                    linePath(values: ema12Values, min: minBreadth, range: breadthRange, w: w, h: h)
                        .stroke(
                            history.last?.isBullish == true ? AppColors.success : AppColors.error,
                            lineWidth: 2
                        )
                }

                // EMA 21 line (lighter)
                if ema21Values.count == history.count {
                    linePath(values: ema21Values, min: minBreadth, range: breadthRange, w: w, h: h)
                        .stroke(
                            (history.last?.isBullish == true ? AppColors.success : AppColors.error).opacity(0.4),
                            lineWidth: 1.5
                        )
                }

                // BTC price line (orange)
                if btcValues.count == history.count && btcRange > 0 {
                    linePath(values: btcValues, min: minBtc, range: btcRange, w: w, h: h)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
                }

                // Crossover markers
                let count = CGFloat(max(1, history.count - 1))
                ForEach(Array(history.enumerated()), id: \.offset) { i, point in
                    if point.isCrossover {
                        let x = w * CGFloat(i) / count
                        let emaVal = point.ema12 ?? point.breadthPct
                        let y = breadthRange > 0
                            ? h * (1 - (emaVal - minBreadth) / breadthRange)
                            : h / 2

                        Image(systemName: point.isBullishCrossover ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(point.isBullishCrossover ? AppColors.success : AppColors.error)
                            .background(
                                Circle()
                                    .fill(cardBackground)
                                    .frame(width: 16, height: 16)
                            )
                            .position(x: x, y: max(12, min(h - 12, y - 14)))
                    }
                }
            }
        }
    }

    // MARK: - Axis Labels

    private var yAxisColumn: some View {
        let breadthValues = history.map { $0.breadthPct }
        let minVal = max(0, (breadthValues.min() ?? 0) - 5)
        let maxVal = min(100, (breadthValues.max() ?? 100) + 5)

        return GeometryReader { geo in
            let h = geo.size.height
            let steps = [0.0, 0.25, 0.5, 0.75, 1.0]
            ForEach(steps, id: \.self) { frac in
                let val = minVal + (maxVal - minVal) * frac
                Text(String(format: "%.0f%%", val))
                    .font(.system(size: 8, design: .rounded))
                    .foregroundColor(AppColors.textTertiary)
                    .position(x: 16, y: h * (1 - frac))
            }
        }
        .frame(height: 240)
    }

    private var btcAxisColumn: some View {
        let btcValues = history.compactMap { $0.btcPrice }
        let minBtc = (btcValues.min() ?? 0) * 0.98
        let maxBtc = (btcValues.max() ?? 1) * 1.02

        return GeometryReader { geo in
            let h = geo.size.height
            if !btcValues.isEmpty {
                ForEach([0.0, 0.5, 1.0], id: \.self) { frac in
                    let val = minBtc + (maxBtc - minBtc) * frac
                    Text("$\(Int(val / 1000))K")
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(Color.orange.opacity(0.6))
                        .position(x: 18, y: h * (1 - frac))
                }
            }
        }
        .frame(height: 240)
    }

    private var xAxisDates: some View {
        HStack {
            if let first = history.first {
                Text(first.shortDateDisplay)
                    .font(.system(size: 9))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if history.count > 2 {
                let mid = history[history.count / 2]
                Text(mid.shortDateDisplay)
                    .font(.system(size: 9))
                    .foregroundColor(AppColors.textTertiary)
            }
            Spacer()
            if let last = history.last {
                Text(last.shortDateDisplay)
                    .font(.system(size: 9))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    // MARK: - Chart Helpers

    private func linePath(values: [Double], min: Double, range: Double, w: CGFloat, h: CGFloat) -> Path {
        Path { path in
            let count = CGFloat(max(1, values.count - 1))
            for (i, val) in values.enumerated() {
                let x = w * CGFloat(i) / count
                let y = range > 0 ? h * (1 - (val - min) / range) : h / 2
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }

    private func zoneLine(at pct: Double, min: Double, range: Double, height: CGFloat, width: CGFloat) -> some View {
        let y = height * (1 - (pct - min) / range)
        return Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
        .foregroundColor(textPrimary.opacity(0.12))
    }

    // MARK: - Chart Legend

    private var chartLegend: some View {
        HStack(spacing: 14) {
            legendItem(color: textPrimary.opacity(0.2), label: "Breadth")
            legendItem(color: history.last?.isBullish == true ? AppColors.success : AppColors.error, label: "EMA 12")
            legendItem(color: (history.last?.isBullish == true ? AppColors.success : AppColors.error).opacity(0.4), label: "EMA 21")
            legendItem(color: Color.orange.opacity(0.5), label: "BTC")
        }
        .font(.system(size: 10))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 2)
            Text(label)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - How It Works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How Market Breadth Works")
                .font(.headline)
                .foregroundColor(textPrimary)

            bulletPoint("Market Breadth measures the percentage of tokens in an uptrend (price above 7-day SMA).")
            bulletPoint("EMA 12/21 crossover on the breadth data identifies trend direction and momentum shifts.")
            bulletPoint("Green EMAs = bullish trend (breadth improving). Red EMAs = bearish trend (breadth declining).")
            bulletPoint("Triangle markers show crossover points — potential turning points in market breadth.")
            bulletPoint("BTC price (orange) provides context for divergences between breadth and the leading asset.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Helpers

    private func trendColor(_ point: MarketBreadthPoint) -> Color {
        point.isBullish ? AppColors.success : point.isBearish ? AppColors.error : AppColors.warning
    }

    private func breadthGradient(_ pct: Double) -> LinearGradient {
        let color: Color = pct >= 70 ? AppColors.success : pct <= 30 ? AppColors.error : AppColors.warning
        return LinearGradient(colors: [color.opacity(0.8), color], startPoint: .leading, endPoint: .trailing)
    }
}
