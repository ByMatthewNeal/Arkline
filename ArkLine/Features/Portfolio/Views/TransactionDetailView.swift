import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let transaction: Transaction
    let portfolioName: String?
    let destinationPortfolioName: String?

    init(
        transaction: Transaction,
        portfolioName: String? = nil,
        destinationPortfolioName: String? = nil
    ) {
        self.transaction = transaction
        self.portfolioName = portfolioName
        self.destinationPortfolioName = destinationPortfolioName
    }

    private var isRealEstate: Bool {
        transaction.assetType == Constants.AssetType.realEstate.rawValue
    }

    private var isSellTransaction: Bool {
        transaction.type == .sell
    }

    private var isTransfer: Bool {
        transaction.type == .transferIn || transaction.type == .transferOut
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard

                    // Transaction Details Card
                    detailsCard

                    // Profit/Loss Card (for sell transactions)
                    if isSellTransaction {
                        profitLossCard
                    }

                    // Transfer Info Card (for transfers)
                    if isTransfer || transaction.destinationPortfolioId != nil {
                        transferCard
                    }

                    // Emotional State Card (if recorded)
                    if let emotionalState = transaction.emotionalState {
                        emotionalStateCard(emotionalState)
                    }

                    // Notes Card (if present)
                    if let notes = transaction.notes, !notes.isEmpty {
                        notesCard(notes)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon and Type
            ZStack {
                Circle()
                    .fill(transactionTypeColor.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: transaction.type.icon)
                    .font(.system(size: 28))
                    .foregroundColor(transactionTypeColor)
            }

            // Transaction Type Label
            Text(transaction.type.displayName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(transactionTypeColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(transactionTypeColor.opacity(0.15))
                )

            // Asset Info
            HStack(spacing: 12) {
                if isRealEstate {
                    RealEstateIconView(size: 40)
                } else {
                    CoinIconView(symbol: transaction.symbol, size: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRealEstate ? transaction.symbol : transaction.symbol.uppercased())
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(transaction.assetType.capitalized)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Total Value
            Text(transaction.totalValue.asCurrency)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Date
            Text(transaction.transactionDate.displayDateTime)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Transaction Details")

            detailRow(label: "Quantity", value: transaction.quantity.asQuantity)

            Divider()
                .padding(.horizontal)

            detailRow(label: "Price per Unit", value: transaction.pricePerUnit.asCryptoPrice)

            if transaction.gasFee > 0 {
                Divider()
                    .padding(.horizontal)

                detailRow(label: "Fee", value: transaction.gasFee.asCurrency)
            }

            Divider()
                .padding(.horizontal)

            detailRow(label: "Total", value: transaction.totalValue.asCurrency, isHighlighted: true)

            if let portfolioName = portfolioName {
                Divider()
                    .padding(.horizontal)

                detailRow(label: "Portfolio", value: portfolioName)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Profit/Loss Card
    private var profitLossCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Realized Profit/Loss")

            if let costBasis = transaction.costBasisPerUnit {
                detailRow(label: "Cost Basis per Unit", value: costBasis.asCryptoPrice)

                Divider()
                    .padding(.horizontal)

                detailRow(
                    label: "Total Cost Basis",
                    value: (transaction.quantity * costBasis).asCurrency
                )

                Divider()
                    .padding(.horizontal)
            }

            detailRow(label: "Sale Proceeds", value: transaction.totalValue.asCurrency)

            if let realizedPL = transaction.realizedProfitLoss {
                Divider()
                    .padding(.horizontal)

                HStack {
                    Text("Realized P/L")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(realizedPL >= 0 ? "+" : "")\(realizedPL.asCurrency)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(realizedPL >= 0 ? AppColors.success : AppColors.error)

                        if let costBasis = transaction.costBasisPerUnit, costBasis > 0 {
                            let totalCost = transaction.quantity * costBasis
                            let percentage = (realizedPL / totalCost) * 100
                            Text("\(realizedPL >= 0 ? "+" : "")\(String(format: "%.2f", percentage))%")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Transfer Card
    private var transferCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Transfer Information")

            if transaction.type == .transferIn {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(AppColors.success)
                    Text("Received into this portfolio")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Spacer()
                }
                .padding()
            } else if transaction.type == .transferOut {
                HStack {
                    Image(systemName: "arrow.left.circle.fill")
                        .foregroundColor(AppColors.error)
                    Text("Sent from this portfolio")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Spacer()
                }
                .padding()
            }

            if let destName = destinationPortfolioName {
                Divider()
                    .padding(.horizontal)

                detailRow(
                    label: transaction.type == .sell ? "Transferred To" : "From Portfolio",
                    value: destName
                )
            } else if transaction.destinationPortfolioId != nil {
                Divider()
                    .padding(.horizontal)

                detailRow(
                    label: "Destination",
                    value: "Another Portfolio"
                )
            }

            if transaction.relatedTransactionId != nil {
                Divider()
                    .padding(.horizontal)

                HStack {
                    Image(systemName: "link")
                        .foregroundColor(AppColors.accent)
                    Text("Linked to transfer transaction")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Emotional State Card
    private func emotionalStateCard(_ state: EmotionalState) -> some View {
        VStack(spacing: 0) {
            sectionHeader("Emotional State")

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: state.color).opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: state.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: state.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("How you felt during this transaction")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Notes Card
    private func notesCard(_ notes: String) -> some View {
        VStack(spacing: 0) {
            sectionHeader("Notes")

            HStack {
                Text(notes)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardBackground(colorScheme))
        )
    }

    // MARK: - Helper Views
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func detailRow(label: String, value: String, isHighlighted: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .padding()
    }

    private var transactionTypeColor: Color {
        switch transaction.type {
        case .buy:
            return AppColors.success
        case .sell:
            return AppColors.error
        case .transferIn:
            return AppColors.accent
        case .transferOut:
            return Color.orange
        }
    }
}

#Preview {
    TransactionDetailView(
        transaction: Transaction(
            portfolioId: UUID(),
            holdingId: UUID(),
            type: .sell,
            assetType: "crypto",
            symbol: "BTC",
            quantity: 0.5,
            pricePerUnit: 67500,
            gasFee: 25,
            transactionDate: Date(),
            notes: "Taking profits after reaching target price",
            emotionalState: .confident,
            costBasisPerUnit: 45000,
            realizedProfitLoss: 11225,
            destinationPortfolioId: UUID()
        ),
        portfolioName: "Main Portfolio",
        destinationPortfolioName: "Savings Portfolio"
    )
}
