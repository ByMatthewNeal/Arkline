import Foundation

/// Protocol for macro indicator statistics calculations
protocol MacroStatisticsServiceProtocol {
    /// Fetch z-score data for a specific macro indicator
    /// - Parameter indicator: The macro indicator type
    /// - Returns: MacroZScoreData with calculated statistics
    func fetchZScoreData(for indicator: MacroIndicatorType) async throws -> MacroZScoreData

    /// Fetch z-score data for all macro indicators
    /// - Returns: Dictionary mapping indicator types to their z-score data
    func fetchAllZScores() async throws -> [MacroIndicatorType: MacroZScoreData]

    /// Check if any indicator has an extreme reading
    /// - Returns: Array of indicators with extreme z-scores
    func getExtremeIndicators() async throws -> [MacroZScoreData]
}
