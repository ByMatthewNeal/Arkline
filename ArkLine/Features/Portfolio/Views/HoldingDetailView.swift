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

    private var currency: String {
        appState.preferredCurrency
    }

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

                        Text(holding.currentValue.asCurrency(code: currency))
                            .font(AppFonts.number44)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    Divider()

                    // Stats Grid
                    HStack(spacing: 0) {
                        StatItem(title: "Quantity", value: holding.quantity.asQuantity)
                        Divider().frame(height: 40)
                        StatItem(title: "Avg. Price", value: (holding.averageBuyPrice ?? 0).asCurrency(code: currency))
                        Divider().frame(height: 40)
                        StatItem(title: "Current Price", value: (holding.currentPrice ?? 0).asCurrency(code: currency))
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
                                Text(holding.profitLoss.asCurrency(code: currency))
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
