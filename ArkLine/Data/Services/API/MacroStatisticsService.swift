import Foundation

/// Service for calculating z-scores and statistics for macro indicators
final class MacroStatisticsService: MacroStatisticsServiceProtocol {

    // MARK: - Dependencies

    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol

    // MARK: - Cache

    private let cache = APICache.shared
    private let cacheTTL: TimeInterval = 1800 // 30 minutes

    // MARK: - Configuration

    /// Minimum data points required for z-score calculation
    private let minimumDataPoints = 20

    /// Default lookback period for historical data
    private let defaultLookbackDays = 90

    // MARK: - Initialization

    init(
        vixService: VIXServiceProtocol? = nil,
        dxyService: DXYServiceProtocol? = nil,
        globalLiquidityService: GlobalLiquidityServiceProtocol? = nil
    ) {
        self.vixService = vixService ?? ServiceContainer.shared.vixService
        self.dxyService = dxyService ?? ServiceContainer.shared.dxyService
        self.globalLiquidityService = globalLiquidityService ?? ServiceContainer.shared.globalLiquidityService
    }

    // MARK: - Protocol Methods

    func fetchZScoreData(for indicator: MacroIndicatorType) async throws -> MacroZScoreData {
        let cacheKey = "macro_zscore_\(indicator.rawValue)"

        // Check cache first
        if let cached: MacroZScoreData = cache.get(cacheKey) {
            return cached
        }

        // Fetch fresh data
        let result = try await calculateZScore(for: indicator)

        // Cache the result
        cache.set(cacheKey, value: result, ttl: cacheTTL)

        return result
    }

    func fetchAllZScores() async throws -> [MacroIndicatorType: MacroZScoreData] {
        // Fetch all indicators in parallel
        async let vixData = fetchZScoreData(for: .vix)
        async let dxyData = fetchZScoreData(for: .dxy)
        async let m2Data = fetchZScoreData(for: .m2)

        // Collect results, allowing partial failures
        var results: [MacroIndicatorType: MacroZScoreData] = [:]

        if let vix = try? await vixData {
            results[.vix] = vix
        }
        if let dxy = try? await dxyData {
            results[.dxy] = dxy
        }
        if let m2 = try? await m2Data {
            results[.m2] = m2
        }

        return results
    }

    func getExtremeIndicators() async throws -> [MacroZScoreData] {
        let allZScores = try await fetchAllZScores()
        return allZScores.values.filter { $0.isExtreme }
    }

    // MARK: - Private Calculation Methods

    private func calculateZScore(for indicator: MacroIndicatorType) async throws -> MacroZScoreData {
        switch indicator {
        case .vix:
            return try await calculateVIXZScore()
        case .dxy:
            return try await calculateDXYZScore()
        case .m2:
            return try await calculateM2ZScore()
        }
    }

    private func calculateVIXZScore() async throws -> MacroZScoreData {
        // Fetch current and historical VIX data
        async let latestTask = vixService.fetchLatestVIX()
        async let historyTask = vixService.fetchVIXHistory(days: defaultLookbackDays)

        let (latest, history) = try await (latestTask, historyTask)

        guard let currentVIX = latest else {
            throw MacroStatisticsError.noCurrentData(indicator: .vix)
        }

        // Extract values from history
        let historyValues = history.map { $0.value }

        guard historyValues.count >= minimumDataPoints else {
            throw MacroStatisticsError.insufficientHistory(
                indicator: .vix,
                required: minimumDataPoints,
                actual: historyValues.count
            )
        }

        // Calculate z-score
        guard let zScore = StatisticsCalculator.calculateZScore(
            currentValue: currentVIX.value,
            history: historyValues
        ) else {
            throw MacroStatisticsError.calculationFailed(indicator: .vix)
        }

        // Calculate SD bands
        let sdBands = StatisticsCalculator.sdBands(mean: zScore.mean, sd: zScore.standardDeviation)

        return MacroZScoreData(
            indicator: .vix,
            currentValue: currentVIX.value,
            zScore: zScore,
            sdBands: sdBands,
            historyValues: historyValues,
            calculatedAt: Date()
        )
    }

    private func calculateDXYZScore() async throws -> MacroZScoreData {
        // Fetch current and historical DXY data
        async let latestTask = dxyService.fetchLatestDXY()
        async let historyTask = dxyService.fetchDXYHistory(days: defaultLookbackDays)

        let (latest, history) = try await (latestTask, historyTask)

        guard let currentDXY = latest else {
            throw MacroStatisticsError.noCurrentData(indicator: .dxy)
        }

        // Extract values from history
        let historyValues = history.map { $0.value }

        guard historyValues.count >= minimumDataPoints else {
            throw MacroStatisticsError.insufficientHistory(
                indicator: .dxy,
                required: minimumDataPoints,
                actual: historyValues.count
            )
        }

        // Calculate z-score
        guard let zScore = StatisticsCalculator.calculateZScore(
            currentValue: currentDXY.value,
            history: historyValues
        ) else {
            throw MacroStatisticsError.calculationFailed(indicator: .dxy)
        }

        // Calculate SD bands
        let sdBands = StatisticsCalculator.sdBands(mean: zScore.mean, sd: zScore.standardDeviation)

        return MacroZScoreData(
            indicator: .dxy,
            currentValue: currentDXY.value,
            zScore: zScore,
            sdBands: sdBands,
            historyValues: historyValues,
            calculatedAt: Date()
        )
    }

    private func calculateM2ZScore() async throws -> MacroZScoreData {
        // Fetch M2 data (includes history)
        let liquidityData = try await globalLiquidityService.fetchLiquidityChanges()

        let currentM2 = liquidityData.current

        // Extract values from history
        let historyValues = liquidityData.history.map { $0.value }

        guard historyValues.count >= minimumDataPoints else {
            throw MacroStatisticsError.insufficientHistory(
                indicator: .m2,
                required: minimumDataPoints,
                actual: historyValues.count
            )
        }

        // Calculate z-score
        guard let zScore = StatisticsCalculator.calculateZScore(
            currentValue: currentM2,
            history: historyValues
        ) else {
            throw MacroStatisticsError.calculationFailed(indicator: .m2)
        }

        // Calculate SD bands
        let sdBands = StatisticsCalculator.sdBands(mean: zScore.mean, sd: zScore.standardDeviation)

        return MacroZScoreData(
            indicator: .m2,
            currentValue: currentM2,
            zScore: zScore,
            sdBands: sdBands,
            historyValues: historyValues,
            calculatedAt: Date()
        )
    }
}

// MARK: - Errors

enum MacroStatisticsError: LocalizedError {
    case noCurrentData(indicator: MacroIndicatorType)
    case insufficientHistory(indicator: MacroIndicatorType, required: Int, actual: Int)
    case calculationFailed(indicator: MacroIndicatorType)

    var errorDescription: String? {
        switch self {
        case .noCurrentData(let indicator):
            return "No current data available for \(indicator.displayName)"
        case .insufficientHistory(let indicator, let required, let actual):
            return "\(indicator.displayName) has insufficient history (\(actual)/\(required) required)"
        case .calculationFailed(let indicator):
            return "Failed to calculate z-score for \(indicator.displayName)"
        }
    }
}
