import Foundation

// MARK: - Operating Costs ViewModel

@Observable @MainActor
class OperatingCostsViewModel {

    // MARK: - State

    var costs: [OperatingCostDTO] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var showAddSheet = false
    var editingCost: OperatingCostDTO?
    var costToDelete: OperatingCostDTO?

    // MARK: - Dependencies

    private let service = OperatingCostsService()

    // MARK: - Computed

    var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for cost in costs {
            if seen.insert(cost.category).inserted {
                ordered.append(cost.category)
            }
        }
        return ordered
    }

    func costs(for category: String) -> [OperatingCostDTO] {
        costs.filter { $0.category == category }
    }

    var totalMonthly: Double {
        costs.compactMap(\.monthlyCost).reduce(0, +)
    }

    var totalAnnual: Double {
        let monthlyPortion = totalMonthly * 12
        let annualOnly = costs.compactMap(\.annualCost).reduce(0, +)
        return monthlyPortion + annualOnly
    }

    var paidCount: Int {
        costs.filter { ($0.monthlyCost ?? 0) > 0 || ($0.annualCost ?? 0) > 0 }.count
    }

    var freeCount: Int {
        costs.filter { ($0.monthlyCost ?? 0) == 0 && ($0.annualCost ?? 0) == 0 }.count
    }

    func categoryMonthlyTotal(_ category: String) -> Double {
        costs(for: category).compactMap(\.monthlyCost).reduce(0, +)
    }

    // MARK: - CRUD

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            costs = try await service.fetchAll()
        } catch {
            logError("Failed to load operating costs: \(error)", category: .network)
            errorMessage = "Failed to load costs"
        }
    }

    func create(
        name: String, category: String, plan: String,
        monthlyCost: Double?, annualCost: Double?,
        note: String?, isEstimate: Bool, paymentDate: String?
    ) async {
        isSaving = true
        defer { isSaving = false }

        let request = CreateCostRequest(
            name: name, category: category, plan: plan,
            monthlyCost: monthlyCost, annualCost: annualCost,
            note: note?.isEmpty == true ? nil : note,
            isEstimate: isEstimate,
            paymentDate: paymentDate?.isEmpty == true ? nil : paymentDate
        )

        do {
            let created = try await service.create(request)
            costs.append(created)
            costs.sort { ($0.category, $0.name) < ($1.category, $1.name) }
        } catch {
            logError("Failed to create cost: \(error)", category: .network)
            errorMessage = "Failed to add cost"
        }
    }

    func update(
        id: UUID, name: String, category: String, plan: String,
        monthlyCost: Double?, annualCost: Double?,
        note: String?, isEstimate: Bool, paymentDate: String?
    ) async {
        isSaving = true
        defer { isSaving = false }

        let request = UpdateCostRequest(
            name: name, category: category, plan: plan,
            monthlyCost: monthlyCost, annualCost: annualCost,
            note: note?.isEmpty == true ? nil : note,
            isEstimate: isEstimate,
            paymentDate: paymentDate?.isEmpty == true ? nil : paymentDate
        )

        do {
            try await service.update(id: id, request)
            if let idx = costs.firstIndex(where: { $0.id == id }) {
                costs[idx] = OperatingCostDTO(
                    id: id, name: name, category: category, plan: plan,
                    monthlyCost: monthlyCost, annualCost: annualCost,
                    note: note, isEstimate: isEstimate, paymentDate: paymentDate
                )
                costs.sort { ($0.category, $0.name) < ($1.category, $1.name) }
            }
        } catch {
            logError("Failed to update cost: \(error)", category: .network)
            errorMessage = "Failed to update cost"
        }
    }

    func delete(_ cost: OperatingCostDTO) async {
        do {
            try await service.delete(id: cost.id)
            costs.removeAll { $0.id == cost.id }
        } catch {
            logError("Failed to delete cost: \(error)", category: .network)
            errorMessage = "Failed to delete cost"
        }
    }
}
