import SwiftUI

// MARK: - Allocation Target Editor
struct AllocationTargetEditor: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: PortfolioViewModel

    @State private var targets: [UUID: String] = [:]
    @State private var isSaving = false

    private var totalTarget: Double {
        targets.values.reduce(0) { sum, str in
            sum + (Double(str) ?? 0)
        }
    }

    private var isValid: Bool {
        let total = totalTarget
        // Allow saving if total is 0 (clearing all) or exactly 100
        return total == 0 || (total >= 99.9 && total <= 100.1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total bar
                totalBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .overlay(AppColors.divider(colorScheme))

                // Holdings list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.holdings.sorted(by: { $0.currentValue > $1.currentValue })) { holding in
                            targetRow(holding)
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Target Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid || isSaving)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    @ViewBuilder
    private var totalBar: some View {
        let total = totalTarget
        let barColor: Color = total == 0 ? AppColors.textSecondary :
            (total >= 99.9 && total <= 100.1) ? AppColors.success : AppColors.error

        VStack(spacing: 8) {
            HStack {
                Text("Total")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
                Text("\(total, specifier: "%.1f")%")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.divider(colorScheme))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(total / 100, 1))
                }
            }
            .frame(height: 6)

            if total > 0 && (total < 99.9 || total > 100.1) {
                Text("Must equal 100% to save")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }
        }
    }

    @ViewBuilder
    private func targetRow(_ holding: PortfolioHolding) -> some View {
        let actualPct = viewModel.totalValue > 0 ? (holding.currentValue / viewModel.totalValue) * 100 : 0

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol.uppercased())
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(actualPct, specifier: "%.1f")% actual")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { targets[holding.id] ?? "" },
                    set: { targets[holding.id] = $0 }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .frame(width: 60)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppColors.fillSecondary(colorScheme))
                .cornerRadius(8)

                Text("%")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }

    private func loadExisting() {
        for holding in viewModel.holdings {
            if let target = holding.targetPercentage {
                targets[holding.id] = String(format: "%.0f", target)
            }
        }
    }

    private func save() {
        isSaving = true
        let parsed: [UUID: Double?] = Dictionary(uniqueKeysWithValues:
            viewModel.holdings.map { holding in
                let value = Double(targets[holding.id] ?? "")
                return (holding.id, value != nil && value! > 0 ? value : nil)
            }
        )

        Task {
            await viewModel.updateTargetAllocations(parsed)
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}
