import Foundation

// MARK: - Swing Setup Service

/// Fetches trade signals and confluence zones from Supabase
final class SwingSetupService {
    private let supabase = SupabaseManager.shared

    /// Short-lived cache to avoid duplicate fetches across multiple ViewModels.
    /// Exposed as internal so detail views can pre-populate with cached data.
    static var activeSignalsCache: [TradeSignal]?
    private static var activeSignalsCacheTime: Date?
    private static let cacheTTL: TimeInterval = 30

    /// Returns cached active signals if available (does not fetch).
    static var cachedActiveSignals: [TradeSignal]? { activeSignalsCache }

    // MARK: - Active Signals

    func fetchActiveSignals(forceRefresh: Bool = false) async throws -> [TradeSignal] {
        // Return cached data if fresh
        if !forceRefresh,
           let cached = Self.activeSignalsCache,
           let cacheTime = Self.activeSignalsCacheTime,
           Date().timeIntervalSince(cacheTime) < Self.cacheTTL {
            return cached
        }

        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["active", "triggered"])
            .order("generated_at", ascending: false)
            .execute()
            .value

        Self.activeSignalsCache = signals
        Self.activeSignalsCacheTime = Date()
        return signals
    }

    // MARK: - Recent Signals (including closed)

    func fetchRecentSignals(limit: Int = 20) async throws -> [TradeSignal] {
        // Fetch closed signals for History + Performance tabs
        // Pipeline resolves to: target_hit (wins), invalidated (manual), expired (losses/partials)
        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["target_hit", "invalidated", "expired"])
            .order("generated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return signals
    }

    // MARK: - Closed Signals Since Date (no limit)

    /// Fetches all closed signals since a given date for historical performance analysis.
    func fetchClosedSignals(since date: Date) async throws -> [TradeSignal] {
        let iso = ISO8601DateFormatter()
        let dateStr = iso.string(from: date)

        let signals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["target_hit", "invalidated", "expired"])
            .gte("closed_at", value: dateStr)
            .order("closed_at", ascending: true)
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

    // MARK: - Manual Resolution (Admin)

    /// Encodable patch for manual signal resolution. Skips nil values to avoid overwriting existing data.
    private struct ManualResolutionPatch: Encodable {
        var status: String
        var outcome: String
        var outcome_pct: Double
        var closed_at: String
        var resolution_source: String = "manual"
        var duration_hours: Int?
        var best_price: Double?
        var t1_hit_at: String?
        var t1_pnl_pct: Double?
        var runner_exit_price: Double?
        var runner_pnl_pct: Double?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(status, forKey: .status)
            try container.encode(outcome, forKey: .outcome)
            try container.encode(outcome_pct, forKey: .outcome_pct)
            try container.encode(closed_at, forKey: .closed_at)
            try container.encode(resolution_source, forKey: .resolution_source)
            if let v = duration_hours { try container.encode(v, forKey: .duration_hours) }
            if let v = best_price { try container.encode(v, forKey: .best_price) }
            if let v = t1_hit_at { try container.encode(v, forKey: .t1_hit_at) }
            if let v = t1_pnl_pct { try container.encode(v, forKey: .t1_pnl_pct) }
            if let v = runner_exit_price { try container.encode(v, forKey: .runner_exit_price) }
            if let v = runner_pnl_pct { try container.encode(v, forKey: .runner_pnl_pct) }
        }

        private enum CodingKeys: String, CodingKey {
            case status, outcome, outcome_pct, closed_at, resolution_source
            case duration_hours, best_price, t1_hit_at, t1_pnl_pct
            case runner_exit_price, runner_pnl_pct
        }
    }

    /// Manually resolve a trade signal with a given exit price.
    /// Auto-determines outcome based on where the exit price falls relative to entry/SL/T1.
    func resolveSignalManually(signal: TradeSignal, exitPrice: Double) async throws -> TradeSignal {
        let isBuy = signal.signalType.isBuy
        let entry = signal.entryPriceMid

        let exitPnlPct = isBuy
            ? ((exitPrice - entry) / entry) * 100
            : ((entry - exitPrice) / entry) * 100

        let now = ISO8601DateFormatter().string(from: Date())
        let duration: Int? = signal.triggeredAt.map { Int(Date().timeIntervalSince($0) / 3600) }

        let t1Hit: Bool = {
            guard let t1 = signal.target1 else { return false }
            return isBuy ? exitPrice >= t1 : exitPrice <= t1
        }()
        let slHit = isBuy ? exitPrice <= signal.stopLoss : exitPrice >= signal.stopLoss

        var patch: ManualResolutionPatch

        if signal.isT1Hit {
            // Runner phase: T1 already hit, resolves the runner half
            let runnerPnl = exitPnlPct
            let t1Pnl = signal.t1PnlPct ?? 0
            let combinedPnl = (t1Pnl + runnerPnl) / 2

            patch = ManualResolutionPatch(
                status: combinedPnl > 0 ? "target_hit" : "invalidated",
                outcome: combinedPnl > 0 ? "win" : "loss",
                outcome_pct: round(combinedPnl * 100) / 100,
                closed_at: now,
                duration_hours: duration,
                runner_exit_price: exitPrice,
                runner_pnl_pct: round(runnerPnl * 100) / 100
            )
        } else if t1Hit {
            // Exit at or beyond T1 — T1 half at T1 price, runner half at exit price
            let t1Pnl: Double = {
                guard let t1 = signal.target1 else { return exitPnlPct }
                return isBuy
                    ? ((t1 - entry) / entry) * 100
                    : ((entry - t1) / entry) * 100
            }()
            let combinedPnl = (t1Pnl + exitPnlPct) / 2

            patch = ManualResolutionPatch(
                status: "target_hit",
                outcome: "win",
                outcome_pct: round(combinedPnl * 100) / 100,
                closed_at: now,
                duration_hours: duration,
                best_price: exitPrice,
                t1_hit_at: now,
                t1_pnl_pct: round(t1Pnl * 100) / 100,
                runner_exit_price: exitPrice,
                runner_pnl_pct: round(exitPnlPct * 100) / 100
            )
        } else {
            // Pre-T1 exit (SL hit or manual close in between)
            let bestPrice: Double? = {
                if let current = signal.bestPrice {
                    let isBetter = isBuy ? exitPrice > current : exitPrice < current
                    return isBetter ? exitPrice : nil
                }
                return exitPrice
            }()

            patch = ManualResolutionPatch(
                status: slHit ? "invalidated" : (exitPnlPct > 0 ? "target_hit" : "invalidated"),
                outcome: exitPnlPct > 0 ? "win" : "loss",
                outcome_pct: round(exitPnlPct * 100) / 100,
                closed_at: now,
                duration_hours: duration,
                best_price: bestPrice
            )
        }

        try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .update(patch)
            .eq("id", value: signal.id.uuidString)
            .execute()

        // Clear cache so lists update
        Self.activeSignalsCache = nil

        return try await fetchSignal(id: signal.id)
    }

    // MARK: - Signal Analytics (Adaptive Feedback)

    func fetchSignalAnalytics() async throws -> SignalAnalytics? {
        struct CacheRow: Decodable {
            let data: SignalAnalytics
        }

        let rows: [CacheRow] = try await supabase.database
            .from(SupabaseTable.marketDataCache.rawValue)
            .select("data")
            .eq("key", value: "signal_analytics")
            .limit(1)
            .execute()
            .value

        return rows.first?.data
    }

    // MARK: - Market Conditions

    func fetchMarketConditions() async throws -> SignalMarketConditions? {
        struct CacheRow: Decodable {
            let data: SignalMarketConditions
        }

        let rows: [CacheRow] = try await supabase.database
            .from(SupabaseTable.marketDataCache.rawValue)
            .select("data")
            .eq("key", value: "signal_market_conditions")
            .limit(1)
            .execute()
            .value

        return rows.first?.data
    }

    // MARK: - Signal Stats

    func fetchSignalStats() async throws -> SignalStats {
        let allSignals: [TradeSignal] = try await supabase.database
            .from(SupabaseTable.tradeSignals.rawValue)
            .select()
            .in("status", values: ["target_hit", "invalidated", "expired"])
            .in("asset", values: Array(TradeSignal.activeAssets))
            .order("closed_at", ascending: false)
            .limit(100)
            .execute()
            .value

        let wins = allSignals.filter { $0.outcome == .win }.count
        let losses = allSignals.filter { $0.outcome == .loss }.count
        let partials = allSignals.filter { $0.outcome == .partial }.count
        let total = wins + losses + partials
        let hitRate = total > 0 ? Double(wins) / Double(total) * 100 : 0

        let winPcts = allSignals.filter { $0.outcome == .win }
            .compactMap { $0.outcomePct }
        let lossPcts = allSignals.filter { $0.outcome == .loss || $0.outcome == .partial }
            .compactMap { $0.outcomePct }

        let avgWinPct = winPcts.isEmpty ? 0 : winPcts.reduce(0, +) / Double(winPcts.count)
        let avgLossPct = lossPcts.isEmpty ? 0 : lossPcts.reduce(0, +) / Double(lossPcts.count)
        let totalWinPct = winPcts.reduce(0, +)
        let totalLossPct = abs(lossPcts.reduce(0, +))
        let profitFactor = totalLossPct > 0 ? totalWinPct / totalLossPct : totalWinPct > 0 ? .infinity : 0

        let durations = allSignals.compactMap { $0.durationHours }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / durations.count

        // Current streak (most recent signals first, skip signals without outcomes)
        // Only full wins count as wins; partials and losses break a win streak
        var streak = 0
        for signal in allSignals {
            guard let outcome = signal.outcome else { continue }
            let isWin = outcome == .win
            let isLoss = outcome == .loss || outcome == .partial
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
            let hr = t > 0 ? Double(w) / Double(t) * 100 : 0
            let returns = signals.compactMap { $0.outcomePct }
            let avgRet = returns.isEmpty ? 0 : returns.reduce(0, +) / Double(returns.count)
            return AssetStats(asset: asset, total: t, wins: w, losses: l, partials: p, hitRate: hr, avgReturnPct: avgRet)
        }
        .sorted { $0.total > $1.total }

        // Opportunity rate: % of closed signals where best price reached 50%+ of T1
        let opportunityCount = allSignals.filter { $0.hadOpportunity }.count
        let opportunityRate = total > 0 ? Double(opportunityCount) / Double(total) * 100 : 0

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
            currentStreak: streak,
            opportunityRate: opportunityRate
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
    let opportunityRate: Double // % of signals where best price reached 50%+ of T1
}

