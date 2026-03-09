import SwiftUI

// MARK: - Swing Setups Detail View

struct SwingSetupsDetailView: View {
    @State private var viewModel = SwingSetupsViewModel()
    @State private var selectedFilter: SignalFilter = .active
    @State private var selectedAsset: String? = nil
    @State private var selectedConfidence: SignalConfidence? = nil
    @State private var showGuide = false
    @State private var signalToShare: TradeSignal? = nil
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    enum SignalFilter: String, CaseIterable {
        case active = "Active"
        case history = "History"
        case performance = "Performance"
    }

    private var baseSignals: [TradeSignal] {
        switch selectedFilter {
        case .active:
            return viewModel.activeSignals
        case .history:
            return viewModel.recentSignals.filter { !$0.status.isLive }
        case .performance:
            return []
        }
    }

    private var filteredSignals: [TradeSignal] {
        var signals = baseSignals
        if let asset = selectedAsset {
            signals = signals.filter { $0.asset == asset }
        }
        if let confidence = selectedConfidence {
            signals = signals.filter { $0.confidence == confidence }
        }
        return signals
    }

    private var availableAssets: [String] {
        let signals = selectedFilter == .active ? viewModel.activeSignals : viewModel.recentSignals.filter { !$0.status.isLive }
        let assets = Set(signals.map(\.asset))
        return assets.sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats header
                if let stats = viewModel.stats, stats.totalSignals > 0 {
                    statsCard(stats)
                }

                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(SignalFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedFilter) { _, _ in
                    // Reset asset filter when switching tabs if current asset not available
                    if let asset = selectedAsset, !availableAssets.contains(asset) {
                        selectedAsset = nil
                    }
                }

                // Filter chips (hidden on Performance tab)
                if selectedFilter != .performance {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Asset filters
                            if availableAssets.count > 1 {
                                assetChip("All", isActive: selectedAsset == nil && selectedConfidence == nil) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedAsset = nil
                                        selectedConfidence = nil
                                    }
                                }
                                ForEach(availableAssets, id: \.self) { asset in
                                    assetChip(asset, isActive: selectedAsset == asset) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedAsset = selectedAsset == asset ? nil : asset
                                        }
                                    }
                                }

                                // Separator
                                Rectangle()
                                    .fill(AppColors.textSecondary.opacity(0.2))
                                    .frame(width: 1, height: 20)
                            }

                            // Confidence filters
                            confidenceChip(.high)
                            confidenceChip(.medium)
                            confidenceChip(.low)
                        }
                        .padding(.horizontal)
                    }
                }

                if selectedFilter == .performance {
                    // Performance dashboard
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonCard()
                            }
                        }
                        .padding(.horizontal)
                    } else if let stats = viewModel.stats, stats.totalSignals > 0 {
                        performanceDashboard(stats)
                    } else {
                        emptyState
                            .padding(.top, 40)
                    }
                } else {
                    // Signal list
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonCard()
                            }
                        }
                        .padding(.horizontal)
                    } else if filteredSignals.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSignals) { signal in
                                NavigationLink {
                                    SignalDetailView(signalId: signal.id)
                                } label: {
                                    SignalCard(signal: signal, colorScheme: colorScheme)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button {
                                        signalToShare = signal
                                    } label: {
                                        Label("Share Signal", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Per-asset breakdown
                    if let stats = viewModel.stats, !stats.assetBreakdown.isEmpty, selectedFilter == .history {
                        assetBreakdownSection(stats.assetBreakdown)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Swing Setups")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showGuide = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            SignalGuideSheet()
        }
        .sheet(item: $signalToShare) { signal in
            TradeSignalShareSheet(signal: signal)
        }
        .task {
            await viewModel.loadAllData()
        }
        .refreshable {
            await viewModel.loadAllData()
        }
    }

    // MARK: - Stats Card

    private func statsCard(_ stats: SignalStats) -> some View {
        VStack(spacing: 14) {
            // Top: Win rate gauge + primary counts
            HStack(spacing: 16) {
                // Circular win rate gauge
                WinRateGauge(hitRate: stats.hitRate, wins: stats.wins, total: stats.totalSignals)

                // Win / Partial / Loss counts
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 16) {
                        miniStat(value: "\(stats.wins)", label: "Wins", color: AppColors.success)
                        miniStat(value: "\(stats.partials)", label: "Partial", color: AppColors.warning)
                        miniStat(value: "\(stats.losses)", label: "Losses", color: AppColors.error)
                    }

                    HStack(spacing: 16) {
                        miniStat(value: String(format: "+%.1f%%", stats.avgWinPct), label: "Avg Win", color: AppColors.success)
                        miniStat(value: String(format: "%.1f%%", stats.avgLossPct), label: "Avg Loss", color: AppColors.error)
                        miniStat(
                            value: stats.currentStreak >= 0 ? "+\(stats.currentStreak)" : "\(stats.currentStreak)",
                            label: "Streak",
                            color: stats.currentStreak >= 0 ? AppColors.success : AppColors.error
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func miniStat(value: String, label: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color ?? textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(minWidth: 44)
    }

    // MARK: - Asset Breakdown

    private func assetBreakdownSection(_ assets: [AssetStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY ASSET")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            ForEach(assets) { asset in
                HStack {
                    Text(asset.asset)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                        .frame(width: 60, alignment: .leading)

                    // Win/loss bar
                    GeometryReader { geo in
                        let total = max(asset.total, 1)
                        let winWidth = geo.size.width * CGFloat(asset.wins + asset.partials) / CGFloat(total)
                        HStack(spacing: 1) {
                            Rectangle()
                                .fill(AppColors.success)
                                .frame(width: max(winWidth, 0))
                            Rectangle()
                                .fill(AppColors.error)
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", asset.hitRate))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, alignment: .trailing)

                    Text(String(format: "%+.1f%%", asset.avgReturnPct))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(asset.avgReturnPct >= 0 ? AppColors.success : AppColors.error)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Performance Dashboard

    private func performanceDashboard(_ stats: SignalStats) -> some View {
        VStack(spacing: 16) {
            // Expanded stats card
            statsCard(stats)

            // Equity curve
            equityCurveCard

            // Direction breakdown
            directionBreakdownCard

            // Per-asset breakdown
            if !stats.assetBreakdown.isEmpty {
                assetBreakdownSection(stats.assetBreakdown)
            }

            // Key metrics grid
            keyMetricsCard(stats)
        }
    }

    // MARK: - Equity Curve

    private var equityCurveCard: some View {
        let closedSignals = viewModel.recentSignals
            .filter { !$0.status.isLive && $0.outcomePct != nil && $0.closedAt != nil }
            .sorted { ($0.closedAt ?? .distantPast) < ($1.closedAt ?? .distantPast) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("CUMULATIVE P&L")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            if closedSignals.count >= 2 {
                let points = cumulativePnL(closedSignals)
                let maxVal = points.map(\.value).max() ?? 1
                let minVal = points.map(\.value).min() ?? 0
                let range = max(maxVal - minVal, 0.01)
                let finalPnl = points.last?.value ?? 0

                // Summary row
                HStack {
                    Text(String(format: "%+.1f%%", finalPnl))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(finalPnl >= 0 ? AppColors.success : AppColors.error)
                    Text("across \(closedSignals.count) trades")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }

                // Chart
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let stepX = w / CGFloat(max(points.count - 1, 1))

                    ZStack(alignment: .topLeading) {
                        // Zero line
                        let zeroY = h * CGFloat((maxVal - 0) / range)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: zeroY))
                            path.addLine(to: CGPoint(x: w, y: zeroY))
                        }
                        .stroke(textPrimary.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                        // Line
                        Path { path in
                            for (i, point) in points.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = h * CGFloat((maxVal - point.value) / range)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            finalPnl >= 0 ? AppColors.success : AppColors.error,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                        // Gradient fill
                        Path { path in
                            for (i, point) in points.enumerated() {
                                let x = CGFloat(i) * stepX
                                let y = h * CGFloat((maxVal - point.value) / range)
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: h))
                            path.addLine(to: CGPoint(x: 0, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    (finalPnl >= 0 ? AppColors.success : AppColors.error).opacity(0.2),
                                    (finalPnl >= 0 ? AppColors.success : AppColors.error).opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 120)
            } else {
                Text("Need at least 2 closed trades to show equity curve")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private struct PnLPoint: Identifiable {
        let id: Int
        let value: Double
    }

    private func cumulativePnL(_ signals: [TradeSignal]) -> [PnLPoint] {
        var cumulative = 0.0
        var points = [PnLPoint(id: 0, value: 0)]
        for (i, signal) in signals.enumerated() {
            cumulative += signal.outcomePct ?? 0
            points.append(PnLPoint(id: i + 1, value: cumulative))
        }
        return points
    }

    // MARK: - Direction Breakdown

    private var directionBreakdownCard: some View {
        let closedSignals = viewModel.recentSignals.filter { !$0.status.isLive && $0.outcome != nil }
        let longs = closedSignals.filter { $0.signalType.isBuy }
        let shorts = closedSignals.filter { !$0.signalType.isBuy }

        let longWins = longs.filter { $0.outcome == .win || $0.outcome == .partial }.count
        let shortWins = shorts.filter { $0.outcome == .win || $0.outcome == .partial }.count
        let longHitRate = longs.isEmpty ? 0 : Double(longWins) / Double(longs.count) * 100
        let shortHitRate = shorts.isEmpty ? 0 : Double(shortWins) / Double(shorts.count) * 100
        let longAvgPnl = longs.compactMap(\.outcomePct).isEmpty ? 0 : longs.compactMap(\.outcomePct).reduce(0, +) / Double(longs.compactMap(\.outcomePct).count)
        let shortAvgPnl = shorts.compactMap(\.outcomePct).isEmpty ? 0 : shorts.compactMap(\.outcomePct).reduce(0, +) / Double(shorts.compactMap(\.outcomePct).count)

        return VStack(alignment: .leading, spacing: 12) {
            Text("BY DIRECTION")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            HStack(spacing: 16) {
                directionColumn(label: "Long", count: longs.count, wins: longWins, hitRate: longHitRate, avgPnl: longAvgPnl, color: AppColors.success)
                directionColumn(label: "Short", count: shorts.count, wins: shortWins, hitRate: shortHitRate, avgPnl: shortAvgPnl, color: AppColors.error)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func directionColumn(label: String, count: Int, wins: Int, hitRate: Double, avgPnl: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)
            }

            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()
                Text("trades")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", hitRate))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(hitRate >= 50 ? AppColors.success : AppColors.error)
                        .monospacedDigit()
                    Text("Win Rate")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%+.1f%%", avgPnl))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(avgPnl >= 0 ? AppColors.success : AppColors.error)
                        .monospacedDigit()
                    Text("Avg P&L")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Key Metrics

    private func keyMetricsCard(_ stats: SignalStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY METRICS")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                metricTile(
                    title: "Profit Factor",
                    value: stats.profitFactor.isInfinite ? "---" : String(format: "%.2f", stats.profitFactor),
                    color: stats.profitFactor >= 1.5 ? AppColors.success : (stats.profitFactor >= 1.0 ? AppColors.warning : AppColors.error)
                )
                metricTile(
                    title: "Avg Duration",
                    value: stats.avgDurationHours >= 24 ? "\(stats.avgDurationHours / 24)d \(stats.avgDurationHours % 24)h" : "\(stats.avgDurationHours)h",
                    color: AppColors.accent
                )
                metricTile(
                    title: "Avg Win",
                    value: String(format: "+%.1f%%", stats.avgWinPct),
                    color: AppColors.success
                )
                metricTile(
                    title: "Avg Loss",
                    value: String(format: "%.1f%%", stats.avgLossPct),
                    color: AppColors.error
                )
                metricTile(
                    title: "Best Streak",
                    value: stats.currentStreak >= 0 ? "+\(stats.currentStreak)" : "\(stats.currentStreak)",
                    color: stats.currentStreak >= 0 ? AppColors.success : AppColors.error
                )
                metricTile(
                    title: "Total Trades",
                    value: "\(stats.totalSignals)",
                    color: textPrimary
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(colorScheme == .dark ? 0.08 : 0.05))
        )
    }

    // MARK: - Asset Chip

    private func assetChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? .white : AppColors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? AppColors.accent : AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Confidence Chip

    private func confidenceChip(_ confidence: SignalConfidence) -> some View {
        let isActive = selectedConfidence == confidence
        let chipColor: Color = {
            switch confidence {
            case .high: return AppColors.success
            case .medium: return AppColors.warning
            case .low: return AppColors.error
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedConfidence = selectedConfidence == confidence ? nil : confidence
            }
        } label: {
            Text(confidence.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isActive ? .white : chipColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? chipColor : chipColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))

            Text(selectedFilter == .active ? "No active setups" : "No signal history yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary)

            Text("Signals fire when price approaches high-confluence Fibonacci zones with supporting risk conditions.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if selectedFilter == .active {
                nextPipelineCheck
            }
        }
    }

    private var nextPipelineCheck: some View {
        let now = Date()
        let calendar = Calendar.current
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        // Pipeline runs every 4h at 0:05, 4:05, 8:05, 12:05, 16:05, 20:05 UTC
        let hour = utcCalendar.component(.hour, from: now)
        let minute = utcCalendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute

        let checkTimes = [0 * 60 + 5, 4 * 60 + 5, 8 * 60 + 5, 12 * 60 + 5, 16 * 60 + 5, 20 * 60 + 5]
        let nextCheck: Int = checkTimes.first(where: { $0 > currentMinutes }) ?? (checkTimes[0] + 24 * 60)
        let minutesUntil = nextCheck - currentMinutes
        let hoursUntil = minutesUntil / 60
        let minsUntil = minutesUntil % 60

        let timeString = hoursUntil > 0 ? "\(hoursUntil)h \(minsUntil)m" : "\(minsUntil)m"

        return HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11))
                .foregroundColor(AppColors.accent)
            Text("Next scan in \(timeString)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppColors.accent.opacity(colorScheme == .dark ? 0.1 : 0.06))
        .cornerRadius(10)
        .padding(.top, 4)
    }
}

// MARK: - Win Rate Gauge

private struct WinRateGauge: View {
    let hitRate: Double
    let wins: Int
    let total: Int

    private var progress: Double { min(max(hitRate / 100, 0), 1) }

    private var gaugeColor: Color {
        if hitRate >= 60 { return AppColors.success }
        if hitRate >= 45 { return AppColors.warning }
        return AppColors.error
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(gaugeColor.opacity(0.15), lineWidth: 6)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gaugeColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 0) {
                Text(String(format: "%.0f%%", hitRate))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(gaugeColor)
                    .monospacedDigit()
                Text("\(wins)/\(total)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(width: 70, height: 70)
    }
}

// MARK: - Signal Card

struct SignalCard: View {
    let signal: TradeSignal
    let colorScheme: ColorScheme

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var borderTintColor: Color? {
        guard !signal.status.isLive else { return nil }
        switch signal.outcome {
        case .win: return AppColors.success
        case .loss: return AppColors.error
        case .partial: return AppColors.warning
        case .none: return nil
        }
    }

    private var expiryCountdown: String? {
        guard signal.status == .active, let expires = signal.expiresAt else { return nil }
        let remaining = expires.timeIntervalSince(Date())
        guard remaining > 0 else { return "Expiring" }
        let hours = Int(remaining / 3600)
        if hours >= 24 {
            return "\(hours / 24)d \(hours % 24)h left"
        }
        return "\(hours)h left"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Colored left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(signalColor)
                .frame(width: 4)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                // Top row: asset, type badge, time
                HStack {
                    Text(signal.asset)
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text(signal.signalType.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(signalColor)
                        .cornerRadius(6)

                    confidenceBadge

                    Spacer()

                    if let countdown = expiryCountdown {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(countdown)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.warning)
                    } else {
                        Text(signal.timeAgo)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Entry zone
                HStack {
                    Text("Entry")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                }

                // AI analysis section
                if let analysis = signal.cardAnalysis {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundColor(AppColors.accent)
                            Text("WHY THIS SETUP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                                .tracking(0.8)
                        }

                        Text(analysis.narrative)
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .lineSpacing(2)
                            .lineLimit(3)

                        HStack(spacing: 6) {
                            analysisContextPill(analysis.confluenceStrength)
                            analysisContextPill(analysis.trendDirection)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accent.opacity(colorScheme == .dark ? 0.06 : 0.04))
                    )
                } else if let rationale = signal.shortRationale, !rationale.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent.opacity(0.7))
                        Text(rationale)
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.6))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }

                // Targets + Stop
                HStack(spacing: 16) {
                    if let t1 = signal.target1 {
                        miniMetric(label: "T1", value: "$\(formatSignalPrice(t1))", color: AppColors.success)
                    }
                    if let t2 = signal.target2 {
                        miniMetric(label: "T2", value: "$\(formatSignalPrice(t2))", color: AppColors.success)
                    }
                    miniMetric(label: "Stop", value: "$\(formatSignalPrice(signal.stopLoss))", color: AppColors.error)

                    Spacer()

                    // R:R badge
                    Text("\(signal.riskRewardRatio, specifier: "%.1f")x")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.15))
                        .cornerRadius(8)
                }

                // Bottom row: runner info + status
                HStack(spacing: 6) {
                    if signal.status.isLive {
                        if signal.isRunnerPhase {
                            chipView(text: "T1 Hit", color: AppColors.success)
                            if let t1Pnl = signal.t1PnlPct {
                                chipView(text: String(format: "50%% @ %+.1f%%", t1Pnl), color: AppColors.success)
                            }
                            chipView(text: "Runner trailing", color: AppColors.accent)
                        } else {
                            if signal.emaTrendAligned == true {
                                chipView(text: "EMA Aligned", color: AppColors.accent)
                            }
                            if signal.isWeakDirection {
                                chipView(text: "Off-trend")
                            }
                            if signal.isCounterTrend {
                                chipView(text: "Counter-Trend", color: AppColors.warning)
                            }
                        }
                    } else {
                        // Outcome details for closed signals
                        if let pct = signal.outcomePct {
                            chipView(
                                text: String(format: "%+.1f%%", pct),
                                color: pct >= 0 ? AppColors.success : AppColors.error
                            )
                        }
                        if let rMult = signal.rMultiple {
                            chipView(
                                text: String(format: "%+.1fR", rMult),
                                color: rMult >= 0 ? AppColors.success : AppColors.error
                            )
                        }
                        if let hours = signal.durationHours {
                            let display = hours >= 24 ? "\(hours / 24)d \(hours % 24)h" : "\(hours)h"
                            chipView(text: display)
                        }
                        if signal.isT1Hit {
                            chipView(text: "T1 Hit", color: AppColors.success)
                        }
                    }

                    Spacer()

                    // Status badge
                    Text(signal.phaseDescription)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(6)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 2)
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderTintColor?.opacity(0.35) ?? Color.clear, lineWidth: borderTintColor != nil ? 1.5 : 0)
                )
        )
    }

    private var confidenceBadge: some View {
        let color: Color = {
            switch signal.confidence {
            case .high: return AppColors.success
            case .medium: return AppColors.warning
            case .low: return AppColors.error
            }
        }()
        return Text(signal.confidence.displayName)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch signal.status {
        case .active: return AppColors.warning
        case .triggered: return AppColors.accent
        case .targetHit: return AppColors.success
        case .invalidated: return AppColors.error
        case .expired: return AppColors.textSecondary
        }
    }

    private func chipView(text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color ?? AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (color ?? (colorScheme == .dark ? Color.white : Color.black))
                    .opacity(color != nil ? 0.12 : (colorScheme == .dark ? 0.08 : 0.05))
            )
            .cornerRadius(4)
    }

    private func analysisContextPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .lineLimit(1)
    }

    private func miniMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }
}

// MARK: - Signal Guide Sheet

struct SignalGuideSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : .white }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.accent)

                        Text("Reading Signal Cards")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textPrimary)

                        Text("A quick guide to understanding everything you see on signal cards and the detail view.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                    // 1. Direction Bar
                    guideSection("Signal Direction") {
                        legendRow(
                            visual: AnyView(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.success)
                                    .frame(width: 4, height: 28)
                            ),
                            title: "Green bar",
                            detail: "Long setup — expecting price to go up"
                        )
                        legendRow(
                            visual: AnyView(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppColors.error)
                                    .frame(width: 4, height: 28)
                            ),
                            title: "Red bar",
                            detail: "Short setup — expecting price to go down"
                        )
                    }

                    // 2. Signal Type Badges
                    guideSection("Signal Strength") {
                        legendRow(
                            visual: AnyView(badgeSample("Strong Long", color: AppColors.success)),
                            title: "Strong Long / Strong Short",
                            detail: "High-confluence zone with multi-timeframe alignment and EMA confirmation"
                        )
                        legendRow(
                            visual: AnyView(badgeSample("Long Setup", color: AppColors.success)),
                            title: "Long Setup / Short Setup",
                            detail: "Valid zone with standard confluence — still meets all detection criteria"
                        )
                    }

                    // 3. Confidence Tiers
                    guideSection("Confidence Tiers") {
                        Text("Based on backtested win rates per asset over 12+ months of data.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.bottom, 4)

                        legendRow(
                            visual: AnyView(confidenceSample("High", color: AppColors.success)),
                            title: "High Confidence",
                            detail: "Asset has 65%+ win rate in backtests (e.g. LINK, SUI)"
                        )
                        legendRow(
                            visual: AnyView(confidenceSample("Medium", color: AppColors.warning)),
                            title: "Medium Confidence",
                            detail: "Asset has 60–65% win rate (e.g. ETH, SOL, ADA)"
                        )
                        legendRow(
                            visual: AnyView(confidenceSample("Low", color: AppColors.error)),
                            title: "Low Confidence",
                            detail: "Asset has <60% win rate — extra caution warranted (e.g. BTC)"
                        )
                    }

                    // 4. Status Lifecycle
                    guideSection("Signal Lifecycle") {
                        statusRow(label: "Watching", color: AppColors.warning,
                                  detail: "Signal generated — price is approaching the zone but hasn't entered yet. The countdown shows time until expiry.")
                        statusRow(label: "In Play", color: AppColors.accent,
                                  detail: "Price confirmed inside the entry zone with a bounce signal. The trade is active.")
                        statusRow(label: "Watching T1", color: AppColors.accent,
                                  detail: "Trade triggered and now watching for Target 1 to be hit.")
                        statusRow(label: "Runner trailing", color: AppColors.accent,
                                  detail: "T1 was hit — 50% of the position closed in profit. The remaining 50% is trailing with a protective stop.")
                        statusRow(label: "Target Hit", color: AppColors.success,
                                  detail: "Full target reached. The signal closed as a win.")
                        statusRow(label: "Stopped Out", color: AppColors.error,
                                  detail: "Price hit the stop loss. The signal closed as a loss.")
                        statusRow(label: "Expired", color: AppColors.textSecondary,
                                  detail: "Price never reached the entry zone within the time window. No trade, no risk.")
                    }

                    // 5. Info Chips
                    guideSection("Info Badges") {
                        legendRow(
                            visual: AnyView(chipSample("EMA Aligned", color: AppColors.accent)),
                            title: "EMA Aligned",
                            detail: "The 20 and 50 EMA on 4H confirm the signal direction — a positive confluence factor"
                        )
                        legendRow(
                            visual: AnyView(chipSample("Counter-Trend", color: AppColors.warning)),
                            title: "Counter-Trend",
                            detail: "Signal goes against the Bull Market Support Band (20W SMA / 21W EMA). Auto-scaled to 0.5R in Your Setup."
                        )
                        legendRow(
                            visual: AnyView(chipSample("Off-trend", color: nil)),
                            title: "Off-trend",
                            detail: "Signal direction is the weaker side for this asset based on backtests (e.g. longing BTC when shorts historically perform better)"
                        )
                        legendRow(
                            visual: AnyView(chipSample("T1 Hit", color: AppColors.success)),
                            title: "T1 Hit",
                            detail: "Target 1 was reached — 50% of the position was closed at a profit"
                        )
                    }

                    // 6. History Card Borders
                    guideSection("History Card Borders") {
                        Text("Closed signals show a subtle colored border so you can scan results at a glance.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.bottom, 4)

                        borderRow(color: AppColors.success, label: "Green border", detail: "Win — target hit or profitable close")
                        borderRow(color: AppColors.error, label: "Red border", detail: "Loss — stopped out")
                        borderRow(color: AppColors.warning, label: "Amber border", detail: "Partial — T1 hit but runner stopped at breakeven")
                    }

                    // 7. Key Metrics
                    guideSection("Key Numbers") {
                        metricRow(label: "R:R (Risk/Reward)",
                                  detail: "How much you stand to gain vs. how much you risk. A 2.5x R:R means the potential reward is 2.5 times the risk. Higher is better.")
                        metricRow(label: "T1 / T2 (Targets)",
                                  detail: "Target 1 is where 50% of the position closes. Target 2 is the extended target for the trailing runner.")
                        metricRow(label: "Stop Loss",
                                  detail: "The price where the trade is invalidated. Placed below/above the Fibonacci zone to limit downside.")
                        metricRow(label: "+2.3R / -1.0R",
                                  detail: "R-multiple — how many \"risk units\" the trade returned. +2.3R means you made 2.3x your risked amount. -1.0R means you lost exactly what you risked.")
                        metricRow(label: "Hit Rate",
                                  detail: "Percentage of closed signals that reached their target. Shown in the stats card at the top.")
                        metricRow(label: "Streak",
                                  detail: "Current consecutive wins (+) or losses (-). Useful for gauging momentum of the system.")
                    }

                    // 8. Detail View Sections
                    guideSection("Signal Detail View") {
                        metricRow(label: "Trade Structure Chart",
                                  detail: "Visual diagram of entry zone, targets, and stop loss with R:R arrows. Green shading = profit zone, red shading = risk zone.")
                        metricRow(label: "Signal Parameters",
                                  detail: "Exact price levels for entry, targets, and stop loss with percentage moves from entry.")
                        metricRow(label: "Your Setup",
                                  detail: "Interactive calculator — set your wallet size, leverage, risk %, and entry strategy to see position sizing, liquidation price, and dollar payouts. Your wallet size is remembered between visits.")
                        metricRow(label: "Entry Strategy",
                                  detail: "Choose where in the entry zone to place your order: Optimal (best R:R edge), Midpoint (zone center), Aggressive (fast fill), or Split (two limit orders at 40/60 split).")
                        metricRow(label: "Split Exit Tracking",
                                  detail: "Shows the P&L for each half of the position — the 50% closed at T1 and the 50% runner. Combined P&L shown at the bottom.")
                        metricRow(label: "AI Analysis",
                                  detail: "Claude-generated narrative context for the signal, including macro conditions and technical reasoning.")
                        metricRow(label: "Timeline",
                                  detail: "Chronological record of every signal event — from generation to outcome.")
                    }

                    // Disclaimer
                    Text("Swing Setups is an educational analysis tool, not financial advice. Always do your own research and consult a licensed financial advisor.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
            .navigationTitle("Signal Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Section Builder

    private func guideSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(cardBg))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Legend Rows

    private func legendRow(visual: AnyView, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            visual
                .frame(width: 100, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(2)
            }
        }
    }

    private func statusRow(label: String, color: Color, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.15))
                .cornerRadius(6)
                .frame(width: 100, alignment: .leading)

            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
        }
    }

    private func borderRow(color: Color, label: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.5), lineWidth: 2)
                .frame(width: 28, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func metricRow(label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Sample Badges

    private func badgeSample(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    private func confidenceSample(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private func chipSample(_ text: String, color: Color?) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color ?? AppColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((color ?? Color.gray).opacity(0.12))
            .cornerRadius(4)
    }
}
