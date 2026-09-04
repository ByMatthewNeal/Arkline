import SwiftUI

// MARK: - Holding Detail View
struct HoldingDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    let holding: PortfolioHolding
    @Bindable var viewModel: PortfolioViewModel
    @State private var showSellSheet = false
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteConfirmation = false
    @State private var showDeleteHoldingConfirmation = false
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss

    // Privacy: shares the same global toggle as the Portfolio/Home hero, so
    // hiding your balance in one place hides it everywhere (and lets you
    // screenshot/share an asset without exposing how much you hold).
    @AppStorage(Constants.UserDefaults.portfolioHidden) private var isHidden = false

    // Per-asset performance chart state.
    @State private var selectedPeriod: TimePeriod = .month
    @State private var chartData: [PricePoint] = []
    @State private var isLoadingChart = false
    @State private var chartAnimationId = UUID()

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService
    /// Ranges offered on the performance card. Mirrors the Market detail
    /// screens but scoped to what makes sense for a holding.
    private let performancePeriods: [TimePeriod] = [.day, .week, .month, .ytd, .year, .all]

    private var currency: String {
        appState.preferredCurrency
    }

    private var liveHolding: PortfolioHolding {
        viewModel.holdings.first(where: { $0.id == holding.id }) ?? holding
    }

    /// Only crypto/stock/metal have a historical price series to chart.
    private var isChartable: Bool {
        switch liveHolding.assetTypeEnum {
        case .crypto, .stock, .metal: return true
        default: return false
        }
    }

    /// Chart line/area color follows the selected range's direction, falling
    /// back to the 24h direction before data loads.
    private var chartIsPositive: Bool {
        guard let first = chartData.first?.price, let last = chartData.last?.price else {
            return (liveHolding.priceChangePercentage24h ?? 0) >= 0
        }
        return last >= first
    }

    /// Percent change across the currently selected range (first vs last point).
    private var rangeChangePercent: Double? {
        guard let first = chartData.first?.price, first > 0,
              let last = chartData.last?.price else { return nil }
        return (last - first) / first * 100
    }

    var holdingTransactions: [Transaction] {
        viewModel.transactions.filter { $0.symbol.uppercased() == holding.symbol.uppercased() }
            .sorted { $0.transactionDate > $1.transactionDate }
    }

    private var groupedHoldingTransactions: [(String, [Transaction])] {
        groupTransactionsByDate(holdingTransactions)
    }

    private func destinationPortfolioName(for transaction: Transaction) -> String? {
        guard let destId = transaction.destinationPortfolioId else { return nil }
        return viewModel.portfolios.first { $0.id == destId }?.name
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    CoinIconView(
                        symbol: liveHolding.symbol,
                        size: 64,
                        iconUrl: liveHolding.iconUrl ?? AssetRiskConfig.forSymbol(liveHolding.symbol)?.logoURL?.absoluteString
                    )

                    Text(liveHolding.name)
                        .font(AppFonts.title24)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(liveHolding.symbol.uppercased())
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 20)

                // Value Card
                VStack(spacing: 16) {
                    // Current Value
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Current Value")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) { isHidden.toggle() }
                            }) {
                                Image(systemName: isHidden ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .accessibilityLabel(isHidden ? "Show values" : "Hide values")
                        }

                        Text(isHidden ? "••••••" : liveHolding.currentValue.asCurrency(code: currency))
                            .font(AppFonts.number44)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .contentTransition(.numericText())
                    }

                    Divider()

                    // Stats Grid — quantity is masked in privacy mode (it's what
                    // lets someone back out your position size); prices stay
                    // visible since they're public market data.
                    HStack(spacing: 0) {
                        StatItem(title: "Quantity", value: isHidden ? "••••" : liveHolding.quantity.asQuantity)
                        Divider().frame(height: 40)
                        StatItem(title: "Avg. Price", value: (liveHolding.averageBuyPrice ?? 0).asCurrency(code: currency))
                        Divider().frame(height: 40)
                        StatItem(title: "Current Price", value: (liveHolding.currentPrice ?? 0).asCurrency(code: currency))
                    }

                    Divider()

                    // P/L
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profit/Loss")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: liveHolding.isProfit ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 14))
                                Text(isHidden ? "••••" : liveHolding.profitLoss.asCurrency(code: currency))
                                    .font(AppFonts.title18SemiBold)
                            }
                            .foregroundColor(liveHolding.isProfit ? AppColors.success : AppColors.error)
                            .accessibilityLabel("\(liveHolding.isProfit ? "Profit" : "Loss") \(isHidden ? "hidden" : liveHolding.profitLoss.asCurrency(code: currency))")
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Return")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            Text("\(liveHolding.isProfit ? "+" : "")\(liveHolding.profitLossPercentage, specifier: "%.2f")%")
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(liveHolding.isProfit ? AppColors.success : AppColors.error)
                        }
                    }

                    // 24h Change
                    if let change24h = liveHolding.priceChangePercentage24h {
                        Divider()

                        HStack {
                            Text("24h Change")
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("\(change24h >= 0 ? "+" : "")\(change24h, specifier: "%.2f")%")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(change24h >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)

                // Performance (price change over time) — hidden for asset types
                // without a historical series (e.g. real estate).
                if isChartable {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Performance")
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Spacer()

                            if let pct = rangeChangePercent {
                                HStack(spacing: 4) {
                                    Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 12))
                                    Text("\(pct >= 0 ? "+" : "")\(pct, specifier: "%.2f")%")
                                        .font(AppFonts.body14Bold)
                                        .contentTransition(.numericText())
                                    Text(selectedPeriod.displayName)
                                        .font(AppFonts.caption12)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .foregroundColor(pct >= 0 ? AppColors.success : AppColors.error)
                            }
                        }

                        AssetPriceChart(
                            data: chartData,
                            isPositive: chartIsPositive,
                            isLoading: isLoadingChart
                        )
                        .frame(height: 180)
                        .id(chartAnimationId)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: chartAnimationId)

                        HoldingTimeframeSelector(selected: $selectedPeriod, periods: performancePeriods)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 20)
                }

                // Transaction History
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transaction History")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .padding(.horizontal, 20)

                    if holdingTransactions.isEmpty {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 20)
                                Spacer()
                            }
                        } else {
                            Text("No transactions for this asset")
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 20)
                        }
                    } else {
                        VStack(spacing: 8) {
                            ForEach(groupedHoldingTransactions, id: \.0) { label, transactions in
                                Text(label)
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, label == groupedHoldingTransactions.first?.0 ? 0 : 4)

                                ForEach(transactions) { transaction in
                                    Button(action: {
                                        selectedTransaction = transaction
                                        showTransactionDetail = true
                                    }) {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            transactionToDelete = transaction
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            transactionToDelete = transaction
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 100)
            }
        }
        .background(AppColors.background(colorScheme))
        .task {
            if isChartable { await loadChart() }
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task { await loadChart() }
        }
        .navigationTitle(liveHolding.symbol.uppercased())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showEditSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Edit holding")
                    Button(action: { showDeleteHoldingConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.error)
                    }
                    .accessibilityLabel("Delete holding")
                    Button(action: { showSellSheet = true }) {
                        Text("Sell")
                            .font(AppFonts.body16Medium)
                            .foregroundColor(AppColors.error)
                    }
                    .accessibilityLabel("Sell \(liveHolding.symbol.uppercased())")
                }
            }
        }
        #endif
        .sheet(isPresented: $showSellSheet) {
            SellAssetView(viewModel: viewModel, holding: liveHolding)
        }
        .sheet(isPresented: $showEditSheet) {
            EditHoldingView(holding: liveHolding) { updated in
                Task { await viewModel.editHolding(updated) }
            }
        }
        .sheet(isPresented: $showTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(
                    transaction: transaction,
                    portfolioName: viewModel.selectedPortfolio?.name,
                    destinationPortfolioName: destinationPortfolioName(for: transaction),
                    onDelete: { tx in
                        Task { await viewModel.deleteTransaction(tx) }
                    },
                    onUpdate: { tx in
                        Task { await viewModel.updateTransaction(tx) }
                    }
                )
            }
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let tx = transactionToDelete {
                    Task { await viewModel.deleteTransaction(tx) }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure? This will recalculate your holdings.")
        }
        .onChange(of: viewModel.holdings) { _, newHoldings in
            if !newHoldings.contains(where: { $0.id == holding.id }) {
                dismiss()
            }
        }
        .alert("Delete \(liveHolding.symbol.uppercased())?", isPresented: $showDeleteHoldingConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteHolding(liveHolding)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove \(liveHolding.name) and all its transactions from your portfolio.")
        }
    }

    // MARK: - Performance Chart Loading

    /// Loads the historical price series for the selected range, branching on
    /// asset class. Mirrors the Market detail screens' fetch paths so behavior
    /// (and data sources) stay consistent. Empty result -> chart shows an empty
    /// state rather than erroring.
    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        let period = selectedPeriod
        let points = (try? await fetchSeries(for: period)) ?? []
        // Guard against a stale response landing after the user switched ranges.
        guard period == selectedPeriod else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            chartAnimationId = UUID()
            chartData = points
        }
    }

    private func fetchSeries(for period: TimePeriod) async throws -> [PricePoint] {
        switch liveHolding.assetTypeEnum {
        case .crypto:
            // fetchCoinMarketChart needs a CoinGecko id, not the ticker.
            guard let geckoId = AssetRiskConfig.geckoId(for: liveHolding.symbol) else {
                return []
            }
            // Prefer stored daily snapshots (reliable, and unaffected by the
            // CoinGecko pro-key status). Fall back to the live market_chart only
            // for coins we don't track in market_snapshots.
            let snaps = try await fetchCryptoSnapshots(geckoId: geckoId, days: period.days)
            if !snaps.isEmpty { return snaps }
            if let chart = try? await marketService.fetchCoinMarketChart(
                id: geckoId, currency: "usd", days: period.days
            ) {
                return chart.priceHistory
            }
            return []

        case .stock:
            return try await fetchFMPSeries(symbol: liveHolding.symbol, period: period)

        case .metal:
            return try await fetchFMPSeries(symbol: metalFuturesSymbol(liveHolding.symbol), period: period)

        default:
            return []
        }
    }

    /// One row of `market_snapshots` (daily crypto history written by the cron).
    private struct MarketSnapshotRow: Decodable {
        let recorded_date: String
        let current_price: Double
    }

    /// Reads daily crypto price history from Supabase `market_snapshots` (same
    /// source the web app uses), keyed by CoinGecko id. Reliable regardless of
    /// the live CoinGecko key.
    private func fetchCryptoSnapshots(geckoId: String, days: Int) async throws -> [PricePoint] {
        let supabase = SupabaseManager.shared
        guard supabase.isConfigured else { return [] }

        let rows: [MarketSnapshotRow] = try await supabase.database
            .from("market_snapshots")
            .select("recorded_date, current_price")
            .eq("coin_id", value: geckoId)
            .order("recorded_date", ascending: true)
            .limit(500)
            .execute()
            .value

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let points = rows.compactMap { row -> PricePoint? in
            guard let date = formatter.date(from: row.recorded_date) else { return nil }
            return PricePoint(date: date, price: row.current_price)
        }
        return Array(points.suffix(max(2, days)))
    }

    /// FMP EOD history is daily-only, so a range maps to a count of trading days.
    private func fetchFMPSeries(symbol: String, period: TimePeriod) async throws -> [PricePoint] {
        let prices = try await FMPService.shared.fetchHistoricalPrices(
            symbol: symbol, limit: tradingDayLimit(for: period)
        )
        return prices
            .compactMap { p -> PricePoint? in p.dateValue.map { PricePoint(date: $0, price: p.close) } }
            .sorted { $0.date < $1.date }
    }

    private func tradingDayLimit(for period: TimePeriod) -> Int {
        switch period {
        case .hour, .day: return 2          // last two closes ≈ 1-day move
        case .week: return 6
        case .month: return 23
        case .ytd: return max(2, Int(ceil(Double(period.days) * 5.0 / 7.0)))
        case .year: return 252
        case .all: return 1260              // ~5 trading years
        }
    }

    private func metalFuturesSymbol(_ symbol: String) -> String {
        switch symbol.uppercased() {
        case "XAU": return "GCUSD"
        case "XAG": return "SIUSD"
        case "XPT": return "PLUSD"
        case "XPD": return "PAUSD"
        default: return "GCUSD"
        }
    }
}

// MARK: - Holding Timeframe Selector
/// Pill-style range selector for the holding performance chart. Mirrors the
/// Market screens' `TimeframeSelector` but drives a `TimePeriod`.
struct HoldingTimeframeSelector: View {
    @Binding var selected: TimePeriod
    let periods: [TimePeriod]
    @Namespace private var timeframeAnimation
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(periods) { period in
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = period
                    }
                }) {
                    Text(period.displayName)
                        .font(AppFonts.caption12Medium)
                        .fontWeight(selected == period ? .semibold : .regular)
                        .foregroundColor(selected == period ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selected == period {
                                Capsule()
                                    .fill(AppColors.accent)
                                    .matchedGeometryEffect(id: "holdingTimeframe", in: timeframeAnimation)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}
