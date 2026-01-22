import SwiftUI

// MARK: - DCA Calculator View
struct DCACalculatorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var calculatorState = DCACalculatorState()
    @State private var showCreateReminderConfirmation = false
    @State private var reminderCreated = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Step indicator
                    DCAStepIndicator(
                        currentStep: calculatorState.currentStep,
                        totalSteps: 5
                    )
                    .padding(.horizontal, 20)

                    // Current step content
                    currentStepContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                    Spacer(minLength: 120)
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
                // Reset the calculator
                calculatorState = DCACalculatorState()
            }
        } message: {
            if let calc = calculatorState.calculation {
                Text("Your DCA reminder for \(calc.asset.symbol) has been created. You'll invest \(calc.formattedAmountPerPurchase) per purchase.")
            }
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var currentStepContent: some View {
        switch calculatorState.currentStep {
        case 1:
            DCAAmountInputCard(
                amount: $calculatorState.amountString
            )
            .padding(.horizontal, 20)

        case 2:
            DCAAssetPickerCard(
                selectedAsset: $calculatorState.selectedAsset,
                selectedType: $calculatorState.selectedAssetType
            )
            .padding(.horizontal, 20)

        case 3:
            DCAFrequencyCard(
                selectedFrequency: $calculatorState.selectedFrequency,
                selectedDays: $calculatorState.selectedDays
            )
            .padding(.horizontal, 20)

        case 4:
            DCADurationCard(selectedDuration: $calculatorState.selectedDuration)
                .padding(.horizontal, 20)

        case 5:
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
                    Text(calculatorState.currentStep == 5 ? "Create Reminder" : "Continue")
                        .font(AppFonts.body14Bold)
                    if calculatorState.currentStep < 5 {
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
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
                .ignoresSafeArea()
        )
    }

    // MARK: - Validation

    private var canProceed: Bool {
        switch calculatorState.currentStep {
        case 1:
            return calculatorState.amount > 0

        case 2:
            return calculatorState.selectedAsset != nil

        case 3:
            // For weekly, must have at least one day selected
            if calculatorState.selectedFrequency == .weekly {
                return !calculatorState.selectedDays.isEmpty
            }
            return true

        case 4:
            return calculatorState.selectedDuration != nil

        case 5:
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
        if calculatorState.currentStep == 5 {
            createReminder()
        } else {
            withAnimation {
                calculatorState.currentStep += 1
            }
        }
    }

    private func createReminder() {
        guard let calculation = calculatorState.calculation else { return }

        // Create DCA reminder using existing DCA system
        let reminder = DCAReminder(
            userId: UUID(), // In real app, get from auth service
            symbol: calculation.asset.symbol,
            name: calculation.asset.name,
            amount: calculation.amountPerPurchase,
            frequency: calculation.frequency,
            totalPurchases: calculation.numberOfPurchases,
            completedPurchases: 0,
            notificationTime: Date(),
            startDate: calculation.startDate,
            isActive: true
        )

        // Create via the DCA service
        Task {
            let dcaService = ServiceContainer.shared.dcaService
            let request = CreateDCARequest(
                userId: reminder.userId,
                symbol: reminder.symbol,
                name: reminder.name,
                amount: reminder.amount,
                frequency: reminder.frequency.rawValue,
                totalPurchases: reminder.totalPurchases,
                notificationTime: reminder.notificationTime,
                startDate: reminder.startDate,
                nextReminderDate: reminder.nextReminderDate ?? Date()
            )

            do {
                _ = try await dcaService.createReminder(request)
                await MainActor.run {
                    reminderCreated = true
                }
            } catch {
                // Handle error - could show an alert
                print("Failed to create DCA reminder: \(error)")
            }
        }
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

    // Step 2: Asset
    var selectedAsset: DCAAsset?
    var selectedAssetType: DCAAssetType = .crypto

    // Step 3: Frequency
    var selectedFrequency: DCAFrequency = .weekly
    var selectedDays: Set<Weekday> = [.friday]

    // Step 4: Duration
    var selectedDuration: DCADuration?

    // Computed calculation
    var calculation: DCACalculation? {
        guard amount > 0,
              let asset = selectedAsset,
              let duration = selectedDuration else {
            return nil
        }

        return DCACalculatorService.calculate(
            totalAmount: amount,
            asset: asset,
            frequency: selectedFrequency,
            duration: duration,
            startDate: Date(),
            selectedDays: selectedDays
        )
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
