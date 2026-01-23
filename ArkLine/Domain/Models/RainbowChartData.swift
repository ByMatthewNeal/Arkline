import SwiftUI

// MARK: - Rainbow Chart Data
/// Bitcoin Rainbow Chart data showing logarithmic regression bands
/// Based on the blockchaincenter.net Rainbow Chart methodology
struct RainbowChartData: Codable, Identifiable {
    let date: Date
    let currentPrice: Double
    let bands: RainbowBands

    var id: Date { date }

    /// Which band the current price falls into
    var currentBand: RainbowBand {
        if currentPrice >= bands.maxBubble {
            return .maxBubble
        } else if currentPrice >= bands.sellSeriously {
            return .sellSeriously
        } else if currentPrice >= bands.fomo {
            return .fomo
        } else if currentPrice >= bands.isBubble {
            return .isBubble
        } else if currentPrice >= bands.hodl {
            return .hodl
        } else if currentPrice >= bands.stillCheap {
            return .stillCheap
        } else if currentPrice >= bands.accumulate {
            return .accumulate
        } else if currentPrice >= bands.buyBuy {
            return .buyBuy
        } else {
            return .fireSale
        }
    }

    /// Normalized position (0-1) within the rainbow
    var normalizedPosition: Double {
        let logPrice = log10(currentPrice)
        let logMin = log10(bands.fireSale)
        let logMax = log10(bands.maxBubble)
        let range = logMax - logMin
        guard range > 0 else { return 0.5 }
        return (logPrice - logMin) / range
    }

    /// Market signal based on position
    var signal: MarketSignal {
        switch currentBand {
        case .fireSale, .buyBuy, .accumulate:
            return .bullish
        case .stillCheap, .hodl:
            return .neutral
        case .isBubble, .fomo, .sellSeriously, .maxBubble:
            return .bearish
        }
    }
}

// MARK: - Rainbow Bands
/// Price levels for each rainbow band at a given date
struct RainbowBands: Codable {
    let fireSale: Double      // Dark Blue - "Fire Sale"
    let buyBuy: Double        // Blue - "BUY!"
    let accumulate: Double    // Cyan - "Accumulate"
    let stillCheap: Double    // Green - "Still Cheap"
    let hodl: Double          // Yellow-Green - "HODL!"
    let isBubble: Double      // Yellow - "Is this a bubble?"
    let fomo: Double          // Orange - "FOMO intensifies"
    let sellSeriously: Double // Light Red - "Sell. Seriously, SELL!"
    let maxBubble: Double     // Dark Red - "Maximum Bubble Territory"

    /// All bands as array for iteration
    var allBands: [(band: RainbowBand, price: Double)] {
        [
            (.fireSale, fireSale),
            (.buyBuy, buyBuy),
            (.accumulate, accumulate),
            (.stillCheap, stillCheap),
            (.hodl, hodl),
            (.isBubble, isBubble),
            (.fomo, fomo),
            (.sellSeriously, sellSeriously),
            (.maxBubble, maxBubble)
        ]
    }
}

// MARK: - Rainbow Band Enum
enum RainbowBand: String, Codable, CaseIterable {
    case fireSale = "Fire Sale"
    case buyBuy = "BUY!"
    case accumulate = "Accumulate"
    case stillCheap = "Still Cheap"
    case hodl = "HODL!"
    case isBubble = "Is this a bubble?"
    case fomo = "FOMO intensifies"
    case sellSeriously = "Sell. Seriously, SELL!"
    case maxBubble = "Maximum Bubble Territory"

    var color: Color {
        switch self {
        case .fireSale: return Color(hex: "0D47A1")      // Dark Blue
        case .buyBuy: return Color(hex: "1976D2")        // Blue
        case .accumulate: return Color(hex: "00BCD4")     // Cyan
        case .stillCheap: return Color(hex: "4CAF50")     // Green
        case .hodl: return Color(hex: "8BC34A")           // Yellow-Green
        case .isBubble: return Color(hex: "FFEB3B")       // Yellow
        case .fomo: return Color(hex: "FF9800")           // Orange
        case .sellSeriously: return Color(hex: "FF5722")  // Light Red
        case .maxBubble: return Color(hex: "B71C1C")      // Dark Red
        }
    }

    var description: String {
        switch self {
        case .fireSale: return "Extreme undervaluation - historically the best buying opportunity"
        case .buyBuy: return "Significantly undervalued - strong buy signal"
        case .accumulate: return "Undervalued - good time to accumulate"
        case .stillCheap: return "Below fair value - still a good entry point"
        case .hodl: return "Near fair value - hold position"
        case .isBubble: return "Starting to look overvalued - exercise caution"
        case .fomo: return "Overvalued - FOMO buying in progress"
        case .sellSeriously: return "Significantly overvalued - consider taking profits"
        case .maxBubble: return "Extreme overvaluation - historically near cycle tops"
        }
    }

    var shortDescription: String {
        switch self {
        case .fireSale: return "Extreme undervalue"
        case .buyBuy: return "Strong buy"
        case .accumulate: return "Accumulation zone"
        case .stillCheap: return "Below fair value"
        case .hodl: return "Fair value"
        case .isBubble: return "Caution zone"
        case .fomo: return "Overvalued"
        case .sellSeriously: return "Take profits"
        case .maxBubble: return "Extreme overvalue"
        }
    }

    /// Signal interpretation
    var marketSignal: MarketSignal {
        switch self {
        case .fireSale, .buyBuy, .accumulate:
            return .bullish
        case .stillCheap, .hodl:
            return .neutral
        case .isBubble, .fomo, .sellSeriously, .maxBubble:
            return .bearish
        }
    }

    /// Index (0-8) for chart positioning
    var index: Int {
        switch self {
        case .fireSale: return 0
        case .buyBuy: return 1
        case .accumulate: return 2
        case .stillCheap: return 3
        case .hodl: return 4
        case .isBubble: return 5
        case .fomo: return 6
        case .sellSeriously: return 7
        case .maxBubble: return 8
        }
    }
}

// MARK: - Historical Rainbow Data Point
/// A single point in rainbow chart history
struct RainbowHistoryPoint: Codable, Identifiable {
    let date: Date
    let price: Double
    let band: RainbowBand

    var id: Date { date }
}
