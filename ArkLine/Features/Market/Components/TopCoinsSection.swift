import SwiftUI
import Kingfisher

// MARK: - Top Coins Section
struct TopCoinsSection: View {
    @Bindable var viewModel: MarketViewModel
    @State private var visibleCount: Int = 5
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    /// When searching, show all results; otherwise respect visibleCount
    private var displayedCoins: [CryptoAsset] {
        if !viewModel.topCoinsSearchQuery.isEmpty {
            return viewModel.topCoins
        }
        return Array(viewModel.topCoins.prefix(visibleCount))
    }

    private var canShowMore: Bool {
        viewModel.topCoinsSearchQuery.isEmpty && visibleCount < viewModel.topCoins.count
    }

    private var canShowLess: Bool {
        viewModel.topCoinsSearchQuery.isEmpty && visibleCount > 5
    }

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

                if !viewModel.topCoins.isEmpty && viewModel.topCoinsSearchQuery.isEmpty {
                    Text("\(min(visibleCount, viewModel.topCoins.count)) of \(viewModel.topCoins.count)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
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
                    ForEach(displayedCoins) { asset in
                        NavigationLink(destination: AssetDetailView(asset: asset)) {
                            CryptoAssetRow(asset: asset)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
                        .contextMenu {
                            Button {
                                Haptics.medium()
                                let isCurrentlyFavorite = FavoritesStore.shared.isFavorite(asset.id)
                                FavoritesStore.shared.setFavorite(asset.id, isFavorite: !isCurrentlyFavorite)
                            } label: {
                                Label(
                                    FavoritesStore.shared.isFavorite(asset.id) ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: FavoritesStore.shared.isFavorite(asset.id) ? "star.fill" : "star"
                                )
                            }
                        } preview: {
                            CryptoAssetRow(asset: asset)
                        }

                        if asset.id != displayedCoins.last?.id {
                            Divider()
                                .background(Color(hex: "2A2A2A"))
                                .padding(.horizontal, 20)
                        }
                    }

                    // Show More / Show Less controls
                    if canShowMore || canShowLess {
                        Divider()
                            .background(Color(hex: "2A2A2A"))
                            .padding(.horizontal, 20)

                        HStack(spacing: 16) {
                            if canShowMore {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        visibleCount = min(visibleCount + 10, viewModel.topCoins.count)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 13))
                                        Text("Show More")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(AppColors.accent)
                                }
                            }

                            if canShowMore && canShowLess {
                                Circle()
                                    .fill(AppColors.textSecondary.opacity(0.3))
                                    .frame(width: 3, height: 3)
                            }

                            if canShowLess {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        visibleCount = 5
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 13))
                                        Text("Show Less")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 12)
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
