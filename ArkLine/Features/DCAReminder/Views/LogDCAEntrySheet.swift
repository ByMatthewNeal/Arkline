import SwiftUI

// MARK: - Log DCA Entry Sheet
struct LogDCAEntrySheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: DCATrackerViewModel
    let plan: DCAPlan

    @State private var selectedDate = Date()
    @State private var amountString = ""
    @State private var priceString = ""
    @State private var notes = ""
    @State private var didInitialize = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { AppColors.cardBackground(colorScheme) }

    private var amount: Double {
        Double(amountString.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var price: Double {
        Double(priceString.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var calculatedQty: Double {
        guard price > 0 else { return 0 }
        return amount / price
    }

    // Post-buy projections
    private var newCumulativeInvested: Double {
        plan.totalInvested + amount
    }

    private var newCumulativeQty: Double {
        plan.currentQty + calculatedQty
    }

    private var newAvgCost: Double {
        guard newCumulativeQty > 0 else { return 0 }
        return (plan.totalCostBasis + amount) / newCumulativeQty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Date picker
                    dateSection

                    // Amount input
                    amountSection

                    // Price input
                    priceSection

                    // Quantity (auto-calculated)
                    quantityDisplay

                    // Notes
                    notesSection

                    // Running totals preview
                    if amount > 0 && price > 0 {
                        runningTotalsCard
                    }

                    // Log button
                    logButton
                }
                .padding(ArkSpacing.lg)
            }
            .navigationTitle("Log DCA Buy")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if !didInitialize {
                    // Pre-fill with recommended amount and live price
                    let recommended = plan.recommendedWeeklyDCA(price: viewModel.livePrice)
                    if recommended > 0 {
                        amountString = String(format: "%.0f", recommended)
                    }
                    if viewModel.livePrice > 0 {
                        priceString = String(format: "%.2f", viewModel.livePrice)
                    }
                    didInitialize = true
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Date")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary.opacity(0.7))

            DatePicker(
                "Purchase Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.timeZone, TimeZone(identifier: "America/New_York")!)
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Amount (USD)")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.7))

                Spacer()

                let recommended = plan.recommendedWeeklyDCA(price: viewModel.livePrice)
                if recommended > 0 {
                    Text("Rec: \(recommended.asCurrency)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.accent)
                }
            }

            HStack {
                Text("$")
                    .font(AppFonts.number20)
                    .foregroundColor(textPrimary.opacity(0.5))

                TextField("0", text: $amountString)
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

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Price Paid")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.7))

                Spacer()

                if viewModel.livePrice > 0 {
                    Button {
                        priceString = String(format: "%.2f", viewModel.livePrice)
                    } label: {
                        Text("Use Live: \(formatPrice(viewModel.livePrice))")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            HStack {
                Text("$")
                    .font(AppFonts.number20)
                    .foregroundColor(textPrimary.opacity(0.5))

                TextField("0", text: $priceString)
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

    // MARK: - Quantity Display

    private var quantityDisplay: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Quantity Bought")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary.opacity(0.7))

            HStack {
                Text(calculatedQty > 0 ? formatQuantity(calculatedQty) : "0")
                    .font(AppFonts.number20)
                    .foregroundColor(calculatedQty > 0 ? textPrimary : textPrimary.opacity(0.3))

                Text(plan.assetSymbol)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.5))

                Spacer()

                Text("Auto-calculated")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.3))
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                    .fill(AppColors.fillSecondary(colorScheme).opacity(0.5))
            )
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Notes (optional)")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary.opacity(0.7))

            TextField("e.g. Bought on Coinbase", text: $notes)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary)
                .padding(ArkSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                        .fill(AppColors.fillSecondary(colorScheme))
                )
        }
    }

    // MARK: - Running Totals Card

    private var runningTotalsCard: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("AFTER THIS BUY")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.accent)

            HStack {
                Text("Cumulative Invested")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                Text(newCumulativeInvested.asCurrency)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
            }

            HStack {
                Text("Total \(plan.assetSymbol)")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                Text(formatQuantity(newCumulativeQty))
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
            }

            HStack {
                Text("New Avg Cost")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                Text("\(formatPrice(newAvgCost))/\(plan.assetSymbol)")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(textPrimary)
            }

            HStack {
                Text("Cash After")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                let cashAfter = plan.cashRemaining - amount
                Text(max(cashAfter, 0).asCurrency)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(cashAfter < 0 ? AppColors.error : textPrimary)
            }
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(AppColors.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            Task {
                await viewModel.logEntry(
                    date: selectedDate,
                    amount: amount,
                    price: price,
                    notes: notes.isEmpty ? nil : notes
                )
                dismiss()
            }
        } label: {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Log Buy")
                    .font(AppFonts.body14Bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                    .fill(canLog ? AppColors.accent : AppColors.accent.opacity(0.5))
            )
        }
        .disabled(!canLog)
    }

    private var canLog: Bool {
        amount > 0 && price > 0
    }

    // MARK: - Formatting

    private func formatQuantity(_ qty: Double) -> String {
        if qty >= 1 {
            return String(format: "%.4f", qty)
        } else {
            return String(format: "%.6f", qty)
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return "$\(String(format: "%.0f", price))"
        } else if price >= 1 {
            return "$\(String(format: "%.2f", price))"
        } else {
            return "$\(String(format: "%.4f", price))"
        }
    }
}

#Preview {
    LogDCAEntrySheet(
        viewModel: DCATrackerViewModel(),
        plan: DCAPlan(
            id: UUID(),
            userId: UUID(),
            assetSymbol: "BTC",
            assetName: "Bitcoin",
            targetAllocationPct: 80,
            cashAllocationPct: 20,
            startingCapital: 50000,
            startingQty: 0,
            preDcaAvgCost: nil,
            frequency: "weekly",
            startDate: "2026-04-02",
            endDate: "2026-10-01",
            totalWeeks: 26,
            currentQty: 0.2345,
            totalInvested: 8240,
            cashRemaining: 32615,
            streakCurrent: 8,
            streakBest: 8,
            status: "active",
            createdAt: Date()
        )
    )
}
