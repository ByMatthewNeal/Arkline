import SwiftUI

// MARK: - Operating Costs View

struct OperatingCostsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = OperatingCostsViewModel()

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if viewModel.isLoading && viewModel.costs.isEmpty {
                ProgressView("Loading costs...")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView {
                    VStack(spacing: ArkSpacing.lg) {
                        summaryCard

                        ForEach(viewModel.categories, id: \.self) { category in
                            categoryCard(category)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, ArkSpacing.md)
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Operating Costs")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.showAddSheet) {
            CostFormSheet(viewModel: viewModel, editing: nil)
        }
        .sheet(item: $viewModel.editingCost) { cost in
            CostFormSheet(viewModel: viewModel, editing: cost)
        }
        .alert("Delete Cost?", isPresented: .init(
            get: { viewModel.costToDelete != nil },
            set: { if !$0 { viewModel.costToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let cost = viewModel.costToDelete {
                    Task { await viewModel.delete(cost) }
                }
            }
            Button("Cancel", role: .cancel) { viewModel.costToDelete = nil }
        } message: {
            if let cost = viewModel.costToDelete {
                Text("Remove \(cost.name) from operating costs?")
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: ArkSpacing.lg) {
            VStack(spacing: 4) {
                Text("Monthly Overhead")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)

                Text("$\(Int(viewModel.totalMonthly))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("/month")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))

            HStack(spacing: ArkSpacing.xl) {
                VStack(spacing: 4) {
                    Text("$\(Int(viewModel.totalAnnual))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("Annual")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("\(viewModel.paidCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.warning)
                    Text("Paid")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("\(viewModel.freeCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.success)
                    Text("Free")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(ArkSpacing.lg)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Category Card

    private func categoryCard(_ category: String) -> some View {
        let items = viewModel.costs(for: category)
        let icon = categoryIcon(category)

        return VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text(category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                let total = viewModel.categoryMonthlyTotal(category)
                if total > 0 {
                    Text("$\(Int(total))/mo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                }
            }

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06))

            ForEach(items) { item in
                costRow(item)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button { viewModel.editingCost = item } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { viewModel.costToDelete = item } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(ArkSpacing.md)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Cost Row

    private func costRow(_ item: OperatingCostDTO) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(item.plan)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.05)
                        )
                        .cornerRadius(4)
                }

                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let paymentDate = item.paymentDate, !paymentDate.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text(paymentDate)
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.accent.opacity(0.7))
                }
            }

            Spacer()

            if let monthly = item.monthlyCost {
                if monthly > 0 {
                    Text("\(item.isEstimate ? "~" : "")$\(Int(monthly))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                } else {
                    Text("Free")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.success)
                }
            } else if let annual = item.annualCost {
                Text("$\(Int(annual))/yr")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "Market Data APIs": return "chart.line.uptrend.xyaxis"
        case "AI & Intelligence": return "sparkles"
        case "Infrastructure": return "server.rack"
        case "Design & Branding": return "paintbrush.fill"
        case "Payments & Distribution": return "creditcard.fill"
        case "Free APIs": return "gift.fill"
        default: return "folder.fill"
        }
    }
}

// MARK: - Cost Form Sheet

private struct CostFormSheet: View {
    @Bindable var viewModel: OperatingCostsViewModel
    let editing: OperatingCostDTO?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var name = ""
    @State private var category = ""
    @State private var customCategory = ""
    @State private var plan = ""
    @State private var monthlyCostText = ""
    @State private var annualCostText = ""
    @State private var note = ""
    @State private var isEstimate = false
    @State private var paymentDate = ""
    @State private var costType = CostType.monthly

    enum CostType: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual Only"
        case free = "Free"
    }

    private let defaultCategories = [
        "Market Data APIs",
        "AI & Intelligence",
        "Infrastructure",
        "Design & Branding",
        "Payments & Distribution",
        "Free APIs",
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !resolvedCategory.isEmpty &&
        !plan.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var resolvedCategory: String {
        category == "Custom" ? customCategory.trimmingCharacters(in: .whitespaces) : category
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Service") {
                    TextField("Name", text: $name)
                    TextField("Plan", text: $plan)
                        .autocorrectionDisabled()
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(defaultCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                        Text("Custom").tag("Custom")
                    }

                    if category == "Custom" {
                        TextField("Custom category name", text: $customCategory)
                    }
                }

                Section("Cost") {
                    Picker("Type", selection: $costType) {
                        ForEach(CostType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if costType == .monthly {
                        HStack {
                            Text("$")
                            TextField("0", text: $monthlyCostText)
                                .keyboardType(.decimalPad)
                            Text("/month")
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Toggle("Estimate", isOn: $isEstimate)
                    }

                    if costType == .annual {
                        HStack {
                            Text("$")
                            TextField("0", text: $annualCostText)
                                .keyboardType(.decimalPad)
                            Text("/year")
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                Section("Details") {
                    TextField("Note (optional)", text: $note)
                    TextField("Payment date (optional)", text: $paymentDate)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(editing == nil ? "Add Cost" : "Edit Cost")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || viewModel.isSaving)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        if let cost = editing {
            name = cost.name
            plan = cost.plan
            note = cost.note ?? ""
            isEstimate = cost.isEstimate
            paymentDate = cost.paymentDate ?? ""

            if defaultCategories.contains(cost.category) {
                category = cost.category
            } else {
                category = "Custom"
                customCategory = cost.category
            }

            if let monthly = cost.monthlyCost, monthly > 0 {
                costType = .monthly
                monthlyCostText = "\(Int(monthly))"
            } else if let annual = cost.annualCost, annual > 0 {
                costType = .annual
                annualCostText = "\(Int(annual))"
            } else {
                costType = .free
            }
        } else {
            category = defaultCategories.first ?? ""
        }
    }

    private func save() async {
        let monthlyCost: Double? = costType == .monthly ? (Double(monthlyCostText) ?? 0) : nil
        let annualCost: Double? = costType == .annual ? (Double(annualCostText) ?? 0) : nil

        if let cost = editing {
            await viewModel.update(
                id: cost.id, name: name, category: resolvedCategory, plan: plan,
                monthlyCost: monthlyCost, annualCost: annualCost,
                note: note, isEstimate: isEstimate, paymentDate: paymentDate
            )
        } else {
            await viewModel.create(
                name: name, category: resolvedCategory, plan: plan,
                monthlyCost: monthlyCost, annualCost: annualCost,
                note: note, isEstimate: isEstimate, paymentDate: paymentDate
            )
        }

        dismiss()
    }
}

#Preview {
    NavigationStack {
        OperatingCostsView()
            .environmentObject(AppState())
    }
}
