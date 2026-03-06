import SwiftUI

// MARK: - Flash Intel Card

struct FlashIntelCard: View {
    let signal: TradeSignal
    @Environment(\.colorScheme) var colorScheme

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        HStack(spacing: 14) {
            // Pulsing indicator
            ZStack {
                Circle()
                    .fill(signalColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(signalColor.opacity(0.4))
                    .frame(width: 28, height: 28)

                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(signalColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(signal.signalType.displayName.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signalColor)
                        .cornerRadius(4)

                    Text(signal.asset)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text(String(format: "%.1fx R:R", signal.riskRewardRatio))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                Text("$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    colorScheme == .dark
                        ? Color(hex: "1A1A1A")
                        : Color.white
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(signalColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }
}

// MARK: - Flash Intel Section

struct FlashIntelSection: View {
    let signals: [TradeSignal]
    let isPro: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if !signals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)

                    Text("FLASH INTEL")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1)
                }

                if isPro {
                    ForEach(signals.prefix(2)) { signal in
                        NavigationLink {
                            SignalDetailView(signalId: signal.id)
                        } label: {
                            FlashIntelCard(signal: signal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else {
                    // Teaser for free users
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(signals.count) active swing signal\(signals.count == 1 ? "" : "s")")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text("Upgrade to Pro for Fibonacci swing trade alerts")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                colorScheme == .dark
                                    ? Color(hex: "1A1A1A")
                                    : Color.white
                            )
                    )
                }
            }
        }
    }
}
