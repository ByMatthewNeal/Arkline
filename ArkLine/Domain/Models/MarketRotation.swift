import Foundation

// MARK: - Market Rotation

/// Daily cross-market verdict: which market (crypto vs equities) conditions
/// currently favor — always accompanied by the factor-level reasoning.
struct MarketRotation: Codable, Identifiable, Hashable {
    let id: UUID
    let rotationDate: String
    let favored: String            // "crypto" | "stocks" | "balanced"
    let score: Int
    let factors: [RotationFactor]
    let createdAt: Date?

    struct RotationFactor: Codable, Hashable {
        let factor: String
        let vote: String           // "crypto" | "stocks" | "neutral"
        let detail: String
    }

    var favoredDisplay: String {
        switch favored {
        case "crypto": return "Crypto"
        case "stocks": return "Stocks"
        default: return "Balanced"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, favored, score, factors
        case rotationDate = "rotation_date"
        case createdAt = "created_at"
    }
}

// MARK: - Service

final class MarketRotationService {

    private let supabase = SupabaseManager.shared

    init() {}

    /// Latest daily rotation verdict.
    func fetchLatest() async throws -> MarketRotation? {
        guard supabase.isConfigured else { return nil }

        let rows: [MarketRotation] = try await supabase.database
            .from("market_rotation")
            .select()
            .order("rotation_date", ascending: false)
            .limit(1)
            .execute()
            .value

        return rows.first
    }
}
