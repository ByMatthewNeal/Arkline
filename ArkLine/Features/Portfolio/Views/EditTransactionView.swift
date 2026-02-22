import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let transaction: Transaction
    let onSave: (Transaction) -> Void

    @State private var quantity: String
    @State private var pricePerUnit: String
    @State private var transactionDate: Date
    @State private var notes: String
    @State private var selectedEmotionalState: EmotionalState?
    @State private var isSaving = false

    init(transaction: Transaction, onSave: @escaping (Transaction) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        _quantity = State(initialValue: String(transaction.quantity))
        _pricePerUnit = State(initialValue: String(transaction.pricePerUnit))
        _transactionDate = State(initialValue: transaction.transactionDate)
        _notes = State(initialValue: transaction.notes ?? "")
        _selectedEmotionalState = State(initialValue: transaction.emotionalState)
    }

    private func parseNumber(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    private var isFormValid: Bool {
        parseNumber(quantity) > 0 && parseNumber(pricePerUnit) > 0
    }

    private var totalValue: Double {
        parseNumber(quantity) * parseNumber(pricePerUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Locked asset info
                Section("Asset") {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Text(transaction.symbol.uppercased())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Type")
                        Spacer()
                        Text(transaction.type.displayName)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack {
                        Text("Asset Type")
                        Spacer()
                        Text(transaction.assetType.capitalized)
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
                        Text("Price per Unit")
                        Spacer()
                        TextField("$0.00", text: $pricePerUnit)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                }

                // Total
                Section {
                    HStack {
                        Text("Total Value")
                            .font(AppFonts.body14Bold)
                        Spacer()
                        Text(totalValue.asCurrency)
                            .font(AppFonts.title18SemiBold)
                            .foregroundColor(AppColors.accent)
                    }
                }

                // Emotional State
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How are you feeling?")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        EmotionalStatePicker(selectedState: $selectedEmotionalState)
                    }
                    .padding(.vertical, 4)
                }

                // Notes
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Transaction")
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
                            saveTransaction()
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

    private func saveTransaction() {
        guard isFormValid, !isSaving else { return }
        isSaving = true

        let newQty = parseNumber(quantity)
        let newPrice = parseNumber(pricePerUnit)

        var updated = transaction
        updated.quantity = newQty
        updated.pricePerUnit = newPrice
        updated.totalValue = (newQty * newPrice) - transaction.gasFee
        updated.transactionDate = transactionDate
        updated.notes = notes.isEmpty ? nil : notes
        updated.emotionalState = selectedEmotionalState

        onSave(updated)
        dismiss()
    }
}
