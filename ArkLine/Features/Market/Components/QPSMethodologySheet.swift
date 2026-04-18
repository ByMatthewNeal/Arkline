import SwiftUI

struct QPSMethodologySheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // What are positioning signals
                    section(
                        title: "What Are Positioning Signals?",
                        icon: "waveform.path.ecg"
                    ) {
                        Text("Positioning signals tell you the current trend state of an asset — whether momentum favors holding, reducing, or staying out. They're computed daily using price structure relative to key moving averages.")
                    }

                    // Signal states
                    section(title: "Signal States", icon: "circle.grid.3x3.fill") {
                        VStack(spacing: 12) {
                            signalRow(
                                signal: .bullish,
                                action: "Favorable to hold or add exposure",
                                detail: "Price is above key moving averages with confirmed trend strength."
                            )
                            signalRow(
                                signal: .neutral,
                                action: "Wait for direction or reduce size",
                                detail: "Trend is transitioning — not yet broken, but momentum is fading or rebuilding."
                            )
                            signalRow(
                                signal: .bearish,
                                action: "Reduce exposure or stay flat",
                                detail: "Trend is broken below key levels. Capital preservation is the priority."
                            )
                        }
                    }

                    // How to use
                    section(title: "How to Use Signals", icon: "lightbulb.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            guideStep("1", "Check the signal before adding to a position. Bullish = green light, Neutral = caution, Bearish = wait.")
                            guideStep("2", "When a signal changes, review your exposure. Downgrades (Bullish \u{2192} Neutral) suggest tightening stops or trimming.")
                            guideStep("3", "Use signals alongside risk levels and trade setups — they're one input, not the whole picture.")
                            guideStep("4", "Signals update daily at midnight UTC. Intraday price moves won't change the signal until the next day.")
                        }
                    }

                    // What drives the score
                    section(title: "What Drives the Score", icon: "chart.bar.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            factorRow("200-Day Moving Average", "Strongest weight. Above = long-term uptrend intact.", weight: "High")
                            factorRow("50-Day Moving Average", "Intermediate trend. Confirms or weakens the 200-day signal.", weight: "Medium")
                            factorRow("21-Day Moving Average", "Short-term momentum. First to break in a pullback.", weight: "Medium")
                            factorRow("SMA Crossovers", "21-day crossing above/below 50-day confirms trend direction.", weight: "Low")
                            factorRow("RSI (14)", "Oversold conditions add a small contrarian boost.", weight: "Low")
                            factorRow("Bull Market Support Band", "Weekly SMA/EMA band used for cycle-level confirmation.", weight: "Low")
                        }
                    }

                    // Important notes
                    section(title: "Important", icon: "exclamationmark.triangle.fill") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Signals are not trade recommendations. They describe trend conditions to help inform your own decisions.")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)

                            Text("No signal system is perfect. False positives and delayed signals are inevitable — always pair with your own risk management.")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Positioning Signals")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func section(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            content()
        }
    }

    private func signalRow(signal: PositioningSignal, action: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.icon)
                .font(.system(size: 18))
                .foregroundColor(signal.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(signal.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(signal.color)
                Text(action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(signal.color.opacity(colorScheme == .dark ? 0.08 : 0.05))
        )
    }

    private func guideStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(AppColors.accent)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func factorRow(_ name: String, _ desc: String, weight: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(weight)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(weight == "High" ? AppColors.accent : AppColors.textSecondary)
                .frame(width: 40)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
