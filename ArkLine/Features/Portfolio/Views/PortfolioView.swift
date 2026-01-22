import SwiftUI

struct PortfolioView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = PortfolioViewModel()
    @State private var showAddTransaction = false
    @State private var showCreatePortfolio = false
    @State private var showPortfolioPicker = false

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
                        case .performance:
                            PerformanceView(viewModel: viewModel)
                        case .transactions:
                            PortfolioTransactionsContent(viewModel: viewModel)
                        }

                        Spacer(minLength: 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
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
                    Button(action: { showAddTransaction = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Add transaction")
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
    let totalValue: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let profitLoss: Double
    let profitLossPercentage: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Value")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Text(totalValue.asCurrency)
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
                        Text("\(dayChange >= 0 ? "+" : "")\(dayChange.asCurrency)")
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
                        Text("\(profitLoss >= 0 ? "+" : "")\(profitLoss.asCurrency)")
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
    @State private var scrollOffset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    private var showTrailingIndicator: Bool {
        contentWidth > containerWidth && scrollOffset < (contentWidth - containerWidth - 10)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PortfolioTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
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
                    }
                }
                .padding(4)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            contentWidth = geo.size.width
                        }
                    }
                )
            }
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        containerWidth = geo.size.width
                    }
                }
            )

            // Scroll indicator - subtle chevron on right edge
            if showTrailingIndicator {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            AppColors.cardBackground(colorScheme).opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 30)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.trailing, 8)
                        .background(AppColors.cardBackground(colorScheme).opacity(0.9))
                }
                .allowsHitTesting(false)
            }
        }
        .glassCard(cornerRadius: 24)
    }
}

