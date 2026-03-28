import SwiftUI

struct MacroSlideView: View {
    let data: MacroSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            VStack(spacing: ArkSpacing.xs) {
                if let vixValue = data.vixValue {
                    macroRow(
                        label: "VIX",
                        value: String(format: "%.1f", vixValue),
                        change: data.vixChange,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }

                if let dxyValue = data.dxyValue {
                    macroRow(
                        label: "DXY",
                        value: String(format: "%.2f", dxyValue),
                        change: data.dxyChange,
                        icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                }

                if data.vixValue != nil || data.dxyValue != nil {
                    Rectangle()
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.08))
                        .frame(height: 1)
                        .padding(.vertical, ArkSpacing.xxs)
                }

                if let m2 = data.m2Trend {
                    directionRow(
                        label: "Global M2",
                        direction: m2,
                        icon: "chart.bar.fill",
                        isPositive: m2.lowercased().contains("expand")
                    )
                }

                if let netLiq = data.netLiquidityDirection {
                    directionRow(
                        label: "Net Liquidity",
                        direction: netLiq,
                        icon: "drop.fill",
                        isPositive: netLiq.lowercased().contains("expand")
                    )
                }
            }

            if let shifts = data.regimeShifts, !shifts.isEmpty {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("REGIME SHIFTS")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .tracking(1.5)

                    ForEach(shifts, id: \.self) { shift in
                        HStack(alignment: .top, spacing: ArkSpacing.xs) {
                            Rectangle()
                                .fill(AppColors.accent)
                                .frame(width: 2, height: 16)
                                .padding(.top, 2)

                            Text(shift)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(ArkSpacing.md)
                .background(AppColors.textPrimary(colorScheme).opacity(0.04))
                .cornerRadius(ArkSpacing.Radius.lg)
            }
        }
    }

    @ViewBuilder
    private func macroRow(label: String, value: String, change: Double?, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24)

            Text(label)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFonts.number20)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let change = change {
                Text(String(format: "%+.1f%%", change))
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    .frame(width: 52, alignment: .trailing)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    @ViewBuilder
    private func directionRow(label: String, direction: String, icon: String, isPositive: Bool) -> some View {
        let color = isPositive ? AppColors.success : AppColors.error

        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24)

            Text(label)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                Text(direction)
                    .font(AppFonts.interFont(size: 11, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, ArkSpacing.xs)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
        }
        .padding(ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }
}
