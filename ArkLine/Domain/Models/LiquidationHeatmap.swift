import Foundation

// MARK: - Liquidation Heatmap Models
/// Projected BTC liquidation clusters, computed daily by the
/// compute-liquidation-heatmap edge function and stored in Supabase.
/// This is an estimate modeled from open positions and typical leverage,
/// not exchange liquidation data.

struct LiquidationCluster: Codable, Hashable {
    let price: Double
    let side: String        // "below" | "above"
    let intensity: Double

    var isBelow: Bool { side == "below" }
}

struct LiquidationHeatmapData: Codable {
    let asset: String
    let currentPrice: Double
    let priceMin: Double
    let priceMax: Double
    let bins: Int
    let days: [Double]      // unix seconds (x axis)
    let closes: [Double]    // daily close (len = days)
    let prices: [Double]    // bin center prices (len = bins)
    let grid: [[Int]]       // bins x days, intensity normalized 0..1000
    let clusters: [LiquidationCluster]
    let asOf: String?

    enum CodingKeys: String, CodingKey {
        case asset
        case currentPrice = "current_price"
        case priceMin = "price_min"
        case priceMax = "price_max"
        case bins
        case days
        case closes
        case prices
        case grid
        case clusters
        case asOf = "as_of"
    }

    // Sorted by price so the lists read in order, nearest to the current price first:
    // below descends from just under price, above ascends from just over it.
    var clustersBelow: [LiquidationCluster] { clusters.filter { $0.isBelow }.sorted { $0.price > $1.price } }
    var clustersAbove: [LiquidationCluster] { clusters.filter { !$0.isBelow }.sorted { $0.price < $1.price } }
}
