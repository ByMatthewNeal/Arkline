import SwiftUI

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    @State private var transactionType: TransactionType = .buy
    @State private var symbol = ""
    @State private var name = ""
    @State private var assetType: Constants.AssetType = .crypto
    @State private var quantity = ""
    @State private var pricePerUnit = ""
    @State private var transactionDate = Date()
    @State private var notes = ""
    @State private var selectedEmotionalState: EmotionalState?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false

    /// Parse a string that may contain commas as a Double
    private func parseNumber(_ string: String) -> Double {
        let cleaned = string.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    private var isFormValid: Bool {
        // Real estate uses its own form
        if assetType == .realEstate { return false }
        return !symbol.isEmpty &&
        !name.isEmpty &&
        parseNumber(quantity) > 0 &&
        parseNumber(pricePerUnit) > 0
    }

    private var totalValue: Double {
        parseNumber(quantity) * parseNumber(pricePerUnit)
    }

    private var hasPortfolio: Bool {
        viewModel.selectedPortfolio != nil || !viewModel.portfolios.isEmpty
    }

    var body: some View {
        NavigationStack {
            if !hasPortfolio {
                // No portfolio - show helpful message
                noPortfolioView
            } else {
            Form {
                // Transaction Type
                Section {
                    Picker("Type", selection: $transactionType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Asset Details
                Section("Asset") {
                    Picker("Asset Type", selection: $assetType) {
                        ForEach(Constants.AssetType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    if assetType == .realEstate {
                        // Show link to real estate form
                        NavigationLink {
                            AddRealEstateView(viewModel: viewModel)
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundColor(AppColors.accent)
                                Text("Add Property Details")
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    } else {
                        TextField("Symbol (e.g., BTC)", text: $symbol)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        TextField("Name (e.g., Bitcoin)", text: $name)
                            .autocorrectionDisabled()
                    }
                }

                if assetType != .realEstate {
                // Transaction Details
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

                        Text("Track your emotional state when making this decision")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)

                        EmotionalStatePicker(selectedState: $selectedEmotionalState)
                    }
                    .padding(.vertical, 4)
                }

                // Notes
                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                } // End of if assetType != .realEstate
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Add Transaction")
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
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            } // End of else (hasPortfolio)
        }
    }

    // MARK: - No Portfolio View
    private var noPortfolioView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.accent)
            }

            // Message
            VStack(spacing: ArkSpacing.sm) {
                Text("Create a Portfolio First")
                    .font(ArkFonts.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("You need to create a portfolio before you can add transactions.")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ArkSpacing.xl)
            }

            // Instructions
            VStack(spacing: ArkSpacing.sm) {
                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(AppColors.accent)
                    Text("Tap")
                        .foregroundColor(AppColors.textSecondary)
                    Text("Portfolio")
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                    Text("at the top")
                        .foregroundColor(AppColors.textSecondary)
                }
                .font(ArkFonts.body)

                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(AppColors.accent)
                    Text("Tap")
                        .foregroundColor(AppColors.textSecondary)
                    Text("Create Portfolio")
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                }
                .font(ArkFonts.body)
            }
            .padding(.top, ArkSpacing.md)

            Spacer()

            // Close button
            Button(action: { dismiss() }) {
                Text("Got it")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ArkSpacing.md)
                    .background(AppColors.accent)
                    .cornerRadius(ArkSpacing.Radius.md)
            }
            .padding(.horizontal, ArkSpacing.xl)
            .padding(.bottom, ArkSpacing.xl)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Add Transaction")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        #endif
    }

    private func saveTransaction() {
        guard isFormValid else { return }
        guard !isSaving else { return }

        // Get portfolio ID - use selected portfolio, first portfolio, or show error
        guard let portfolioId = viewModel.selectedPortfolio?.id ?? viewModel.portfolios.first?.id else {
            errorMessage = "No portfolio found. Please create a portfolio first."
            showingError = true
            return
        }

        isSaving = true

        let transaction = Transaction(
            portfolioId: portfolioId,
            holdingId: nil,
            type: transactionType,
            assetType: assetType.rawValue,
            symbol: symbol.uppercased(),
            quantity: parseNumber(quantity),
            pricePerUnit: parseNumber(pricePerUnit),
            transactionDate: transactionDate,
            notes: notes.isEmpty ? nil : notes,
            emotionalState: selectedEmotionalState
        )

        Task {
            await viewModel.addTransaction(transaction)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Emotional State Picker
struct EmotionalStatePicker: View {
    @Binding var selectedState: EmotionalState?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(EmotionalState.allCases, id: \.self) { state in
                EmotionalStateChip(
                    state: state,
                    isSelected: selectedState == state,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedState == state {
                                selectedState = nil
                            } else {
                                selectedState = state
                            }
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Flow Layout for Wrapping Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX - spacing)
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Emotional State Chip
struct EmotionalStateChip: View {
    let state: EmotionalState
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var stateColor: Color {
        Color(hex: state.color)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: state.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(state.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? stateColor : AppColors.cardBackground(colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
