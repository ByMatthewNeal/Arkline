import SwiftUI

// MARK: - Portfolio Picker Sheet

/// Sheet for selecting a portfolio from the user's portfolio list
struct PortfolioPickerSheet: View {
    let title: String
    let portfolios: [Portfolio]
    let onSelect: (Portfolio) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if portfolios.isEmpty {
                    emptyState
                } else {
                    portfolioList
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .background(AppColors.background(colorScheme))
        }
    }

    // MARK: - Portfolio List

    private var portfolioList: some View {
        ScrollView {
            LazyVStack(spacing: ArkSpacing.sm) {
                ForEach(portfolios) { portfolio in
                    PortfolioPickerRow(
                        portfolio: portfolio,
                        onTap: {
                            onSelect(portfolio)
                            dismiss()
                        }
                    )
                }
            }
            .padding(ArkSpacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No Portfolios Available")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Create a portfolio first to use the showcase feature")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)
        }
    }
}

// MARK: - Portfolio Picker Row

private struct PortfolioPickerRow: View {
    let portfolio: Portfolio
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ArkSpacing.md) {
                // Icon
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "wallet.pass.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.accent)
                    )

                // Name and info
                VStack(alignment: .leading, spacing: 2) {
                    Text(portfolio.name)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: ArkSpacing.xs) {
                        if portfolio.isPublic {
                            HStack(spacing: 2) {
                                Image(systemName: "globe")
                                    .font(.caption2)
                                Text("Public")
                                    .font(ArkFonts.caption)
                            }
                            .foregroundColor(AppColors.success)
                        } else {
                            HStack(spacing: 2) {
                                Image(systemName: "lock")
                                    .font(.caption2)
                                Text("Private")
                                    .font(ArkFonts.caption)
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }

                        if let holdings = portfolio.holdings {
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text("\(holdings.count) assets")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PortfolioPickerSheet(
        title: "Select Portfolio",
        portfolios: [
            Portfolio(userId: UUID(), name: "Crypto Portfolio", isPublic: false),
            Portfolio(userId: UUID(), name: "Stock Portfolio", isPublic: true),
            Portfolio(userId: UUID(), name: "Mixed Portfolio", isPublic: false)
        ],
        onSelect: { _ in }
    )
}