// MARK: - Overview Content
struct PortfolioOverviewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

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
                        value: viewModel.totalCost.asCurrencyCompact,
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
    @Bindable var viewModel: PortfolioViewModel

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

                            Text(allocation.value.asCurrency)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)

                            Text("\(allocation.percentage, specifier: "%.1f")%")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .frame(width: 50, alignment: .trailing)
                        }
                        .padding(.horizontal, 20)
                        .accessibilityLabel("\(allocation.category), \(allocation.percentage, specifier: "%.1f") percent, \(allocation.value.asCurrency)")
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

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    @State private var transactionType: TransactionType = .buy
    @State private var symbol = ""
    @State private var name = ""
    @State private var assetType: Constants.AssetType = .crypto
    @State private var quantity = ""
    @State private var pricePerUnit = ""
    @State private var transactionDate = Date()
    @State private var notes = ""
    @State private var selectedEmotionalState: EmotionalState?
    @State private var showingError = false
    @State private var errorMessage = ""

    private var isFormValid: Bool {
        // Real estate uses its own form
        if assetType == .realEstate { return false }
        return !symbol.isEmpty &&
        !name.isEmpty &&
        Double(quantity) ?? 0 > 0 &&
        Double(pricePerUnit) ?? 0 > 0
    }

    private var totalValue: Double {
        (Double(quantity) ?? 0) * (Double(pricePerUnit) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction Type
                Section {
                    Picker("Type", selection: $transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Asset Details
                Section("Asset") {
                    Picker("Asset Type", selection: $assetType) {
                        ForEach(Constants.AssetType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    if assetType == .realEstate {
                        // Show link to real estate form
                        NavigationLink {
                            AddRealEstateView(viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundColor(AppColors.accent)
                                Text("Add Property Details")
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    } else {
                        TextField("Symbol (e.g., BTC)", text: $symbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        TextField("Name (e.g., Bitcoin)", text: $name)
                            .autocorrectionDisabled()
                    }
                }

                if assetType != .realEstate {
                // Transaction Details
                Section("Details") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0.00", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Price per Unit")
                        Spacer()
                        TextField("$0.00", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                }

                // Total
                Section {
                    HStack {
                        Text("Total Value")
                            .font(AppFonts.body14Bold)
                        Spacer()
                        Text(totalValue.asCurrency)
                            .font(AppFonts.title18SemiBold)
                            .foregroundColor(AppColors.accent)
                    }
                }

                // Emotional State
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How are you feeling?")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("Track your emotional state when making this decision")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)

                        EmotionalStatePicker(selectedState: $selectedEmotionalState)
                    }
                    .padding(.vertical, 4)
                }

                // Notes
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                } // End of if assetType != .realEstate
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Add Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid ? AppColors.accent : AppColors.textSecondary)
                    .disabled(!isFormValid)
                }
            }
            #endif
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveTransaction() {
        guard isFormValid else { return }

        let transaction = Transaction(
            portfolioId: viewModel.holdings.first?.portfolioId ?? UUID(),
            holdingId: nil,
            type: transactionType,
            assetType: assetType.rawValue,
            symbol: symbol.uppercased(),
            quantity: Double(quantity) ?? 0,
            pricePerUnit: Double(pricePerUnit) ?? 0,
            transactionDate: transactionDate,
            notes: notes.isEmpty ? nil : notes,
            emotionalState: selectedEmotionalState
        )

        Task { await viewModel.addTransaction(transaction) }
        dismiss()
    }
}

// MARK: - Emotional State Picker
struct EmotionalStatePicker: View {
    @Binding var selectedState: EmotionalState?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(EmotionalState.allCases, id: \.self) { state in
                EmotionalStateChip(
                    state: state,
                    isSelected: selectedState == state,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedState == state {
                                selectedState = nil
                            } else {
                                selectedState = state
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Flow Layout for Wrapping Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Emotional State Chip
struct EmotionalStateChip: View {
    let state: EmotionalState
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var stateColor: Color {
        Color(hex: state.color)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: state.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(state.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? stateColor : AppColors.cardBackground(colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Holding Detail View
struct HoldingDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding
    @Bindable var viewModel: PortfolioViewModel
    @State private var showSellSheet = false
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false

    var holdingTransactions: [Transaction] {
        viewModel.transactions.filter { $0.symbol.uppercased() == holding.symbol.uppercased() }
            .sorted { $0.transactionDate > $1.transactionDate }
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
                    CoinIconView(symbol: holding.symbol, size: 64)

                    Text(holding.name)
                        .font(AppFonts.title24)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(holding.symbol.uppercased())
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 20)

                // Value Card
                VStack(spacing: 16) {
                    // Current Value
                    VStack(spacing: 4) {
                        Text("Current Value")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)

                        Text(holding.currentValue.asCurrency)
                            .font(AppFonts.number44)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    Divider()

                    // Stats Grid
                    HStack(spacing: 0) {
                        StatItem(title: "Quantity", value: holding.quantity.asQuantity)
                        Divider().frame(height: 40)
                        StatItem(title: "Avg. Price", value: (holding.averageBuyPrice ?? 0).asCurrency)
                        Divider().frame(height: 40)
                        StatItem(title: "Current Price", value: (holding.currentPrice ?? 0).asCurrency)
                    }

                    Divider()

                    // P/L
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profit/Loss")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 14))
                                Text(holding.profitLoss.asCurrency)
                                    .font(AppFonts.title18SemiBold)
                            }
                            .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Return")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            Text("\(holding.isProfit ? "+" : "")\(holding.profitLossPercentage, specifier: "%.2f")%")
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)
                        }
                    }

                    // 24h Change
                    if let change24h = holding.priceChangePercentage24h {
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

                // Transaction History
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transaction History")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .padding(.horizontal, 20)

                    if holdingTransactions.isEmpty {
                        Text("No transactions for this asset")
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(holdingTransactions) { transaction in
                                Button(action: {
                                    selectedTransaction = transaction
                                    showTransactionDetail = true
                                }) {
                                    TransactionRow(transaction: transaction)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer(minLength: 100)
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle(holding.symbol.uppercased())
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSellSheet = true }) {
                    Text("Sell")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.error)
                }
            }
        }
        #endif
        .sheet(isPresented: $showSellSheet) {
            SellAssetView(viewModel: viewModel, holding: holding)
        }
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

struct AllocationPieChart: View {
    let allocations: [PortfolioAllocation]
    let colorScheme: ColorScheme

    private var sliceData: [(allocation: PortfolioAllocation, startAngle: Angle, endAngle: Angle)] {
        var currentAngle = Angle(degrees: -90)
        return allocations.map { allocation in
            let start = currentAngle
            let end = currentAngle + Angle(degrees: allocation.percentage * 3.6)
            currentAngle = end
            return (allocation, start, end)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 10

            ZStack {
                ForEach(sliceData, id: \.allocation.id) { slice in
                    Path { path in
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: slice.startAngle, endAngle: slice.endAngle, clockwise: false)
                    }
                    .fill(Color(hex: slice.allocation.color))
                }

                // Inner circle for donut effect
                Circle()
                    .fill(AppColors.background(colorScheme))
                    .frame(width: radius * 1.2, height: radius * 1.2)
            }
        }
    }
}

// MARK: - Portfolio Switcher Sheet
struct PortfolioSwitcherSheet: View {
    let portfolios: [Portfolio]
    @Binding var selectedPortfolio: Portfolio?
    var onCreatePortfolio: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(portfolios) { portfolio in
                            PortfolioSwitcherRow(
                                portfolio: portfolio,
                                isSelected: selectedPortfolio?.id == portfolio.id,
                                onSelect: {
                                    selectedPortfolio = portfolio
                                    dismiss()
                                }
                            )
                        }

                        if portfolios.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.textSecondary)
                                Text("No portfolios yet")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(textPrimary)
                                Text("Create your first portfolio to start tracking your assets")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Button(action: {
                    dismiss()
                    onCreatePortfolio?()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }

                        Text("Create New Portfolio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Select Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct PortfolioSwitcherRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(portfolio.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(portfolio.isPublic ? "Public" : "Private")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppState())
}
