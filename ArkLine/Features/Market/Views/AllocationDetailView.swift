import SwiftUI
import Kingfisher

// MARK: - Allocation Detail View

/// Full detail view showing macro regime header, macro inputs, per-asset allocation table, and guide.
struct AllocationDetailView: View {
    let summary: AllocationSummary
    let sentimentViewModel: SentimentViewModel

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Regime Header
                regimeHeader

                // 2. Macro Inputs (VIX, DXY, M2)
                macroInputsSection

                // 3. Asset Table
                assetTable

                // 4. Allocation Scale Legend
                allocationScaleLegend

                // 5. Understanding This View
                guideCard

                // 6. Disclaimer
                FinancialDisclaimer()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Crypto Positioning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Regime Header

    private var regimeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Macro Regime")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    Text(summary.regime.quadrant.rawValue)
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(textPrimary)

                    Text(summary.regime.quadrant.shortLabel)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(summary.regime.quadrant.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(summary.regime.quadrant.color.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            Text(summary.regime.quadrant.description)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                scoreBar(label: "Growth", value: summary.regime.growthScore, color: AppColors.success)
                scoreBar(label: "Inflation", value: summary.regime.inflationScore, color: AppColors.warning)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func scoreBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * max(0, min(1, value / 100)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Macro Inputs Section

    private var macroInputsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Inputs")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal)

            // GEI (composite leading indicator)
            MacroIndicatorCard(
                title: "GEI",
                subtitle: "Global Economy",
                value: sentimentViewModel.geiData?.formattedScore ?? "--",
                signal: geiSignal,
                description: geiDescription,
                icon: "globe.americas.fill",
                geiData: sentimentViewModel.geiData
            )

            // VIX
            MacroIndicatorCard(
                title: "VIX",
                subtitle: "Volatility Index",
                value: sentimentViewModel.vixData.map { String(format: "%.2f", $0.value) } ?? "--",
                signal: vixSignal,
                description: vixDescription,
                icon: "chart.line.uptrend.xyaxis",
                vixData: sentimentViewModel.vixData,
                zScoreData: sentimentViewModel.macroZScores[.vix]
            )

            // DXY
            MacroIndicatorCard(
                title: "DXY",
                subtitle: "US Dollar Index",
                value: sentimentViewModel.dxyData.map { String(format: "%.2f", $0.value) } ?? "--",
                signal: dxySignal,
                description: dxyDescription,
                icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90",
                dxyData: sentimentViewModel.dxyData,
                zScoreData: sentimentViewModel.macroZScores[.dxy]
            )

            // Global M2
            MacroIndicatorCard(
                title: "Global M2",
                subtitle: "Money Supply",
                value: sentimentViewModel.globalM2Data.map { String(format: "$%.1fT", $0.current / 1_000_000_000_000) } ?? "--",
                signal: m2Signal,
                description: m2Description,
                icon: "chart.bar.fill",
                liquidityData: sentimentViewModel.globalM2Data,
                zScoreData: sentimentViewModel.macroZScores[.m2]
            )

            // WTI Crude Oil
            MacroIndicatorCard(
                title: "WTI",
                subtitle: "Crude Oil",
                value: sentimentViewModel.crudeOilData.map { String(format: "$%.2f", $0.value) } ?? "--",
                signal: crudeOilSignal,
                description: crudeOilDescription,
                icon: "drop.fill",
                crudeOilData: sentimentViewModel.crudeOilData,
                zScoreData: sentimentViewModel.macroZScores[.crudeOil]
            )

            // Gold
            MacroIndicatorCard(
                title: "Gold",
                subtitle: "XAU/USD",
                value: sentimentViewModel.goldData.map { String(format: "$%.0f", $0.value) } ?? "--",
                signal: goldSignal,
                description: goldDescription,
                icon: "diamond.fill",
                goldData: sentimentViewModel.goldData,
                zScoreData: sentimentViewModel.macroZScores[.gold]
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Macro Signal Helpers

    private var geiSignal: MacroTrendSignal {
        guard let gei = sentimentViewModel.geiData else { return .neutral }
        switch gei.signal {
        case .expansion: return .bullish
        case .contraction: return .bearish
        case .neutral: return .neutral
        }
    }

    private var geiDescription: String {
        guard let gei = sentimentViewModel.geiData else { return "Composite index" }
        return gei.signalDescription
    }

    private var vixSignal: MacroTrendSignal {
        guard let vix = sentimentViewModel.vixData?.value else { return .neutral }
        if vix < 20 { return .bullish }
        if vix > 25 { return .bearish }
        return .neutral
    }

    private var vixDescription: String {
        guard let vix = sentimentViewModel.vixData?.value else { return "Market fear gauge" }
        if vix < 20 { return "Bullish" }
        if vix < 25 { return "Neutral" }
        return "Bearish"
    }

    private var dxySignal: MacroTrendSignal {
        guard let dxy = sentimentViewModel.dxyData?.value else { return .neutral }
        if dxy < 100 { return .bullish }
        if dxy < 105 { return .neutral }
        return .bearish
    }

    private var dxyDescription: String {
        guard let dxy = sentimentViewModel.dxyData?.value else { return "Dollar strength" }
        if dxy < 100 { return "Bullish" }
        if dxy < 105 { return "Neutral" }
        return "Bearish"
    }

    private var m2Signal: MacroTrendSignal {
        guard let m2 = sentimentViewModel.globalM2Data else { return .neutral }
        if m2.monthlyChange > 0 { return .bullish }
        if m2.monthlyChange > -1.0 { return .neutral }
        return .bearish
    }

    private var m2Description: String {
        guard let m2 = sentimentViewModel.globalM2Data else { return "Global liquidity" }
        if m2.monthlyChange > 0 { return "Bullish" }
        if m2.monthlyChange > -1.0 { return "Neutral" }
        return "Bearish"
    }

    private var crudeOilSignal: MacroTrendSignal {
        guard let oil = sentimentViewModel.crudeOilData?.value else { return .neutral }
        if oil < 80 { return .bullish }
        if oil > 95 { return .bearish }
        return .neutral
    }

    private var crudeOilDescription: String {
        guard let oil = sentimentViewModel.crudeOilData?.value else { return "Oil prices" }
        if oil < 80 { return "Bullish" }
        if oil < 95 { return "Neutral" }
        return "Bearish"
    }

    private var goldSignal: MacroTrendSignal {
        guard let gold = sentimentViewModel.goldData?.value else { return .neutral }
        if gold < 4000 { return .bullish }
        if gold > 6000 { return .bearish }
        return .neutral
    }

    private var goldDescription: String {
        guard let gold = sentimentViewModel.goldData?.value else { return "Safe-haven asset" }
        if gold < 4000 { return "Bullish" }
        if gold < 6000 { return "Neutral" }
        return "Bearish"
    }

    // MARK: - Asset Table

    private var assetTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Each asset is scored on its technical trend, risk level, and macro regime fit.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal)
                .padding(.bottom, 12)

            HStack {
                Text("Asset")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Signal")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 80)
                Text("Allocation")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 65, alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            ForEach(summary.allocations) { allocation in
                assetRow(allocation: allocation)
                if allocation.id != summary.allocations.last?.id {
                    Divider()
                        .background(AppColors.divider(colorScheme))
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func assetRow(allocation: AssetAllocation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                if let url = allocation.iconUrl.flatMap({ URL(string: $0) }) {
                    KFImage(url)
                        .resizable()
                        .placeholder {
                            Circle()
                                .fill(AppColors.accent.opacity(0.2))
                        }
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(AppColors.accent.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(allocation.assetId.prefix(1)))
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(AppColors.accent)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(allocation.displayName)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                    Text(allocation.assetId)
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                signalBadge(allocation: allocation)
                    .frame(width: 80)

                Text("\(allocation.targetAllocation)%")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(allocationColor(allocation.targetAllocation))
                    .frame(width: 65, alignment: .trailing)
            }

            Text(allocation.interpretation)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textTertiary)
                .padding(.leading, 44)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func signalBadge(allocation: AssetAllocation) -> some View {
        let label = allocation.isDCAOpportunity ? "DCA" : allocation.signal.label
        let color = allocation.isDCAOpportunity ? Color(hex: "3B82F6") : allocation.signal.color

        return Text(label)
            .font(AppFonts.caption12Medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func allocationColor(_ percent: Int) -> Color {
        switch percent {
        case 100: return AppColors.success
        case 50: return Color(hex: "84CC16")
        case 25: return AppColors.warning
        default: return AppColors.textSecondary
        }
    }

    // MARK: - Allocation Scale Legend

    private var allocationScaleLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Allocation Scale")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            HStack(spacing: 0) {
                scaleSegment(label: "0%", sublabel: "Sidelines", color: AppColors.textSecondary)
                scaleSegment(label: "25%", sublabel: "Small / DCA", color: AppColors.warning)
                scaleSegment(label: "50%", sublabel: "Half", color: Color(hex: "84CC16"))
                scaleSegment(label: "100%", sublabel: "Full", color: AppColors.success)
            }

            Text("This scale shows how much of your planned position to deploy. A 25% DCA allocation means the trend is weak but risk levels suggest small, gradual accumulation may be favorable.")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func scaleSegment(label: String, sublabel: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(AppFonts.body14Bold)
                .foregroundColor(color)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(height: 4)
            Text(sublabel)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Guide Card

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Understanding This View")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            guideRow(
                title: "What is the Macro Regime?",
                text: "We analyze VIX (volatility), DXY (dollar strength), Global M2 (money supply), and WTI Crude Oil (inflation pressure) to classify the current macro environment into one of four regimes. Each regime has different implications for crypto performance."
            )

            guideRow(
                title: "What does the Signal mean?",
                text: "Each asset's signal combines its technical trend (price momentum, moving averages), risk level, and macro regime fit into one recommendation. Bullish means the trend is strong. Bearish means the trend has weakened. DCA means the trend is weak but the asset's risk level is low enough that gradual accumulation may make sense."
            )

            guideRow(
                title: "What is a DCA opportunity?",
                text: "When an asset's trend is negative but its risk level is low (the price has already corrected and stabilized), it may be a good time for dollar-cost averaging — buying small amounts gradually. This is different from a bearish signal with high risk, which means the asset is still falling."
            )

            guideRow(
                title: "How should I read the Allocation %?",
                text: "The allocation percentage tells you how much of your planned position to deploy right now. For example, if you normally hold $10,000 in BTC and the allocation says 25% DCA, conditions support gradually building toward about $2,500. This synthesizes trend, risk, and macro into one number."
            )

            guideRow(
                title: "Why might an asset show 0%?",
                text: "A 0% allocation means the trend is bearish AND risk is elevated — the asset is still falling or hasn't stabilized. This is different from a DCA opportunity at 25%, where the correction appears complete."
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func guideRow(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFonts.caption12Medium)
                .foregroundColor(textPrimary)
            Text(text)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
