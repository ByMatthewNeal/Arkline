import SwiftUI

// MARK: - Investment Budget Calculator
/// A budgeting tool that works out how much of a member's own monthly income is
/// left over to invest, then hands off to the DCA reminder + model portfolios.
///
/// IMPORTANT — this is a BUDGETING tool, not investment advice. It only does
/// arithmetic on numbers the user enters, and the user chooses the share of
/// their surplus. It never recommends an amount or an allocation, and never
/// projects investment returns (the "over a year" figure is just contributions
/// × 12). Keep it that way — see FinancialDisclaimer below.
struct BudgetCalculatorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// When presented from the DCA create sheet, this feeds the chosen monthly
    /// amount back into that form. When nil (standalone), the view offers to
    /// open a DCA reminder itself.
    var onUseAmount: ((Double) -> Void)?

    // Persisted on-device only (no financial data leaves the phone).
    @AppStorage("budget_income") private var incomeText = ""
    @AppStorage("budget_expenses") private var expensesText = ""
    @AppStorage("budget_savings") private var savingsText = ""
    @AppStorage("budget_fun") private var funText = ""
    @AppStorage("budget_share_pct") private var sharePct = 0.0

    @State private var dcaViewModel = DCAViewModel()
    @State private var showDCASheet = false

    private var currency: String { appState.preferredCurrency }
    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var sectionBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var currencySymbol: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        return f.currencySymbol ?? "$"
    }

    private func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var income: Double { parse(incomeText) }
    private var surplus: Double {
        max(0, income - parse(expensesText) - parse(savingsText) - parse(funText))
    }
    private var investMonthly: Double { surplus * sharePct / 100 }
    private var investAnnual: Double { investMonthly * 12 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    inputsCard
                    if surplus > 0 { resultCard } else { emptyHint }
                    FinancialDisclaimer()
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Investment Budget")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .sheet(isPresented: $showDCASheet) {
                CreateDCASheetView(
                    viewModel: dcaViewModel,
                    prefilledAmount: investMonthly,
                    prefilledFrequency: .monthly
                )
            }
        }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What can I invest?")
                .font(AppFonts.title20)
                .foregroundColor(textPrimary)
            Text("Enter your own numbers to see what's left over each month. You decide how much of that surplus to put toward investing — nothing here is a recommendation.")
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.65))
        }
        .padding(.top, 4)
    }

    // MARK: Inputs

    private var inputsCard: some View {
        VStack(spacing: 14) {
            inputRow("Monthly income", subtitle: "Your take-home pay", text: $incomeText)
            Divider()
            inputRow("Fixed expenses", subtitle: "Rent, insurance, bills, gas, subscriptions", text: $expensesText)
            Divider()
            inputRow("Monthly savings", subtitle: "Cash you set aside", text: $savingsText)
            Divider()
            inputRow("Fun money", subtitle: "Eating out, gifts, trips (optional)", text: $funText)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(sectionBackground))
    }

    private func inputRow(_ title: String, subtitle: String, text: Binding<String>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
                Text(subtitle)
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.55))
            }
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 16))
                    .foregroundColor(textPrimary.opacity(0.6))
                TextField("0", text: text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 70)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
        }
    }

    private var emptyHint: some View {
        Text("Enter your income and expenses above to see your investable surplus.")
            .font(AppFonts.body14)
            .foregroundColor(textPrimary.opacity(0.6))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(sectionBackground))
    }

    // MARK: Result

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Left over to invest")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                Text(surplus.asCurrency(code: currency))
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(textPrimary)
            }

            Divider()

            // User-chosen share of the surplus (starts at 0 — the app never picks).
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("How much of that do you want to invest?")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                    Spacer()
                    Text("\(Int(sharePct))%")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.accent)
                }
                Slider(value: $sharePct, in: 0...100, step: 5)
                    .tint(AppColors.accent)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("You'd invest")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.6))
                Text("\(investMonthly.asCurrency(code: currency)) / month")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(AppColors.accent)
                Text("≈ \(investAnnual.asCurrency(code: currency)) contributed over a year at this pace")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.55))
            }

            actionButtons
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(sectionBackground))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let onUseAmount {
            // Presented from the DCA sheet — feed the amount back into the form.
            Button {
                onUseAmount(investMonthly)
                dismiss()
            } label: {
                Text("Use \(investMonthly.asCurrency(code: currency)) / month")
                    .font(AppFonts.body16Medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
            }
            .disabled(investMonthly <= 0)
            .opacity(investMonthly <= 0 ? 0.5 : 1)
        } else {
            // Standalone — offer to open a monthly DCA reminder prefilled.
            Button {
                showDCASheet = true
            } label: {
                Text("Set up a monthly DCA reminder")
                    .font(AppFonts.body16Medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
            }
            .disabled(investMonthly <= 0)
            .opacity(investMonthly <= 0 ? 0.5 : 1)

            Text("Then choose a strategy on your Portfolio tab — the Model Portfolios card shows what each one holds.")
                .font(AppFonts.caption12)
                .foregroundColor(textPrimary.opacity(0.55))
        }
    }
}

// MARK: - Entry Card (Portfolio overview)
/// Tappable card that opens the Investment Budget calculator.
struct BudgetCalculatorCard: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var showCalculator = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        Button {
            showCalculator = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "function")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Investment Budget")
                        .font(AppFonts.body16Medium)
                        .foregroundColor(textPrimary)
                    Text("Work out what you can afford to invest")
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.3))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(cardBackground))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCalculator) {
            BudgetCalculatorView()
        }
    }
}
