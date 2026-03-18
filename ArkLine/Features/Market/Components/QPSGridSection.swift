import SwiftUI

// MARK: - QPS Summary Card (Market Tab Widget)

struct QPSGridSection: View {
    let signals: [DailyPositioningSignal]
    let isPro: Bool
    @Environment(\.colorScheme) var colorScheme

    private var bullishCount: Int { signals.filter { $0.positioningSignal == .bullish }.count }
    private var neutralCount: Int { signals.filter { $0.positioningSignal == .neutral }.count }
    private var bearishCount: Int { signals.filter { $0.positioningSignal == .bearish }.count }
    private var changedCount: Int { signals.filter { $0.hasChanged }.count }

    private var groupedSignals: [(QPSAssetCategory, [DailyPositioningSignal])] {
        let grouped = Dictionary(grouping: signals) { $0.assetCategory }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(AppColors.accent)
                Text("Daily Positioning")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if !isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(AppColors.accent.opacity(0.15))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.horizontal)

            if isPro {
                NavigationLink {
                    QPSFullGridView(signals: signals)
                } label: {
                    summaryCard
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                lockedCard
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if signals.isEmpty {
                emptyState
            } else {
                // Signal distribution bar
                signalDistribution

                // Category breakdown
                categoryBreakdown

                // Changes today
                if changedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.warning)
                        Text("\(changedCount) signal \(changedCount == 1 ? "change" : "changes") today")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.warning)
                    }
                }

                // Chevron
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View all \(signals.count) assets")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Signal Distribution

    private var signalDistribution: some View {
        VStack(spacing: 8) {
            // Bar
            GeometryReader { geo in
                let total = max(signals.count, 1)
                HStack(spacing: 2) {
                    if bullishCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PositioningSignal.bullish.color)
                            .frame(width: CGFloat(bullishCount) / CGFloat(total) * geo.size.width - 2)
                    }
                    if neutralCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PositioningSignal.neutral.color)
                            .frame(width: CGFloat(neutralCount) / CGFloat(total) * geo.size.width - 2)
                    }
                    if bearishCount > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PositioningSignal.bearish.color)
                            .frame(width: CGFloat(bearishCount) / CGFloat(total) * geo.size.width - 2)
                    }
                }
            }
            .frame(height: 8)

            // Labels
            HStack {
                signalLabel("Bullish", count: bullishCount, signal: .bullish)
                Spacer()
                signalLabel("Neutral", count: neutralCount, signal: .neutral)
                Spacer()
                signalLabel("Bearish", count: bearishCount, signal: .bearish)
            }
        }
    }

    private func signalLabel(_ text: String, count: Int, signal: PositioningSignal) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(signal.color)
                .frame(width: 6, height: 6)
            Text("\(count) \(text)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(spacing: 0) {
            ForEach(Array(groupedSignals.enumerated()), id: \.element.0) { index, pair in
                let (category, catSignals) = pair
                HStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 16)

                    Text(category.displayName)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    // Mini signal badges
                    HStack(spacing: 3) {
                        ForEach(catSignals.prefix(6), id: \.id) { signal in
                            Text(signal.positioningSignal.label.prefix(1))
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(signal.positioningSignal.color)
                                .cornerRadius(3)
                        }
                        if catSignals.count > 6 {
                            Text("+\(catSignals.count - 6)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 6)

                if index < groupedSignals.count - 1 {
                    Divider().opacity(0.1)
                }
            }
        }
    }

    // MARK: - Empty & Locked States

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No positioning signals yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Signals are computed daily at midnight UTC.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var lockedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.swap")
                .font(.title2)
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text("Unlock daily positioning signals across 36 assets with Arkline Premium.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .opacity(0.6)
        .padding(.horizontal)
    }
}
