import Foundation

// MARK: - Swing Setup Service

/// Fetches trade signals and confluence zones from Supabase
final class SwingSetupService {
    private let supabase = SupabaseManager.shared

    // MARK: - Active Signals

    func fetchActiveSignals() async throws -> [TradeSignal] {
        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["active", "triggered"])
            .order("generated_at", ascending: false)
            .execute()
            .value

        return signals
    }

    // MARK: - Recent Signals (including closed)

    func fetchRecentSignals(limit: Int = 20) async throws -> [TradeSignal] {
        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .order("generated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return signals
    }

    // MARK: - Signal by ID

    func fetchSignal(id: UUID) async throws -> TradeSignal {
        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let signal = signals.first else {
            throw AppError.notFound
        }
        return signal
    }

    // MARK: - Confluence Zone for Signal

    func fetchConfluenceZone(id: UUID) async throws -> FibConfluenceZone {
        let zones: [FibConfluenceZone] = try await supabase.database
            .from(SupabaseTable.fibConfluenceZones.rawValue)
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let zone = zones.first else {
            throw AppError.notFound
        }
        return zone
    }

    // MARK: - Signal Stats

    func fetchSignalStats() async throws -> SignalStats {
        let allSignals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["target_hit", "invalidated"])
            .order("closed_at", ascending: false)
            .limit(100)
            .execute()
            .value

        let wins = allSignals.filter { $0.outcome == .win }.count
        let losses = allSignals.filter { $0.outcome == .loss }.count
        let partials = allSignals.filter { $0.outcome == .partial }.count
        let total = wins + losses + partials
        let hitRate = total > 0 ? Double(wins + partials) / Double(total) * 100 : 0

        let winPcts = allSignals.filter { $0.outcome == .win || $0.outcome == .partial }
            .compactMap { $0.outcomePct }
        let lossPcts = allSignals.filter { $0.outcome == .loss }
            .compactMap { $0.outcomePct }

        let avgWinPct = winPcts.isEmpty ? 0 : winPcts.reduce(0, +) / Double(winPcts.count)
        let avgLossPct = lossPcts.isEmpty ? 0 : lossPcts.reduce(0, +) / Double(lossPcts.count)
        let totalWinPct = winPcts.reduce(0, +)
        let totalLossPct = abs(lossPcts.reduce(0, +))
        let profitFactor = totalLossPct > 0 ? totalWinPct / totalLossPct : totalWinPct > 0 ? .infinity : 0

        let durations = allSignals.compactMap { $0.durationHours }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count

        // Current streak (most recent signals first, skip signals without outcomes)
        var streak = 0
        for signal in allSignals {
            guard let outcome = signal.outcome else { continue }
            let isWin = outcome == .win || outcome == .partial
            let isLoss = outcome == .loss
            if streak == 0 {
                streak = isWin ? 1 : -1
            } else if streak > 0 && isWin {
                streak += 1
            } else if streak < 0 && isLoss {
                streak -= 1
            } else {
                break
            }
        }

        // Per-asset breakdown
        let assetGroups = Dictionary(grouping: allSignals) { $0.asset }
        let assetBreakdown: [AssetStats] = assetGroups.map { asset, signals in
            let w = signals.filter { $0.outcome == .win }.count
            let l = signals.filter { $0.outcome == .loss }.count
            let p = signals.filter { $0.outcome == .partial }.count
            let t = w + l + p
            let hr = t > 0 ? Double(w + p) / Double(t) * 100 : 0
            let returns = signals.compactMap { $0.outcomePct }
            let avgRet = returns.isEmpty ? 0 : returns.reduce(0, +) / Double(returns.count)
            return AssetStats(asset: asset, total: t, wins: w, losses: l, partials: p, hitRate: hr, avgReturnPct: avgRet)
        }
        .sorted { $0.total > $1.total }

        return SignalStats(
            totalSignals: total,
            wins: wins,
            losses: losses,
            partials: partials,
            hitRate: hitRate,
            avgWinPct: avgWinPct,
            avgLossPct: avgLossPct,
            profitFactor: profitFactor,
            avgDurationHours: avgDuration,
            assetBreakdown: assetBreakdown,
            currentStreak: streak
        )
    }
}

// MARK: - Signal Stats

struct SignalStats {
    let totalSignals: Int
    let wins: Int
    let losses: Int
    let partials: Int
    let hitRate: Double
    let avgWinPct: Double
    let avgLossPct: Double
    let profitFactor: Double
    let avgDurationHours: Int
    let assetBreakdown: [AssetStats]
    let currentStreak: Int // positive = wins, negative = losses
}

struct AssetStats: Identifiable {
    var id: String { asset }
    let asset: String
    let total: Int
    let wins: Int
    let losses: Int
    let partials: Int
    let hitRate: Double
    let avgReturnPct: Double
}
