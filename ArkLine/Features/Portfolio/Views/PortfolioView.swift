import SwiftUI

struct PortfolioView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = PortfolioViewModel()
    @State private var showAddTransaction = false
    @State private var showCreatePortfolio = false
    @State private var showPortfolioPicker = false
    @State private var showShowcase = false

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()

                // Content
                VStack(spacing: 0) {
                // Error Banner
                if let error = viewModel.error {
                    ErrorBanner(error: error) {
                        viewModel.dismissError()
                    } onRetry: {
                        Task { await viewModel.refresh() }
                    }
                }

                // Portfolio Value Header
                PortfolioHeader(
                    totalValue: viewModel.totalValue,
                    dayChange: viewModel.dayChange,
                    dayChangePercentage: viewModel.dayChangePercentage,
                    profitLoss: viewModel.totalProfitLoss,
                    profitLossPercentage: viewModel.totalProfitLossPercentage
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Tab Selector
                PortfolioTabSelector(selectedTab: $viewModel.selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Content
                ZStack {
                    ScrollView {
                        switch viewModel.selectedTab {
                        case .overview:
                            PortfolioOverviewContent(viewModel: viewModel)
                        case .holdings:
                            PortfolioHoldingsContent(viewModel: viewModel)
                        case .allocation:
                            PortfolioAllocationContent(viewModel: viewModel)
                        case .dcaCalculator:
                            DCACalculatorView(viewModel: viewModel)
                        case .performance:
                            PerformanceView(viewModel: viewModel)
                        case .transactions:
                            PortfolioTransactionsContent(viewModel: viewModel)
                        }

                        // Disclaimer
                        FinancialDisclaimer()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Spacer(minLength: 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                    .task {
                        await viewModel.refresh()
                    }
                    .onAppear {
                        Task { await AnalyticsService.shared.trackScreenView("portfolio") }
                    }

                    // Loading Overlay
                    if viewModel.isLoading {
                        LoadingOverlay()
                    }
                }
                }
            }
            .navigationTitle(viewModel.selectedPortfolio?.name ?? "Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showPortfolioPicker = true }) {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedPortfolio?.name ?? "Portfolio")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: ArkSpacing.sm) {
                        // Showcase button
                        Button(action: { showShowcase = true }) {
                            Image(systemName: "square.split.2x1")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Portfolio showcase")

                        // Add transaction button
                        Button(action: { showAddTransaction = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Add transaction")
                    }
                }
            }
            #endif
            .sheet(isPresented: $showPortfolioPicker) {
                PortfolioSwitcherSheet(
                    portfolios: viewModel.portfolios,
                    selectedPortfolio: Binding(
                        get: { viewModel.selectedPortfolio },
                        set: { portfolio in
                            if let portfolio = portfolio {
                                viewModel.selectPortfolio(portfolio)
                            }
                        }
                    ),
                    viewModel: viewModel,
                    onCreatePortfolio: {
                        showCreatePortfolio = true
                    }
                )
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreatePortfolio) {
                CreatePortfolioView(viewModel: viewModel)
            }
            .sheet(isPresented: $showShowcase) {
                PortfolioShowcaseView()
            }
            .onChange(of: appState.shouldShowPortfolioCreation) { _, shouldShow in
                if shouldShow {
                    // Small delay to allow view transition to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreatePortfolio = true
                        appState.shouldShowPortfolioCreation = false
                    }
                }
            }
            .onAppear {
                // Also check on appear in case onChange missed it
                if appState.shouldShowPortfolioCreation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreatePortfolio = true
                        appState.shouldShowPortfolioCreation = false
                    }
                }
            }
        }
    }
}

