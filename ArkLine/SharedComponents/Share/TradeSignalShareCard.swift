import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Trade Signal Share Card Content

struct TradeSignalCardContent: View {
    let signal: TradeSignal
    var isLight: Bool = true
    var leverageInfo: ShareLeverageInfo? = nil

    private var textPrimary: Color { isLight ? Color(hex: "1A1A2E") : .white }
    private var textSecondary: Color { isLight ? Color(hex: "64748B") : Color.white.opacity(0.6) }
    private var textMuted: Color { isLight ? Color(hex: "94A3B8") : Color.white.opacity(0.4) }
    private var dividerColor: Color { isLight ? Color(hex: "E2E8F0") : Color.white.opacity(0.08) }
    private var cardBg: Color { isLight ? Color(hex: "F8FAFC") : Color(hex: "1A1A1A") }

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Asset + Signal Badge
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.asset)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textPrimary)

                    Text(signal.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }

                Spacer()

                Text(signal.signalType.displayName.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(signalColor)
                    .cornerRadius(6)
            }
            .padding(.bottom, 16)

            // Trade Parameters
            VStack(spacing: 0) {
                paramRow(label: "Entry Zone",
                         value: "$\(signal.entryZoneLow.asSignalPrice) – $\(signal.entryZoneHigh.asSignalPrice)")

                sectionDivider

                if let t1 = signal.target1, let pct = signal.entryPctFromTarget1 {
                    paramRow(label: "Target 1",
                             value: "$\(t1.asSignalPrice)",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                    sectionDivider
                }

                if let t2 = signal.target2, let pct = signal.entryPctFromTarget2 {
                    paramRow(label: "Target 2",
                             value: "$\(t2.asSignalPrice)",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                    sectionDivider
                }

                paramRow(label: "Stop Loss",
                         value: "$\(signal.stopLoss.asSignalPrice)",
                         badge: String(format: "%.1f%%", signal.stopLossPct),
                         badgeColor: AppColors.error)

                sectionDivider

                paramRow(label: "Risk / Reward",
                         value: String(format: "%.1fx", signal.riskRewardRatio),
                         valueColor: AppColors.accent)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBg)
            )

            // Outcome (only if signal is closed)
            if let pnl = signal.outcomePct {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(pnl >= 0 ? AppColors.success : AppColors.error)
                            .frame(width: 8, height: 8)
                        Text(pnl >= 0 ? "WIN" : "LOSS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(pnl >= 0 ? AppColors.success : AppColors.error)
                    }

                    Spacer()

                    Text(String(format: "%+.2f%%", pnl))
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(pnl >= 0 ? AppColors.success : AppColors.error)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((pnl >= 0 ? AppColors.success : AppColors.error).opacity(isLight ? 0.08 : 0.12))
                )
                .padding(.top, 12)
            }

            // Leverage summary (optional, no dollar amounts)
            if let info = leverageInfo {
                VStack(spacing: 6) {
                    HStack {
                        Text("Leverage Used")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text("\(info.leverage)x")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(textPrimary)
                    }
                    HStack {
                        Text("Max Safe Leverage")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text("\(info.maxSafeLeverage)x")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppColors.accent)
                    }
                    if let strategyLabel = info.entryStrategyLabel, let entryPrice = info.effectiveEntryPrice {
                        HStack {
                            Text("Entry: \(strategyLabel)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(textSecondary)
                            Spacer()
                            Text("$\(entryPrice.asSignalPrice)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(textPrimary)
                        }
                    }
                    if let adjRR = info.adjustedRiskReward {
                        HStack {
                            Text("Adjusted R:R")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(textSecondary)
                            Spacer()
                            Text(String(format: "1 : %.1f", adjRR))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(isLight ? Color(hex: "F0F4FF") : Color.white.opacity(0.05)))
                .padding(.top, 12)
            }

            // CTA
            HStack {
                Spacer()
                Text("Full analysis at arkline.io")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Spacer()
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Helpers

    private func paramRow(label: String, value: String, badge: String? = nil, badgeColor: Color? = nil, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(valueColor ?? textPrimary)
                .monospacedDigit()

            if let badge, let color = badgeColor {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
            .padding(.vertical, 8)
    }
}

// MARK: - Share Leverage Info (no dollar amounts)

struct ShareLeverageInfo {
    let leverage: Int
    let maxSafeLeverage: Int
    let adjustedRiskReward: Double?
    let entryStrategyLabel: String?
    let effectiveEntryPrice: Double?

    init(from calc: LeverageCalculation) {
        self.leverage = calc.leverageMultiplier
        self.maxSafeLeverage = calc.maxSafeLeverage
        self.adjustedRiskReward = calc.adjustedRiskReward
        self.entryStrategyLabel = calc.hasEntryZone ? calc.entryStrategy.label : nil
        self.effectiveEntryPrice = calc.hasEntryZone ? calc.entryPrice : nil
    }
}

// MARK: - Branded Card Wrapper

private struct SignalBrandedCard<Content: View>: View {
    let isLight: Bool
    let showBranding: Bool
    let showTimestamp: Bool
    let logoImage: UIImage?
    @ViewBuilder let content: Content

    private var bgColor: Color { isLight ? .white : Color(hex: "121212") }
    private var textColor: Color { isLight ? Color(hex: "1A1A2E") : .white }
    private var mutedColor: Color { isLight ? Color(hex: "94A3B8") : Color.white.opacity(0.3) }
    private var timestampColor: Color { isLight ? Color(hex: "64748B") : Color.white.opacity(0.5) }

    var body: some View {
        VStack(spacing: 0) {
            if showBranding {
                HStack {
                    HStack(spacing: 8) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Text("ArkLine")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(textColor)
                    }

                    Spacer()

                    if showTimestamp {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(timestampColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            content
                .padding(.horizontal, 16)

            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(mutedColor)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(bgColor)
    }
}

// MARK: - Trade Signal Share Sheet

struct TradeSignalShareSheet: View {
    let signal: TradeSignal
    var leverageInfo: ShareLeverageInfo? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showBranding = true
    @State private var showTimestamp = true
    @State private var useLightTheme = true
    @State private var includeLeverage = false
    @State private var isExporting = false
    @State private var logoImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        cardView
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Options")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        VStack(spacing: 0) {
                            Toggle(isOn: $showBranding) {
                                HStack {
                                    Image(systemName: "star.circle")
                                        .foregroundColor(AppColors.accent)
                                    Text("Show ArkLine Branding")
                                        .font(AppFonts.body14)
                                }
                            }
                            .tint(AppColors.accent)
                            .padding(14)

                            Divider()

                            Toggle(isOn: $showTimestamp) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(AppColors.accent)
                                    Text("Show Timestamp")
                                        .font(AppFonts.body14)
                                }
                            }
                            .tint(AppColors.accent)
                            .padding(14)

                            Divider()

                            Toggle(isOn: $useLightTheme) {
                                HStack {
                                    Image(systemName: "sun.max.fill")
                                        .foregroundColor(AppColors.accent)
                                    Text("Light Theme")
                                        .font(AppFonts.body14)
                                }
                            }
                            .tint(AppColors.accent)
                            .padding(14)

                            if leverageInfo != nil {
                                Divider()

                                Toggle(isOn: $includeLeverage) {
                                    HStack {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundColor(AppColors.accent)
                                        Text("Include Risk Calculator")
                                            .font(AppFonts.body14)
                                    }
                                }
                                .tint(AppColors.accent)
                                .padding(14)
                            }
                        }
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Share Signal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await exportAndShare() }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .task {
                logoImage = UIImage(named: "ArkLineAppIcon")
            }
        }
    }

    @ViewBuilder
    private var cardView: some View {
        SignalBrandedCard(
            isLight: useLightTheme,
            showBranding: showBranding,
            showTimestamp: showTimestamp,
            logoImage: logoImage
        ) {
            TradeSignalCardContent(
                signal: signal,
                isLight: useLightTheme,
                leverageInfo: includeLeverage ? leverageInfo : nil
            )
        }
    }

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        var height: CGFloat = 320
        if signal.target2 != nil { height += 36 }
        if signal.outcomePct != nil { height += 56 }
        if includeLeverage, let info = leverageInfo {
            height += 80
            if info.entryStrategyLabel != nil { height += 20 }
        }
        if showBranding { height += 70 }

        guard let image = ShareCardRenderer.renderImage(
            content: cardView,
            width: 390,
            height: height
        ) else {
            logError("Trade signal share card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
