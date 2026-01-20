import SwiftUI

struct TransactionRow: View {
    @Environment(\.colorScheme) var colorScheme
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            transactionIcon

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(transaction.type.displayName)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(transaction.symbol.uppercased())
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text(transaction.transactionDate.displayDate)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Amount & Value
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type.isIncoming ? "+" : "-")\(transaction.quantity, specifier: "%.4f")")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(transaction.type.isIncoming ? AppColors.success : AppColors.error)

                Text(transaction.totalValue.asCurrency)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }

    private var transactionIcon: some View {
        ZStack {
            Circle()
                .fill(transaction.type.isIncoming ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: transaction.type.icon)
                .font(.system(size: 16))
                .foregroundColor(transaction.type.isIncoming ? AppColors.success : AppColors.error)
        }
    }
}


#Preview {
    VStack(spacing: 12) {
        TransactionRow(transaction: Transaction(
            portfolioId: UUID(),
            holdingId: UUID(),
            type: .buy,
            assetType: "crypto",
            symbol: "BTC",
            quantity: 0.5,
            pricePerUnit: 45000,
            transactionDate: Date()
        ))

        TransactionRow(transaction: Transaction(
            portfolioId: UUID(),
            holdingId: UUID(),
            type: .sell,
            assetType: "crypto",
            symbol: "ETH",
            quantity: 1.0,
            pricePerUnit: 3000,
            transactionDate: Date().addingTimeInterval(-86400 * 5)
        ))
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
