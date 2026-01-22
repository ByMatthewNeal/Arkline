import SwiftUI

// MARK: - App Store Ranking Detail View
struct AppStoreRankingDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SentimentViewModel

    @State private var selectedPlatform: AppPlatform = .ios
    @State private var selectedRegion: AppRegion = .us

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Primary apps to track
    private let primaryApps = ["Coinbase", "Binance", "Kraken"]

    var body: some View {
        ZStack {
            // Background
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: 24) {
                    // Composite Sentiment Score
                    CompositeScoreSection(sentiment: viewModel.appStoreCompositeSentiment)

                    // Platform/Region Filter
                    FilterSection(
                        selectedPlatform: $selectedPlatform,
                        selectedRegion: $selectedRegion
                    )

                    // Individual App Rankings
                    AppRankingsSection(
                        viewModel: viewModel,
                        selectedPlatform: selectedPlatform,
                        selectedRegion: selectedRegion,
                        primaryApps: primaryApps
                    )

                    // Why This Matters Section
                    WhyItMattersSection()

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("App Store Rankings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Composite Score Section
struct CompositeScoreSection: View {
    @Environment(\.colorScheme) var colorScheme
    let sentiment: AppStoreCompositeSentiment

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var tierColor: Color {
        Color(hex: sentiment.tier.color.replacingOccurrences(of: "#", with: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Retail Interest Score")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                // Tier badge
                HStack(spacing: 6) {
                    Image(systemName: sentiment.tier.icon)
                        .font(.system(size: 12, weight: .bold))
                    Text(sentiment.tier.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(tierColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tierColor.opacity(0.15))
                .cornerRadius(20)
            }

            HStack(alignment: .top, spacing: 24) {
                // Score display
                VStack(alignment: .leading, spacing: 4) {
                    Text(sentiment.scoreFormatted)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(textPrimary)

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Gauge
                CompositeScoreGauge(score: sentiment.score, tier: sentiment.tier)
            }

            // Tier description
            Text(sentiment.tier.description)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tierColor.opacity(0.1))
                )
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Composite Score Gauge
struct CompositeScoreGauge: View {
    let score: Double
    let tier: AppStoreSentimentTier

    private var progress: Double {
        score / 100.0
    }

    private var tierColor: Color {
        Color(hex: tier.color.replacingOccurrences(of: "#", with: ""))
    }

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(hex: "2A2A2A"), lineWidth: 10)
                .frame(width: 80, height: 80)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tierColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            // Center icon
            Image(systemName: tier.icon)
                .font(.system(size: 24))
                .foregroundColor(tierColor)
        }
    }
}

// MARK: - Filter Section
struct FilterSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedPlatform: AppPlatform
    @Binding var selectedRegion: AppRegion

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(textPrimary)

            HStack(spacing: 12) {
                // Platform selector
                HStack(spacing: 8) {
                    ForEach(AppPlatform.allCases, id: \.self) { platform in
                        RankingFilterChip(
                            title: platform.displayName,
                            icon: platform.icon,
                            isSelected: selectedPlatform == platform
                        ) {
                            selectedPlatform = platform
                        }
                    }
                }

                Divider()
                    .frame(height: 24)
                    .background(AppColors.textSecondary.opacity(0.3))

                // Region selector
                HStack(spacing: 8) {
                    ForEach(AppRegion.allCases, id: \.self) { region in
                        RankingFilterChip(
                            title: "\(region.flag) \(region.displayName)",
                            icon: nil,
                            isSelected: selectedRegion == region
                        ) {
                            selectedRegion = region
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Filter Chip
struct RankingFilterChip: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppColors.accent : Color(hex: "2A2A2A"))
            )
        }
    }
}

// MARK: - App Rankings Section
struct AppRankingsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let selectedPlatform: AppPlatform
    let selectedRegion: AppRegion
    let primaryApps: [String]

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var filteredRankings: [AppStoreRanking] {
        viewModel.filteredRankings(
            platform: selectedPlatform,
            region: selectedRegion,
            apps: primaryApps
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exchange Rankings")
                .font(.headline)
                .foregroundColor(textPrimary)
                .padding(.horizontal, 20)

            if filteredRankings.isEmpty {
                // Show message for unavailable data (e.g., Binance in US)
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.warning)

                    Text("No data available for this selection")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    if selectedRegion == .us {
                        Text("Note: Binance is not available in the US App Store")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredRankings) { ranking in
                        AppRankingRow(ranking: ranking)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - App Ranking Row
struct AppRankingRow: View {
    @Environment(\.colorScheme) var colorScheme
    let ranking: AppStoreRanking

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var changeColor: Color {
        ranking.isImproving ? AppColors.success : AppColors.error
    }

    var body: some View {
        HStack(spacing: 16) {
            // App icon placeholder
            AppIconPlaceholder(appName: ranking.appName)

            // App name and details
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.appName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textPrimary)

                Text("\(ranking.platform.displayName) • \(ranking.region.displayName)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Ranking
            VStack(alignment: .trailing, spacing: 2) {
                Text("#\(ranking.ranking)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                HStack(spacing: 4) {
                    Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(abs(ranking.change))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(changeColor)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - App Icon Placeholder
struct AppIconPlaceholder: View {
    let appName: String

    private var backgroundColor: Color {
        switch appName {
        case "Coinbase": return Color(hex: "0052FF")
        case "Binance": return Color(hex: "F0B90B")
        case "Kraken": return Color(hex: "5741D9")
        case "Crypto.com": return Color(hex: "002D74")
        case "Robinhood": return Color(hex: "00C805")
        default: return Color(hex: "666666")
        }
    }

    private var initial: String {
        String(appName.prefix(1))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .frame(width: 44, height: 44)

            Text(initial)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Why It Matters Section
struct WhyItMattersSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(AppColors.warning)

                    Text("Why App Store Rankings Matter")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    InfoPoint(
                        icon: "flame.fill",
                        iconColor: AppColors.error,
                        title: "Retail FOMO Indicator",
                        description: "When exchange apps spike into the top 10-20, it signals retail money rushing into crypto. Historically, this coincides with local tops."
                    )

                    InfoPoint(
                        icon: "arrow.down.circle.fill",
                        iconColor: AppColors.success,
                        title: "Capitulation Signal",
                        description: "When rankings drop significantly, retail has left the market. These periods often present accumulation opportunities."
                    )

                    InfoPoint(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppColors.accent,
                        title: "Leading Indicator",
                        description: "App store rankings often move before price. Rising rankings can signal incoming buying pressure."
                    )

                    // Historical context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Historical Reference")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(textPrimary)

                        Text("During the 2021 bull run, Coinbase reached #1 in the App Store when Bitcoin hit $64K. During the 2022 bear market, it fell to #200+.")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accent.opacity(0.1))
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Info Point
struct InfoPoint: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AppStoreRankingDetailView(viewModel: SentimentViewModel())
            .environmentObject(AppState())
    }
}
