import SwiftUI

// MARK: - Gold Detail View
struct GoldDetailView: View {
    let goldData: GoldData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var levelColor: Color {
        guard let gold = goldData?.value else { return .gray }
        if gold > 3000 { return AppColors.success }    // Bullish (strong safe haven)
        if gold > 2000 { return AppColors.warning }    // Neutral
        return AppColors.error                         // Bearish
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(goldData.map { String(format: "$%.0f", $0.value) } ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        if let change = goldData?.changePercent {
                            HStack(spacing: 8) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%+.2f%%", change))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(levelColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(levelColor.opacity(0.15))
                            .cornerRadius(12)
                        }

                        Text(goldData?.signalDescription ?? "Loading...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(levelColor)
                    }
                    .padding(.top, 20)

                    MacroInfoSection(title: "What is Gold?", content: """
Gold (XAU/USD) is the world's oldest safe-haven asset and inflation hedge. Central banks hold gold as a reserve asset, and investors flock to it during periods of economic uncertainty, geopolitical tension, or currency debasement. Gold prices are quoted in US dollars per troy ounce.
""")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Level Interpretation")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        GoldLevelRow(range: "Below $1,800", description: "Very low - Strong risk-on sentiment", color: .green)
                        GoldLevelRow(range: "$1,800-2,000", description: "Low - Risk appetite is healthy", color: .green)
                        GoldLevelRow(range: "$2,000-2,200", description: "Normal range", color: .blue)
                        GoldLevelRow(range: "$2,200-2,400", description: "Elevated - Growing uncertainty", color: .orange)
                        GoldLevelRow(range: "$2,400-2,600", description: "High - Strong safe-haven demand", color: .red)
                        GoldLevelRow(range: "Above $2,600", description: "Very high - Extreme fear or debasement", color: .purple)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    MacroInfoSection(title: "Impact on Crypto", content: """
\u{2022} Short-term: Gold and crypto often move inversely. When gold surges on safe-haven demand, risk assets like crypto tend to sell off.
\u{2022} Long-term: Both gold and Bitcoin are "hard money" assets that benefit from monetary debasement and inflation. They can rally together during periods of aggressive money printing.
\u{2022} Central bank buying of gold signals distrust in the dollar system — a narrative that also supports Bitcoin's store-of-value thesis.
\u{2022} Watch for divergences: if gold rises while crypto falls, it suggests risk-off positioning. If both rise together, it suggests inflation/debasement fears.
""")

                    MacroInfoSection(title: "Historical Context", content: """
\u{2022} 2020 COVID: Gold hit $2,075 as central banks printed trillions
\u{2022} 2022 Rate Hikes: Fell to $1,615 as real yields surged
\u{2022} 2023-24 Rally: Central bank buying (China, India) drove gold above $2,400
\u{2022} 2024-25: Record highs above $2,800 on geopolitical tensions and de-dollarization
\u{2022} Gold has averaged ~8% annual returns since 2000
""")
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Gold - XAU/USD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GoldLevelRow: View {
    let range: String
    let description: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
