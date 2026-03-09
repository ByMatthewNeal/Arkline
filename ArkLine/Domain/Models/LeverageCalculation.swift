import Foundation

// MARK: - Leverage Calculation

/// Pure logic model for leverage risk calculations.
/// All values are derived from a signal's parameters + user inputs.
struct LeverageCalculation {
    let entryZoneHigh: Double
    let entryZoneLow: Double
    let stopLossPrice: Double
    let target1Price: Double?
    let target2Price: Double?
    let isLong: Bool
    let leverageMultiplier: Int
    let marginAmount: Double
    let entryStrategy: EntryStrategy

    /// Safety factor — stop must be within this fraction of liquidation distance
    private let safetyFactor: Double = 0.55

    // MARK: - Entry

    var entryPrice: Double {
        entryStrategy.effectiveEntryPrice(
            zoneLow: entryZoneLow,
            zoneHigh: entryZoneHigh,
            isLong: isLong
        )
    }

    var hasEntryZone: Bool {
        let mid = (entryZoneHigh + entryZoneLow) / 2.0
        guard mid > 0 else { return false }
        return abs(entryZoneHigh - entryZoneLow) / mid * 100 > 0.1
    }

    var zoneWidthPercent: Double {
        let mid = (entryZoneHigh + entryZoneLow) / 2.0
        guard mid > 0 else { return 0 }
        return abs(entryZoneHigh - entryZoneLow) / mid * 100
    }

    var entryDeltaVsMidpoint: Double {
        let midpointPrice = (entryZoneHigh + entryZoneLow) / 2.0
        return entryPrice - midpointPrice
    }

    var isEntryDeltaFavorable: Bool {
        if isLong {
            return entryDeltaVsMidpoint < 0 // Lower entry = better for longs
        } else {
            return entryDeltaVsMidpoint > 0 // Higher entry = better for shorts
        }
    }

    var splitDetail: SplitEntryDetail? {
        guard entryStrategy == .split else { return nil }
        return SplitEntryDetail(
            zoneLow: entryZoneLow,
            zoneHigh: entryZoneHigh,
            isLong: isLong,
            leverage: leverageMultiplier,
            totalMargin: marginAmount
        )
    }

    // MARK: - Core

    var notionalPosition: Double {
        marginAmount * Double(leverageMultiplier)
    }

    /// Quantity of the asset at the effective entry price
    var assetQuantity: Double {
        guard entryPrice > 0 else { return 0 }
        return notionalPosition / entryPrice
    }

    var stopLossPercent: Double {
        guard entryPrice > 0 else { return 0 }
        return abs(stopLossPrice - entryPrice) / entryPrice * 100
    }

    var liquidationPercent: Double {
        100.0 / Double(leverageMultiplier)
    }

    var liquidationPrice: Double {
        if isLong {
            return entryPrice * (1 - liquidationPercent / 100)
        } else {
            return entryPrice * (1 + liquidationPercent / 100)
        }
    }

    // MARK: - Stop Adjustment

    var adjustedStopLossPercent: Double {
        let maxSafeStop = liquidationPercent * safetyFactor
        return min(stopLossPercent, maxSafeStop)
    }

    var adjustedStopLossPrice: Double {
        if isLong {
            return entryPrice * (1 - adjustedStopLossPercent / 100)
        } else {
            return entryPrice * (1 + adjustedStopLossPercent / 100)
        }
    }

    var stopLossWasAdjusted: Bool {
        adjustedStopLossPercent < stopLossPercent
    }

    // MARK: - Risk

    var dollarRiskPerTrade: Double {
        notionalPosition * (adjustedStopLossPercent / 100)
    }

    var marginLossPercent: Double {
        guard marginAmount > 0 else { return 0 }
        return (dollarRiskPerTrade / marginAmount) * 100
    }

    var maxConsecutiveLosses: Int {
        guard dollarRiskPerTrade > 0 else { return 0 }
        let raw = floor(marginAmount / dollarRiskPerTrade)
        guard raw.isFinite, raw <= Double(Int.max) else { return 999 }
        return Int(raw)
    }

