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
        VStack(spacing: 14) {
            if signals.isEmpty {
                emptyState
            } else {
                // Signal counts
                HStack(spacing: 0) {
                    signalCount(count: bullishCount, signal: .bullish)
                    Divider().frame(height: 32).opacity(0.15)
                    signalCount(count: neutralCount, signal: .neutral)
                    Divider().frame(height: 32).opacity(0.15)
                    signalCount(count: bearishCount, signal: .bearish)
                }

                // Changes today
                if changedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.warning)
                        Text("\(changedCount) signal \(changedCount == 1 ? "change" : "changes") today")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.warning)
                    }
                }

                // Tap hint
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

    // MARK: - Signal Count

    private func signalCount(count: Int, signal: PositioningSignal) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(signal.color)
            Text(signal.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
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
            Text("Unlock daily positioning signals across 54 assets with Arkline Premium.")
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
