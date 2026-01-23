import Foundation

// MARK: - API VIX Service
/// Real API implementation of VIXServiceProtocol.
/// Uses Alpha Vantage API with VIXY ETF as VIX proxy.
final class APIVIXService: VIXServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared

    // MARK: - VIX Scaling
    /// VIXY ETF price to VIX approximation multiplier
    /// This is a rough conversion since VIXY tracks VIX futures, not spot VIX
    private let vixScalingFactor: Double = 1.5

    // MARK: - VIXServiceProtocol

    func fetchLatestVIX() async throws -> VIXData? {
        let endpoint = AlphaVantageEndpoint.vixGlobalQuote

        do {
            let response: AlphaVantageGlobalQuoteResponse = try await networkManager.request(endpoint)
            return convertQuoteToVIXData(response.globalQuote)
        } catch {
            logError("Failed to fetch latest VIX: \(error)")
            throw error
        }
    }

    func fetchVIXHistory(days: Int) async throws -> [VIXData] {
        let endpoint = AlphaVantageEndpoint.vixDaily

        do {
            let response: AlphaVantageTimeSeries = try await networkManager.request(endpoint)
            return convertTimeSeriesToVIXData(response, days: days)
        } catch {
            logError("Failed to fetch VIX history: \(error)")
            throw error
        }
    }

    // MARK: - Private Helpers

    private func convertQuoteToVIXData(_ quote: AlphaVantageQuote) -> VIXData {
        let price = Double(quote.price) ?? 0
        let scaledValue = price * vixScalingFactor

        return VIXData(
            date: quote.latestTradingDay,
            value: scaledValue,
            open: (Double(quote.open) ?? 0) * vixScalingFactor,
            high: (Double(quote.high) ?? 0) * vixScalingFactor,
            low: (Double(quote.low) ?? 0) * vixScalingFactor,
            close: scaledValue
        )
    }

    private func convertTimeSeriesToVIXData(_ timeSeries: AlphaVantageTimeSeries, days: Int) -> [VIXData] {
        let sortedDates = timeSeries.timeSeries.keys.sorted(by: >)
        let limitedDates = Array(sortedDates.prefix(days))

        return limitedDates.compactMap { date -> VIXData? in
            guard let data = timeSeries.timeSeries[date] else { return nil }

            let close = Double(data.close) ?? 0
            let scaledValue = close * vixScalingFactor

            return VIXData(
                date: date,
                value: scaledValue,
                open: (Double(data.open) ?? 0) * vixScalingFactor,
                high: (Double(data.high) ?? 0) * vixScalingFactor,
                low: (Double(data.low) ?? 0) * vixScalingFactor,
                close: scaledValue
            )
        }
    }
}