    // MARK: - Payouts

    var target1DollarPayout: Double? {
        guard let t1 = target1Price, entryPrice > 0 else { return nil }
        let pct = abs(t1 - entryPrice) / entryPrice * 100
        return notionalPosition * (pct / 100)
    }

    var target2DollarPayout: Double? {
        guard let t2 = target2Price, entryPrice > 0 else { return nil }
        let pct = abs(t2 - entryPrice) / entryPrice * 100
        return notionalPosition * (pct / 100)
    }

    var target1ReturnOnMargin: Double? {
        guard marginAmount > 0, let payout = target1DollarPayout else { return nil }
        return (payout / marginAmount) * 100
    }

    var target2ReturnOnMargin: Double? {
        guard marginAmount > 0, let payout = target2DollarPayout else { return nil }
        return (payout / marginAmount) * 100
    }

    // MARK: - R-Multiple Target Ladder

    struct RTarget: Identifiable {
        let id: String
        let rMultiple: Double
        let dollarMove: Double    // $ per unit move from entry to target
        let targetPrice: Double
        let pnl: Double           // Dollar P&L at this level
    }

    /// Stop distance in dollar terms (per unit of asset)
    var stopDistanceDollar: Double {
        abs(entryPrice - stopLossPrice)
    }

    /// R-multiple target levels with price, P&L, and dollar move
    var rTargetLadder: [RTarget] {
        guard entryPrice > 0, stopDistanceDollar > 0, assetQuantity > 0 else { return [] }
        let rMultiples = [1.0, 1.5, 2.0, 3.0, 5.0]
        return rMultiples.map { r in
            let dollarMove = stopDistanceDollar * r
            let targetPrice: Double
            if isLong {
                targetPrice = entryPrice + dollarMove
            } else {
                targetPrice = entryPrice - dollarMove
            }
            let pnl = dollarMove * assetQuantity
            return RTarget(
                id: "\(r)R",
                rMultiple: r,
                dollarMove: dollarMove,
                targetPrice: targetPrice,
                pnl: pnl
            )
        }
    }

    // MARK: - Viability

    var maxSafeLeverage: Int {
        guard stopLossPercent > 0 else { return 200 }
        return max(1, Int(floor((100.0 / stopLossPercent) * safetyFactor)))
    }

    var isSignalViableAtLeverage: Bool {
        stopLossPercent < liquidationPercent
    }

    var isStopSafe: Bool {
        adjustedStopLossPercent == stopLossPercent
    }

    var adjustedRiskReward: Double? {
        guard adjustedStopLossPercent > 0, let t1 = target1Price, entryPrice > 0 else { return nil }
        let targetPct = abs(t1 - entryPrice) / entryPrice * 100
        return targetPct / adjustedStopLossPercent
    }
}

// MARK: - Margin Mode

enum MarginMode: String, CaseIterable {
    case isolated = "Isolated"
    case cross = "Cross"
}

// MARK: - Risk Size

enum RiskSize: String, CaseIterable {
    case oneR = "1R"
    case halfR = "0.5R"

    var label: String { rawValue }

    var multiplier: Double {
        switch self {
        case .oneR: return 1.0
        case .halfR: return 0.5
        }
    }
}

// MARK: - Convenience Init from TradeSignal

extension LeverageCalculation {
    init(signal: TradeSignal, leverage: Int, margin: Double, strategy: EntryStrategy = .midpoint) {
        self.entryZoneHigh = signal.entryZoneHigh
        self.entryZoneLow = signal.entryZoneLow
        self.stopLossPrice = signal.stopLoss
        self.target1Price = signal.target1
        self.target2Price = signal.target2
        self.isLong = signal.signalType.isBuy
        self.leverageMultiplier = leverage
        self.marginAmount = margin
        self.entryStrategy = strategy
    }
}
