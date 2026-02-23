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

                // 3. How to Read Guide
                guideCard

                // 4. Disclaimer
                FinancialDisclaimer()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 40)
            }
            .padding(.top, 16)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Positioning Signals")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Regime Header

    private var regimeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quadrant name + icon
            HStack(spacing: 10) {
                Image(systemName: summary.regime.quadrant.icon)
                    .font(.title2)
                    .foregroundColor(summary.regime.quadrant.color)
                    .frame(width: 44, height: 44)
                    .background(summary.regime.quadrant.color.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Regime")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                    Text(summary.regime.quadrant.rawValue)
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(textPrimary)
                }

                Spacer()
            }

            // Description
            Text(summary.regime.quadrant.description)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

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
                Text("Target")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 55, alignment: .trailing)
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
        HStack(spacing: 12) {
            // Asset icon + name
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

            // Target allocation %
            Text("\(allocation.targetAllocation)%")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(allocationColor(allocation.targetAllocation))
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func signalBadge(signal: PositioningSignal) -> some View {
        HStack(spacing: 4) {
            Image(systemName: signal.icon)
                .font(.system(size: 10, weight: .bold))
            Text(signal.label)
                .font(AppFonts.caption12Medium)
        }
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

    // MARK: - Guide Card

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Read This")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            guideRow(
                icon: "arrow.up.right.circle.fill",
                color: AppColors.success,
                title: "Signal",
                text: "Derived from technical trend score and risk level. Bullish = strong trend + low risk."
            )

            guideRow(
                icon: "globe",
                color: AppColors.accent,
                title: "Regime Fit",
                text: "How well each asset historically performs in the current macro environment."
            )

            guideRow(
                icon: "target",
                color: AppColors.warning,
                title: "Target %",
                text: "Suggested allocation of your position. 100% = full, 0% = sidelines. Not financial advice."
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func guideRow(icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
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
}
