import Foundation

// MARK: - API Global Liquidity Service
/// Fetches global M2 liquidity data aggregating 5 major economies:
/// US, China, Eurozone, Japan, and UK.
///
/// Methodology matches TradingView's "M2 Global Liquidity Index" by Mik3Christ3ns3n:
///   total = (CNM2×CNYUSD + USM2 + EUM2×EURUSD + JPM2×JPYUSD + GBM2×GBPUSD)
///
/// - US M2: Actual data from FRED (M2SL series, monthly)
/// - FX Rates: Live daily data from FRED (DEXCHUS, DEXUSEU, DEXJPUS, DEXUSUK)
/// - Non-US M2: Calibrated base values with estimated growth rates,
///   since FRED's international M2 series were discontinued (2017-2019).
final class APIGlobalLiquidityService: GlobalLiquidityServiceProtocol {
    // MARK: - Constants

    // API key injected server-side by api-proxy Edge Function

    // MARK: - Global M2 Reference Data
    // Base values sourced from central bank publications as of Jan 2025.
    // Growth rates are approximate annual rates used for extrapolation.

    private enum M2Base {
        // M2 in local currency (actual values)
        static let china: Double  = 313_530_000_000_000    // ¥313.53T CNY (PBoC, Jan 2025)
        static let eurozone: Double = 16_200_000_000_000   // €16.2T EUR (ECB, Jan 2025)
        static let japan: Double  = 1_240_000_000_000_000  // ¥1,240T JPY (BOJ, Jan 2025)
        static let uk: Double     = 3_100_000_000_000      // £3.1T GBP (BOE, Jan 2025)

        // Approximate annual M2 growth rates
        static let chinaGrowth: Double    = 0.07   // ~7%
        static let eurozoneGrowth: Double = 0.025  // ~2.5%
        static let japanGrowth: Double    = 0.02   // ~2%
        static let ukGrowth: Double       = 0.035  // ~3.5%

        // Reference date for base values
        static let referenceDateStr = "2025-01-01"

        // Default FX rates (fallback if FRED FX series fail)
        static let defaultCNYUSD: Double = 0.137   // USD per 1 CNY
        static let defaultEURUSD: Double = 1.04    // USD per 1 EUR
        static let defaultJPYUSD: Double = 0.0064  // USD per 1 JPY
        static let defaultGBPUSD: Double = 1.25    // USD per 1 GBP
    }

    // FRED daily FX rate series
    private enum FXSeriesID {
        static let cnyusd = "DEXCHUS"  // CNY per USD → invert for USD per CNY
        static let eurusd = "DEXUSEU"  // USD per EUR → use directly
        static let jpyusd = "DEXJPUS"  // JPY per USD → invert for USD per JPY
        static let gbpusd = "DEXUSUK"  // USD per GBP → use directly
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private lazy var referenceDate: Date = {
        dateFormatter.date(from: M2Base.referenceDateStr) ?? Date()
    }()

    // MARK: - Public Methods

    func fetchLiquidityChanges() async throws -> GlobalLiquidityChanges {
        let history = try await fetchLiquidityHistory(days: 400)

        guard !history.isEmpty else {
            throw LiquidityError.noData
        }

        let current = history.last?.value ?? 0
        let sortedHistory = history.sorted { $0.date < $1.date }

        let dailyChange = calculateChange(from: sortedHistory, daysAgo: 1)
        let weeklyChange = calculateChange(from: sortedHistory, daysAgo: 7)
        let monthlyChange = calculateChange(from: sortedHistory, daysAgo: 30)
        let yearlyChange = calculateChange(from: sortedHistory, daysAgo: 365)

        return GlobalLiquidityChanges(
            current: current,
            dailyChange: dailyChange,
            weeklyChange: weeklyChange ?? 0,
            monthlyChange: monthlyChange ?? 0,
            yearlyChange: yearlyChange ?? 0,
            history: sortedHistory
        )
    }

