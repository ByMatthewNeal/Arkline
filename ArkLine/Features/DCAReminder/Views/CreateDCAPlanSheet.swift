import SwiftUI

// MARK: - Create DCA Plan Sheet (Wizard)
struct CreateDCAPlanSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: DCATrackerViewModel

    @State private var currentStep = 1
    private let totalSteps = 6

    // Step 1: Asset
    @State private var selectedAssetSymbol = "BTC"
    @State private var selectedAssetName = "Bitcoin"

    // Step 2: Strategy Type
    @State private var strategyType: DCAStrategyType = .timeBased

    // Step 3: Capital
    @State private var capitalString = ""
    @State private var existingQtyString = ""
    @State private var existingAvgCostString = ""

    // Step 4: Target allocation
    @State private var targetPct: Double = 80

    // Step 5: Schedule
    @State private var frequency = "weekly"
    @State private var durationWeeks: Int = 26
    @State private var riskBand: String = "low"  // for risk-based: very_low, low, neutral

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { AppColors.cardBackground(colorScheme) }

    private var capital: Double {
        Double(capitalString.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var existingQty: Double {
        Double(existingQtyString.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var existingAvgCost: Double? {
        let val = Double(existingAvgCostString.replacingOccurrences(of: ",", with: ""))
        return val == nil || val == 0 ? nil : val
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: ArkSpacing.lg) {
                        // Step indicator
                        DCAStepIndicator(currentStep: currentStep, totalSteps: totalSteps)
                            .padding(.horizontal, ArkSpacing.lg)

                        // Step content
                        currentStepView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                        Spacer(minLength: 140)
                    }
                    .padding(.top, ArkSpacing.md)
                }

                // Bottom navigation
                VStack {
                    Spacer()
                    navigationButtons
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
            .navigationTitle("Create DCA Plan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 1: assetSelectionStep
        case 2: strategyTypeStep
        case 3: capitalStep
        case 4: allocationStep
        case 5: scheduleStep
        case 6: reviewStep
        default: EmptyView()
        }
    }

    // MARK: - Step 1: Asset Selection

    private var assetSelectionStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Choose an Asset")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)
                .padding(.horizontal, ArkSpacing.lg)

            Text("Select the asset you want to DCA into")
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.6))
                .padding(.horizontal, ArkSpacing.lg)

            VStack(spacing: ArkSpacing.xs) {
                ForEach(availableAssets, id: \.symbol) { asset in
                    Button {
                        selectedAssetSymbol = asset.symbol
                        selectedAssetName = asset.name
                    } label: {
                        HStack(spacing: ArkSpacing.sm) {
                            DCACoinIconView(symbol: asset.symbol, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.symbol)
                                    .font(AppFonts.body14Bold)
                                    .foregroundColor(textPrimary)
                                Text(asset.name)
                                    .font(AppFonts.caption12)
                                    .foregroundColor(textPrimary.opacity(0.5))
                            }

                            Spacer()

                            if selectedAssetSymbol == asset.symbol {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(ArkSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                .fill(selectedAssetSymbol == asset.symbol ? AppColors.accent.opacity(0.1) : cardBg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                .stroke(selectedAssetSymbol == asset.symbol ? AppColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ArkSpacing.lg)
        }
    }

    // MARK: - Step 2: Capital

    private var capitalStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text("Starting Capital")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Total capital to deploy")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.7))

                HStack {
                    Text("$")
                        .font(AppFonts.number24)
                        .foregroundColor(textPrimary.opacity(0.5))

                    TextField("50,000", text: $capitalString)
                        .font(AppFonts.number24)
                        .foregroundColor(textPrimary)
                        .keyboardType(.decimalPad)
                }
                .padding(ArkSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                        .fill(AppColors.fillSecondary(colorScheme))
                )
            }

            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Existing \(selectedAssetSymbol) holdings (optional)")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.7))

                TextField("0", text: $existingQtyString)
                    .font(AppFonts.number20)
                    .foregroundColor(textPrimary)
                    .keyboardType(.decimalPad)
                    .padding(ArkSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                            .fill(AppColors.fillSecondary(colorScheme))
                    )
            }

            if existingQty > 0 {
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Average cost per \(selectedAssetSymbol)")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    HStack {
                        Text("$")
                            .font(AppFonts.number20)
                            .foregroundColor(textPrimary.opacity(0.5))

                        TextField("0", text: $existingAvgCostString)
                            .font(AppFonts.number20)
                            .foregroundColor(textPrimary)
                            .keyboardType(.decimalPad)
                    }
                    .padding(ArkSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                            .fill(AppColors.fillSecondary(colorScheme))
                    )
                }
            }
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Step 3: Target Allocation

    private var allocationStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text("Target Allocation")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("What percentage of your capital should be in \(selectedAssetSymbol)?")
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.6))

            VStack(spacing: ArkSpacing.md) {
                // Visual allocation bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * targetPct / 100)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.fillSecondary(colorScheme))
                    }
                }
                .frame(height: 12)

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(Int(targetPct))% \(selectedAssetSymbol)")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.accent)
                        if capital > 0 {
                            Text(formatCurrency(capital * targetPct / 100))
                                .font(AppFonts.caption12)
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(Int(100 - targetPct))% Cash")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(textPrimary.opacity(0.6))
                        if capital > 0 {
                            Text(formatCurrency(capital * (100 - targetPct) / 100))
                                .font(AppFonts.caption12)
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                    }
                }

                Slider(value: $targetPct, in: 10...100, step: 5)
                    .tint(AppColors.accent)

                // Quick select buttons
                HStack(spacing: ArkSpacing.xs) {
                    ForEach([50, 60, 70, 80, 90, 100], id: \.self) { pct in
                        Button {
                            targetPct = Double(pct)
                        } label: {
                            Text("\(pct)%")
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(Int(targetPct) == pct ? .white : textPrimary.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Int(targetPct) == pct ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Step 2: Strategy Type

    private var strategyTypeStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text("How do you want to DCA?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Choose your approach to dollar-cost averaging.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: ArkSpacing.sm) {
                strategyCard(
                    type: .timeBased,
                    icon: "calendar.badge.clock",
                    title: "Time-Based",
                    description: "Fixed schedule — buy the same amount every week or two weeks regardless of price. Simple and consistent."
                )

                strategyCard(
                    type: .riskBased,
                    icon: "gauge.with.dots.needle.33percent",
                    title: "Risk-Based",
                    description: "Buy more when risk is low, less when risk is high. Uses Arkline's risk model to suggest optimal buy amounts."
                )
            }
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    private func strategyCard(type: DCAStrategyType, icon: String, title: String, description: String) -> some View {
        let isSelected = strategyType == type
        return Button { strategyType = type } label: {
            HStack(alignment: .top, spacing: ArkSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : AppColors.accent)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(isSelected ? .white : textPrimary)
                    Text(description)
                        .font(AppFonts.caption12)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 5: Schedule

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text(strategyType == .riskBased ? "Risk Settings" : "Schedule")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            if strategyType == .riskBased {
                // Risk-based: buy trigger level
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Buy When Risk Reaches")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    Text("The app will notify you to buy when the asset's risk level drops to this band.")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    VStack(spacing: ArkSpacing.xs) {
                        riskBandOption(band: "very_low", label: "Very Low Risk", range: "0.00 – 0.20", description: "Deep value — historically best entries", color: AppColors.success)
                        riskBandOption(band: "low", label: "Low Risk", range: "0.20 – 0.40", description: "Favorable — good accumulation zone", color: AppColors.success.opacity(0.7))
                        riskBandOption(band: "neutral", label: "Neutral", range: "0.40 – 0.55", description: "Fair value — standard DCA", color: AppColors.warning)
                    }
                }

                // Still show duration for risk-based
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Plan Duration")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    HStack(spacing: ArkSpacing.xs) {
                        ForEach([26, 52, 104], id: \.self) { weeks in
                            Button {
                                durationWeeks = weeks
                            } label: {
                                VStack(spacing: 2) {
                                    Text(weeks == 104 ? "2yr" : (weeks == 52 ? "1yr" : "6mo"))
                                        .font(AppFonts.body14Medium)
                                        .foregroundColor(durationWeeks == weeks ? .white : textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ArkSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                        .fill(durationWeeks == weeks ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                                )
                            }
                        }
                    }
                }
            } else {
                // Time-based: frequency + duration
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Purchase Frequency")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    HStack(spacing: ArkSpacing.xs) {
                        ForEach(["weekly", "biweekly"], id: \.self) { freq in
                            Button {
                                frequency = freq
                            } label: {
                                Text(freq.capitalized)
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(frequency == freq ? .white : textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ArkSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                            .fill(frequency == freq ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                                    )
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Duration (weeks)")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    HStack(spacing: ArkSpacing.xs) {
                        ForEach([12, 26, 52], id: \.self) { weeks in
                            Button {
                                durationWeeks = weeks
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(weeks)")
                                        .font(AppFonts.number20)
                                        .foregroundColor(durationWeeks == weeks ? .white : textPrimary)
                                    Text(weeks == 12 ? "3 mo" : (weeks == 26 ? "6 mo" : "1 yr"))
                                        .font(AppFonts.caption12)
                                        .foregroundColor(durationWeeks == weeks ? .white.opacity(0.7) : textPrimary.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ArkSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                        .fill(durationWeeks == weeks ? AppColors.accent : AppColors.fillSecondary(colorScheme))
                                )
                            }
                        }
                    }
                }
            }

            // Estimated weekly DCA (time-based only)
            if strategyType == .timeBased && capital > 0 {
                let weeklyAmount = capital * targetPct / 100 / Double(durationWeeks)
                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text("Estimated Weekly Buy")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(textPrimary.opacity(0.5))
                    Text(formatCurrency(weeklyAmount))
                        .font(AppFonts.number24)
                        .foregroundColor(AppColors.accent)
                }
                .padding(ArkSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                        .fill(AppColors.accent.opacity(0.08))
                )
            }
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    private func riskBandOption(band: String, label: String, range: String, description: String, color: Color) -> some View {
        let isSelected = riskBand == band
        return Button { riskBand = band } label: {
            HStack(spacing: ArkSpacing.sm) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(label)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(isSelected ? .white : textPrimary)
                        Spacer()
                        Text(range)
                            .font(AppFonts.caption12)
                            .foregroundColor(isSelected ? .white.opacity(0.7) : AppColors.textSecondary)
                    }
                    Text(description)
                        .font(AppFonts.caption12)
                        .foregroundColor(isSelected ? .white.opacity(0.7) : AppColors.textSecondary)
                }
            }
            .padding(ArkSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.accent : AppColors.fillSecondary(colorScheme))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 5: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text("Review Your Plan")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            VStack(spacing: ArkSpacing.sm) {
                reviewRow(label: "Asset", value: "\(selectedAssetName) (\(selectedAssetSymbol))")
                reviewRow(label: "Starting Capital", value: formatCurrency(capital))

                if existingQty > 0 {
                    reviewRow(label: "Existing Holdings", value: "\(String(format: "%.4f", existingQty)) \(selectedAssetSymbol)")
                    if let avgCost = existingAvgCost {
                        reviewRow(label: "Existing Avg Cost", value: formatCurrency(avgCost))
                    }
                }

                Divider().background(AppColors.divider(colorScheme))

                reviewRow(label: "Target Allocation", value: "\(Int(targetPct))% \(selectedAssetSymbol) / \(Int(100 - targetPct))% Cash")
                reviewRow(label: "Frequency", value: frequency.capitalized)
                reviewRow(label: "Duration", value: "\(durationWeeks) weeks")

                Divider().background(AppColors.divider(colorScheme))

                let weeklyAmount = capital * targetPct / 100 / Double(durationWeeks)
                reviewRow(label: "Est. Weekly DCA", value: formatCurrency(weeklyAmount), highlight: true)
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .fill(cardBg)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    private func reviewRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary.opacity(0.6))
            Spacer()
            Text(value)
                .font(highlight ? AppFonts.body14Bold : AppFonts.body14Medium)
                .foregroundColor(highlight ? AppColors.accent : textPrimary)
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: ArkSpacing.sm) {
            if currentStep > 1 {
                Button(action: goBack) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(AppFonts.body14Medium)
                    }
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                            .fill(AppColors.fillSecondary(colorScheme))
                    )
                }
            }

            Button(action: goForward) {
                HStack(spacing: ArkSpacing.xs) {
                    Text(currentStep == totalSteps ? "Create Plan" : "Continue")
                        .font(AppFonts.body14Bold)
                    if currentStep < totalSteps {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                        .fill(canProceed ? AppColors.accent : AppColors.accent.opacity(0.5))
                )
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, ArkSpacing.lg)
        .padding(.bottom, ArkSpacing.xxl)
    }

    // MARK: - Validation

    private var canProceed: Bool {
        switch currentStep {
        case 1: return !selectedAssetSymbol.isEmpty
        case 2: return capital > 0
        case 3: return targetPct >= 10
        case 4: return durationWeeks > 0
        case 5: return true
        default: return false
        }
    }

    // MARK: - Actions

    private func goBack() {
        withAnimation { currentStep -= 1 }
    }

    private func goForward() {
        if currentStep == totalSteps {
            createPlan()
        } else {
            withAnimation { currentStep += 1 }
        }
    }

    private func createPlan() {
        Task {
            let freq = strategyType == .riskBased ? "risk_\(riskBand)" : frequency
            await viewModel.createPlan(
                assetSymbol: selectedAssetSymbol,
                assetName: selectedAssetName,
                targetAllocationPct: targetPct,
                startingCapital: capital,
                startingQty: existingQty,
                preDcaAvgCost: existingAvgCost,
                frequency: freq,
                totalWeeks: durationWeeks
            )
            dismiss()
        }
    }

    // MARK: - Formatting

    private func formatCurrency(_ value: Double) -> String {
        value.asCurrency
    }

    // MARK: - Available Assets

    private var availableAssets: [(symbol: String, name: String)] {
        let crypto = CoinOption.cryptoCoins.map { ($0.symbol, $0.name) }
        let stocks = CoinOption.stockCoins.map { ($0.symbol, $0.name) }
        return crypto + stocks
    }
}

#Preview {
    CreateDCAPlanSheet(viewModel: DCATrackerViewModel())
}
