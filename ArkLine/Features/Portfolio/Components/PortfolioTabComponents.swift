import SwiftUI

// MARK: - Overview Content
struct PortfolioOverviewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: PortfolioViewModel
    @Namespace private var zoomNamespace

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
                                NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel).zoomDestination(id: holding.id, in: zoomNamespace)) {
                                    HoldingRowCompact(holding: holding)
                                }
                                .zoomSource(id: holding.id, in: zoomNamespace)
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
                                NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel).zoomDestination(id: holding.id, in: zoomNamespace)) {
                                    HoldingRowCompact(holding: holding)
                                }
                                .zoomSource(id: holding.id, in: zoomNamespace)
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
    @Namespace private var zoomNamespace

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
                        NavigationLink(destination: HoldingDetailView(holding: holding, viewModel: viewModel).zoomDestination(id: holding.id, in: zoomNamespace)) {
                            HoldingRow(holding: holding)
                        }
                        .zoomSource(id: holding.id, in: zoomNamespace)
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
