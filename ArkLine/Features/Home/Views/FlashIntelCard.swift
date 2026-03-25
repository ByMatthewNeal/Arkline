import SwiftUI

// MARK: - Flash Intel Card

struct FlashIntelCard: View {
    let signal: TradeSignal
    @Environment(\.colorScheme) var colorScheme
    @State private var isPulsing = false

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        HStack(spacing: 14) {
            // Pulsing indicator
            ZStack {
                Circle()
                    .fill(signalColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.25 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)

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
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                withAnimation(.linear(duration: 0)) {
                    isPulsing = false
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(signal.signalType.displayName.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .fixedSize()
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

                    confidenceBadge

                    Text(signal.timeframeBadge.uppercased())
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(signal.isScalp ? AppColors.accent : AppColors.textSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background((signal.isScalp ? AppColors.accent : AppColors.textSecondary).opacity(0.15))
                        .cornerRadius(3)

                    if let grade = signal.scoreGrade {
                        Text(grade)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .frame(height: 16)
                            .background(grade.hasPrefix("A") ? AppColors.success : AppColors.accent)
                            .cornerRadius(3)
                    }

                    if signal.isCounterTrend {
                        Text("CT")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.warning.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                Text("$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                if let analysis = signal.cardAnalysis {
                    Text(analysis.narrative)
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .lineLimit(1)
                } else if let rationale = signal.shortRationale, !rationale.isEmpty {
                    Text(rationale)
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .lineLimit(1)
                }
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

    private var confidenceBadge: some View {
        let color: Color = signal.confidence == .high ? AppColors.success : (signal.confidence == .medium ? AppColors.warning : AppColors.error)
        return Text(signal.confidence.displayName)
            .font(.system(size: 8, weight: .heavy))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }
}

// MARK: - Swing Setups Section

struct FlashIntelSection: View {
    let signals: [TradeSignal]
    let isPro: Bool
    var size: WidgetSize = .standard
    var stats: SignalStats? = nil
    var highImpactEvents: [EconomicEvent] = []
    var marketConditions: SignalMarketConditions? = nil
    @State private var showMethodology = false
    @State private var showPaywall = false
    @Environment(\.colorScheme) var colorScheme

    private var maxSignals: Int {
        switch size {
        case .compact: return 1
        case .standard: return 2
        case .expanded: return 4
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "scope")
                    .foregroundColor(AppColors.accent)
                Text("Trade Signals")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showMethodology = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            // High-impact event warning
            if isPro && !highImpactEvents.isEmpty {
                highImpactWarningBanner
            }

            if isPro {
                if signals.isEmpty {
                    NavigationLink {
                        SwingSetupsDetailView()
                    } label: {
                        emptyStateCard
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    ForEach(signals.prefix(maxSignals)) { signal in
                        NavigationLink {
                            SignalDetailView(signalId: signal.id)
                        } label: {
                            FlashIntelCard(signal: signal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    NavigationLink {
                        SwingSetupsDetailView()
                    } label: {
                        Text(signals.count > maxSignals ? "View all \(signals.count) setups" : "View all setups & history")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Signal stats strip
                if let stats, stats.totalSignals > 0 {
                    signalStatsStrip(stats)
                }
            } else {
                Button { showPaywall = true } label: { lockedCard }
                    .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showMethodology) {
            SignalMethodologySheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .swingSetups)
        }
    }

    private func signalStatsStrip(_ stats: SignalStats) -> some View {
        NavigationLink {
            SwingSetupsDetailView()
        } label: {
            HStack(spacing: 0) {
                // Win rate
                statItem(
                    value: String(format: "%.0f%%", stats.hitRate),
                    label: "Win Rate",
                    color: stats.hitRate >= 55 ? AppColors.success : (stats.hitRate >= 45 ? AppColors.warning : AppColors.error)
                )

                Divider()
                    .frame(height: 24)
                    .opacity(0.2)

                // Streak
                statItem(
                    value: stats.currentStreak >= 0 ? "+\(stats.currentStreak)" : "\(stats.currentStreak)",
                    label: "Streak",
                    color: stats.currentStreak >= 0 ? AppColors.success : AppColors.error
                )

                Divider()
                    .frame(height: 24)
                    .opacity(0.2)

                // Profit factor
                statItem(
                    value: stats.profitFactor.isInfinite ? "---" : String(format: "%.1f", stats.profitFactor),
                    label: "PF",
                    color: stats.profitFactor >= 1.5 ? AppColors.success : (stats.profitFactor >= 1.0 ? AppColors.warning : AppColors.error)
                )

                Divider()
                    .frame(height: 24)
                    .opacity(0.2)

                // Total trades
                statItem(
                    value: "\(stats.totalSignals)",
                    label: "Trades",
                    color: AppColors.textPrimary(colorScheme)
                )
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateCard: some View {
        let conditions = marketConditions
        let headline = conditions?.headline ?? "No active setups"
        let detail = conditions?.detail ?? "Signals fire when price approaches high-confluence Fibonacci zones with supporting risk conditions."

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: conditions?.status == "quiet" ? "waveform.path" : "scope")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)

                Text(headline)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }

            Text(detail)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Top skip reasons
            if let reasons = conditions?.topReasons, !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(reasons.prefix(2), id: \.self) { reason in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppColors.textSecondary.opacity(0.4))
                                .frame(width: 4, height: 4)
                            Text(reason)
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }

            HStack {
                if let conditions, conditions.totalSkipped > 0 {
                    Text("\(conditions.totalSkipped) setups filtered")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("View history")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    private var lockedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fibonacci trade signal detection")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Upgrade to Pro for trade signal analysis")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    private var highImpactWarningBanner: some View {
        let eventNames = highImpactEvents.prefix(2).map { $0.title }.joined(separator: ", ")
        return HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("High-Volatility Day")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.warning)

                Text("\(eventNames) today. Expect sharp moves — manage risk carefully.")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(10)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Signal Methodology Sheet

struct SignalMethodologySheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.accent)

                        Text("How Signal Detection Works")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textPrimary)

                        Text("Fibonacci-based pattern detection running 24/7 across 1H and 4H candle data. For educational purposes only.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                    // Conditions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Detection Criteria")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        conditionRow(
                            icon: "chart.xyaxis.line",
                            title: "Fibonacci Golden Pocket",
                            detail: "Price must reach a 0.618\u{2013}0.786 retracement zone, the highest-probability reversal area."
                        )

                        conditionRow(
                            icon: "arrow.triangle.merge",
                            title: "Multi-Timeframe Confluence",
                            detail: "The zone must align across multiple timeframes — 1H/4H for scalps and 4H/Daily for swings. More overlapping levels = stronger pattern."
                        )

                        conditionRow(
                            icon: "arrow.up.arrow.down",
                            title: "EMA Trend Alignment",
                            detail: "The bias-timeframe EMAs must support the trade direction. The 20 EMA should be above the 50 EMA for longs (below for shorts). In a pullback, the 50 EMA slope must be favorable and price near the 50 EMA."
                        )

                        conditionRow(
                            icon: "checkmark.circle",
                            title: "Bounce Confirmation",
                            detail: "A wick rejection or volume spike at the zone is required before a pattern is flagged."
                        )

                        conditionRow(
                            icon: "scalemass",
                            title: "Minimum 1:1 Risk/Reward",
                            detail: "Every pattern must have at least a 1:1 risk-to-reward ratio — raised to 2:1 in choppy market conditions. Strong patterns require 2:1+ with multi-timeframe confluence."
                        )

                        conditionRow(
                            icon: "waveform.path.ecg",
                            title: "Bull Market Support Band",
                            detail: "The 20-week SMA and 21-week EMA define the macro regime. Signals that go against this regime are tagged \"Counter-Trend\" and auto-scaled to 0.5R in Your Setup."
                        )

                        conditionRow(
                            icon: "chart.bar.xaxis",
                            title: "Volume Profile Confluence",
                            detail: "The pipeline computes a volume profile from recent 4H candles to identify high-volume nodes. When a node overlaps with the Fibonacci zone, it adds structural support/resistance — shown as the \"Vol Shelf\" badge."
                        )

                        conditionRow(
                            icon: "waveform.badge.magnifyingglass",
                            title: "Choppy Market Detection",
                            detail: "When EMAs are tightly compressed with frequent crossovers or price whipsaws, the market is flagged as choppy. In these conditions, the minimum R:R is raised to 2:1 and bounce confirmation requires stronger evidence."
                        )

                        conditionRow(
                            icon: "bolt.horizontal",
                            title: "Momentum Filter",
                            detail: "Blocks signals that go against strong recent momentum — no shorts during a 5%+ rally over 5 days, and no longs during a 5%+ selloff."
                        )

                        conditionRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Daily Trend Guard",
                            detail: "When the daily chart shows a clear uptrend (EMA 20 above 50 with rising slope and >1% spread), short signals are blocked. Longs are never blocked by this filter."
                        )

                        conditionRow(
                            icon: "timer",
                            title: "24-Hour Cooldown",
                            detail: "After a signal is generated for an asset, the same asset won't produce another signal for 24 hours — preventing signal spam in volatile conditions."
                        )
                    }
                    .padding(.horizontal, 20)

                    // Signal Scoring
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signal Quality Score")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accent)
                                .frame(width: 24)

                            Text("Every signal receives a **0–100 quality score** combining five factors: Confluence Depth (how many Fib levels overlap + multi-timeframe bonus), EMA Alignment Strength (spread and slope), Volume Confirmation Quality (wick rejection, volume spike, consecutive closes, volume shelf), Risk/Reward Ratio, and Macro Context (Bull Market Support Band regime). The score appears as a letter grade on each signal card — A+ (90+), A (80+), B+ (70+), B (60+). Signals scoring below B are filtered out. Use the Sort by Score chip to prioritize the strongest setups.")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary.opacity(0.8))
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Execution window
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detection Window")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accent)
                                .frame(width: 24)

                            Text("Patterns are evaluated **every 30 minutes** using 1H and 4H candle data for fast bounce detection. A **lightweight monitor** checks open signals against live prices for stop loss, target, and trailing stop resolution. Swing signals (4H) expire after 72 hours and scalp signals (1H) expire after 48 hours, closing at the current price.")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary.opacity(0.8))
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Backtesting
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Backtested & Validated")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                                .frame(width: 24)

                            Text("This detection methodology has been backtested across 10 assets (BTC, ETH, SOL, SUI, LINK, ADA, AVAX, APT, XRP, ATOM) over 12+ months of data covering multiple market regimes. Both 1H scalp and 4H swing tiers include choppiness detection, momentum filtering, and daily trend analysis. The split-exit framework (50% at T1, 50% trailing) is designed for educational analysis of trade management.")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary.opacity(0.8))
                                .lineSpacing(3)
                        }
                    }
                    .padding(.horizontal, 20)

                    // How to use signals
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to Use Signals")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(textPrimary)

                        stepRow(
                            number: "1",
                            title: "Signal Appears — \"In Play\"",
                            detail: "The system detects a confirmed bounce at a high-confluence Fibonacci zone (wick rejection, volume spike, or consecutive closes) and creates the signal as In Play. Check the signal score and analysis to assess quality."
                        )

                        stepRow(
                            number: "2",
                            title: "Proximity Alert",
                            detail: "When price approaches within 2% of the entry zone, you'll receive a push notification (if enabled in Settings). There is a 4-hour cooldown between repeated proximity alerts for the same signal. This is your heads-up to prepare limit orders."
                        )

                        stepRow(
                            number: "3",
                            title: "Set Limit Orders",
                            detail: "Place a limit order within the entry zone (low\u{2013}high range). Use the Entry Strategy selector in Your Setup to pick optimal, midpoint, or split entry."
                        )

                        stepRow(
                            number: "4",
                            title: "Manage the Trade",
                            detail: "Set your stop loss at the signal's stop level. When T1 hits, 50% closes at the first target. The remaining 50% trails with a 1R stop for extended gains. The outcome PnL is the weighted average of the T1 half (50%) and the runner half (50%)."
                        )

                        stepRow(
                            number: "5",
                            title: "Expiry — No Trade",
                            detail: "If neither target nor stop is hit within the time window (48h for scalps, 72h for swings), the signal expires and is closed at the current price. Patience is the edge."
                        )

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.warning)
                                .frame(width: 24)

                            Text("These are **limit entry** signals at key reversal levels — not market orders. If price has already moved well past the entry zone, skip the signal. The risk/reward is no longer favorable.")
                                .font(.system(size: 13))
                                .foregroundColor(textPrimary.opacity(0.7))
                                .lineSpacing(2)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Disclaimer
                    Text("Trade Signals is an educational analysis tool, not financial advice. Arkline does not recommend any specific trades. Always do your own research and consult a licensed financial advisor.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
            .navigationTitle("Trade Signals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func conditionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineSpacing(2)
            }
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(AppColors.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineSpacing(2)
            }
        }
    }
}
