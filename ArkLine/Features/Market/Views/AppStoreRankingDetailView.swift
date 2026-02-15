import SwiftUI

// MARK: - App Store Ranking Detail View
struct AppStoreRankingDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SentimentViewModel
    @State private var showingInfo = false
    @State private var rankingHistory: [AppStoreRankingDTO] = []
    @State private var isLoading = true

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Get current Coinbase ranking
    private var currentRanking: AppStoreRanking? {
        viewModel.appStoreRankings.first { $0.appName == "Coinbase" }
    }

    // Check if actually ranked (ranking > 0)
    private var isRanked: Bool {
        guard let ranking = currentRanking else { return false }
        return ranking.ranking > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Ranking Header
                currentRankingHeader

                // Daily Rankings List (collapsible)
                DailyRankingsCard(
                    rankingHistory: rankingHistory,
                    isLoading: isLoading
                )

                // Historical Milestones (collapsible)
                HistoricalMilestonesCard()

                // Interpretation Guide
                InterpretationGuideCard()

                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .background {
            ZStack {
                MeshGradientBackground()
                if isDarkMode { BrushEffectOverlay() }
            }
            .ignoresSafeArea()
        }
        .navigationTitle("Coinbase Ranking")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        #endif
        .sheet(isPresented: $showingInfo) {
            DataSourceInfoSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            await loadRankingHistory()
        }
    }

    // MARK: - Load Ranking History
    private func loadRankingHistory() async {
        isLoading = true
        do {
            let sentimentService = APISentimentService()
            rankingHistory = try await sentimentService.fetchAppStoreRankingHistory(limit: 30)
            logInfo("Loaded \(rankingHistory.count) historical rankings", category: .data)
        } catch {
            logError("Failed to load ranking history: \(error.localizedDescription)", category: .data)
        }
        isLoading = false
    }

    // MARK: - Current Ranking Header
    private var currentRankingHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Coinbase icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "0052FF"))
                        .frame(width: 56, height: 56)

                    Text("C")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Coinbase")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(textPrimary)

                    Text("iOS • US App Store")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Current rank
                if isRanked, let ranking = currentRanking {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("#")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(ranking.ranking)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(textPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }

                        if ranking.change != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 12, weight: .bold))
                                Text("\(abs(ranking.change))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(ranking.isImproving ? AppColors.success : AppColors.error)
                        }
                    }
                } else {
                    // Not in top 200
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(">200")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text("Outside Top 200")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }

}

