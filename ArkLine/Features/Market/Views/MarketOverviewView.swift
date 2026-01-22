import SwiftUI

struct MarketOverviewView: View {
    @State private var viewModel = MarketViewModel()
    @State private var sentimentViewModel = SentimentViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                MeshGradientBackground()

                // Brush effect overlay for dark mode
                if isDarkMode {
                    BrushEffectOverlay()
                }

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Daily News Section
                        DailyNewsSection(
                            news: viewModel.newsItems,
                            onSeeAll: { /* Navigate to full news list */ }
                        )

                        // 2. Fed Watch Section
                        FedWatchSection(meetings: viewModel.fedWatchMeetings)

                        // 3. Derivatives Data Section (Coinglass)
                        DerivativesDataSection(
                            overview: viewModel.derivativesOverview,
                            isLoading: viewModel.isDerivativesLoading
                        )

                        // 4. Market Sentiment Section
                        MarketSentimentSection(
                            viewModel: sentimentViewModel,
                            lastUpdated: Date()
                        )

                        // 5. Market Assets Section
                        MarketAssetsSection(viewModel: viewModel)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.refresh()
                    await sentimentViewModel.refresh()
                }
            }
            .navigationTitle("Market Overview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Notifications */ }) {
                        Image(systemName: "bell")
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }
            }
            #endif
        }
    }
}

// MARK: - Supporting Views (kept for compatibility)
struct MarketStatsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let marketCap: Double
    let volume: Double
    let btcDominance: Double
    let change: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                StatColumn(label: "Market Cap", value: marketCap.asCurrencyCompact, change: change)
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                StatColumn(label: "24h Volume", value: volume.asCurrencyCompact, change: nil)
                Divider().frame(height: 40).background(Color.white.opacity(0.1))
                StatColumn(label: "BTC Dom.", value: String(format: "%.1f%%", btcDominance), change: nil)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

struct StatColumn: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let value: String
    let change: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let change = change {
                Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.2f")%")
                    .font(.caption2)
                    .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactFearGreedCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: FearGreedIndex

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fear & Greed Index")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    Text("\(index.value)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // Simplified: neutral badge, no color
                    Text(index.level.rawValue)
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.05)
                        )
                        .cornerRadius(8)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

struct SectionHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            if let action = action {
                Button(action: action) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

struct TrendingAssetCard: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: CryptoAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(asset.symbol.uppercased())
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                    .font(.caption)
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            Text(asset.currentPrice.asCurrency)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .frame(width: 140)
        .glassCard(cornerRadius: 12)
    }
}

struct CategoryChip: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .if(isSelected) { view in
                    view.background(AppColors.accent)
                        .cornerRadius(20)
                }
                .if(!isSelected) { view in
                    view.glassCard(cornerRadius: 20)
                }
        }
    }
}

// MARK: - Placeholder Detail Views
struct BTCDominanceDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("BTC Dominance Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct ETFNetFlowDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("ETF Net Flow Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct FundingRateDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("Funding Rate Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct LiquidationDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("Liquidation Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

struct AltcoinSeasonDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            Text("Altcoin Season Detail")
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

#Preview {
    MarketOverviewView()
        .environmentObject(AppState())
}
