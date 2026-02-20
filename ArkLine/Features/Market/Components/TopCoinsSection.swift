import SwiftUI
import Kingfisher

// MARK: - Top Coins Section
struct TopCoinsSection: View {
    @Bindable var viewModel: MarketViewModel
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text("Top Coins")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)

                TextField("Search coins...", text: Binding(
                    get: { viewModel.topCoinsSearchQuery },
                    set: { viewModel.updateTopCoinsSearch($0) }
                ))
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                if !viewModel.topCoinsSearchQuery.isEmpty {
                    Button {
                        viewModel.updateTopCoinsSearch("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
            )
            .padding(.horizontal, 20)

            // Coin List
            if viewModel.isSearchingTopCoins {
                // Loading state
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        TopCoinShimmerRow()
                        Divider()
                            .background(Color(hex: "2A2A2A"))
                            .padding(.horizontal, 20)
                    }
                }
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            } else if viewModel.topCoins.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(viewModel.topCoinsSearchQuery.isEmpty ? "No coins available" : "No results for \"\(viewModel.topCoinsSearchQuery)\"")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.topCoins) { asset in
                        NavigationLink(destination: AssetDetailView(asset: asset)) {
                            CryptoAssetRow(asset: asset)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if asset.id != viewModel.topCoins.last?.id {
                            Divider()
                                .background(Color(hex: "2A2A2A"))
                                .padding(.horizontal, 20)
                        }
                    }
                }
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Shimmer Row
private struct TopCoinShimmerRow: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(shimmerColor)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerColor)
                    .frame(width: 50, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerColor)
                    .frame(width: 80, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerColor)
                    .frame(width: 70, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerColor)
                    .frame(width: 50, height: 12)
            }
        }
        .padding(16)
        .opacity(isAnimating ? 0.4 : 0.8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var shimmerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
}
