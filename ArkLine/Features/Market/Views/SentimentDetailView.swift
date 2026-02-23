import SwiftUI

// MARK: - Sentiment Detail View

/// Full-page detail view wrapping the existing MarketSentimentSection.
/// Pushed via NavigationLink from SentimentSummarySection.
struct SentimentDetailView: View {
    @Bindable var viewModel: SentimentViewModel
    var isPro: Bool = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MarketSentimentSection(
                    viewModel: viewModel,
                    lastUpdated: viewModel.lastRefreshed ?? Date(),
                    isPro: isPro
                )

                FinancialDisclaimer()
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Market Sentiment")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
