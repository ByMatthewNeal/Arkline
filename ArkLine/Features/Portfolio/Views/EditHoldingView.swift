import SwiftUI

struct EditHoldingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    let holding: PortfolioHolding
    let onSave: (PortfolioHolding) -> Void

    @State private var quantity: String
    @State private var averageBuyPrice: String
    @State private var isSaving = false

    private var currency: String { appState.preferredCurrency }

    init(holding: PortfolioHolding, onSave: @escaping (PortfolioHolding) -> Void) {
        self.holding = holding
        self.onSave = onSave
        _quantity = State(initialValue: String(holding.quantity))
        _averageBuyPrice = State(initialValue: holding.averageBuyPrice.map { String($0) } ?? "")
    }

    private func parseNumber(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    private var isFormValid: Bool {
        parseNumber(quantity) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Locked asset info
                Section("Asset") {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Text(holding.symbol.uppercased())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Name")
                        Spacer()
                        Text(holding.name)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Asset Type")
                        Spacer()
                        Text(holding.assetType.capitalized)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Editable details
                Section("Details") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0.00", text: $quantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Avg. Buy Price")
                        Spacer()
                        TextField("Optional", text: $averageBuyPrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // Total cost
                if !averageBuyPrice.isEmpty && parseNumber(averageBuyPrice) > 0 {
                    Section {
                        HStack {
                            Text("Total Cost")
                                .font(AppFonts.body14Bold)
                            Spacer()
                            Text((parseNumber(quantity) * parseNumber(averageBuyPrice)).asCurrency(code: currency))
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Holding")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveHolding()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(isFormValid ? AppColors.accent : AppColors.textSecondary)
                        .disabled(!isFormValid)
                    }
                }
            }
            #endif
        }
    }

    private func saveHolding() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        var updated = holding
        updated.quantity = parseNumber(quantity)

        let priceValue = parseNumber(averageBuyPrice)
        updated.averageBuyPrice = averageBuyPrice.isEmpty ? nil : (priceValue > 0 ? priceValue : nil)

        onSave(updated)
        dismiss()
    }
}
