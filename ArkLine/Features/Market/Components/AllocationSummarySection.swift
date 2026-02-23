import SwiftUI

// MARK: - Allocation Summary Section

/// Compact summary card for MarketOverviewView showing macro regime and signal distribution.
/// Taps through to AllocationDetailView via NavigationLink.
struct AllocationSummarySection: View {
    let allocationSummary: AllocationSummary?
    let isLoading: Bool
    let hasExtremeMove: Bool
    let sentimentViewModel: SentimentViewModel

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(AppColors.accent)
                Text("Crypto Positioning")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                // Extreme macro move indicator
                if hasExtremeMove {
                    PulsingExtremeIndicator(isActive: true, color: AppColors.error)
                }

                Spacer()
            }
            .padding(.horizontal)

            // Content
            if isLoading && allocationSummary == nil {
                loadingView
            } else if let summary = allocationSummary {
                NavigationLink {
                    AllocationDetailView(
                        summary: summary,
                        sentimentViewModel: sentimentViewModel
                    )
                } label: {
                    summaryCard(summary: summary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Summary Card

    private func summaryCard(summary: AllocationSummary) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                // Regime badge (text only, no icon)
                regimeBadge(regime: summary.regime)

                // Signal summary line
                signalSummary(allocations: summary.allocations)

                // Stacked signal bar
                signalBar(allocations: summary.allocations)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Regime Badge

    private func regimeBadge(regime: MacroRegimeResult) -> some View {
        Text("Macro: \(regime.quadrant.shortLabel)")
            .font(AppFonts.caption12Medium)
            .foregroundColor(regime.quadrant.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(regime.quadrant.color.opacity(0.12))
            .cornerRadius(8)
    }

    // MARK: - Signal Summary

    private func signalSummary(allocations: [AssetAllocation]) -> some View {
        let bullishCount = allocations.filter { $0.signal == .bullish }.count
        let total = allocations.count

        let text: String
        if bullishCount == 0 {
            text = "No assets showing bullish signals"
        } else if bullishCount == total {
            text = "All \(total) assets bullish"
        } else {
            text = "\(bullishCount) of \(total) assets showing bullish signals"
        }

        return Text(text)
            .font(AppFonts.body14Medium)
            .foregroundColor(textPrimary)
    }

    // MARK: - Signal Bar

    private func signalBar(allocations: [AssetAllocation]) -> some View {
        let total = max(allocations.count, 1)
        let bullish = Double(allocations.filter { $0.signal == .bullish }.count) / Double(total)
        let neutral = Double(allocations.filter { $0.signal == .neutral }.count) / Double(total)
        let bearish = Double(allocations.filter { $0.signal == .bearish }.count) / Double(total)

        return GeometryReader { geo in
            HStack(spacing: 2) {
                if bullish > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.success)
                        .frame(width: max(4, geo.size.width * bullish - 1))
                }
                if neutral > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.warning)
                        .frame(width: max(4, geo.size.width * neutral - 1))
                }
                if bearish > 0 {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppColors.error)
                        .frame(width: max(4, geo.size.width * bearish - 1))
                }
            }
        }
        .frame(height: 6)
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(AppColors.accent)
            Text("Analyzing positions...")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }
}
