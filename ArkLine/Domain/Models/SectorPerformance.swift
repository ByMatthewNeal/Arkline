import Foundation

// MARK: - Sector Performance

/// Daily performance data for a market sector with relative strength vs SPY.
struct SectorPerformance: Codable, Identifiable {
    let id: UUID
    let signalDate: String
    let sectorId: String
    let sectorName: String
    let return7d: Double?
    let return30d: Double?
    let relativeStrengthVsSpy: Double?
    let topPerformer: String?
    let topPerformerReturn: Double?
    let stockReturns: [String: Double]?
    let isDefensive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case signalDate = "signal_date"
        case sectorId = "sector_id"
        case sectorName = "sector_name"
        case return7d = "return_7d"
        case return30d = "return_30d"
        case relativeStrengthVsSpy = "relative_strength_vs_spy"
        case topPerformer = "top_performer"
        case topPerformerReturn = "top_performer_return"
        case stockReturns = "stock_returns"
        case isDefensive = "is_defensive"
    }

    /// Sector icon for display
    var icon: String {
        switch sectorId {
        case "semiconductors": return "cpu"
        case "cloud_ai": return "cloud"
        case "consumer_internet": return "globe"
        case "data_centers": return "server.rack"
        case "cybersecurity": return "lock.shield"
        case "power_electrification": return "bolt.fill"
        case "utilities": return "powerplug"
        case "nuclear": return "atom"
        case "crypto_miners": return "bitcoinsign.circle"
        case "fintech": return "creditcard"
        case "space_quantum": return "sparkles"
        case "rare_earths": return "mountain.2"
        case "industrials": return "gearshape.2"
        case "defensives": return "shield.checkered"
        default: return "chart.bar"
        }
    }
}
