import Foundation

// MARK: - API DXY Service
/// Real API implementation of DXYServiceProtocol.
/// Uses Alpha Vantage API with UUP ETF as DXY proxy.
final class APIDXYService: DXYServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared

    // MARK: - DXY Scaling
    /// UUP ETF price to DXY approximation multiplier
    /// UUP trades around $27-28, DXY around 100-105
    /// This provides a rough conversion for display purposes
    private let dxyScalingFactor: Double = 3.7

    // MARK: - DXYServiceProtocol

    func fetchLatestDXY() async throws -> DXYData? {
        let endpoint = AlphaVantageEndpoint.dxyGlobalQuote

        do {
            let response: AlphaVantageGlobalQuoteResponse = try await networkManager.request(endpoint)
            return convertQuoteToDXYData(response.globalQuote)
        } catch {
            logError("Failed to fetch latest DXY: \(error)")
            throw error
        }
    }

    func fetchDXYHistory(days: Int) async throws -> [DXYData] {
        let endpoint = AlphaVantageEndpoint.dxyDaily

        do {
            let response: AlphaVantageTimeSeries = try await networkManager.request(endpoint)
            return convertTimeSeriesToDXYData(response, days: days)
        } catch {
            logError("Failed to fetch DXY history: \(error)")
            throw error
        }
    }

    // MARK: - Private Helpers

    private func convertQuoteToDXYData(_ quote: AlphaVantageQuote) -> DXYData {
        let price = Double(quote.price) ?? 0
        let previousClose = Double(quote.previousClose) ?? 0
        let scaledValue = price * dxyScalingFactor
        let scaledPreviousClose = previousClose * dxyScalingFactor

        return DXYData(
            date: quote.latestTradingDay,
            value: scaledValue,
            open: (Double(quote.open) ?? 0) * dxyScalingFactor,
            high: (Double(quote.high) ?? 0) * dxyScalingFactor,
            low: (Double(quote.low) ?? 0) * dxyScalingFactor,
            close: scaledValue,
            previousClose: scaledPreviousClose
        )
    }

    private func convertTimeSeriesToDXYData(_ timeSeries: AlphaVantageTimeSeries, days: Int) -> [DXYData] {
        let sortedDates = timeSeries.timeSeries.keys.sorted(by: >)
        let limitedDates = Array(sortedDates.prefix(days + 1)) // +1 to get previous close for first item

        var result: [DXYData] = []

        for (index, date) in limitedDates.enumerated() {
            guard let data = timeSeries.timeSeries[date] else { continue }
            // Skip the last item as it's only used for previous close
            if index == limitedDates.count - 1 && limitedDates.count > 1 { continue }

            let close = Double(data.close) ?? 0
            let scaledValue = close * dxyScalingFactor

            // Get previous close from next date in array (which is previous chronologically)
            var scaledPreviousClose: Double? = nil
            if index + 1 < limitedDates.count,
               let previousData = timeSeries.timeSeries[limitedDates[index + 1]] {
                scaledPreviousClose = (Double(previousData.close) ?? 0) * dxyScalingFactor
            }

            result.append(DXYData(
                date: date,
                value: scaledValue,
                open: (Double(data.open) ?? 0) * dxyScalingFactor,
                high: (Double(data.high) ?? 0) * dxyScalingFactor,
                low: (Double(data.low) ?? 0) * dxyScalingFactor,
                close: scaledValue,
                previousClose: scaledPreviousClose
            ))
        }

        return result
    }
}