// MARK: - Daily Rankings Card (Collapsible)
struct DailyRankingsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let rankingHistory: [AppStoreRankingDTO]
    let isLoading: Bool
    @State private var isExpanded = true

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header button
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(AppColors.accent)

                    Text("Daily Rankings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textPrimary)

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if !rankingHistory.isEmpty {
                        Text("\(rankingHistory.count) days")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isExpanded {
                if isLoading {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading history...")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                } else if rankingHistory.isEmpty {
                    // No data yet
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))

                        Text("No historical data yet")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Text("Rankings will be saved daily starting today")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                } else {
                    // Daily rankings list
                    VStack(spacing: 0) {
                        // Header row
                        HStack {
                            Text("Date")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Ranking")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(minWidth: 50, alignment: .trailing)

                            Text("BTC Price")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(minWidth: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                        .background(
                            colorScheme == .dark
                                ? Color.white.opacity(0.05)
                                : Color.black.opacity(0.03)
                        )

                        ForEach(rankingHistory, id: \.id) { ranking in
                            DailyRankingRow(ranking: ranking)

                            if ranking.id != rankingHistory.last?.id {
                                Divider()
                                    .background(AppColors.textSecondary.opacity(0.2))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.textSecondary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Historical Milestones Card (Collapsible)
struct HistoricalMilestonesCard: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Historical data from key crypto events
    private let milestones: [HistoricalMilestone] = [
        // 2021
        HistoricalMilestone(
            date: "Nov 10, 2021",
            event: "BTC All-Time High",
            ranking: 1,
            btcPrice: 69000,
            note: "Peak retail FOMO"
        ),
        // 2022
        HistoricalMilestone(
            date: "May 10, 2022",
            event: "LUNA Collapse",
            ranking: 4,
            btcPrice: 31000,
            note: "Panic selling spike"
        ),
        HistoricalMilestone(
            date: "Nov 11, 2022",
            event: "FTX Collapse",
            ranking: 2,
            btcPrice: 17000,
            note: "Bank run on exchanges"
        ),
        HistoricalMilestone(
            date: "Dec 31, 2022",
            event: "Bear Market Bottom",
            ranking: nil,
            btcPrice: 16500,
            note: "Retail capitulation"
        ),
        // 2024
        HistoricalMilestone(
            date: "Jan 11, 2024",
            event: "BTC ETF Approved",
            ranking: 1,
            btcPrice: 46000,
            note: "Historic moment"
        ),
        HistoricalMilestone(
            date: "Mar 14, 2024",
            event: "BTC New ATH",
            ranking: 1,
            btcPrice: 73000,
            note: "Broke 2021 high"
        ),
        HistoricalMilestone(
            date: "Nov 5, 2024",
            event: "Trump Election",
            ranking: 1,
            btcPrice: 75000,
            note: "Pro-crypto president"
        ),
        HistoricalMilestone(
            date: "Dec 5, 2024",
            event: "BTC $100K",
            ranking: 1,
            btcPrice: 100000,
            note: "Psychological milestone"
        ),
        // 2025
        HistoricalMilestone(
            date: "Feb 21, 2025",
            event: "Bybit $1.5B Hack",
            ranking: 3,
            btcPrice: 96000,
            note: "Largest crypto hack ever"
        ),
        HistoricalMilestone(
            date: "Mar 6, 2025",
            event: "US Bitcoin Reserve",
            ranking: 1,
            btcPrice: 92000,
            note: "Trump executive order"
        ),
        HistoricalMilestone(
            date: "Jul 18, 2025",
            event: "GENIUS Act Signed",
            ranking: 2,
            btcPrice: 108000,
            note: "Major stablecoin regulation"
        ),
        HistoricalMilestone(
            date: "Oct 6, 2025",
            event: "BTC ATH $126K",
            ranking: 1,
            btcPrice: 126038,
            note: "New all-time high"
        ),
        HistoricalMilestone(
            date: "Oct 2025",
            event: "SOL & XRP ETFs",
            ranking: 1,
            btcPrice: 118000,
            note: "First altcoin spot ETFs"
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header button
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(AppColors.accent)

                    Text("Historical Milestones")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textPrimary)

                    Spacer()

                    Text("\(milestones.count) events")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    // Header row
                    HStack {
                        Text("Event")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Rank")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(minWidth: 40, alignment: .trailing)

                        Text("BTC")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(minWidth: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                    .background(
                        colorScheme == .dark
                            ? Color.white.opacity(0.05)
                            : Color.black.opacity(0.03)
                    )

                    ForEach(milestones) { milestone in
                        MilestoneRow(milestone: milestone)

                        if milestone.id != milestones.last?.id {
                            Divider()
                                .background(AppColors.textSecondary.opacity(0.2))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.textSecondary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Historical Milestone Model
struct HistoricalMilestone: Identifiable {
    let id = UUID()
    let date: String
    let event: String
    let ranking: Int? // nil means >200
    let btcPrice: Int
    let note: String

    var rankDisplay: String {
        if let rank = ranking {
            return "#\(rank)"
        }
        return ">200"
    }

    var btcPriceDisplay: String {
        "$\(btcPrice.formatted())"
    }
}

// MARK: - Milestone Row
struct MilestoneRow: View {
    @Environment(\.colorScheme) var colorScheme
    let milestone: HistoricalMilestone

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.event)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary)

                Text(milestone.date)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Ranking
            Text(milestone.rankDisplay)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(milestone.ranking != nil ? AppColors.success : AppColors.textSecondary)
                .frame(minWidth: 40, alignment: .trailing)
                .lineLimit(1)

            // BTC Price
            Text(milestone.btcPriceDisplay)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .frame(minWidth: 60, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Daily Ranking Row
struct DailyRankingRow: View {
    @Environment(\.colorScheme) var colorScheme
    let ranking: AppStoreRankingDTO

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            // Date
            Text(ranking.dateDisplay)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Ranking
            Text(ranking.rankDisplay)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(ranking.isRanked ? textPrimary : AppColors.textSecondary)
                .frame(minWidth: 50, alignment: .trailing)
                .lineLimit(1)

            // BTC Price
            Text(ranking.btcPriceDisplay)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .frame(minWidth: 70, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Interpretation Guide Card
struct InterpretationGuideCard: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .foregroundColor(AppColors.accent)

                    Text("Interpretation Guide")
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
                VStack(alignment: .leading, spacing: 10) {
                    GuideItem(
                        title: "Top 10 = Peak Retail Interest",
                        description: "Strong FOMO, often near local tops",
                        color: AppColors.success
                    )

                    GuideItem(
                        title: "Top 50 = High Interest",
                        description: "Significant retail engagement in the market",
                        color: AppColors.accent
                    )

                    GuideItem(
                        title: "Top 100-200 = Moderate Interest",
                        description: "Some retail activity, market recovering or cooling",
                        color: AppColors.warning
                    )

                    GuideItem(
                        title: ">200 = Low Interest",
                        description: "Retail has largely exited, potential accumulation zone",
                        color: AppColors.textSecondary
                    )
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
        .padding(.horizontal, 20)
    }
}

// MARK: - Guide Item
struct GuideItem: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let description: String
    let color: Color

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(textPrimary)

                Text(description)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Data Source Info Sheet
struct DataSourceInfoSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // How it's calculated
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How It Works", systemImage: "function")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("We check Apple's Top 200 Free Apps chart for the US App Store to see if Coinbase is ranked.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoBullet(text: "If in Top 200, we show the exact position")
                            InfoBullet(text: "If outside Top 200, we show \">200\"")
                            InfoBullet(text: "Data is saved daily along with BTC price")
                        }
                    }

                    Divider()

                    // Historical data note
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Historical Data", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("Each day's ranking is automatically saved to build up historical data over time. The longer you use the app, the more history you'll have.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // Why it matters
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Why Track This?", systemImage: "lightbulb")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("Coinbase's App Store ranking is a proxy for retail crypto interest. Historically, Coinbase hitting #1 overall has coincided with market tops, while being outside the Top 200 often signals retail capitulation.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                }
                .padding(20)
            }
            .navigationTitle("About This Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Info Bullet
struct InfoBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
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
