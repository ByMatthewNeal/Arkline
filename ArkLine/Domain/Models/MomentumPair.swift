import SwiftUI

// MARK: - Momentum Quadrant

/// Classifies an asset by the alignment of its USD pair and its BTC pair.
/// "True momentum" = both bullish. The off-diagonal quadrants surface
/// relative-strength leaders (gaining on BTC) and laggards.
enum MomentumQuadrant: String, CaseIterable, Identifiable {
    case momentum          // USD bullish + BTC bullish
    case outperformingBTC  // BTC bullish, USD not bullish — relative-strength leader
    case usdLeading        // USD bullish, BTC not bullish — strong vs USD, lagging BTC
    case bothBearish       // USD bearish + BTC bearish
    case mixed             // neutral combinations / everything else

    var id: String { rawValue }

    var title: String {
        switch self {
        case .momentum: return "True momentum"
        case .outperformingBTC: return "Outperforming BTC"
        case .usdLeading: return "Leading in USD"
        case .bothBearish: return "Both bearish"
        case .mixed: return "Mixed / neutral"
        }
    }

    var subtitle: String {
        switch self {
        case .momentum: return "USD and BTC pair both bullish — the wave is real."
        case .outperformingBTC: return "Gaining on Bitcoin while USD lags — early relative strength."
        case .usdLeading: return "Strong in dollar terms, not yet beating BTC."
        case .bothBearish: return "Both pairs bearish — no momentum."
        case .mixed: return "Signals not aligned — wait for confirmation."
        }
    }

    var accent: Color {
        switch self {
        case .momentum: return AppColors.success
        case .outperformingBTC: return AppColors.accent
        case .usdLeading: return AppColors.warning
        case .bothBearish: return AppColors.error
        case .mixed: return AppColors.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .momentum: return "waveform.path.ecg"
        case .outperformingBTC: return "arrow.up.forward.circle"
        case .usdLeading: return "dollarsign.circle"
        case .bothBearish: return "arrow.down.right.circle"
        case .mixed: return "equal.circle"
        }
    }

    /// Display order for the board.
    var sortOrder: Int {
        switch self {
        case .momentum: return 0
        case .outperformingBTC: return 1
        case .usdLeading: return 2
        case .mixed: return 3
        case .bothBearish: return 4
        }
    }
}

// MARK: - Momentum Pair

/// An asset paired across its USD and BTC positioning signals for the same day.
/// Both legs come straight from `positioning_signals`, so no extra fetch is needed.
struct MomentumPair: Identifiable, Hashable {
    let asset: String              // base ticker, e.g. "SOL"
    let displayName: String
    let usdSignal: PositioningSignal
    let usdScore: Int
    let btcSignal: PositioningSignal
    let btcScore: Int
    let isRealBTCPair: Bool         // true = real Coinbase pair, false = synthetic (USD ÷ BTC-USD)

    var id: String { asset }

    /// Combined strength, used to rank within a quadrant.
    var combinedScore: Int { (usdScore + btcScore) / 2 }

    var quadrant: MomentumQuadrant {
        let usdBull = usdSignal == .bullish
        let btcBull = btcSignal == .bullish
        let usdBear = usdSignal == .bearish
        let btcBear = btcSignal == .bearish

        if usdBull && btcBull { return .momentum }
        if btcBull && !usdBull { return .outperformingBTC }
        if usdBull && !btcBull { return .usdLeading }
        if usdBear && btcBear { return .bothBearish }
        return .mixed
    }

    // MARK: - Builder

    /// Real Coinbase /BTC pairs. The rest are synthesized as USD ÷ BTC-USD, which
    /// can read bullish purely because BTC is falling faster — so we flag them.
    private static let realBTCPairs: Set<String> = [
        "ETH", "SOL", "LINK", "AVAX", "DOGE", "BCH", "UNI", "AAVE",
    ]

    /// Pair each asset's USD positioning row with its /BTC row for the latest day.
    /// Only assets that have BOTH rows are returned.
    static func build(from signals: [DailyPositioningSignal]) -> [MomentumPair] {
        var usdByAsset: [String: DailyPositioningSignal] = [:]
        var btcByAsset: [String: DailyPositioningSignal] = [:]

        for s in signals {
            if s.asset.contains("/BTC") {
                let base = s.asset.replacingOccurrences(of: "/BTC", with: "")
                btcByAsset[base] = s
            } else if s.assetCategory == .crypto {
                usdByAsset[s.asset] = s
            }
        }

        var pairs: [MomentumPair] = []
        for (base, usd) in usdByAsset {
            guard let btc = btcByAsset[base] else { continue }
            pairs.append(MomentumPair(
                asset: base,
                displayName: usd.displayName,
                usdSignal: usd.positioningSignal,
                usdScore: Int(usd.trendScore.rounded()),
                btcSignal: btc.positioningSignal,
                btcScore: Int(btc.trendScore.rounded()),
                isRealBTCPair: realBTCPairs.contains(base)
            ))
        }

        return pairs.sorted {
            if $0.quadrant.sortOrder != $1.quadrant.sortOrder {
                return $0.quadrant.sortOrder < $1.quadrant.sortOrder
            }
            return $0.combinedScore > $1.combinedScore
        }
    }

    /// Built pairs grouped by quadrant in display order (empty quadrants omitted).
    static func grouped(from signals: [DailyPositioningSignal]) -> [(MomentumQuadrant, [MomentumPair])] {
        let grouped = Dictionary(grouping: build(from: signals)) { $0.quadrant }
        return grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map { ($0.key, $0.value) }
    }
}
