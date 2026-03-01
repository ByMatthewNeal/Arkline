import Foundation

// MARK: - API GEI Service
/// Computes the Global Economy Index (GEI) by combining 6 leading economic indicators:
///   1. Copper Futures (HG=F) — industrial demand
///   2. 10Y Treasury Yield (^TNX) — growth expectations
///   3. 10Y-2Y Yield Spread (T10Y2Y) — yield curve
///   4. HY Credit Spread (BAMLH0A0HYM2) — credit stress (inverted)
///   5. Initial Jobless Claims (ICSA) — labor market (inverted)
///   6. Consumer Sentiment (UMCSENT) — consumer confidence
///
/// Each component is z-scored against its own 90-day history.
/// Inverted components have their sign flipped.
/// GEI = equal-weighted mean of 6 z-scores.
/// GEI > 0 = expansion, < 0 = contraction.
final class APIGEIService: GEIServiceProtocol {

    // MARK: - Constants

    private static let cacheKey = "gei_composite_data"
    private static let historyCacheKey = "gei_history_data"
    private static let cacheTTL: TimeInterval = 1800 // 30 minutes

    private let yahooService = YahooFinanceService.shared

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Component Definitions

    private struct ComponentDef {
        let name: String
        let seriesId: String
        let isInverted: Bool
        let source: DataSource

        enum DataSource {
            case fred
            case yahoo
        }
    }

    private let componentDefs: [ComponentDef] = [
        ComponentDef(name: "Copper Futures", seriesId: "HG=F", isInverted: false, source: .yahoo),
        ComponentDef(name: "10Y Treasury Yield", seriesId: "^TNX", isInverted: false, source: .yahoo),
        ComponentDef(name: "Yield Curve (10Y-2Y)", seriesId: "T10Y2Y", isInverted: false, source: .fred),
        ComponentDef(name: "HY Credit Spread", seriesId: "BAMLH0A0HYM2", isInverted: true, source: .fred),
        ComponentDef(name: "Initial Jobless Claims", seriesId: "ICSA", isInverted: true, source: .fred),
        ComponentDef(name: "Consumer Sentiment", seriesId: "UMCSENT", isInverted: false, source: .fred),
    ]

    // MARK: - Public Methods

    func fetchGEI() async throws -> GEIData {
        // Check cache first
        if let cached: GEIData = APICache.shared.get(Self.cacheKey) {
            return cached
        }

        // Fetch all components in parallel
        async let copperTask = fetchYahooHistory(symbol: "HG=F")
        async let tnxTask = fetchYahooHistory(symbol: "^TNX")
        async let yieldCurveTask = fetchFREDHistory(seriesId: "T10Y2Y")
        async let creditSpreadTask = fetchFREDHistory(seriesId: "BAMLH0A0HYM2")
        async let claimsTask = fetchFREDHistory(seriesId: "ICSA")
        async let sentimentTask = fetchFREDHistory(seriesId: "UMCSENT")

        let copper = await copperTask
        let tnx = await tnxTask
        let yieldCurve = await yieldCurveTask
        let creditSpread = await creditSpreadTask
        let claims = await claimsTask
        let sentiment = await sentimentTask

        // Build components from available data
        let allHistories: [(ComponentDef, [Double])] = [
            (componentDefs[0], copper),
            (componentDefs[1], tnx),
            (componentDefs[2], yieldCurve),
            (componentDefs[3], creditSpread),
            (componentDefs[4], claims),
            (componentDefs[5], sentiment),
        ]

        var components: [GEIComponent] = []

        for (def, history) in allHistories {
            guard let currentValue = history.last, !history.isEmpty else {
                logWarning("GEI: No data for \(def.name) (\(def.seriesId))", category: .data)
                continue
            }

            // z-score requires 20+ data points; fall back to manual calc for shorter series
            let zScoreResult = StatisticsCalculator.calculateZScore(
                currentValue: currentValue,
                history: history
            )

            let zScore = zScoreResult?.zScore ?? manualZScore(current: currentValue, history: history)

            components.append(GEIComponent(
                name: def.name,
                seriesId: def.seriesId,
                currentValue: currentValue,
                zScore: zScore,
                isInverted: def.isInverted
            ))
        }

        guard !components.isEmpty else {
            throw GEIError.noData
        }

        // GEI = equal-weighted mean of contributions
        let totalContribution = components.reduce(0.0) { $0 + $1.contribution }
        let score = totalContribution / Double(components.count)
        let signal = GEISignal.from(score: score)

        let geiData = GEIData(
            score: score,
            components: components,
            signal: signal,
            timestamp: Date()
        )

        // Cache result
        APICache.shared.set(Self.cacheKey, value: geiData, ttl: Self.cacheTTL)

        logInfo("GEI computed: \(geiData.formattedScore) (\(signal.label)), \(components.count)/6 components", category: .data)

        return geiData
    }

