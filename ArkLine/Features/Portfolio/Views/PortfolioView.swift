import SwiftUI

struct PortfolioView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = PortfolioViewModel()
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                ScrollView {
                    switch viewModel.selectedTab {
                    case .overview:
                        PortfolioOverviewContent(viewModel: viewModel)
                    case .holdings:
                        PortfolioHoldingsContent(viewModel: viewModel)
                    case .allocation:
                        PortfolioAllocationContent(viewModel: viewModel)
                    case .transactions:
                        PortfolioTransactionsContent(viewModel: viewModel)
                    }

                    Spacer(minLength: 100)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTransaction = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
        }
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

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PortfolioTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(selectedTab == tab ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? AppColors.accent : Color.clear)
                        .cornerRadius(20)
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(24)
    }
}

// MARK: - Overview Content
struct PortfolioOverviewContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Mini Chart
            if !viewModel.historyPoints.isEmpty {
                PortfolioMiniChart(data: viewModel.historyPoints)
                    .frame(height: 150)
                    .padding(.horizontal, 20)
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
                            HoldingRowCompact(holding: holding)
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
                            HoldingRowCompact(holding: holding)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Holdings Content
struct PortfolioHoldingsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        VStack(spacing: 16) {
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
            }
            .padding(.horizontal, 20)

            // Holdings List
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredHoldings) { holding in
                    NavigationLink(destination: HoldingDetailView(holding: holding)) {
                        HoldingRow(holding: holding)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
}

// MARK: - Allocation Content
struct PortfolioAllocationContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        VStack(spacing: 24) {
            // Pie Chart
            AllocationPieChart(allocations: viewModel.allocations)
                .frame(height: 250)
                .padding(.horizontal, 20)

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
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Transactions Content
struct PortfolioTransactionsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    var body: some View {
        VStack(spacing: 16) {
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

            // Transaction List
            LazyVStack(spacing: 8) {
                ForEach(viewModel.filteredTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
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
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
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

// MARK: - Placeholder Views
struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack {
                Text("Add Transaction")
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Add Transaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }
}

struct HoldingDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding

    var body: some View {
        VStack {
            Text(holding.name)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(colorScheme))
        .navigationTitle(holding.symbol)
    }
}

struct AllocationPieChart: View {
    let allocations: [PortfolioAllocation]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 10

            ZStack {
                var startAngle = Angle(degrees: -90)

                ForEach(allocations) { allocation in
                    let endAngle = startAngle + Angle(degrees: allocation.percentage * 3.6)

                    Path { path in
                        path.move(to: center)
                        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    }
                    .fill(Color(hex: allocation.color))

                    let _ = startAngle = endAngle
                }

                // Inner circle for donut effect
                Circle()
                    .fill(Color(hex: "0F0F0F"))
                    .frame(width: radius * 1.2, height: radius * 1.2)
            }
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppState())
}
