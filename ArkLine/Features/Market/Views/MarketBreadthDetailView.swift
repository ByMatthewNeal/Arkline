import SwiftUI
import Charts

// MARK: - Market Breadth Detail View
struct MarketBreadthDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var history: [MarketBreadthPoint] = []
    @State private var crossovers: [MarketBreadthPoint] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRange: TimeRange = .threeMonths
    @State private var selected: MarketBreadthPoint?
    @State private var showBTC = false

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
            .padding(.top)
            // Clear the floating tab bar so the last section isn't covered.
            .padding(.bottom, 100)
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
        selected = nil
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
                            Text("\(point.isBullishCrossover ? "bullish" : "bearish") · \(point.shortDateDisplay)")
                                .font(.system(size: 11, weight: .medium))
                            // Show the BTC price the signal fired at (older rows may lack it).
                            if point.btcPrice != nil {
                                Text("· \(point.btcPriceFormatted)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
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
            // Controls: time range + BTC overlay toggle
            HStack {
                timeRangePicker
                Spacer()
                btcToggle
            }
            .padding(.horizontal)

            // Native Swift Charts chart
            breadthChart
                .frame(height: 260)
                .padding(.horizontal, 8)

            // Drag-to-inspect readout
            readout
                .padding(.horizontal)

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

    private var btcToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showBTC.toggle() }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(showBTC ? Color.orange : AppColors.textTertiary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text("BTC")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showBTC ? textPrimary : AppColors.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(textPrimary.opacity(showBTC ? 0.10 : 0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart (Swift Charts)

    /// Breadth y-domain: zoom to the data but always keep the 30/70 zone lines in
    /// view so the Weak/Mixed/Strong bands stay meaningful.
    private var breadthDomain: (lo: Double, hi: Double) {
        let values = history.map(\.breadthPct) + history.compactMap(\.ema12) + history.compactMap(\.ema21)
        let dataMin = values.min() ?? 0
        let dataMax = values.max() ?? 100
        let lo = max(0, min(dataMin, 25) - 4)
        let hi = min(100, max(dataMax, 75) + 4)
        return (lo, hi)
    }

    private var btcRange: (min: Double, max: Double) {
        let btc = history.compactMap(\.btcPrice)
        let lo = (btc.min() ?? 0) * 0.98
        let hi = (btc.max() ?? 1) * 1.02
        return (lo, max(hi, lo + 1))
    }

    /// Map a BTC price into the breadth y-domain so it can share one axis without
    /// a second scale (the real price is always shown in the readout/legend).
    private func btcToBreadth(_ price: Double) -> Double {
        let b = btcRange
        let d = breadthDomain
        let frac = (price - b.min) / (b.max - b.min)
        return d.lo + frac * (d.hi - d.lo)
    }

    private var breadthChart: some View {
        let domain = breadthDomain
        let trendUp = history.last?.isBullish == true
        let emaColor = trendUp ? AppColors.success : AppColors.error

        return Chart {
            // Zone reference lines (only when inside the visible domain)
            ForEach([30.0, 70.0], id: \.self) { level in
                if level >= domain.lo && level <= domain.hi {
                    RuleMark(y: .value("Zone", level))
                        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(textPrimary.opacity(0.12))
                }
            }

            // Raw breadth: faint area + thin line (context under the EMAs)
            ForEach(history) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Breadth", p.breadthPct)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.14), AppColors.accent.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            ForEach(history) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Breadth", p.breadthPct),
                    series: .value("Series", "Breadth")
                )
                .foregroundStyle(textPrimary.opacity(0.18))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .interpolationMethod(.catmullRom)
            }

            // EMA 12 (bold, trend-colored)
            ForEach(history) { p in
                if let ema = p.ema12 {
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("EMA 12", ema),
                        series: .value("Series", "EMA 12")
                    )
                    .foregroundStyle(emaColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }
            // EMA 21 (lighter)
            ForEach(history) { p in
                if let ema = p.ema21 {
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("EMA 21", ema),
                        series: .value("Series", "EMA 21")
                    )
                    .foregroundStyle(emaColor.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
                }
            }

            // BTC overlay (optional, scaled into the breadth domain)
            if showBTC {
                ForEach(history) { p in
                    if let btc = p.btcPrice {
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("BTC", btcToBreadth(btc)),
                            series: .value("Series", "BTC")
                        )
                        .foregroundStyle(Color.orange.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }

            // Crossover markers
            ForEach(history.filter { $0.isCrossover }) { p in
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Crossover", p.ema12 ?? p.breadthPct)
                )
                .foregroundStyle(p.isBullishCrossover ? AppColors.success : AppColors.error)
                .symbol {
                    Image(systemName: p.isBullishCrossover ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(p.isBullishCrossover ? AppColors.success : AppColors.error)
                }
            }

            // Drag-to-inspect crosshair
            if let sel = selected {
                RuleMark(x: .value("Date", sel.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                PointMark(
                    x: .value("Date", sel.date),
                    y: .value("Breadth", sel.breadthPct)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(70)
            }
        }
        .chartYScale(domain: domain.lo...domain.hi)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(textPrimary.opacity(0.04))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let x = value.location.x - geo[plotFrame].origin.x
                                guard let date = proxy.value(atX: x, as: Date.self) else { return }
                                selected = nearestPoint(to: date)
                            }
                            .onEnded { _ in selected = nil }
                    )
            }
        }
    }

    private func nearestPoint(to date: Date) -> MarketBreadthPoint? {
        history.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: - Readout (drag-to-inspect)

    private var readout: some View {
        Group {
            if let sel = selected {
                HStack(spacing: 10) {
                    Text(sel.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Spacer()
                    readoutChip("Breadth", sel.breadthFormatted, color: breadthColor(sel.breadthPct))
                    readoutChip("EMA12", sel.ema12Formatted, color: trendColor(sel))
                    readoutChip("EMA21", sel.ema21Formatted, color: trendColor(sel).opacity(0.7))
                    if sel.btcPrice != nil {
                        readoutChip("BTC", sel.btcPriceFormatted, color: .orange)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                    Text("Drag across the chart to read any day")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
            }
        }
        .frame(height: 24)
    }

    private func readoutChip(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }

    // MARK: - Chart Legend

    private var chartLegend: some View {
        HStack(spacing: 14) {
            legendItem(color: textPrimary.opacity(0.2), label: "Breadth")
            legendItem(color: history.last?.isBullish == true ? AppColors.success : AppColors.error, label: "EMA 12")
            legendItem(color: (history.last?.isBullish == true ? AppColors.success : AppColors.error).opacity(0.4), label: "EMA 21")
            if showBTC {
                legendItem(color: Color.orange.opacity(0.55), label: "BTC")
            }
            Spacer()
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
            bulletPoint("Triangle markers show crossover points, potential turning points in market breadth.")
            bulletPoint("Toggle BTC (orange) to spot divergences between breadth and the leading asset.")
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

    private func breadthColor(_ pct: Double) -> Color {
        if pct >= 70 { return AppColors.success }
        if pct <= 30 { return AppColors.error }
        return AppColors.warning
    }

    private func breadthGradient(_ pct: Double) -> LinearGradient {
        let color: Color = pct >= 70 ? AppColors.success : pct <= 30 ? AppColors.error : AppColors.warning
        return LinearGradient(colors: [color.opacity(0.8), color], startPoint: .leading, endPoint: .trailing)
    }
}
