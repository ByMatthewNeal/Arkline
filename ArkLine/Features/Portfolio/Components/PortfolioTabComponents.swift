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

                // Header with Edit Targets button
                HStack {
                    Text("Allocation")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    Button {
                        viewModel.showTargetEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Targets")
                        }
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Edit target allocations")
                }
                .padding(.horizontal, 20)

                // Legend
                VStack(spacing: 12) {
                    ForEach(viewModel.allocations) { allocation in
                        allocationRow(allocation)
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.top, 20)
            .sheet(isPresented: $viewModel.showTargetEditor) {
                AllocationTargetEditor(viewModel: viewModel)
                    .environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private func allocationRow(_ allocation: PortfolioAllocation) -> some View {
        HStack(spacing: 8) {
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

            if let target = allocation.targetPercentage {
                driftBadge(actual: allocation.percentage, target: target)
            }
        }
        .accessibilityLabel(allocationAccessibilityLabel(allocation))
    }

    @ViewBuilder
    private func driftBadge(actual: Double, target: Double) -> some View {
        let drift = actual - target
        let absDrift = abs(drift)
        let color: Color = absDrift <= 2 ? AppColors.success : absDrift <= 5 ? AppColors.warning : AppColors.error

        HStack(spacing: 2) {
            Image(systemName: drift >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8))
            Text("\(target, specifier: "%.0f")%")
                .font(AppFonts.caption12Medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .cornerRadius(4)
    }

    private func allocationAccessibilityLabel(_ allocation: PortfolioAllocation) -> String {
        var label = "\(allocation.category), \(String(format: "%.1f", allocation.percentage)) percent, \(allocation.value.asCurrency(code: currency))"
        if let target = allocation.targetPercentage {
            let drift = allocation.percentage - target
            label += ", target \(String(format: "%.0f", target)) percent, \(abs(drift) < 0.1 ? "on target" : drift > 0 ? "overweight" : "underweight")"
        }
        return label
    }
}

// MARK: - Allocation Target Editor
struct AllocationTargetEditor: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: PortfolioViewModel

    @State private var targets: [UUID: String] = [:]
    @State private var isSaving = false

    private var totalTarget: Double {
        targets.values.reduce(0) { sum, str in
            sum + (Double(str) ?? 0)
        }
    }

    private var isValid: Bool {
        let total = totalTarget
        // Allow saving if total is 0 (clearing all) or exactly 100
        return total == 0 || (total >= 99.9 && total <= 100.1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total bar
                totalBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .overlay(AppColors.divider(colorScheme))

                // Holdings list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.holdings.sorted(by: { $0.currentValue > $1.currentValue })) { holding in
                            targetRow(holding)
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Target Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid || isSaving)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    @ViewBuilder
    private var totalBar: some View {
        let total = totalTarget
        let barColor: Color = total == 0 ? AppColors.textSecondary :
            (total >= 99.9 && total <= 100.1) ? AppColors.success : AppColors.error

        VStack(spacing: 8) {
            HStack {
                Text("Total")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
                Text("\(total, specifier: "%.1f")%")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.divider(colorScheme))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(total / 100, 1))
                }
            }
            .frame(height: 6)

            if total > 0 && (total < 99.9 || total > 100.1) {
                Text("Must equal 100% to save")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }
        }
    }

    @ViewBuilder
    private func targetRow(_ holding: PortfolioHolding) -> some View {
        let actualPct = viewModel.totalValue > 0 ? (holding.currentValue / viewModel.totalValue) * 100 : 0

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol.uppercased())
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(actualPct, specifier: "%.1f")% actual")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { targets[holding.id] ?? "" },
                    set: { targets[holding.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppColors.fillSecondary(colorScheme))
                .cornerRadius(8)

                Text("%")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }

    private func loadExisting() {
        for holding in viewModel.holdings {
            if let target = holding.targetPercentage {
                targets[holding.id] = String(format: "%.0f", target)
            }
        }
    }

    private func save() {
        isSaving = true
        let parsed: [UUID: Double?] = Dictionary(uniqueKeysWithValues:
            viewModel.holdings.map { holding in
                let value = Double(targets[holding.id] ?? "")
                return (holding.id, value != nil && value! > 0 ? value : nil)
            }
        )

        Task {
            await viewModel.updateTargetAllocations(parsed)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Transactions Content
struct PortfolioTransactionsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    @State private var transactionToDelete: Transaction?
    @State private var showDeleteConfirmation = false

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
                LazyVStack(spacing: ArkSpacing.xs) {
                    ForEach(viewModel.filteredTransactions) { transaction in
                        Button(action: {
                            selectedTransaction = transaction
                            showTransactionDetail = true
                        }) {
                            TransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                transactionToDelete = transaction
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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
