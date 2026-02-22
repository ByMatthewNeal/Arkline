import SwiftUI

// MARK: - DCA Calculator View
struct DCACalculatorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var calculatorState = DCACalculatorState()
    @State private var reminderCreated = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var totalSteps: Int {
        calculatorState.strategyType == .timeBased ? 6 : 6
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Step indicator
                    DCAStepIndicator(
                        currentStep: calculatorState.currentStep,
                        totalSteps: totalSteps
                    )
                    .padding(.horizontal, 20)

                    // Current step content
                    currentStepContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    Spacer(minLength: 160)
                }
                .padding(.top, 16)
            }

            // Bottom navigation
            VStack {
                Spacer()
                navigationButtons
            }
        }
        .animation(.easeInOut(duration: 0.3), value: calculatorState.currentStep)
        .alert("DCA Reminder Created", isPresented: $reminderCreated) {
            Button("OK") {
                calculatorState = DCACalculatorState()
            }
        } message: {
            if let calc = calculatorState.calculation {
                if calc.strategyType == .timeBased {
                    Text("Your DCA reminder for \(calc.asset.symbol) has been created. You'll invest \(calc.formattedAmountPerPurchase) per purchase to \(calc.targetPortfolioName ?? "your portfolio").")
                } else {
                    Text("Your risk-based DCA for \(calc.asset.symbol) has been created. You'll be notified when BTC risk reaches \(calc.riskBandDescription) levels.")
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }
        .onAppear {
            // Load portfolios for selection
            calculatorState.availablePortfolios = viewModel.portfolios
            if let selected = viewModel.selectedPortfolio {
                calculatorState.selectedPortfolioId = selected.id
                calculatorState.selectedPortfolioName = selected.name
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepContent: some View {
        switch calculatorState.currentStep {
        case 1:
            // Step 1: Amount
            DCAAmountInputCard(amount: $calculatorState.amountString)
                .padding(.horizontal, 20)

        case 2:
            // Step 2: Strategy Type
            DCAStrategyTypeCard(
                selectedStrategy: $calculatorState.strategyType
            )
            .padding(.horizontal, 20)

        case 3:
            // Step 3: Asset Selection
            DCAAssetPickerCard(
                selectedAsset: $calculatorState.selectedAsset,
                selectedType: $calculatorState.selectedAssetType,
                isRiskBased: calculatorState.strategyType == .riskBased
            )
            .padding(.horizontal, 20)

        case 4:
            // Step 4: Frequency (time-based) or Score Type (risk-based)
            if calculatorState.strategyType == .timeBased {
                DCAFrequencyCard(
                    selectedFrequency: $calculatorState.selectedFrequency,
                    selectedDays: $calculatorState.selectedDays
                )
                .padding(.horizontal, 20)
            } else {
                DCAScoreTypeCard(
                    selectedScoreType: $calculatorState.selectedScoreType
                )
                .padding(.horizontal, 20)
            }

        case 5:
            // Step 5: Duration (time-based) or Risk Bands (risk-based)
            if calculatorState.strategyType == .timeBased {
                DCADurationCard(selectedDuration: $calculatorState.selectedDuration)
                    .padding(.horizontal, 20)
            } else {
                DCARiskBandCard(
                    selectedBands: $calculatorState.selectedRiskBands
                )
                .padding(.horizontal, 20)
            }

        case 6:
            // Step 6: Portfolio (time-based) or Portfolio (risk-based)
            if calculatorState.strategyType == .timeBased {
                DCAPortfolioPickerCard(
                    selectedPortfolioId: $calculatorState.selectedPortfolioId,
                    selectedPortfolioName: $calculatorState.selectedPortfolioName,
                    availablePortfolios: calculatorState.availablePortfolios
                )
                .padding(.horizontal, 20)
            } else {
                DCAPortfolioPickerCard(
                    selectedPortfolioId: $calculatorState.selectedPortfolioId,
                    selectedPortfolioName: $calculatorState.selectedPortfolioName,
                    availablePortfolios: calculatorState.availablePortfolios
                )
                .padding(.horizontal, 20)
            }

        case 7:
            // Step 7: Summary (both strategies)
            if let calculation = calculatorState.calculation {
                DCACalculationSummaryCard(calculation: calculation)
                    .padding(.horizontal, 20)
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            // Back button
            if calculatorState.currentStep > 1 {
                Button(action: goBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(AppFonts.body14Medium)
                    }
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                    )
                }
            }

            // Continue / Create Reminder button
            Button(action: goForward) {
                HStack(spacing: 8) {
                    Text(isLastStep ? "Create Reminder" : "Continue")
                        .font(AppFonts.body14Bold)
                    if !isLastStep {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canProceed ? AppColors.accent : AppColors.accent.opacity(0.5))
                )
            }
            .disabled(!canProceed)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 120)
    }

    private var isLastStep: Bool {
        return calculatorState.currentStep == 7
    }

    // MARK: - Validation

    private var canProceed: Bool {
        switch calculatorState.currentStep {
        case 1:
            return calculatorState.amount > 0

        case 2:
            return true // Strategy type always has a default

        case 3:
            return calculatorState.selectedAsset != nil

        case 4:
            if calculatorState.strategyType == .timeBased {
                if calculatorState.selectedFrequency == .weekly {
                    return !calculatorState.selectedDays.isEmpty
                }
                return true
            } else {
                return true // Score type always has a default
            }

        case 5:
            if calculatorState.strategyType == .timeBased {
                return calculatorState.selectedDuration != nil
            } else {
                return !calculatorState.selectedRiskBands.isEmpty
            }

        case 6:
            return calculatorState.selectedPortfolioId != nil

        case 7:
            return calculatorState.calculation != nil

        default:
            return false
        }
    }

    // MARK: - Actions

    private func goBack() {
        withAnimation {
            calculatorState.currentStep -= 1
        }
    }

    private func goForward() {
        if isLastStep {
            createReminder()
        } else {
            // When leaving strategy step, validate asset selection
            if calculatorState.currentStep == 2 {
                if calculatorState.strategyType == .riskBased {
                    // Clear asset if it's not a supported risk asset
                    if let asset = calculatorState.selectedAsset {
                        let supported = DCAAsset.riskSupportedCryptoAssets.map { $0.symbol }
                        if !supported.contains(asset.symbol) {
                            calculatorState.selectedAsset = nil
                        }
                    }
                    calculatorState.selectedAssetType = .crypto
                }
            }

            withAnimation {
                calculatorState.currentStep += 1
            }
        }
    }

    private func createReminder() {
        guard let calculation = calculatorState.calculation else { return }

        Task {
            do {
                guard let userId = SupabaseAuthManager.shared.currentUserId else {
                    throw AppError.custom(message: "Please sign in to create DCA reminders")
                }

                if calculation.strategyType == .timeBased {
                    try await createTimeBasedReminder(calculation, userId: userId)
                } else {
                    try await createRiskBasedReminder(calculation, userId: userId)
                }

                await MainActor.run {
                    reminderCreated = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = AppError.from(error).userMessage
                    showError = true
                }
            }
        }
    }

    private func createTimeBasedReminder(_ calculation: DCACalculation, userId: UUID) async throws {
        let dcaService = ServiceContainer.shared.dcaService

        let request = CreateDCARequest(
            userId: userId,
            symbol: calculation.asset.symbol,
            name: calculation.asset.name,
            amount: calculation.amountPerPurchase,
            frequency: calculation.frequency.rawValue,
            totalPurchases: calculation.numberOfPurchases,
            notificationTime: CreateDCARequest.timeString(from: Date()),
            startDate: calculation.startDate,
            nextReminderDate: calculation.purchaseDates.first ?? Date()
        )

        _ = try await dcaService.createReminder(request)
    }

    private func createRiskBasedReminder(_ calculation: DCACalculation, userId: UUID) async throws {
        let dcaService = ServiceContainer.shared.dcaService

        // Get the risk threshold from selected bands
        let sortedBands = calculation.riskBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
        let riskThreshold = sortedBands.first?.riskRange.upperBound ?? 40

        let request = CreateRiskBasedDCARequest(
            userId: userId,
            symbol: calculation.asset.symbol,
            name: calculation.asset.name,
            amount: calculation.totalAmount,
            riskThreshold: riskThreshold,
            riskCondition: RiskCondition.below.rawValue,
            portfolioId: calculation.targetPortfolioId
        )

        _ = try await dcaService.createRiskBasedReminder(request)
    }
}

// MARK: - Calculator State
@Observable
class DCACalculatorState {
    var currentStep: Int = 1

    // Step 1: Amount
    var amountString: String = ""

    var amount: Double {
        Double(amountString.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    // Step 2: Strategy Type
    var strategyType: DCAStrategyType = .timeBased

    // Step 3: Asset
    var selectedAsset: DCAAsset?
    var selectedAssetType: DCAAssetType = .crypto

    // Step 4 (time-based): Frequency
    var selectedFrequency: DCAFrequency = .weekly
    var selectedDays: Set<Weekday> = [.friday]

    // Step 4 (risk-based): Score Type & Risk Bands
    var selectedScoreType: DCAScoreType = .regression
    var selectedRiskBands: Set<DCABTCRiskBand> = []

    // Step 5 (time-based): Duration
    var selectedDuration: DCADuration?

    // Portfolio Selection
    var selectedPortfolioId: UUID?
    var selectedPortfolioName: String?
    var availablePortfolios: [Portfolio] = []

    // Computed calculation
    var calculation: DCACalculation? {
        guard amount > 0, let asset = selectedAsset else { return nil }

        if strategyType == .timeBased {
            guard let duration = selectedDuration else { return nil }

            return DCACalculatorService.calculateTimeBased(
                totalAmount: amount,
                asset: asset,
                frequency: selectedFrequency,
                duration: duration,
                startDate: Date(),
                selectedDays: selectedDays,
                targetPortfolioId: selectedPortfolioId,
                targetPortfolioName: selectedPortfolioName
            )
        } else {
            guard !selectedRiskBands.isEmpty else { return nil }

            return DCACalculatorService.calculateRiskBased(
                totalAmount: amount,
                asset: asset,
                riskBands: selectedRiskBands,
                scoreType: selectedScoreType,
                targetPortfolioId: selectedPortfolioId,
                targetPortfolioName: selectedPortfolioName
            )
        }
    }
}

// MARK: - Empty DCA State
struct EmptyDCACalculatorState: View {
    @Environment(\.colorScheme) var colorScheme
    let onStartTap: () -> Void

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 56))
                .foregroundColor(AppColors.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("DCA Calculator")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(textPrimary)

                Text("Plan your investment schedule and calculate\nhow much to invest per period")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onStartTap) {
                Text("Start Planning")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.accent)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
}

#Preview {
    DCACalculatorView(viewModel: PortfolioViewModel())
}
