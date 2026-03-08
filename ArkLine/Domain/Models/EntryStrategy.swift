import Foundation

// MARK: - Entry Strategy

enum EntryStrategy: String, CaseIterable, Identifiable {
    case aggressive
    case midpoint
    case optimal
    case conservative
    case split

    var id: String { rawValue }

    var label: String {
        switch self {
        case .aggressive: return "Aggressive"
        case .midpoint: return "Midpoint"
        case .optimal: return "Optimal"
        case .conservative: return "Conservative"
        case .split: return "Split Entry"
        }
    }

    var shortDescription: String {
        switch self {
        case .aggressive: return "Enter at zone edge, first touch"
        case .midpoint: return "Center of the zone"
        case .optimal: return "0.705 level — highest reversal probability"
        case .conservative: return "Deep zone entry, tightest stop"
        case .split: return "40% early + 60% deep, averaged"
        }
    }

    var iconName: String {
        switch self {
        case .aggressive: return "hare.fill"
        case .midpoint: return "equal.circle.fill"
        case .optimal: return "target"
        case .conservative: return "tortoise.fill"
        case .split: return "arrow.triangle.branch"
        }
    }

    func effectiveEntryPrice(zoneLow: Double, zoneHigh: Double, isLong: Bool) -> Double {
        let zoneRange = abs(zoneHigh - zoneLow)

        switch self {
        case .aggressive:
            // First touch: for longs price enters from above (zoneHigh), for shorts from below...
            // Actually: for LONG setups, price drops INTO the zone — aggressive = buy at the top of the zone (first touch)
            // For SHORT setups, price rises INTO the zone — aggressive = sell at the bottom of the zone (first touch)
            // Long: aggressive = zoneHigh (enter early, wider stop to zoneLow area)
            // Short: aggressive = zoneLow (enter early, wider stop to zoneHigh area)
            return isLong ? zoneHigh : zoneLow

        case .midpoint:
            return (zoneHigh + zoneLow) / 2.0

        case .optimal:
            // 0.705 depth into the zone from the aggressive edge
            if isLong {
                return zoneHigh - (zoneRange * 0.705)
            } else {
                return zoneLow + (zoneRange * 0.705)
            }

        case .conservative:
            // Deepest part of the zone — best entry but might not fill
            return isLong ? zoneLow : zoneHigh

        case .split:
            // Weighted average: 40% at aggressive edge, 60% at conservative edge
            let aggressivePrice = isLong ? zoneHigh : zoneLow
            let conservativePrice = isLong ? zoneLow : zoneHigh
            return (aggressivePrice * 0.4) + (conservativePrice * 0.6)
        }
    }
}

// MARK: - Split Entry Detail

struct SplitEntryDetail {
    let entry1Price: Double
    let entry1Margin: Double
    let entry1Notional: Double

    let entry2Price: Double
    let entry2Margin: Double
    let entry2Notional: Double

    let averageEntryPrice: Double
    let totalNotional: Double

    let partialFillNotional: Double
    let partialFillMargin: Double

    init(zoneLow: Double, zoneHigh: Double, isLong: Bool,
         leverage: Int, totalMargin: Double) {

        let aggressivePrice = isLong ? zoneHigh : zoneLow
        let conservativePrice = isLong ? zoneLow : zoneHigh

        self.entry1Price = aggressivePrice
        self.entry1Margin = totalMargin * 0.4
        self.entry1Notional = entry1Margin * Double(leverage)

        self.entry2Price = conservativePrice
        self.entry2Margin = totalMargin * 0.6
        self.entry2Notional = entry2Margin * Double(leverage)

        self.totalNotional = entry1Notional + entry2Notional

        self.averageEntryPrice = totalNotional > 0
            ? ((entry1Price * entry1Notional) + (entry2Price * entry2Notional)) / totalNotional
            : (aggressivePrice + conservativePrice) / 2.0

        self.partialFillNotional = entry1Notional
        self.partialFillMargin = entry1Margin
    }
}
