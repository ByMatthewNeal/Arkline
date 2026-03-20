import SwiftUI

// MARK: - Swing Setups Summary Section

struct SwingSetupsSummarySection: View {
    @State private var viewModel = SwingSetupsViewModel()
    var isPro: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "scope")
                    .foregroundColor(AppColors.accent)
                Text("Trade Signals")
                    .font(.headline)
                    .foregroundColor(textPrimary)

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
                    SwingSetupsDetailView()
                } label: {
                    contentCard
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                lockedCard
            }
        }
        .task {
            if isPro {
                await viewModel.loadActiveSignals()
            }
        }
    }

    // MARK: - Content Card (for premium users)

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading setups...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if viewModel.activeSignals.isEmpty {
                emptyState
            } else {
                // Show up to 2 active signals
                ForEach(viewModel.activeSignals.prefix(2)) { signal in
                    SignalSummaryRow(signal: signal, colorScheme: colorScheme)
                }

                if viewModel.activeSignals.count > 2 {
                    Text("+\(viewModel.activeSignals.count - 2) more")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.accent)
                }
            }

            // Chevron
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No active setups")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary)

            Text("Signals fire when price approaches high-confluence Fibonacci zones with supporting risk conditions.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Locked Card (for free users)

    private var lockedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.title2)
                .foregroundColor(AppColors.accent.opacity(0.5))

            Text("Unlock multi-timeframe Fibonacci trade signals with Arkline Premium.")
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

// MARK: - Signal Summary Row

struct SignalSummaryRow: View {
    let signal: TradeSignal
    let colorScheme: ColorScheme

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    var body: some View {
        HStack(spacing: 12) {
            // Asset + type badge
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(signal.asset)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(signal.signalType.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signalColor)
                        .cornerRadius(4)

                    Text(signal.timeframeBadge.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(signal.isScalp ? AppColors.accent : AppColors.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background((signal.isScalp ? AppColors.accent : AppColors.textSecondary).opacity(0.15))
                        .cornerRadius(3)
                }

                Text("$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // R:R and status
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(signal.riskRewardRatio, specifier: "%.1f")x R:R")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(signal.phaseDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(signal.isRunnerPhase ? AppColors.accent : statusColor)
            }
        }
    }

    private var statusColor: Color {
        switch signal.status {
        case .active: return AppColors.warning
        case .triggered: return AppColors.accent
        case .targetHit: return AppColors.success
        case .invalidated: return AppColors.error
        case .expired: return AppColors.textSecondary
        }
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }
}