    // MARK: - Historical GEI

    func fetchGEIHistory() async throws -> [MacroChartPoint] {
        // Check cache first
        if let cached: [MacroChartPoint] = APICache.shared.get(Self.historyCacheKey) {
            return cached
        }

        // Fetch all components with dates in parallel
        async let copperTask = fetchYahooHistoryWithDates(symbol: "HG=F")
        async let tnxTask = fetchYahooHistoryWithDates(symbol: "^TNX")
        async let yieldCurveTask = fetchFREDHistoryWithDates(seriesId: "T10Y2Y")
        async let creditSpreadTask = fetchFREDHistoryWithDates(seriesId: "BAMLH0A0HYM2")
        async let claimsTask = fetchFREDHistoryWithDates(seriesId: "ICSA")
        async let sentimentTask = fetchFREDHistoryWithDates(seriesId: "UMCSENT")

        let allSeries: [(ComponentDef, [(Date, Double)])] = [
            (componentDefs[0], await copperTask),
            (componentDefs[1], await tnxTask),
            (componentDefs[2], await yieldCurveTask),
            (componentDefs[3], await creditSpreadTask),
            (componentDefs[4], await claimsTask),
            (componentDefs[5], await sentimentTask),
        ]

        // Collect all unique trading dates (sorted ascending)
        var dateSet = Set<Date>()
        for (_, series) in allSeries {
            for (date, _) in series {
                let day = Calendar.current.startOfDay(for: date)
                dateSet.insert(day)
            }
        }
        let allDates = dateSet.sorted()
        guard allDates.count >= 20 else { throw GEIError.noData }

        // Forward-fill each series to daily granularity
        let filledSeries: [[(Date, Double)]] = allSeries.map { (def, series) in
            forwardFill(series: series, toDates: allDates)
        }

        // Compute GEI at each date using expanding-window z-scores
        var history: [MacroChartPoint] = []

        for dateIndex in 0..<allDates.count {
            let date = allDates[dateIndex]
            var zScores: [Double] = []

            for (compIndex, (def, _)) in allSeries.enumerated() {
                let filled = filledSeries[compIndex]
                // Values up to and including this date
                let valuesUpToNow = filled.prefix(dateIndex + 1).map(\.1)
                guard valuesUpToNow.count >= 10 else { continue }

                guard let current = valuesUpToNow.last else { continue }
                let mean = valuesUpToNow.reduce(0, +) / Double(valuesUpToNow.count)
                let variance = valuesUpToNow.reduce(0) { $0 + pow($1 - mean, 2) } / Double(valuesUpToNow.count - 1)
                let sd = sqrt(variance)
                guard sd > 0 else { continue }

                var z = (current - mean) / sd
                if def.isInverted { z = -z }
                zScores.append(z)
            }

            guard zScores.count >= 3 else { continue }
            let geiScore = zScores.reduce(0, +) / Double(zScores.count)
            history.append(MacroChartPoint(date: date, value: geiScore))
        }

        // Cache result
        APICache.shared.set(Self.historyCacheKey, value: history, ttl: Self.cacheTTL)
        logInfo("GEI history computed: \(history.count) data points", category: .data)

        return history
    }

