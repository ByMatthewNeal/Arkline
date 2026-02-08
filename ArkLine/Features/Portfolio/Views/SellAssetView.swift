import SwiftUI

struct SellAssetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    let holding: PortfolioHolding

    // Form state
    @State private var quantityString = ""
    @State private var priceString = ""
    @State private var feeString = ""
    @State private var transactionDate = Date()
    @State private var notes = ""
    @State private var selectedEmotionalState: EmotionalState?

    // Transfer state
    @State private var transferToPortfolio = false
    @State private var selectedDestinationPortfolio: Portfolio?
    @State private var convertToCash = true

    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    private var quantity: Double {
        Double(quantityString) ?? 0
    }

    private var salePrice: Double {
        Double(priceString) ?? (holding.currentPrice ?? 0)
    }

    private var fee: Double {
        Double(feeString) ?? 0
    }

    private var totalProceeds: Double {
        (quantity * salePrice) - fee
    }

    private var costBasis: Double {
        quantity * (holding.averageBuyPrice ?? 0)
    }

    private var profitLoss: Double {
        totalProceeds - costBasis
    }

    private var profitLossPercentage: Double {
        guard costBasis > 0 else { return 0 }
        return (profitLoss / costBasis) * 100
    }

    private var isValid: Bool {
        quantity > 0 &&
        quantity <= holding.quantity &&
        salePrice > 0 &&
        fee >= 0 &&
        totalProceeds > 0
    }

    private var isRealEstate: Bool {
        holding.assetType == Constants.AssetType.realEstate.rawValue
    }

    var body: some View {
        NavigationStack {
            Form {
                // Asset Info Section
                Section {
                    HStack(spacing: 12) {
                        if isRealEstate {
                            RealEstateIconView(size: 44)
                        } else {
                            CoinIconView(symbol: holding.symbol, size: 44)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(isRealEstate ? holding.symbol : holding.symbol.uppercased())
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text(holding.name)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Available")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)

                            Text(isRealEstate ? "1" : holding.quantity.asQuantity)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Quantity Section
                Section("Sell Amount") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantityString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)

                        Button("Max") {
                            quantityString = isRealEstate ? "1" : String(format: "%.8f", holding.quantity)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.accent)
                    }

                    if quantity > holding.quantity {
                        Text("Cannot sell more than available quantity")
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                    }
                }

                // Price Section
                Section("Sale Price") {
                    HStack {
                        Text("Price per unit")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $priceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if let currentPrice = holding.currentPrice {
                        Button("Use current price: \(currentPrice.asCurrency)") {
                            priceString = String(format: "%.2f", currentPrice)
                        }
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.accent)
                    }

                    HStack {
                        Text("Fee (optional)")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $feeString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                }

                // Summary Section
                if quantity > 0 && salePrice > 0 {
                    Section("Summary") {
                        HStack {
                            Text("Total Proceeds")
                            Spacer()
                            Text(totalProceeds.asCurrency)
                                .font(.system(size: 16, weight: .semibold))
                        }

                        HStack {
                            Text("Cost Basis")
                            Spacer()
                            Text(costBasis.asCurrency)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        HStack {
                            Text("Profit / Loss")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(profitLoss >= 0 ? "+" : "")\(profitLoss.asCurrency)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(profitLoss >= 0 ? AppColors.success : AppColors.error)

                                Text("\(profitLoss >= 0 ? "+" : "")\(String(format: "%.2f", profitLossPercentage))%")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }

                // Transfer Section
                Section {
                    Toggle("Transfer proceeds to another portfolio", isOn: $transferToPortfolio)

                    if transferToPortfolio {
                        Picker("Destination", selection: $selectedDestinationPortfolio) {
                            Text("Select portfolio").tag(nil as Portfolio?)
                            ForEach(viewModel.portfolios.filter { $0.id != viewModel.selectedPortfolio?.id }) { portfolio in
                                Text(portfolio.name).tag(portfolio as Portfolio?)
                            }
                        }

                        if selectedDestinationPortfolio != nil {
                            Toggle("Add as cash/USDT", isOn: $convertToCash)

                            if !convertToCash {
                                Text("Proceeds will be used to buy the same asset in destination portfolio")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Transfer (Optional)")
                } footer: {
                    if !transferToPortfolio {
                        Text("Proceeds will be recorded as a withdrawal from this portfolio")
                    }
                }

                // Emotional State Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How are you feeling about this sale?")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        EmotionalStatePicker(selectedState: $selectedEmotionalState)
                    }
                    .padding(.vertical, 4)
                }

                // Notes Section
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Sell \(isRealEstate ? holding.symbol : holding.symbol.uppercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Sell") {
                        executeSale()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isValid ? AppColors.error : AppColors.textSecondary.opacity(0.5))
                    .disabled(!isValid || isSaving)
                }
            }
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
            .onAppear {
                // Pre-fill with current price
                if let price = holding.currentPrice {
                    priceString = String(format: "%.2f", price)
                }
            }
        }
    }

    private func executeSale() {
        guard isValid else { return }

        isSaving = true

        Task {
            do {
                try await viewModel.sellAsset(
                    holding: holding,
                    quantity: quantity,
                    pricePerUnit: salePrice,
                    fee: fee,
                    date: transactionDate,
                    notes: notes.isEmpty ? nil : notes,
                    emotionalState: selectedEmotionalState,
                    transferToPortfolio: transferToPortfolio ? selectedDestinationPortfolio : nil,
                    convertToCash: convertToCash
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    SellAssetView(
        viewModel: PortfolioViewModel(),
        holding: PortfolioHolding(
            portfolioId: UUID(),
            assetType: "crypto",
            symbol: "BTC",
            name: "Bitcoin",
            quantity: 0.5,
            averageBuyPrice: 45000
        ).withLiveData(currentPrice: 67500, change24h: 2.5)
    )
}
