import SwiftUI

// MARK: - Derivatives Positioning Section
/// Perpetual premium and funding rate, relocated out of Market Sentiment so the
/// derivatives signals (this, the liquidation heatmap, and spot vs derivatives)
/// sit together in the Assets zone. Reuses the same cards and the same
/// SentimentViewModel data — this is a move, not a new data source.
struct DerivativesPositioningSection: View {
    @Bindable var viewModel: SentimentViewModel
    var embedded: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Derivatives")
                .font(.headline)
                .foregroundColor(textPrimary)

            if viewModel.btcPerpPremium != nil || viewModel.ethPerpPremium != nil {
                PerpPremiumSentimentCard(
                    btcPremium: viewModel.btcPerpPremium,
                    ethPremium: viewModel.ethPerpPremium
                )
            }

            if let funding = viewModel.fundingRate {
                FundingRateCard(fundingRate: funding)
            } else {
                ShimmerPlaceholderCard(title: "Funding Rate", icon: "percent", isLoading: viewModel.isLoading) {
                    await viewModel.retryFundingRate()
                }
            }
        }
        .padding(.horizontal, embedded ? 0 : 16)
    }
}