    func fetchLiquidityHistory(days: Int) async throws -> [GlobalLiquidityData] {
        guard SupabaseManager.shared.isConfigured else {
            throw LiquidityError.apiKeyNotConfigured
        }

        // Fetch US M2 and all FX rates in parallel
        async let usM2Task = fetchFREDObservations(seriesId: FREDSeries.m2.rawValue, days: days)
        async let cnyTask = fetchFREDObservationsSafe(seriesId: FXSeriesID.cnyusd, days: days)
        async let eurTask = fetchFREDObservationsSafe(seriesId: FXSeriesID.eurusd, days: days)
        async let jpyTask = fetchFREDObservationsSafe(seriesId: FXSeriesID.jpyusd, days: days)
        async let gbpTask = fetchFREDObservationsSafe(seriesId: FXSeriesID.gbpusd, days: days)

        let usM2Observations = try await usM2Task
        let cnyRates = await cnyTask
        let eurRates = await eurTask
        let jpyRates = await jpyTask
        let gbpRates = await gbpTask

        let hasFXData = !cnyRates.isEmpty || !eurRates.isEmpty || !jpyRates.isEmpty || !gbpRates.isEmpty

        if hasFXData {
            logInfo("Building Global M2 with FX data: CNY=\(cnyRates.count), EUR=\(eurRates.count), JPY=\(jpyRates.count), GBP=\(gbpRates.count) observations", category: .data)
        } else {
            logInfo("No FX data available, using default rates for Global M2", category: .data)
        }

        return buildGlobalM2(
            usM2: usM2Observations,
            cnyRates: cnyRates,
            eurRates: eurRates,
            jpyRates: jpyRates,
            gbpRates: gbpRates
        )
    }

    func fetchLatestM2() async throws -> Double {
        let history = try await fetchLiquidityHistory(days: 7)
        guard let latest = history.last else {
            throw LiquidityError.noData
        }
        return latest.value
    }

    // MARK: - FRED API Fetching

