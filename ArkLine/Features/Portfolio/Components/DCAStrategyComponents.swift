import SwiftUI

// MARK: - Step Indicator
struct DCAStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - Strategy Type Card
struct DCAStrategyTypeCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedStrategy: DCAStrategyType

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your DCA strategy")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select how you want to trigger your investments")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                ForEach(DCAStrategyType.allCases) { strategy in
                    DCAStrategyOptionCard(
                        strategy: strategy,
                        isSelected: selectedStrategy == strategy,
                        onSelect: { selectedStrategy = strategy }
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Strategy Option Card
struct DCAStrategyOptionCard: View {
    let strategy: DCAStrategyType
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.15) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                        .frame(width: 48, height: 48)

                    Image(systemName: strategy.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(strategy.rawValue)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text(strategy.description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Score Type Card
struct DCAScoreTypeCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedScoreType: DCAScoreType

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which risk model?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Choose which scoring method should determine your risk levels. This affects when your DCA purchases are triggered.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                ForEach(DCAScoreType.allCases) { scoreType in
                    DCAScoreTypeOptionCard(
                        scoreType: scoreType,
                        isSelected: selectedScoreType == scoreType,
                        onSelect: { selectedScoreType = scoreType }
                    )
                }
            }

            // Explanation
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "FFD600"))

                Text("Regression is simpler and based on long-term fair value. Composite uses multiple market signals for a more nuanced view.")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
            )
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Score Type Option Card
struct DCAScoreTypeOptionCard: View {
    let scoreType: DCAScoreType
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.15) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                        .frame(width: 48, height: 48)

                    Image(systemName: scoreType.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(scoreType.rawValue)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text(scoreType.description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(3)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk Band Card
struct DCARiskBandCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedBands: Set<DCABTCRiskBand>

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When should you buy?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select the BTC risk levels that will trigger your DCA purchases. Lower risk levels are typically better for accumulation.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            // Risk meter visualization
            DCABTCRiskMeter(selectedBands: selectedBands)
                .padding(.vertical, 8)

            // Risk band options
            VStack(spacing: 10) {
                ForEach(DCABTCRiskBand.allCases) { band in
                    DCARiskBandOptionRow(
                        band: band,
                        isSelected: selectedBands.contains(band),
                        onToggle: { toggleBand(band) }
                    )
                }
            }

            // Selected bands summary
            if !selectedBands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You'll be notified when BTC risk is:")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)

                    let sortedBands = selectedBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
                    if let firstBand = sortedBands.first, let lastBand = sortedBands.last {
                        let rangeText = String(format: "%.2f - %.2f", firstBand.riskRange.lowerBound / 100, lastBand.riskRange.upperBound / 100)
                        Text("\(sortedBands.map { $0.rawValue }.joined(separator: ", ")) (\(rangeText))")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }

    private func toggleBand(_ band: DCABTCRiskBand) {
        if selectedBands.contains(band) {
            selectedBands.remove(band)
        } else {
            selectedBands.insert(band)
        }
    }
}

// MARK: - BTC Risk Meter
struct DCABTCRiskMeter: View {
    let selectedBands: Set<DCABTCRiskBand>
    @Environment(\.colorScheme) var colorScheme

    /// Width proportion for each band based on its range size (total = 100)
    private func bandWidth(for band: DCABTCRiskBand, totalWidth: CGFloat) -> CGFloat {
        let rangeSize = band.riskRange.upperBound - band.riskRange.lowerBound
        let gaps = CGFloat(DCABTCRiskBand.allCases.count - 1) * 2
        return (rangeSize / 100.0) * (totalWidth - gaps)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Risk meter bar with proportional widths
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(DCABTCRiskBand.allCases) { band in
                        Rectangle()
                            .fill(Color(hex: band.color).opacity(selectedBands.contains(band) ? 1.0 : 0.3))
                            .frame(width: bandWidth(for: band, totalWidth: geometry.size.width))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            // Labels
            HStack {
                Text("Low Risk")
                    .font(AppFonts.footnote10)
                    .foregroundColor(Color(hex: DCABTCRiskBand.veryLow.color))

                Spacer()

                Text("Extreme Risk")
                    .font(AppFonts.footnote10)
                    .foregroundColor(Color(hex: DCABTCRiskBand.extreme.color))
            }
        }
    }
}

// MARK: - Risk Band Option Row
struct DCARiskBandOptionRow: View {
    let band: DCABTCRiskBand
    let isSelected: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Color indicator
                Circle()
                    .fill(Color(hex: band.color))
                    .frame(width: 12, height: 12)

                // Band info
                VStack(alignment: .leading, spacing: 2) {
                    Text(band.rawValue)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)

                    Text(String(format: "%.2f - %.2f", band.riskRange.lowerBound / 100, band.riskRange.upperBound / 100))
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Portfolio Picker Card
struct DCAPortfolioPickerCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedPortfolioId: UUID?
    @Binding var selectedPortfolioName: String?
    let availablePortfolios: [Portfolio]

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which portfolio?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select the portfolio where DCA transactions will be added")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            if availablePortfolios.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))

                    Text("No portfolios available")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    Text("Create a portfolio first to link your DCA plan")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // Portfolio list
                VStack(spacing: 10) {
                    ForEach(availablePortfolios) { portfolio in
                        DCAPortfolioOptionRow(
                            portfolio: portfolio,
                            isSelected: selectedPortfolioId == portfolio.id,
                            onSelect: {
                                selectedPortfolioId = portfolio.id
                                selectedPortfolioName = portfolio.name
                            }
                        )
                    }
                }
            }

            // Info note
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)

                Text("DCA transactions will be automatically added to this portfolio when you complete each purchase.")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.accent.opacity(0.08))
            )
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Portfolio Option Row
struct DCAPortfolioOptionRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Portfolio icon
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(portfolio.name)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text("\(portfolio.holdings?.count ?? 0) holdings • \((portfolio.totalValue ?? 0).asCurrency)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
