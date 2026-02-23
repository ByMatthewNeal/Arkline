import SwiftUI
import Kingfisher

// MARK: - Allocation Detail View

/// Full detail view showing macro regime header, per-asset allocation table, and guide.
struct AllocationDetailView: View {
    let summary: AllocationSummary

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Regime Header
                regimeHeader

                // 2. Asset Table
                assetTable

                // 3. Allocation Scale Legend
                allocationScaleLegend

                // 4. Understanding This View
                guideCard

                // 5. Disclaimer
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
            // Quadrant name (no icon)
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

            // Description
            Text(summary.regime.quadrant.description)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Growth / Inflation score bars
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

    // MARK: - Asset Table

    private var assetTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section intro
            Text("Each asset is scored on its technical trend and how well it fits the current macro regime.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal)
                .padding(.bottom, 12)

            // Table header
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
            // Main row: icon + name + signal + allocation
            HStack(spacing: 12) {
                // Asset icon
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

                // Signal badge
                signalBadge(signal: allocation.signal)
                    .frame(width: 80)

                // Allocation %
                Text("\(allocation.targetAllocation)%")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(allocationColor(allocation.targetAllocation))
                    .frame(width: 65, alignment: .trailing)
            }

            // Interpretation line
            Text(allocation.interpretation)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textTertiary)
                .padding(.leading, 44) // Align with text after icon
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func signalBadge(signal: PositioningSignal) -> some View {
        Text(signal.label)
            .font(AppFonts.caption12Medium)
            .foregroundColor(signal.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(signal.color.opacity(0.12))
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
                scaleSegment(label: "0%", sublabel: "No position", color: AppColors.textSecondary, isFirst: true)
                scaleSegment(label: "25%", sublabel: "Quarter", color: AppColors.warning, isFirst: false)
                scaleSegment(label: "50%", sublabel: "Half", color: Color(hex: "84CC16"), isFirst: false)
                scaleSegment(label: "100%", sublabel: "Full", color: AppColors.success, isFirst: false)
            }

            Text("This scale represents how much of your intended position size to deploy based on current conditions. 100% means conditions fully support the position; 0% means stay on the sidelines.")
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

    private func scaleSegment(label: String, sublabel: String, color: Color, isFirst: Bool) -> some View {
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
                text: "We analyze VIX (volatility), DXY (dollar strength), and Global M2 (money supply) to classify the current macro environment into one of four regimes. Each regime has different implications for crypto performance."
            )

            guideRow(
                title: "What does the Signal mean?",
                text: "Each asset's signal combines its technical trend (price momentum, moving averages) with its risk level. Bullish means the trend is strong and risk is low. Bearish means the trend has weakened or risk is elevated."
            )

            guideRow(
                title: "How should I read the Allocation %?",
                text: "The allocation percentage tells you how much of your planned position to deploy right now. For example, if you normally hold $10,000 in BTC and the allocation says 50%, conditions support holding about $5,000. This is based on how well the asset fits the current regime and its trend signal."
            )

            guideRow(
                title: "Why might an asset show 0%?",
                text: "A 0% allocation means either the trend is bearish (negative momentum) or the asset is a poor fit for the current macro regime. It doesn't mean the asset is bad long-term, just that current conditions don't favor it."
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
