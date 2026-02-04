import SwiftUI

// MARK: - Investment History Sheet
struct InvestmentHistorySheetView: View {
    let reminder: DCAReminder
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var investments: [DCAInvestment] = []
    @State private var isLoading = true

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if investments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(investments) { investment in
                                InvestmentHistoryRow(investment: investment, symbol: reminder.symbol)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Investment History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            #endif
            .task {
                // In a real app, fetch from service
                // For now, simulate with mock data
                try? await Task.sleep(nanoseconds: 500_000_000)
                isLoading = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(textPrimary.opacity(0.3))

            Text("No Investment History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Your investment history will appear here\nonce you start investing")
                .font(.system(size: 14))
                .foregroundColor(textPrimary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Investment History Row
struct InvestmentHistoryRow: View {
    let investment: DCAInvestment
    let symbol: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            // Coin icon
            DCACoinIconView(symbol: symbol, size: 44)

            // Date and details
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.purchaseDate.displayDate)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textPrimary)

                Text("@ \(investment.priceAtPurchase.asCryptoPrice)")
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.amount.asCurrency)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("Invested")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.success.opacity(0.15))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