struct SignalMarketConditions: Codable {
    let status: String           // "active" or "quiet"
    let headline: String         // e.g. "Zones identified, waiting for bounce confirmation"
    let detail: String           // Longer explanation
    let topReasons: [String]     // e.g. ["no bounce confirmation (8x)"]
    let totalSkipped: Int
    let totalGenerated: Int
    let updatedAt: String
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

// MARK: - Signal Analytics (Adaptive Feedback Loop)

struct SignalAnalytics: Codable {
    let computedAt: String
    let system: SystemAnalytics
    let adaptive: AdaptiveParams

    struct SystemAnalytics: Codable {
        let rolling30d: AnalyticsBucket
        let allTime: AnalyticsBucket

        enum CodingKeys: String, CodingKey {
            case rolling30d = "rolling_30d"
            case allTime = "all_time"
        }
    }

    struct AnalyticsBucket: Codable {
        let signalCount: Int
        let wins: Int
        let losses: Int
        let winRate: Double
        let profitFactor: Double
        let avgPnl: Double
        let avgDurationHours: Int
        let longCount: Int
        let shortCount: Int
        let longWinRate: Double
        let shortWinRate: Double

        enum CodingKeys: String, CodingKey {
            case signalCount = "signal_count"
            case wins, losses
            case winRate = "win_rate"
            case profitFactor = "profit_factor"
            case avgPnl = "avg_pnl"
            case avgDurationHours = "avg_duration_hours"
            case longCount = "long_count"
            case shortCount = "short_count"
            case longWinRate = "long_win_rate"
            case shortWinRate = "short_win_rate"
        }
    }

    struct AdaptiveParams: Codable {
        let pausedAssets: [String]
        let directionBonus: [String: DirectionBonus]
        let minRr: Double
        let minScore: Int
        let state: String
        let stateLabel: String
        let reasons: [String]

        enum CodingKeys: String, CodingKey {
            case pausedAssets = "paused_assets"
            case directionBonus = "direction_bonus"
            case minRr = "min_rr"
            case minScore = "min_score"
            case state
            case stateLabel = "state_label"
            case reasons
        }
    }

    struct DirectionBonus: Codable {
        let long: Int
        let short: Int
    }

    enum CodingKeys: String, CodingKey {
        case computedAt = "computed_at"
        case system, adaptive
    }
}