    private func fetchFREDObservations(seriesId: String, days: Int) async throws -> [FREDObservation] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            throw LiquidityError.invalidDate
        }

        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)

        // api_key injected server-side by api-proxy Edge Function
        let queryItems: [String: String] = [
            "series_id": seriesId,
            "file_type": "json",
            "observation_start": startDateStr,
            "observation_end": endDateStr,
            "sort_order": "asc"
        ]

        let data = try await APIProxy.shared.request(
            service: .fred,
            path: "/series/observations",
            queryItems: queryItems
        )

        let fredResponse = try JSONDecoder().decode(FREDResponse.self, from: data)
        return fredResponse.observations
    }

    /// Non-throwing wrapper for parallel FX fetches
    private func fetchFREDObservationsSafe(seriesId: String, days: Int) async -> [FREDObservation] {
        do {
            return try await fetchFREDObservations(seriesId: seriesId, days: days)
        } catch {
            logError("Failed to fetch FRED series \(seriesId): \(error)", category: .data)
            return []
        }
    }

    // MARK: - Global M2 Aggregation

    private func buildGlobalM2(
        usM2: [FREDObservation],
        cnyRates: [FREDObservation],
        eurRates: [FREDObservation],
        jpyRates: [FREDObservation],
        gbpRates: [FREDObservation]
    ) -> [GlobalLiquidityData] {
        // Parse FX rates into lookup arrays
        let cnyLookup = parseFXRates(cnyRates)
        let eurLookup = parseFXRates(eurRates)
        let jpyLookup = parseFXRates(jpyRates)
        let gbpLookup = parseFXRates(gbpRates)

        var results: [GlobalLiquidityData] = []
        var previousValue: Double = 0

        for obs in usM2 {
            guard let date = dateFormatter.date(from: obs.date),
                  let usValue = Double(obs.value) else {
                continue
            }

            // US M2 from FRED is in billions → convert to actual dollars
            let usM2Actual = usValue * 1_000_000_000

            // Years since reference date (can be negative for dates before reference)
            let yearsSinceRef = date.timeIntervalSince(referenceDate) / (365.25 * 86400)

            // Estimate each country's M2 by growing from base values
            let chinaM2 = M2Base.china * pow(1 + M2Base.chinaGrowth, yearsSinceRef)
            let euM2 = M2Base.eurozone * pow(1 + M2Base.eurozoneGrowth, yearsSinceRef)
            let jpM2 = M2Base.japan * pow(1 + M2Base.japanGrowth, yearsSinceRef)
            let ukM2 = M2Base.uk * pow(1 + M2Base.ukGrowth, yearsSinceRef)

            // Get FX rates (USD per 1 unit of local currency)
            // DEXCHUS gives CNY per USD → invert to get USD per CNY
            // DEXUSEU gives USD per EUR → use directly
            // DEXJPUS gives JPY per USD → invert to get USD per JPY
            // DEXUSUK gives USD per GBP → use directly
            let cnyusd = findClosestRate(for: date, in: cnyLookup, invert: true) ?? M2Base.defaultCNYUSD
            let eurusd = findClosestRate(for: date, in: eurLookup, invert: false) ?? M2Base.defaultEURUSD
            let jpyusd = findClosestRate(for: date, in: jpyLookup, invert: true) ?? M2Base.defaultJPYUSD
            let gbpusd = findClosestRate(for: date, in: gbpLookup, invert: false) ?? M2Base.defaultGBPUSD

            // Aggregate: matches TradingView Pine Script formula
            let globalM2 = usM2Actual
                + (chinaM2 * cnyusd)
                + (euM2 * eurusd)
                + (jpM2 * jpyusd)
                + (ukM2 * gbpusd)

            let dataPoint = GlobalLiquidityData(
                date: date,
                value: globalM2,
                previousValue: previousValue > 0 ? previousValue : globalM2
            )

            results.append(dataPoint)
            previousValue = globalM2
        }

        return results
    }

    // MARK: - FX Rate Helpers

    private struct FXDataPoint {
        let date: Date
        let rate: Double
    }

    /// Parse FRED observations into date-rate pairs, filtering invalid values
    private func parseFXRates(_ observations: [FREDObservation]) -> [FXDataPoint] {
        observations.compactMap { obs in
            guard let date = dateFormatter.date(from: obs.date),
                  let rate = Double(obs.value),
                  rate > 0 else {
                return nil  // FRED uses "." for missing values (weekends/holidays)
            }
            return FXDataPoint(date: date, rate: rate)
        }
    }

    /// Find the closest FX rate to a target date, optionally inverting
    private func findClosestRate(for targetDate: Date, in rates: [FXDataPoint], invert: Bool) -> Double? {
        guard !rates.isEmpty else { return nil }

        let closest = rates.min { a, b in
            abs(a.date.timeIntervalSince(targetDate)) < abs(b.date.timeIntervalSince(targetDate))
        }

        guard let match = closest else { return nil }

        // Only use rates within 7 days of target (handles weekends + holidays)
        let daysDiff = abs(match.date.timeIntervalSince(targetDate)) / 86400
        guard daysDiff <= 7 else { return nil }

        return invert ? (1.0 / match.rate) : match.rate
    }

    // MARK: - Change Calculation

    private func calculateChange(from history: [GlobalLiquidityData], daysAgo: Int) -> Double? {
        guard !history.isEmpty else { return nil }

        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

        let pastData = history.min { a, b in
            abs(a.date.timeIntervalSince(targetDate)) < abs(b.date.timeIntervalSince(targetDate))
        }

        guard let past = pastData, let current = history.last else { return nil }

        let change = ((current.value - past.value) / past.value) * 100
        return change
    }
}

// MARK: - FRED API Response Models

private struct FREDResponse: Codable {
    let realtime_start: String
    let realtime_end: String
    let observation_start: String
    let observation_end: String
    let units: String
    let output_type: Int
    let file_type: String
    let order_by: String
    let sort_order: String
    let count: Int
    let offset: Int
    let limit: Int
    let observations: [FREDObservation]
}

private struct FREDObservation: Codable {
    let realtime_start: String
    let realtime_end: String
    let date: String
    let value: String
}

// MARK: - Liquidity Errors

enum LiquidityError: Error, LocalizedError {
    case apiKeyNotConfigured
    case invalidURL
    case invalidDate
    case apiError
    case noData

    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "FRED API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidDate:
            return "Invalid date range"
        case .apiError:
            return "Failed to fetch liquidity data"
        case .noData:
            return "No liquidity data available"
        }
    }
}
