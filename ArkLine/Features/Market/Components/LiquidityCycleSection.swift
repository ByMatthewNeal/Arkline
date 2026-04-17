import SwiftUI

// MARK: - Liquidity Cycle Section (Market Tab)
/// Displays the 65-month liquidity cycle clock with momentum index,
/// cycle phase, yield curve regime, and crypto-specific guidance.
struct LiquidityCycleSection: View {
    var refreshId: UUID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var liquidityIndex: GlobalLiquidityIndex?
    @State private var isLoading = true
    @State private var showInfo = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Liquidity Cycle")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let cycle = liquidityIndex?.liquidityCycle {
                    phaseBadge(cycle.phase)
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .frame(height: 320)
                    .redacted(reason: .placeholder)
            } else if let gli = liquidityIndex, let cycle = gli.liquidityCycle {
                VStack(spacing: 16) {
                    // Clock + Momentum side by side
                    HStack(alignment: .top, spacing: 16) {
                        // Clock visualization
                        CycleClockView(
                            angleDegrees: cycle.cycleAngleDegrees,
                            phase: cycle.phase,
                            colorScheme: colorScheme
                        )
                        .frame(width: 160, height: 160)

                        // Momentum + Stats
                        VStack(alignment: .leading, spacing: 12) {
                            // Momentum Index
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MOMENTUM")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(textPrimary.opacity(0.4))
                                    .tracking(1)

                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(cycle.momentumIndex)")
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(momentumColor(cycle.momentumIndex))
                                    Text("/ 100")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            // 65-month wave
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CYCLE WAVE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(textPrimary.opacity(0.4))
                                    .tracking(1)

                                HStack(spacing: 4) {
                                    Text(String(format: "%.0f", cycle.theoreticalWave))
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundColor(textPrimary)
                                    Text("/ 100")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            // Yield curve
                            if cycle.yieldCurve.parsedRegime != .unknown {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("YIELD CURVE")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(textPrimary.opacity(0.4))
                                        .tracking(1)

                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(cycle.yieldCurve.parsedRegime.color)
                                            .frame(width: 6, height: 6)
                                        Text(cycle.yieldCurve.parsedRegime.displayName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(textPrimary.opacity(0.8))

                                        if let spread = cycle.yieldCurve.t10y2y {
                                            Text(String(format: "%.2f%%", spread))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()
                        .background(textPrimary.opacity(0.08))

                    // Crypto guidance
                    positioningBlock(
                        title: "CRYPTO POSITIONING",
                        label: cycle.phase.cryptoLabel,
                        detail: cycle.cryptoGuidance,
                        color: cycle.phase.color
                    )

                    Divider()
                        .background(textPrimary.opacity(0.08))

                    // Equity guidance
                    positioningBlock(
                        title: "EQUITY POSITIONING",
                        label: cycle.phase.equityLabel,
                        detail: cycle.equityGuidance ?? cycle.phase.defaultEquityGuidance,
                        color: cycle.phase.color
                    )

                    Divider()
                        .background(textPrimary.opacity(0.08))

                    // Momentum details row
                    HStack(spacing: 0) {
                        if let m3 = cycle.momentum3m {
                            momentumChip("3M RoC", m3)
                        }
                        if let m6 = cycle.momentum6m {
                            momentumChip("6M RoC", m6)
                        }
                        momentumChip("Accel", cycle.acceleration)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                )
            } else {
                Text("Unable to load cycle data")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal)
        .task(id: refreshId) {
            await loadData()
        }
        .sheet(isPresented: $showInfo) {
            LiquidityCycleInfoSheet()
        }
    }

    // MARK: - Helpers

    private func phaseBadge(_ phase: LiquidityCyclePhase) -> some View {
        HStack(spacing: 4) {
            Image(systemName: phase.icon)
                .font(.system(size: 10, weight: .bold))
            Text(phase.shortLabel)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(phase.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(phase.color.opacity(0.12))
        .cornerRadius(6)
    }

    private func positioningBlock(title: String, label: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.4))
                .tracking(1)

            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)

            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(textPrimary.opacity(0.6))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func momentumColor(_ index: Int) -> Color {
        if index >= 70 { return AppColors.success }
        if index >= 40 { return AppColors.warning }
        return AppColors.error
    }

    private func momentumChip(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            Text(String(format: "%+.2f%%", value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(value >= 0 ? AppColors.success : AppColors.error)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadData() async {
        do {
            let service: GlobalLiquidityServiceProtocol = ServiceContainer.shared.globalLiquidityService
            liquidityIndex = try await service.fetchGlobalLiquidityIndex()
        } catch {
            logWarning("LiquidityCycleSection: \(error.localizedDescription)", category: .network)
        }
        isLoading = false
    }
}

// MARK: - Cycle Clock Visualization
/// A circular clock with 4 quadrants showing the current cycle position

struct CycleClockView: View {
    let angleDegrees: Double
    let phase: LiquidityCyclePhase
    let colorScheme: ColorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    // Map cycle angle to clock: 0° cycle = bottom (6 o'clock), clockwise
    // Cycle: 0=trough(bottom), 90=equities(left→top-left), 180=peak(top), 270=cash(right)
    // SwiftUI angles: 0=right(3 o'clock), goes clockwise
    // We want: trough at bottom (270° SwiftUI), peak at top (90° SwiftUI)
    // Mapping: swiftUI = 270 - cycleDegrees (then normalize)
    private var needleAngle: Angle {
        // Cycle 0° = bottom, cycle 90° = left, cycle 180° = top, cycle 270° = right
        // SwiftUI 0° = right (3 o'clock), 90° = bottom (6), 180° = left (9), 270° = top (12)
        // So: swiftUI = (cycleDegrees + 90) mapped... let me think differently.
        // We want cycle 0° at 6 o'clock position (bottom)
        // In SwiftUI, 6 o'clock = 90°
        // Cycle goes: 0°→90°→180°→270° = bottom→left→top→right (counterclockwise in standard)
        // But for a clock we want clockwise rotation from bottom
        // SwiftUI clockwise from right: 0=right, 90=bottom, 180=left, 270=top
        // So cycle 0° (bottom) = SwiftUI 90°
        // cycle 90° should be left side = SwiftUI 180°
        // cycle 180° (top) = SwiftUI 270°
        // cycle 270° = SwiftUI 360° = 0° (right)
        // Pattern: swiftUI = cycleDegrees + 90
        Angle(degrees: angleDegrees + 90)
    }

    var body: some View {
        ZStack {
            // Background quadrants
            ForEach(LiquidityCyclePhase.allCases, id: \.rawValue) { quadPhase in
                quadrantArc(quadPhase)
            }

            // Labels
            quadrantLabels

            // Center circle
            Circle()
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                .frame(width: 44, height: 44)

            // Needle
            needleView

            // Center dot
            Circle()
                .fill(phase.color)
                .frame(width: 10, height: 10)
                .shadow(color: phase.color.opacity(0.5), radius: 4)
        }
    }

    private func quadrantArc(_ quadPhase: LiquidityCyclePhase) -> some View {
        let startAngle = Angle(degrees: quadPhase.clockStartAngle + 90) // +90 offset
        let endAngle = Angle(degrees: quadPhase.clockStartAngle + 90 + 90)
        let isActive = quadPhase == phase

        return Path { path in
            path.move(to: CGPoint(x: 80, y: 80))
            path.addArc(
                center: CGPoint(x: 80, y: 80),
                radius: 72,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(quadPhase.color.opacity(isActive ? 0.25 : 0.08))
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 80, y: 80))
                path.addArc(
                    center: CGPoint(x: 80, y: 80),
                    radius: 72,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false
                )
                path.closeSubpath()
            }
            .stroke(quadPhase.color.opacity(isActive ? 0.4 : 0.1), lineWidth: 1)
        )
    }

    private var quadrantLabels: some View {
        ZStack {
            // Top: Peak
            VStack(spacing: 0) {
                Text("Peak")
                    .font(.system(size: 8, weight: .bold))
                Text("Alts")
                    .font(.system(size: 7))
            }
            .foregroundColor(textPrimary.opacity(0.5))
            .offset(y: -56)

            // Bottom: Trough
            VStack(spacing: 0) {
                Text("DCA")
                    .font(.system(size: 7))
                Text("Trough")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(textPrimary.opacity(0.5))
            .offset(y: 56)

            // Left: Equities/BTC
            VStack(spacing: 0) {
                Text("BTC")
                    .font(.system(size: 8, weight: .bold))
                Text("Accum")
                    .font(.system(size: 7))
            }
            .foregroundColor(textPrimary.opacity(0.5))
            .offset(x: -56)

            // Right: Cash
            VStack(spacing: 0) {
                Text("Stables")
                    .font(.system(size: 8, weight: .bold))
                Text("Cash")
                    .font(.system(size: 7))
            }
            .foregroundColor(textPrimary.opacity(0.5))
            .offset(x: 56)
        }
    }

    private var needleView: some View {
        // Draw needle from center to edge
        let length: CGFloat = 52
        return Path { path in
            path.move(to: CGPoint(x: 80, y: 80))
            let endX = 80 + length * CGFloat(cos(needleAngle.radians))
            let endY = 80 + length * CGFloat(sin(needleAngle.radians))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(phase.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .shadow(color: phase.color.opacity(0.4), radius: 3)
    }
}

// MARK: - Liquidity Cycle Info Sheet

private struct LiquidityCycleInfoSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("What is the Liquidity Cycle?") {
                        Text("Global liquidity moves in roughly 65-month (5.4 year) cycles driven by central bank policy. When central banks expand balance sheets, risk assets rally. When they contract, markets correct. This clock shows where we are in the current cycle.")
                    }

                    section("The Four Phases") {
                        VStack(alignment: .leading, spacing: 12) {
                            phaseRow(.earlyExpansion, "Liquidity momentum turns positive. BTC typically leads — it's the first major risk asset to respond to improving liquidity conditions.")
                            phaseRow(.lateExpansion, "Peak speculation. Altcoins outperform as liquidity peaks. This is where maximum euphoria occurs. Consider taking profits.")
                            phaseRow(.earlyContraction, "Liquidity momentum fades. Defensive rotation — reduce altcoin exposure, move to BTC or stablecoins.")
                            phaseRow(.lateContraction, "Maximum pessimism. Smart money begins accumulating. DCA into BTC and quality projects for the next cycle.")
                        }
                    }

                    section("Momentum Index (0-100)") {
                        Text("Percentile rank of the 3-month rate of change of our composite central bank liquidity index. A reading of 80 means current momentum is higher than 80% of the last 2 years. Above 60 is expansionary, below 40 is contractionary.")
                    }

                    section("65-Month Wave") {
                        Text("A theoretical sine wave anchored to the October 2022 liquidity trough. Based on Michael Howell's research at Crossborder Capital showing liquidity cycles average ~65 months. The wave shows where we \"should\" be if the cycle repeats — compare with the actual momentum index to spot divergences.")
                    }

                    section("Yield Curve") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The 10Y-2Y Treasury spread confirms where we are in the cycle:")
                            ycRow("Steepening", "Early cycle — bullish for risk assets", AppColors.success)
                            ycRow("Flattening", "Late cycle — Fed tightening", AppColors.warning)
                            ycRow("Inverted", "Recession warning — historically bearish", AppColors.error)
                            ycRow("Un-inverting", "Final stage before recession begins", AppColors.error)
                        }
                    }

                    section("Data Sources") {
                        Text("Liquidity: BIS central bank balance sheets (10 economies) + FRED (Fed, TGA, RRP). Yield curve: FRED T10Y2Y and T10Y3M series. Updated daily at 08:00 UTC.")
                    }
                }
                .padding(20)
            }
            .background(colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
            .navigationTitle("About Liquidity Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)
            content()
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.7))
        }
    }

    private func phaseRow(_ phase: LiquidityCyclePhase, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: phase.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(phase.color)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(phase.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(phase.color)
                    Text("·")
                        .foregroundColor(textPrimary.opacity(0.3))
                    Text(phase.cryptoLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
            }
        }
    }

    private func ycRow(_ label: String, _ desc: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
    }
}
