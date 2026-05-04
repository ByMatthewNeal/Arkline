import Foundation

// MARK: - Operating Costs Service
/// CRUD operations for the `operating_costs` Supabase table.
final class OperatingCostsService {

    private let supabase = SupabaseManager.shared

    init() {}

    // MARK: - Fetch

    func fetchAll() async throws -> [OperatingCostDTO] {
        guard supabase.isConfigured else { return [] }

        let costs: [OperatingCostDTO] = try await supabase.database
            .from(SupabaseTable.operatingCosts.rawValue)
            .select()
            .order("category", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value

        return costs
    }

    // MARK: - Create

    func create(_ request: CreateCostRequest) async throws -> OperatingCostDTO {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        let created: OperatingCostDTO = try await supabase.database
            .from(SupabaseTable.operatingCosts.rawValue)
            .insert(request)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update

    func update(id: UUID, _ request: UpdateCostRequest) async throws {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        try await supabase.database
            .from(SupabaseTable.operatingCosts.rawValue)
            .update(request)
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        try await supabase.database
            .from(SupabaseTable.operatingCosts.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - DTO

struct OperatingCostDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let plan: String
    let monthlyCost: Double?
    let annualCost: Double?
    let note: String?
    let isEstimate: Bool
    let paymentDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, plan, note
        case monthlyCost = "monthly_cost"
        case annualCost = "annual_cost"
        case isEstimate = "is_estimate"
        case paymentDate = "payment_date"
    }
}

// MARK: - Request Models

struct CreateCostRequest: Encodable {
    let name: String
    let category: String
    let plan: String
    let monthlyCost: Double?
    let annualCost: Double?
    let note: String?
    let isEstimate: Bool
    let paymentDate: String?

    enum CodingKeys: String, CodingKey {
        case name, category, plan, note
        case monthlyCost = "monthly_cost"
        case annualCost = "annual_cost"
        case isEstimate = "is_estimate"
        case paymentDate = "payment_date"
    }
}

struct UpdateCostRequest: Encodable {
    let name: String
    let category: String
    let plan: String
    let monthlyCost: Double?
    let annualCost: Double?
    let note: String?
    let isEstimate: Bool
    let paymentDate: String?

    enum CodingKeys: String, CodingKey {
        case name, category, plan, note
        case monthlyCost = "monthly_cost"
        case annualCost = "annual_cost"
        case isEstimate = "is_estimate"
        case paymentDate = "payment_date"
    }
}