    /// Forward-fill a sparse series to a full set of daily dates
    private func forwardFill(series: [(Date, Double)], toDates: [Date]) -> [(Date, Double)] {
        // Build a lookup from the sparse series (keyed by start-of-day)
        var lookup: [Date: Double] = [:]
        for (date, value) in series {
            lookup[Calendar.current.startOfDay(for: date)] = value
        }

        var result: [(Date, Double)] = []
        var lastValue: Double?

        for date in toDates {
            if let value = lookup[date] {
                lastValue = value
            }
            if let value = lastValue {
                result.append((date, value))
            }
        }
        return result
    }

    // MARK: - Date-Preserving Fetch Helpers

    /// Fetches ~90 days of daily close prices from Yahoo Finance, preserving dates
    private func fetchYahooHistoryWithDates(symbol: String) async -> [(Date, Double)] {
        do {
            let result = try await yahooService.fetchChartBars(
                symbol: symbol,
                interval: "1d",
                range: "3mo"
            )
            return result.bars.map { ($0.date, $0.close) }
        } catch {
            logError("GEI: Yahoo fetch failed for \(symbol): \(error)", category: .data)
            return []
        }
    }

    /// Fetches ~90 days of observations from FRED, preserving dates
    private func fetchFREDHistoryWithDates(seriesId: String) async -> [(Date, Double)] {
        do {
            let calendar = Calendar.current
            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -120, to: endDate) else {
                return []
            }

            let queryItems: [String: String] = [
                "series_id": seriesId,
                "file_type": "json",
                "observation_start": dateFormatter.string(from: startDate),
                "observation_end": dateFormatter.string(from: endDate),
                "sort_order": "asc"
            ]

            let data = try await APIProxy.shared.request(
                service: .fred,
                path: "/series/observations",
                queryItems: queryItems
            )

            let response = try JSONDecoder().decode(FREDResponse.self, from: data)
            return response.observations.compactMap { obs in
                guard let value = Double(obs.value),
                      let date = self.dateFormatter.date(from: obs.date) else { return nil }
                return (date, value)
            }
        } catch {
            logError("GEI: FRED fetch failed for \(seriesId): \(error)", category: .data)
            return []
        }
    }

    // MARK: - Yahoo Finance Fetching

    /// Fetches ~90 days of daily close prices from Yahoo Finance
    private func fetchYahooHistory(symbol: String) async -> [Double] {
        do {
            let result = try await yahooService.fetchChartBars(
                symbol: symbol,
                interval: "1d",
                range: "3mo"
            )
            return result.bars.map { $0.close }
        } catch {
            logError("GEI: Yahoo fetch failed for \(symbol): \(error)", category: .data)
            return []
        }
    }

    // MARK: - FRED API Fetching

    /// Fetches ~90 days of observations from FRED
    private func fetchFREDHistory(seriesId: String) async -> [Double] {
        do {
            let calendar = Calendar.current
            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .day, value: -120, to: endDate) else {
                return []
            }

            let queryItems: [String: String] = [
                "series_id": seriesId,
                "file_type": "json",
                "observation_start": dateFormatter.string(from: startDate),
                "observation_end": dateFormatter.string(from: endDate),
                "sort_order": "asc"
            ]

            let data = try await APIProxy.shared.request(
                service: .fred,
                path: "/series/observations",
                queryItems: queryItems
            )

            let response = try JSONDecoder().decode(FREDResponse.self, from: data)
            return response.observations.compactMap { obs in
                Double(obs.value)
            }
        } catch {
            logError("GEI: FRED fetch failed for \(seriesId): \(error)", category: .data)
            return []
        }
    }

    // MARK: - Fallback Z-Score

    /// Manual z-score for series with fewer than 20 data points (e.g., monthly UMCSENT)
    private func manualZScore(current: Double, history: [Double]) -> Double {
        guard history.count >= 3 else { return 0 }
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(history.count - 1)
        let sd = sqrt(variance)
        guard sd > 0 else { return 0 }
        return (current - mean) / sd
    }
}

// MARK: - Private FRED Response Models

private struct FREDResponse: Codable {
    let observations: [FREDObservation]
}

private struct FREDObservation: Codable {
    let date: String
    let value: String
}

// MARK: - GEI Errors

enum GEIError: Error, LocalizedError {
    case noData

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No GEI data available"
        }
    }
}