// MARK: - Error Banner
struct ErrorBanner: View {
    @Environment(\.colorScheme) var colorScheme
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "An error occurred")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if error.isRecoverable {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.error.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Text(title)
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(message)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Portfolio Header
struct PortfolioHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    let totalValue: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let profitLoss: Double
    let profitLossPercentage: Double

    private var currency: String {
        appState.preferredCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Value")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Text(totalValue.asCurrency(code: currency))
                .font(AppFonts.number44)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: 16) {
                // Day Change
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text("\(dayChange >= 0 ? "+" : "")\(dayChange.asCurrency(code: currency))")
                            .font(AppFonts.body14Medium)
                        Text("(\(dayChangePercentage >= 0 ? "+" : "")\(dayChangePercentage, specifier: "%.2f")%)")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(dayChange >= 0 ? AppColors.success : AppColors.error)
                }

                Divider().frame(height: 30)

                // Total P/L
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Time")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: profitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text("\(profitLoss >= 0 ? "+" : "")\(profitLoss.asCurrency(code: currency))")
                            .font(AppFonts.body14Medium)
                        Text("(\(profitLossPercentage >= 0 ? "+" : "")\(profitLossPercentage, specifier: "%.2f")%)")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(profitLoss >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tab Selector
struct PortfolioTabSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTab: PortfolioTab

    var body: some View {
        HStack(spacing: 0) {
            // Left chevron hint
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                .padding(.leading, 8)
                .padding(.trailing, 2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(PortfolioTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                withAnimation {
                                    proxy.scrollTo(tab, anchor: .center)
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(selectedTab == tab ? .white : AppColors.textSecondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? AppColors.accent : Color.clear)
                                    .cornerRadius(20)
                            }
                            .id(tab)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Right chevron hint
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                .padding(.leading, 2)
                .padding(.trailing, 8)
        }
        .glassCard(cornerRadius: 24)
    }
}

// MARK: - Overview Content
struct PortfolioOverviewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: PortfolioViewModel

    private var currency: String {
        appState.preferredCurrency
    }

    var body: some View {
        if viewModel.holdings.isEmpty {
            EmptyStateView(
                icon: "chart.pie",
                title: "No Holdings Yet",
                message: "Add your first asset to start tracking your portfolio performance."
            )
            .padding(.top, 40)
        } else {
            VStack(spacing: 20) {
                // Mini Chart
                if !viewModel.historyPoints.isEmpty {
                    PortfolioMiniChart(data: viewModel.historyPoints)
                        .frame(height: 150)
                        .padding(.horizontal, 20)
                        .accessibilityLabel("Portfolio value chart for the last 30 days")
                }

                // Quick Stats
                HStack(spacing: 12) {
                    QuickStatCard(
                        title: "Assets",
                        value: "\(viewModel.holdings.count)",
                        icon: "chart.pie"
                    )

                    QuickStatCard(
                        title: "Cost Basis",
                        value: viewModel.totalCost.asCurrencyCompact(code: currency),
                        icon: "dollarsign.circle"
                    )
                }
                .padding(.horizontal, 20)

                // Top Performers
                if !viewModel.topPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Performers")
                            .font(AppFonts.title18SemiBold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(viewModel.topPerformers) { holding in
                                NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel)) {
                                    HoldingRowCompact(holding: holding)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(holding.name), \(holding.profitLossPercentage >= 0 ? "up" : "down") \(abs(holding.profitLossPercentage), specifier: "%.1f") percent")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Worst Performers
                if !viewModel.worstPerformers.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Worst Performers")
                            .font(AppFonts.title18SemiBold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(viewModel.worstPerformers) { holding in
                                NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel)) {
                                    HoldingRowCompact(holding: holding)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(holding.name), \(holding.profitLossPercentage >= 0 ? "up" : "down") \(abs(holding.profitLossPercentage), specifier: "%.1f") percent")
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Holdings Content
struct PortfolioHoldingsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        VStack(spacing: 16) {
            if !viewModel.holdings.isEmpty {
                // Search & Filter
                HStack(spacing: 12) {
                    SearchBar(text: $viewModel.holdingsSearchText, placeholder: "Search holdings...")

                    Menu {
                        Button("All") { viewModel.selectAssetType(nil) }
                        ForEach(Constants.AssetType.allCases, id: \.self) { type in
                            Button(type.displayName) { viewModel.selectAssetType(type) }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundColor(viewModel.selectedAssetType == nil ? AppColors.textSecondary : AppColors.accent)
                    }
                    .accessibilityLabel("Filter by asset type")
                }
                .padding(.horizontal, 20)
            }

            if viewModel.holdings.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Holdings",
                    message: "Start building your portfolio by adding your first asset."
                )
                .padding(.top, 20)
            } else if viewModel.filteredHoldings.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "No holdings match your search criteria."
                )
                .padding(.top, 20)
            } else {
                // Holdings List
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.filteredHoldings) { holding in
                        NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel)) {
                            HoldingRow(holding: holding)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("\(holding.name), value \(holding.currentValue.asCurrency), \(holding.isProfit ? "profit" : "loss") of \(abs(holding.profitLossPercentage), specifier: "%.1f") percent")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Allocation Content
struct PortfolioAllocationContent: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: PortfolioViewModel

    private var currency: String {
        appState.preferredCurrency
    }

    var body: some View {
        if viewModel.allocations.isEmpty {
            EmptyStateView(
                icon: "chart.pie",
                title: "No Allocation Data",
                message: "Add assets to your portfolio to see your allocation breakdown."
            )
            .padding(.top, 40)
        } else {
            VStack(spacing: 24) {
                // Pie Chart
                AllocationPieChart(allocations: viewModel.allocations, colorScheme: colorScheme)
                    .frame(height: 250)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Portfolio allocation pie chart")

                // Legend
                VStack(spacing: 12) {
                    ForEach(viewModel.allocations) { allocation in
                        HStack {
                            Circle()
                                .fill(Color(hex: allocation.color))
                                .frame(width: 12, height: 12)

                            Text(allocation.category)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Spacer()

                            Text(allocation.value.asCurrency(code: currency))
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)

                            Text("\(allocation.percentage, specifier: "%.1f")%")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .accessibilityLabel("\(allocation.category), \(allocation.percentage, specifier: "%.1f") percent, \(allocation.value.asCurrency(code: currency))")
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Transactions Content
struct PortfolioTransactionsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false

    private func destinationPortfolioName(for transaction: Transaction) -> String? {
        guard let destId = transaction.destinationPortfolioId else { return nil }
        return viewModel.portfolios.first { $0.id == destId }?.name
    }

    var body: some View {
        VStack(spacing: 16) {
            if !viewModel.transactions.isEmpty {
                // Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: viewModel.transactionFilter == nil) {
                            viewModel.selectTransactionFilter(nil)
                        }
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            FilterChip(title: type.displayName, isSelected: viewModel.transactionFilter == type) {
                                viewModel.selectTransactionFilter(type)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            if viewModel.transactions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Transactions",
                    message: "Your transaction history will appear here once you start trading."
                )
                .padding(.top, 20)
            } else if viewModel.filteredTransactions.isEmpty {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matching Transactions",
                    message: "No transactions match the selected filter."
                )
                .padding(.top, 20)
            } else {
                // Transaction List
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.filteredTransactions) { transaction in
                        Button(action: {
                            selectedTransaction = transaction
                            showTransactionDetail = true
                        }) {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(transaction.type.displayName) \(transaction.quantity, specifier: "%.4f") \(transaction.symbol) for \(transaction.totalValue.asCurrency)")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .sheet(isPresented: $showTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(
                    transaction: transaction,
                    portfolioName: viewModel.selectedPortfolio?.name,
                    destinationPortfolioName: destinationPortfolioName(for: transaction)
                )
            }
        }
    }
}

// MARK: - Supporting Views
struct QuickStatCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Text(value)
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

struct FilterChip: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.caption12Medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.accent : AppColors.cardBackground(colorScheme))
                .cornerRadius(20)
        }
    }
}

struct PortfolioMiniChart: View {
    let data: [PortfolioHistoryPoint]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }

                let values = data.map { $0.value }
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 1
                let range = maxValue - minValue

                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let stepY = geometry.size.height / CGFloat(range == 0 ? 1 : range)

                for (index, point) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - (CGFloat(point.value - minValue) * stepY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppState())
}
