import SwiftUI

// MARK: - Google Trends Detail View
struct GoogleTrendsDetailView: View {
    let trends: GoogleTrendsData?
    var searchIndex: Int? = nil
    var history: [GoogleTrendsDTO] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var currentIndex: Int {
        trends?.currentIndex ?? searchIndex ?? 0
    }

    // Filter history to only show days where value changed
    private var changedHistory: [(dto: GoogleTrendsDTO, change: Int)] {
        guard history.count > 1 else {
            return history.map { ($0, 0) }
        }

        var result: [(dto: GoogleTrendsDTO, change: Int)] = []
        let sortedHistory = history.sorted { $0.date > $1.date } // Most recent first

        for (index, item) in sortedHistory.enumerated() {
            if index == 0 {
                // Most recent - always show, calculate change from previous
                let change = sortedHistory.count > 1 ? item.searchIndex - sortedHistory[1].searchIndex : 0
                if change != 0 || result.isEmpty {
                    result.append((item, change))
                }
            } else {
                // Compare with previous day
                let previousIndex = sortedHistory[index - 1].searchIndex
                let change = previousIndex - item.searchIndex // Change that happened after this day
                if change != 0 {
                    result.append((item, change))
                }
            }
        }

        return result
    }

    // Static historical events for reference
    private var historicalEvents: [(date: String, event: String, searchIndex: Int, btcPrice: String)] {
        [
            ("Jan 2025", "New ATH", 88, "$109,000"),
            ("Dec 2024", "BTC Breaks $100K", 95, "$100,000"),
            ("Nov 2024", "Trump Election Rally", 82, "$93,000"),
            ("Apr 2024", "Bitcoin Halving", 68, "$64,000"),
            ("Mar 2024", "Pre-Halving ATH", 75, "$73,000"),
            ("Jan 2024", "Spot ETF Approved", 85, "$46,000"),
            ("Nov 2021", "Previous Cycle ATH", 100, "$69,000"),
            ("May 2021", "China Mining Ban", 85, "$37,000"),
            ("Apr 2021", "Coinbase IPO", 78, "$64,000"),
            ("Jan 2021", "Tesla Buys BTC", 72, "$40,000"),
            ("Dec 2017", "2017 Bull Run Peak", 100, "$20,000")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Index
                    VStack(spacing: 12) {
                        Text("\(currentIndex)")
                            .font(.system(size: 64, weight: .bold, design: .default))
                            .foregroundColor(textPrimary)
                            .monospacedDigit()

                        Text("of 100")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        if let change = trends?.changeFromLastWeek {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(change >= 0 ? "+" : "")\(change) from last week")
                                    .font(.subheadline)
                            }
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                    .padding(.top, 20)

                    // What is Search Interest
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is Search Interest?")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("Search Interest measures relative public attention for Bitcoin on a scale of 0-100. A value of 100 represents peak interest in the 90-day window, while 50 means moderate interest. It's a useful gauge of retail attention and potential market tops/bottoms.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Data: Wikipedia Pageviews")
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Recent Changes (from database)
                    if !changedHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Changes")
                                    .font(.headline)
                                    .foregroundColor(textPrimary)

                                Spacer()

                                Text("\(history.count) days tracked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if changedHistory.isEmpty || changedHistory.allSatisfy({ $0.change == 0 }) {
                                HStack {
                                    Image(systemName: "equal.circle.fill")
                                        .foregroundColor(AppColors.warning)
                                    Text("No changes recorded yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ForEach(changedHistory.prefix(10), id: \.dto.id) { item in
                                    GoogleTrendsHistoryRow(
                                        date: item.dto.shortDateDisplay,
                                        searchIndex: item.dto.searchIndex,
                                        change: item.change,
                                        btcPrice: item.dto.btcPriceDisplay
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }

                    // Historical Events
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Historical Events")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        ForEach(historicalEvents, id: \.date) { event in
                            SearchEventRow(
                                date: event.date,
                                event: event.event,
                                searchIndex: event.searchIndex,
                                btcPrice: event.btcPrice,
                                isHighlight: event.searchIndex >= 80
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Interpretation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Interpret")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        SearchLevelRow(range: "80-100", label: "Extreme Interest", description: "Often signals market tops, FOMO peak", color: AppColors.error)
                        SearchLevelRow(range: "50-80", label: "High Interest", description: "Strong retail participation", color: AppColors.warning)
                        SearchLevelRow(range: "20-50", label: "Moderate Interest", description: "Healthy market, accumulation phase", color: AppColors.success)
                        SearchLevelRow(range: "0-20", label: "Low Interest", description: "Potential bottom, smart money accumulates", color: AppColors.accent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Trading Insight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trading Insight")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("""
- Peak search interest often coincides with local/global tops
- Low search interest during bear markets can signal accumulation zones
- Sudden spikes may indicate news-driven volatility
- Divergence between price and search interest can signal trend changes
""")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Bitcoin Search Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Google Trends History Row
struct GoogleTrendsHistoryRow: View {
    let date: String
    let searchIndex: Int
    let change: Int
    let btcPrice: String

    var changeColor: Color {
        if change > 0 { return AppColors.success }
        if change < 0 { return AppColors.error }
        return .secondary
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if btcPrice != "--" {
                    Text(btcPrice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Change indicator
                if change != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(change > 0 ? "+" : "")\(change)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(changeColor)
                }

                // Current value
                Text("\(searchIndex)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(searchIndex >= 80 ? AppColors.error : .primary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Search Event Row
struct SearchEventRow: View {
    let date: String
    let event: String
    let searchIndex: Int
    let btcPrice: String
    let isHighlight: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(searchIndex)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isHighlight ? AppColors.error : .primary)
                    .monospacedDigit()
                Text(btcPrice)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Search Level Row
struct SearchLevelRow: View {
    let range: String
    let label: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(range)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    Text("-")
                        .foregroundColor(.secondary)
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
