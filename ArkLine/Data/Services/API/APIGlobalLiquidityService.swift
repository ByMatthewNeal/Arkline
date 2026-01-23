import Foundation

// MARK: - API Global Liquidity Service
/// Fetches global liquidity data from FRED (Federal Reserve Economic Data)
/// Uses M2 Money Stock as the primary liquidity indicator
final class APIGlobalLiquidityService: GlobalLiquidityServiceProtocol {
    // MARK: - Constants

    private let baseURL = Constants.Endpoints.fredBase
    private var apiKey: String { Constants.API.fredAPIKey }

    // MARK: - Public Methods

    func fetchLiquidityChanges() async throws -> GlobalLiquidityChanges {
        // Fetch M2 data with enough history for all timeframes
        let history = try await fetchLiquidityHistory(days: 400)

        guard !history.isEmpty else {
            throw LiquidityError.noData
        }

        let current = history.last?.value ?? 0
        let sortedHistory = history.sorted { $0.date < $1.date }

        // Calculate changes for different timeframes
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
        // If API key not set, throw an error that can be handled gracefully
        guard apiKey != "your-fred-api-key" else {
            throw LiquidityError.apiKeyNotConfigured
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            throw LiquidityError.invalidDate
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startDateStr = dateFormatter.string(from: startDate)
        let endDateStr = dateFormatter.string(from: endDate)

        // Build FRED API URL for M2 money stock
        var components = URLComponents(string: "\(baseURL)/series/observations")
        components?.queryItems = [
            URLQueryItem(name: "series_id", value: FREDSeries.m2.rawValue),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "file_type", value: "json"),
            URLQueryItem(name: "observation_start", value: startDateStr),
            URLQueryItem(name: "observation_end", value: endDateStr),
            URLQueryItem(name: "sort_order", value: "asc")
        ]

        guard let url = components?.url else {
            throw LiquidityError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LiquidityError.apiError
        }

        let fredResponse = try JSONDecoder().decode(FREDResponse.self, from: data)
        return convertToLiquidityData(observations: fredResponse.observations)
    }

    func fetchLatestM2() async throws -> Double {
        let history = try await fetchLiquidityHistory(days: 7)
        guard let latest = history.last else {
            throw LiquidityError.noData
        }
        return latest.value
    }

    // MARK: - Private Methods

    private func calculateChange(from history: [GlobalLiquidityData], daysAgo: Int) -> Double? {
        guard !history.isEmpty else { return nil }

        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()

        // Find closest data point to target date
        let pastData = history.min { a, b in
            abs(a.date.timeIntervalSince(targetDate)) < abs(b.date.timeIntervalSince(targetDate))
        }

        guard let past = pastData, let current = history.last else { return nil }

        let change = ((current.value - past.value) / past.value) * 100
        return change
    }

    private func convertToLiquidityData(observations: [FREDObservation]) -> [GlobalLiquidityData] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var results: [GlobalLiquidityData] = []
        var previousValue: Double = 0

        for obs in observations {
            guard let date = dateFormatter.date(from: obs.date),
                  let value = Double(obs.value) else {
                continue
            }

            // M2 values are in billions, convert to actual value
            let actualValue = value * 1_000_000_000

            let dataPoint = GlobalLiquidityData(
                date: date,
                value: actualValue,
                previousValue: previousValue > 0 ? previousValue : actualValue
            )

            results.append(dataPoint)
            previousValue = actualValue
        }

        return results
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
