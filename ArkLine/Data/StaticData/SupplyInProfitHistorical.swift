import Foundation

// MARK: - Supply in Profit Historical Data
// Estimated historical values for BTC Supply in Profit percentage
// Used as fallback when Santiment API data is unavailable
// Values are percentages (0-100 scale) representing % of BTC supply in profit
//
// Note: Historical values are estimates based on cycle patterns.
// Recent data comes from Santiment API when available.

struct SupplyInProfitHistorical {

    /// Static historical data points (monthly granularity)
    /// Source: TradingView AlgoAlpha BTCSPL indicator
    static let historicalData: [SupplyProfitData] = [
        // 2012 - Early adoption phase
        SupplyProfitData(date: "2012-01-01", value: 45),
        SupplyProfitData(date: "2012-04-01", value: 55),
        SupplyProfitData(date: "2012-07-01", value: 60),
        SupplyProfitData(date: "2012-10-01", value: 65),

        // 2013 - First major bull run
        SupplyProfitData(date: "2013-01-01", value: 75),
        SupplyProfitData(date: "2013-04-01", value: 92),
        SupplyProfitData(date: "2013-07-01", value: 70),
        SupplyProfitData(date: "2013-10-01", value: 85),
        SupplyProfitData(date: "2013-12-01", value: 96), // Peak

        // 2014 - Bear market begins
        SupplyProfitData(date: "2014-01-01", value: 88),
        SupplyProfitData(date: "2014-04-01", value: 55),
        SupplyProfitData(date: "2014-07-01", value: 48),
        SupplyProfitData(date: "2014-10-01", value: 42),

        // 2015 - Bear market bottom
        SupplyProfitData(date: "2015-01-01", value: 38),
        SupplyProfitData(date: "2015-04-01", value: 45),
        SupplyProfitData(date: "2015-07-01", value: 52),
        SupplyProfitData(date: "2015-10-01", value: 60),

        // 2016 - Recovery
        SupplyProfitData(date: "2016-01-01", value: 58),
        SupplyProfitData(date: "2016-04-01", value: 65),
        SupplyProfitData(date: "2016-07-01", value: 72),
        SupplyProfitData(date: "2016-10-01", value: 78),

        // 2017 - Major bull run
        SupplyProfitData(date: "2017-01-01", value: 85),
        SupplyProfitData(date: "2017-04-01", value: 90),
        SupplyProfitData(date: "2017-07-01", value: 88),
        SupplyProfitData(date: "2017-10-01", value: 92),
        SupplyProfitData(date: "2017-12-01", value: 97), // ATH peak

        // 2018 - Bear market
        SupplyProfitData(date: "2018-01-01", value: 92),
        SupplyProfitData(date: "2018-04-01", value: 65),
        SupplyProfitData(date: "2018-07-01", value: 55),
        SupplyProfitData(date: "2018-10-01", value: 48),
        SupplyProfitData(date: "2018-12-01", value: 42), // Bottom

        // 2019 - Recovery and mini bull
        SupplyProfitData(date: "2019-01-01", value: 45),
        SupplyProfitData(date: "2019-04-01", value: 68),
        SupplyProfitData(date: "2019-07-01", value: 82),
        SupplyProfitData(date: "2019-10-01", value: 62),

        // 2020 - COVID crash and recovery
        SupplyProfitData(date: "2020-01-01", value: 70),
        SupplyProfitData(date: "2020-03-01", value: 55), // COVID crash
        SupplyProfitData(date: "2020-04-01", value: 62),
        SupplyProfitData(date: "2020-07-01", value: 75),
        SupplyProfitData(date: "2020-10-01", value: 85),
        SupplyProfitData(date: "2020-12-01", value: 92),

        // 2021 - Bull market peak
        SupplyProfitData(date: "2021-01-01", value: 95),
        SupplyProfitData(date: "2021-04-01", value: 97), // First peak
        SupplyProfitData(date: "2021-07-01", value: 75),
        SupplyProfitData(date: "2021-10-01", value: 92),
        SupplyProfitData(date: "2021-11-01", value: 98), // ATH

        // 2022 - Bear market
        SupplyProfitData(date: "2022-01-01", value: 78),
        SupplyProfitData(date: "2022-04-01", value: 65),
        SupplyProfitData(date: "2022-07-01", value: 52),
        SupplyProfitData(date: "2022-10-01", value: 50),
        SupplyProfitData(date: "2022-12-01", value: 52), // FTX bottom

        // 2023 - Recovery
        SupplyProfitData(date: "2023-01-01", value: 58),
        SupplyProfitData(date: "2023-04-01", value: 72),
        SupplyProfitData(date: "2023-07-01", value: 78),
        SupplyProfitData(date: "2023-10-01", value: 82),

        // 2024 - New bull market
        SupplyProfitData(date: "2024-01-01", value: 85),
        SupplyProfitData(date: "2024-03-01", value: 95), // ETF approval rally
        SupplyProfitData(date: "2024-04-01", value: 92),
        SupplyProfitData(date: "2024-07-01", value: 88),
        SupplyProfitData(date: "2024-10-01", value: 92),
        SupplyProfitData(date: "2024-12-01", value: 95), // New ATH

        // 2025 - Cycle continuation
        SupplyProfitData(date: "2025-01-01", value: 94),
        SupplyProfitData(date: "2025-04-01", value: 90),
        SupplyProfitData(date: "2025-07-01", value: 85),
        SupplyProfitData(date: "2025-10-01", value: 72),
        SupplyProfitData(date: "2025-12-01", value: 68),

        // 2026 - Current (from Santiment API)
        SupplyProfitData(date: "2026-01-01", value: 67),
        SupplyProfitData(date: "2026-01-02", value: 70), // Latest from Santiment free tier
    ]

    /// Get the most recent static data point
    static var latestValue: SupplyProfitData? {
        historicalData.last
    }

    /// Get data for chart display (sorted oldest to newest)
    static var chartData: [SupplyProfitData] {
        historicalData
    }

    /// Get data within a date range
    static func data(from startDate: Date, to endDate: Date) -> [SupplyProfitData] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return historicalData.filter { point in
            guard let date = formatter.date(from: point.date) else { return false }
            return date >= startDate && date <= endDate
        }
    }

    /// Get data for last N days (approximate - uses monthly data)
    static func recentData(days: Int) -> [SupplyProfitData] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return data(from: startDate, to: endDate)
    }
}
