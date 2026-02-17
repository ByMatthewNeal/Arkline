import SwiftUI

struct AddRealEstateView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    // Property Details
    @State private var propertyName = ""
    @State private var address = ""
    @State private var propertyType: PropertyType = .house
    @State private var squareFootage = ""

    // Purchase Information
    @State private var purchasePrice = ""
    @State private var purchaseDate = Date()

    // Valuation
    @State private var currentEstimatedValue = ""

    // Rental Income
    @State private var monthlyRentalIncome = ""
    @State private var monthlyExpenses = ""

    // Notes
    @State private var notes = ""

    // UI State
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    private var isFormValid: Bool {
        !propertyName.isEmpty &&
        !address.isEmpty &&
        Double(purchasePrice) ?? 0 > 0 &&
        Double(currentEstimatedValue) ?? 0 > 0
    }

    private var appreciation: Double {
        let purchase = Double(purchasePrice) ?? 0
        let current = Double(currentEstimatedValue) ?? 0
        return current - purchase
    }

    private var appreciationPercentage: Double {
        let purchase = Double(purchasePrice) ?? 0
        guard purchase > 0 else { return 0 }
        return (appreciation / purchase) * 100
    }

    private var monthlyNetIncome: Double {
        let income = Double(monthlyRentalIncome) ?? 0
        let expenses = Double(monthlyExpenses) ?? 0
        return income - expenses
    }

    var body: some View {
        NavigationStack {
            Form {
                // Property Details Section
                Section("Property Details") {
                    TextField("Property Name", text: $propertyName)
                        .autocorrectionDisabled()

                    TextField("Address", text: $address)
                        .autocorrectionDisabled()

                    Picker("Property Type", selection: $propertyType) {
                        ForEach(PropertyType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    HStack {
                        Text("Square Footage")
                        Spacer()
                        TextField("Optional", text: $squareFootage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        if !squareFootage.isEmpty {
                            Text("sq ft")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                // Purchase Information Section
                Section("Purchase Information") {
                    HStack {
                        Text("Purchase Price")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                }

                // Current Valuation Section
                Section("Current Valuation") {
                    HStack {
                        Text("Estimated Value")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $currentEstimatedValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if let purchase = Double(purchasePrice), purchase > 0,
                       let current = Double(currentEstimatedValue), current > 0 {
                        HStack {
                            Text("Appreciation")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(appreciation.asCurrency)
                                    .foregroundColor(appreciation >= 0 ? AppColors.success : AppColors.error)
                                Text("\(appreciationPercentage >= 0 ? "+" : "")\(String(format: "%.1f", appreciationPercentage))%")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }

                // Rental Income Section
                Section {
                    HStack {
                        Text("Monthly Rent")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $monthlyRentalIncome)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Monthly Expenses")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $monthlyExpenses)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if let income = Double(monthlyRentalIncome), income > 0 {
                        HStack {
                            Text("Net Monthly Income")
                            Spacer()
                            Text(monthlyNetIncome.asCurrency)
                                .foregroundColor(monthlyNetIncome >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                } header: {
                    Text("Rental Income (Optional)")
                } footer: {
                    Text("Include property tax, HOA fees, insurance, and maintenance in expenses")
                }

                // Notes Section
                Section("Notes (Optional)") {
                    TextField("Add notes about this property...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Add Property")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProperty()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(isFormValid ? AppColors.accent : AppColors.textSecondary)
                    .disabled(!isFormValid || isSaving)
                }
            }
            #endif
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
        }
    }

    private func saveProperty() {
        guard isFormValid else { return }

        isSaving = true

        Task {
            do {
                try await viewModel.addRealEstateProperty(
                    propertyName: propertyName,
                    address: address,
                    propertyType: propertyType,
                    squareFootage: Double(squareFootage),
                    purchasePrice: Double(purchasePrice) ?? 0,
                    purchaseDate: purchaseDate,
                    currentEstimatedValue: Double(currentEstimatedValue) ?? 0,
                    monthlyRentalIncome: Double(monthlyRentalIncome),
                    monthlyExpenses: Double(monthlyExpenses),
                    notes: notes.isEmpty ? nil : notes
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = AppError.from(error).userMessage
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    AddRealEstateView(viewModel: PortfolioViewModel())
}
