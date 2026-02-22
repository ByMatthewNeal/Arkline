import SwiftUI

// MARK: - Calculation Summary Card
struct DCACalculationSummaryCard: View {
    @Environment(\.colorScheme) var colorScheme
    let calculation: DCACalculation

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Your DCA Plan")
                    .font(AppFonts.title24)
                    .foregroundColor(textPrimary)

                // Strategy badge
                HStack(spacing: 6) {
                    Image(systemName: calculation.strategyType.icon)
                        .font(.system(size: 12))
                    Text(calculation.strategyType.rawValue)
                        .font(AppFonts.caption12Medium)
                }
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.accent.opacity(0.15))
                )

                // Asset info
                HStack(spacing: 8) {
                    DCAAssetIconView(asset: calculation.asset, size: 24)
                    Text(calculation.asset.symbol)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }
            }

            Divider()

            if calculation.strategyType == .timeBased {
                timeBasedSummary
            } else {
                riskBasedSummary
            }

            // Portfolio info
            if let portfolioName = calculation.targetPortfolioName {
                Divider()

                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)

                    Text("Target Portfolio")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(portfolioName)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Time-Based Summary

    @ViewBuilder
    private var timeBasedSummary: some View {
        // Plan details
        VStack(spacing: 12) {
            SummaryRow(label: "Total Investment", value: calculation.formattedTotalAmount)
            SummaryRow(label: "Frequency", value: DCACalculatorService.frequencyDescription(
                frequency: calculation.frequency,
                selectedDays: calculation.selectedDays
            ))
            SummaryRow(label: "Duration", value: calculation.duration.displayName)
        }

        Divider()

        // Key metrics
        VStack(spacing: 16) {
            // Per purchase amount - highlighted
            VStack(spacing: 4) {
                Text("Per Purchase")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Text(calculation.formattedAmountPerPurchase)
                    .font(AppFonts.number36)
                    .foregroundColor(AppColors.accent)
            }

            HStack(spacing: 20) {
                MetricItem(
                    icon: "calendar",
                    value: "\(calculation.numberOfPurchases)",
                    label: "Purchases"
                )

                MetricItem(
                    icon: "play.circle",
                    value: dateFormatter.string(from: calculation.startDate),
                    label: "First"
                )

                if let endDate = calculation.endDate {
                    MetricItem(
                        icon: "flag.checkered",
                        value: dateFormatter.string(from: endDate),
                        label: "Last"
                    )
                }
            }
        }

        // Upcoming schedule preview
        if !calculation.purchaseDates.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Upcoming Schedule")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(textPrimary)

                VStack(spacing: 8) {
                    ForEach(Array(calculation.purchaseDates.prefix(5).enumerated()), id: \.offset) { _, date in
                        HStack {
                            Text(shortDateFormatter.string(from: date))
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text(calculation.formattedAmountPerPurchase)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(textPrimary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                        )
                    }

                    if calculation.purchaseDates.count > 5 {
                        Text("+ \(calculation.purchaseDates.count - 5) more purchases")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - Risk-Based Summary

    @ViewBuilder
    private var riskBasedSummary: some View {
        // Plan details
        VStack(spacing: 12) {
            SummaryRow(label: "Total Investment", value: calculation.formattedTotalAmount)
            SummaryRow(label: "Risk Model", value: calculation.scoreType.rawValue)
            SummaryRow(label: "Risk Levels", value: calculation.riskBandDescription)
            SummaryRow(label: "Risk Range", value: calculation.riskRangeDescription)
        }

        Divider()

        // Risk meter visualization
        VStack(spacing: 16) {
            Text("Active Risk Zones")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            DCABTCRiskMeter(selectedBands: calculation.riskBands)

            // Investment explanation
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)

                    Text("You'll receive a notification when BTC risk enters your selected zones")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }

                // List selected bands with investment amounts
                VStack(spacing: 6) {
                    let sortedBands = calculation.riskBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
                    let amountPerBand = calculation.totalAmount / Double(sortedBands.count)

                    ForEach(sortedBands) { band in
                        HStack {
                            Circle()
                                .fill(Color(hex: band.color))
                                .frame(width: 8, height: 8)

                            Text(band.rawValue)
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(textPrimary)

                            Text("(\(Int(band.riskRange.lowerBound))-\(Int(band.riskRange.upperBound)))")
                                .font(AppFonts.footnote10)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text(amountPerBand.asCurrency)
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
            }
        }

        // How it works
        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text("How It Works")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                RiskBasedStepRow(number: 1, text: "BTC risk indicator updates based on market conditions")
                RiskBasedStepRow(number: 2, text: "When risk enters your selected zone, you get notified")
                RiskBasedStepRow(number: 3, text: "Execute your DCA purchase at optimal risk levels")
            }
        }
    }
}

// MARK: - Supporting Views

struct RiskBasedStepRow: View {
    let number: Int
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 20, height: 20)

                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }

            Text(text)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)
        }
    }
}

struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
