import SwiftUI
import Charts

struct ModelPortfolioDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let portfolio: ModelPortfolio
    @Bindable var viewModel: ModelPortfolioViewModel
    @State private var showUnfollowConfirmation = false

    private var navHistory: [ModelPortfolioNav] {
        if portfolio.isCore { return viewModel.coreNav }
        if portfolio.isEdge { return viewModel.edgeNav }
        return viewModel.alphaNav
    }

    private var trades: [ModelPortfolioTrade] {
        if portfolio.isCore { return viewModel.coreTrades }
        if portfolio.isEdge { return viewModel.edgeTrades }
        return viewModel.alphaTrades
    }

    private var latestNav: ModelPortfolioNav? {
        navHistory.last
    }

    private var returnPct: Double {
        latestNav?.returnPct ?? 0
    }

    /// NAV on Jan 1, 2026 (or first entry of 2026)
    private var nav2026Start: Double? {
        navHistory.first(where: { $0.navDate >= "2026-01-01" })?.nav
    }

    /// Return since Jan 1, 2026
    private var returnSince2026: Double? {
        guard let start = nav2026Start, let current = latestNav?.nav else { return nil }
        return ((current - start) / start) * 100
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ArkSpacing.lg) {
                // NAV Header
                navHeader

                // Performance Chart
                performanceChart

                // Current Allocation
                if let alloc = latestNav?.allocations, !alloc.isEmpty {
                    allocationSection(alloc)
                }

                // Strategy Status
                strategyStatus

                // Trade Log
                if !trades.isEmpty {
                    tradeLog
                }

                // Stats
                statsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, ArkSpacing.md)
        }
        .refreshable {
            await viewModel.loadDetail(for: portfolio)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle(portfolio.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Haptics.selection()
                    if viewModel.isFollowing(portfolio) {
                        showUnfollowConfirmation = true
                    } else {
                        viewModel.toggleFollow(portfolio)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isFollowing(portfolio) ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 15))
                        Text(viewModel.isFollowing(portfolio) ? "Following" : "Follow")
                            .font(AppFonts.caption12Medium)
                    }
                    .foregroundColor(viewModel.isFollowing(portfolio) ? AppColors.success : AppColors.accent)
                }
            }
        }
        .alert("Unfollow \(portfolio.name)?", isPresented: $showUnfollowConfirmation) {
            Button("Unfollow", role: .destructive) {
                viewModel.toggleFollow(portfolio)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll no longer receive rebalance notifications for this portfolio.")
        }
        .task {
            await viewModel.loadDetail(for: portfolio)
        }
    }

    // MARK: - NAV Header

    @ViewBuilder
    private var navHeader: some View {
        VStack(spacing: 6) {
            Text(Self.navFormatter.string(from: NSNumber(value: latestNav?.nav ?? 50000)) ?? "$50,000.00")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let date = latestNav?.navDate {
                Text("as of \(formatNavDate(date))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
            }

            HStack(spacing: ArkSpacing.lg) {
                VStack(spacing: 2) {
                    Text("Since Jan 2019")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                    Text("\(returnPct >= 0 ? "+" : "")\(returnPct, specifier: "%.2f")%")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(returnPct >= 0 ? AppColors.success : AppColors.error)
                }

                if let ytd = returnSince2026 {
                    VStack(spacing: 2) {
                        Text("Since Jan 2026")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textTertiary)
                        Text("\(ytd >= 0 ? "+" : "")\(ytd, specifier: "%.2f")%")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(ytd >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ArkSpacing.sm)
    }

    // MARK: - Performance Chart

    private static let spyColor = Color(hex: "FF9500")

    private enum ChartRange: String, CaseIterable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        case oneYear = "1Y"
        case threeYears = "3Y"
        case fiveYears = "5Y"
        case all = "ALL"

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .oneYear: return 365
            case .threeYears: return 1095
            case .fiveYears: return 1825
            case .all: return nil
            }
        }
    }

    @State private var selectedRange: ChartRange = .all

    /// Max chart points to keep rendering fast
    private static let maxChartPoints = 200

    /// Downsample an array to at most `maxPoints` entries, keeping first and last
    private static func downsample<T>(_ data: [T], maxPoints: Int) -> [T] {
        guard data.count > maxPoints else { return data }
        let step = Double(data.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { i in
            data[min(Int(Double(i) * step), data.count - 1)]
        }
    }

    private var filteredNavHistory: [ModelPortfolioNav] {
        guard let days = selectedRange.days else { return navHistory }
        return Array(navHistory.suffix(days))
    }

    private var filteredBenchmark: [BenchmarkNav] {
        guard let days = selectedRange.days else {
            return Array(viewModel.benchmarkNav.prefix(navHistory.count))
        }
        let navCount = navHistory.count
        let benchSlice = Array(viewModel.benchmarkNav.prefix(navCount))
        return Array(benchSlice.suffix(days))
    }

    /// Normalize NAV series to % return for comparable charting (downsampled)
    private var portfolioReturnPcts: [(idx: Int, pct: Double)] {
        let data = Self.downsample(filteredNavHistory, maxPoints: Self.maxChartPoints)
        guard let firstNav = data.first?.nav, firstNav > 0 else { return [] }
        return data.enumerated().map { (idx, nav) in
            (idx: idx, pct: ((nav.nav / firstNav) - 1) * 100)
        }
    }

    private var benchmarkReturnPcts: [(idx: Int, pct: Double)] {
        let data = Self.downsample(filteredBenchmark, maxPoints: Self.maxChartPoints)
        guard let firstNav = data.first?.nav, firstNav > 0 else { return [] }
        return data.enumerated().map { (idx, bench) in
            (idx: idx, pct: ((bench.nav / firstNav) - 1) * 100)
        }
    }

    /// Period return for the selected range
    private var periodReturn: Double {
        let data = filteredNavHistory
        guard let first = data.first?.nav, let last = data.last?.nav, first > 0 else { return 0 }
        return ((last / first) - 1) * 100
    }

    private var periodBenchmarkReturn: Double {
        let data = filteredBenchmark
        guard let first = data.first?.nav, let last = data.last?.nav, first > 0 else { return 0 }
        return ((last / first) - 1) * 100
    }

    @ViewBuilder
    private var performanceChart: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Text("Performance")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
                // Period returns summary
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(periodReturn >= 0 ? "+" : "")\(periodReturn, specifier: "%.1f")%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(periodReturn >= 0 ? AppColors.success : AppColors.error)
                    Text("vs SPY \(periodBenchmarkReturn >= 0 ? "+" : "")\(periodBenchmarkReturn, specifier: "%.1f")%")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            if viewModel.isLoadingDetail {
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else if navHistory.count >= 2 {
                Chart {
                    ForEach(portfolioReturnPcts, id: \.idx) { item in
                        LineMark(
                            x: .value("Day", item.idx),
                            y: .value("Return", item.pct),
                            series: .value("Series", "portfolio")
                        )
                        .foregroundStyle(AppColors.accent)
                        .interpolationMethod(.catmullRom)
                    }

                    // SPY benchmark
                    ForEach(benchmarkReturnPcts, id: \.idx) { item in
                        LineMark(
                            x: .value("Day", item.idx),
                            y: .value("Return", item.pct),
                            series: .value("Series", "spy")
                        )
                        .foregroundStyle(Self.spyColor)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(dash: [5, 5]))
                    }
                }
                .chartForegroundStyleScale([
                    "portfolio": AppColors.accent,
                    "spy": Self.spyColor,
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("\(val >= 0 ? "+" : "")\(val, specifier: "%.0f")%")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
                .chartXAxis(.hidden)
                .chartLegend(.hidden)
                .id(selectedRange)
                .frame(height: 200)

                // Legend + date range
                HStack {
                    legendItem(color: AppColors.accent, label: portfolio.name)
                    Spacer()
                    if let first = filteredNavHistory.first?.navDate,
                       let last = filteredNavHistory.last?.navDate {
                        Text("\(formatNavDate(first)) → \(formatNavDate(last))")
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    legendItem(color: Self.spyColor, label: "S&P 500", dashed: true)
                }

                // Time range picker
                HStack(spacing: 0) {
                    ForEach(ChartRange.allCases, id: \.self) { range in
                        Button {
                            selectedRange = range
                        } label: {
                            Text(range.rawValue)
                                .font(.system(size: 12, weight: selectedRange == range ? .semibold : .regular))
                                .foregroundColor(selectedRange == range ? .white : AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    selectedRange == range
                                        ? AppColors.accent
                                        : Color.clear
                                )
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(3)
                .background(AppColors.cardBorder(colorScheme))
                .cornerRadius(8)
            } else {
                Text("Loading chart data...")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String, dashed: Bool = false) -> some View {
        HStack(spacing: 4) {
            if dashed {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 12, height: 2)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Allocation

    @ViewBuilder
    private func allocationSection(_ allocations: [String: ModelPortfolioNav.AllocationDetail]) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Current Allocation")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            let sorted = allocations.sorted { $0.value.pct > $1.value.pct }

            // Pie chart
            Chart(sorted, id: \.key) { asset, detail in
                SectorMark(
                    angle: .value("Allocation", detail.pct),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(assetColor(asset))
                .cornerRadius(3)
            }
            .frame(height: 160)

            // Legend list
            ForEach(sorted, id: \.key) { asset, detail in
                HStack {
                    Circle()
                        .fill(assetColor(asset))
                        .frame(width: 8, height: 8)
                    Text(assetDisplayName(asset))
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    if asset == "USDC" {
                        Text("USDC / USDT")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                    Text("\(detail.pct, specifier: "%.1f")%")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                    if let value = detail.value {
                        Text("$\(value, specifier: "%.0f")")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Strategy Status

    @ViewBuilder
    private var strategyStatus: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Strategy Signals")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: ArkSpacing.sm) {
                statusCell(label: "BTC Signal", value: latestNav?.btcSignal?.capitalized ?? "—")
                statusCell(label: "Gold Signal", value: latestNav?.goldSignal?.capitalized ?? "—")
                statusCell(label: "Macro Regime", value: latestNav?.macroRegime ?? "—")
                statusCell(label: "BTC Risk", value: latestNav?.btcRiskCategory ?? "—")
                if portfolio.isEdge, let alt = latestNav?.dominantAlt {
                    statusCell(label: "Dominant Alt", value: alt)
                }
                if let risk = latestNav?.btcRiskLevel {
                    statusCell(label: "Risk Level", value: String(format: "%.2f", risk))
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(signalColor(value))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trade Log

    @State private var showFullTradeHistory = false
    @State private var expandedTradeId: UUID?

    private var recentTrades: [ModelPortfolioTrade] {
        trades.filter { $0.tradeDate >= "2026-01-01" }
    }

    private var displayedTrades: [ModelPortfolioTrade] {
        showFullTradeHistory ? trades : recentTrades
    }

    @ViewBuilder
    private var tradeLog: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Trade Log")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Spacer()
                    Text("\(displayedTrades.count) rebalances")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text("Days without an entry held the same allocation")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
            }

            ForEach(displayedTrades.prefix(20)) { trade in
                tradeRow(trade)
                    .padding(.vertical, 4)

                if trade.id != displayedTrades.prefix(20).last?.id {
                    Divider()
                        .background(AppColors.divider(colorScheme))
                }
            }

            // Toggle button
            Button {
                withAnimation { showFullTradeHistory.toggle() }
            } label: {
                HStack {
                    Spacer()
                    Text(showFullTradeHistory ? "Show Recent Only" : "Show Full History (\(trades.count) trades)")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: showFullTradeHistory ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Spacer()
                }
            }
            .padding(.top, 4)
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    // MARK: - Stats

    /// Daily returns derived from NAV history
    private var dailyReturns: [Double] {
        guard navHistory.count >= 2 else { return [] }
        return zip(navHistory.dropFirst(), navHistory).map { current, previous in
            ((current.nav - previous.nav) / previous.nav) * 100
        }
    }

    /// Max drawdown: worst peak-to-trough decline as a percentage
    private var maxDrawdown: Double {
        guard !navHistory.isEmpty else { return 0 }
        var peak = navHistory[0].nav
        var maxDD = 0.0
        for snapshot in navHistory {
            if snapshot.nav > peak { peak = snapshot.nav }
            let dd = ((peak - snapshot.nav) / peak) * 100
            if dd > maxDD { maxDD = dd }
        }
        return maxDD
    }

    /// Win rate: % of days with positive returns
    private var winRate: Double {
        guard !dailyReturns.isEmpty else { return 0 }
        let wins = dailyReturns.filter { $0 > 0 }.count
        return Double(wins) / Double(dailyReturns.count) * 100
    }

    /// Best and worst single-day returns
    private var bestDay: Double { dailyReturns.max() ?? 0 }
    private var worstDay: Double { dailyReturns.min() ?? 0 }

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Statistics")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text("Simulated $50,000 investment since Jan 1, 2019")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: ArkSpacing.sm) {
                statCell(label: "Starting Balance", value: "$50,000")
                statCell(label: "Current Value", value: Self.navFormatter.string(from: NSNumber(value: latestNav?.nav ?? 50000)) ?? "$50,000")
                statCell(label: "Return", value: String(format: "%@%.2f%%", returnPct >= 0 ? "+" : "", returnPct), valueColor: returnPct >= 0 ? AppColors.success : AppColors.error)
                statCell(label: "S&P 500 Return", value: String(format: "%@%.2f%%", viewModel.benchmarkReturn >= 0 ? "+" : "", viewModel.benchmarkReturn))
                statCell(label: "vs S&P 500", value: String(format: "%@%.2f%%", returnPct - viewModel.benchmarkReturn >= 0 ? "+" : "", returnPct - viewModel.benchmarkReturn), valueColor: returnPct - viewModel.benchmarkReturn >= 0 ? AppColors.success : AppColors.error)
                statCell(label: "Max Drawdown", value: String(format: "-%.1f%%", maxDrawdown), valueColor: AppColors.error)
                statCell(label: "Best Day", value: String(format: "+%.2f%%", bestDay), valueColor: AppColors.success)
                statCell(label: "Worst Day", value: String(format: "%.2f%%", worstDay), valueColor: AppColors.error)
                statCell(label: "Win Rate (Days)", value: String(format: "%.0f%%", winRate))
                statCell(label: "Rebalances", value: "\(trades.count)")
            }

            // Since Jan 2026
            if let startNav = nav2026Start, let currentNav = latestNav?.nav {
                Divider()
                    .background(AppColors.divider(colorScheme))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Since Jan 1, 2026")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("If you started following this strategy in 2026")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                }

                let ytdReturn = ((currentNav - startNav) / startNav) * 100
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: ArkSpacing.sm) {
                    statCell(label: "Jan 2026 Value", value: Self.navFormatter.string(from: NSNumber(value: startNav)) ?? "—")
                    statCell(label: "Current Value", value: Self.navFormatter.string(from: NSNumber(value: currentNav)) ?? "—")
                    statCell(label: "Return", value: String(format: "%@%.2f%%", ytdReturn >= 0 ? "+" : "", ytdReturn), valueColor: ytdReturn >= 0 ? AppColors.success : AppColors.error)
                    statCell(label: "P&L", value: Self.navFormatter.string(from: NSNumber(value: currentNav - startNav)) ?? "—", valueColor: currentNav - startNav >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statCell(label: String, value: String, valueColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(valueColor ?? AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let navFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 2
        return f
    }()

    private static let isoParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private func formatNavDate(_ dateString: String) -> String {
        guard let date = Self.isoParser.date(from: dateString) else { return dateString }
        return Self.displayDateFormatter.string(from: date)
    }

    // MARK: - Helpers

    private func assetDisplayName(_ asset: String) -> String {
        switch asset {
        case "USDC": return "Cash"
        case "PAXG": return "Gold"
        default: return asset
        }
    }

    private func assetColor(_ asset: String) -> Color {
        switch asset {
        case "BTC": return Color(hex: "F7931A")
        case "ETH": return Color(hex: "627EEA")
        case "SOL": return Color(hex: "9945FF")
        case "PAXG": return Color(hex: "E4B926")
        case "USDC": return Color(hex: "2775CA")
        case "LINK": return Color(hex: "2A5ADA")
        case "AVAX": return Color(hex: "E84142")
        case "SUI": return Color(hex: "6FBCF0")
        case "AAVE": return Color(hex: "B6509E")
        case "RENDER": return Color(hex: "00E0FF")
        case "ONDO": return Color(hex: "1A1A2E")
        case "UNI": return Color(hex: "FF007A")
        case "DOGE": return Color(hex: "C3A634")
        case "BNB": return Color(hex: "F3BA2F")
        case "XRP": return Color(hex: "23292F")
        case "BCH": return Color(hex: "8DC351")
        default: return AppColors.accent
        }
    }

    // MARK: - Trade Row

    private struct TradeChange: Identifiable {
        let id: String
        let asset: String
        let displayName: String
        let action: Action
        let fromPct: Double
        let toPct: Double

        enum Action {
            case bought      // new position (0 → X%)
            case sold        // exited position (X% → 0)
            case scaledIn    // increased (X% → Y% where Y > X)
            case scaledOut   // decreased (X% → Y% where Y < X)
        }

        var delta: Double { toPct - fromPct }
    }

    private func tradeChanges(from trade: ModelPortfolioTrade) -> [TradeChange] {
        let allAssets = Set(trade.fromAllocation.keys).union(trade.toAllocation.keys)
        var changes: [TradeChange] = []

        for asset in allAssets {
            let from = trade.fromAllocation[asset] ?? 0
            let to = trade.toAllocation[asset] ?? 0
            let delta = to - from

            // Skip tiny changes (rounding noise)
            guard abs(delta) >= 1 else { continue }

            let action: TradeChange.Action
            if from == 0 && to > 0 {
                action = .bought
            } else if from > 0 && to == 0 {
                action = .sold
            } else if delta > 0 {
                action = .scaledIn
            } else {
                action = .scaledOut
            }

            changes.append(TradeChange(
                id: asset,
                asset: asset,
                displayName: assetDisplayName(asset),
                action: action,
                fromPct: from,
                toPct: to
            ))
        }

        // Sort: buys first, then scale-ins, then scale-outs, then sells
        return changes.sorted { a, b in
            let order: [TradeChange.Action: Int] = [.bought: 0, .scaledIn: 1, .scaledOut: 2, .sold: 3]
            let ao = order[a.action] ?? 2
            let bo = order[b.action] ?? 2
            if ao != bo { return ao < bo }
            return abs(a.delta) > abs(b.delta)
        }
    }

    @ViewBuilder
    private func tradeRow(_ trade: ModelPortfolioTrade) -> some View {
        let changes = tradeChanges(from: trade)
        let isExpanded = expandedTradeId == trade.id
        let hasContext = trade.marketContext != nil && !(trade.marketContext?.isEmpty ?? true)

        VStack(alignment: .leading, spacing: 6) {
            Button {
                if hasContext {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedTradeId = isExpanded ? nil : trade.id
                    }
                }
            } label: {
                HStack {
                    Text(formatNavDate(trade.tradeDate))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(trade.trigger)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                    if hasContext {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
            }
            .buttonStyle(.plain)

            ForEach(changes) { change in
                HStack(spacing: 6) {
                    tradeActionIcon(change.action)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(tradeActionColor(change.action))
                        .frame(width: 14)

                    Text(change.displayName)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(tradeActionLabel(change))
                        .font(AppFonts.caption12)
                        .foregroundColor(tradeActionColor(change.action))

                    Spacer()

                    if change.action != .sold {
                        Text("\(change.toPct, specifier: "%.0f")%")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            // Expandable market context
            if isExpanded, let context = trade.marketContext {
                VStack(alignment: .leading, spacing: 8) {
                    if let events = context.events, !events.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.warning)
                                Text("ECONOMIC EVENTS")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .tracking(0.5)
                            }
                            ForEach(events, id: \.self) { event in
                                Text("• \(event)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    if let headlines = context.headlines, !headlines.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "newspaper")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.accent)
                                Text("HEADLINES")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .tracking(0.5)
                            }
                            ForEach(headlines, id: \.self) { headline in
                                Text("• \(headline)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func tradeActionIcon(_ action: TradeChange.Action) -> some View {
        switch action {
        case .bought:
            return Image(systemName: "plus.circle.fill")
        case .sold:
            return Image(systemName: "minus.circle.fill")
        case .scaledIn:
            return Image(systemName: "arrow.up.circle.fill")
        case .scaledOut:
            return Image(systemName: "arrow.down.circle.fill")
        }
    }

    private func tradeActionColor(_ action: TradeChange.Action) -> Color {
        switch action {
        case .bought, .scaledIn: return AppColors.success
        case .sold, .scaledOut: return AppColors.error
        }
    }

    private func tradeActionLabel(_ change: TradeChange) -> String {
        let from = String(format: "%.0f", change.fromPct)
        let to = String(format: "%.0f", change.toPct)
        switch change.action {
        case .bought:
            return "Bought"
        case .sold:
            return "Sold \(from)%"
        case .scaledIn:
            return "\(from)% → \(to)%"
        case .scaledOut:
            return "\(from)% → \(to)%"
        }
    }

    private func signalColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        case "risk-off": return AppColors.error
        case "risk-on": return AppColors.success
        case "very low risk", "low risk": return AppColors.success
        case "elevated risk", "high risk", "extreme risk": return AppColors.error
        default: return AppColors.textPrimary(colorScheme)
        }
    }
}
