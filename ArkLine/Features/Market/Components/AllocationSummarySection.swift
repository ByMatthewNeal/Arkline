import SwiftUI

// MARK: - Allocation Summary Section

/// Compact summary card for MarketOverviewView showing macro regime and signal distribution.
/// Taps through to AllocationDetailView via NavigationLink.
struct AllocationSummarySection: View {
    let allocationSummary: AllocationSummary?
    let isLoading: Bool

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .foregroundColor(AppColors.accent)
                Text("Positioning Signals")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            // Content
            if isLoading && allocationSummary == nil {
                loadingView
            } else if let summary = allocationSummary {
                NavigationLink(value: summary) {
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
                // Regime badge
                regimeBadge(regime: summary.regime)

                // Signal distribution
                signalDistribution(allocations: summary.allocations)
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
        HStack(spacing: 6) {
            Image(systemName: regime.quadrant.icon)
                .font(.system(size: 12))
            Text(regime.quadrant.rawValue)
                .font(AppFonts.caption12Medium)
        }
        .foregroundColor(regime.quadrant.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(regime.quadrant.color.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Signal Distribution

    private func signalDistribution(allocations: [AssetAllocation]) -> some View {
        let bullishCount = allocations.filter { $0.signal == .bullish }.count
        let neutralCount = allocations.filter { $0.signal == .neutral }.count
        let bearishCount = allocations.filter { $0.signal == .bearish }.count

        return HStack(spacing: 12) {
            signalDot(color: AppColors.success, count: bullishCount, label: "Bullish")
            signalDot(color: AppColors.warning, count: neutralCount, label: "Neutral")
            signalDot(color: AppColors.error, count: bearishCount, label: "Bearish")
        }
    }

    private func signalDot(color: Color, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(AppColors.accent)
            Text("Loading signals...")
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
