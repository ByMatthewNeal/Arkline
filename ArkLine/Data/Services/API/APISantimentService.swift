import Foundation

// MARK: - Santiment GraphQL Response Models
struct SantimentGraphQLResponse: Codable {
    let data: SantimentResponseData?
    let errors: [SantimentError]?
}

struct SantimentResponseData: Codable {
    let getMetric: SantimentMetric
}

struct SantimentMetric: Codable {
    let timeseriesData: [SantimentTimeseriesPoint]?
}

struct SantimentTimeseriesPoint: Codable {
    let datetime: String
    let value: Double
}

struct SantimentError: Codable {
    let message: String
}

// MARK: - API Santiment Service
/// Real API implementation using Santiment's free GraphQL API.
/// Data is stored in Supabase for persistence and reduced API calls.
/// No API key required for basic metrics like supply in profit.
final class APISantimentService: SantimentServiceProtocol {
    // MARK: - Configuration
    private let baseURL = "https://api.santiment.net/graphql"
    private let cache = APICache.shared
    private let database = SupabaseDatabase.shared

    // MARK: - Date Formatting
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - SantimentServiceProtocol

    func fetchLatestSupplyInProfit() async throws -> SupplyProfitData? {
        // Try Supabase first, but only if data is reasonably fresh
        if let supabaseLatest = try? await database.getLatestSupplyInProfitData() {
            let data = supabaseLatest.toSupplyProfitData()

            // Santiment free tier lags ~30 days. Consider data stale if it's more
            // than 33 days old, meaning newer data should be available on the API.
            if let dateObj = data.dateObject {
                let daysSinceData = Calendar.current.dateComponents([.day], from: dateObj, to: Date()).day ?? 0
                if daysSinceData <= 33 {
                    return data
                }
            }
        }

        // Supabase data is missing or stale — fetch from API to get the latest
        let history = try await fetchSupplyInProfitHistory(days: 7)
        return history.first
    }

    func fetchSupplyInProfitHistory(days: Int) async throws -> [SupplyProfitData] {
        let cacheKey = "supply_in_profit_\(days)"

        return try await cache.getOrFetch(cacheKey, ttl: APICache.TTL.long) {
            // Step 1: Get data from Supabase (non-blocking, fails gracefully)
            let supabaseData = await fetchFromSupabase(days: days)
            let supabaseDates = Set(supabaseData.map { $0.date })

            // Step 2: Get static historical data for dates not in Supabase
            let staticData = SupplyInProfitHistorical.recentData(days: days)
                .filter { !supabaseDates.contains($0.date) }

            // Step 3: Determine what dates we're missing from Santiment API range
            let allKnownDates = supabaseDates.union(Set(staticData.map { $0.date }))

            // Step 4: Try to fetch new data from Santiment API
            var newApiData: [SupplyProfitData] = []
            if let apiData = try? await fetchFromAPI(days: min(days, 90)), !apiData.isEmpty {
                // Filter to only new data not already stored
                let dataToStore = apiData.filter { !allKnownDates.contains($0.date) }

                // Step 5: Store new data to Supabase in background (non-blocking)
                if !dataToStore.isEmpty {
                    Task { await self.storeToSupabase(dataToStore) }
                }

                // Include API data that's not in Supabase yet
                let freshApiData = apiData.filter { !supabaseDates.contains($0.date) }
                newApiData = freshApiData
            }

            // Step 6: Combine all sources (newest first)
            let combined = (supabaseData + newApiData + staticData)
                .sorted { $0.date > $1.date }

            // Remove duplicates keeping newest first
            var seenDates = Set<String>()
            let deduplicated = combined.filter { data in
                if seenDates.contains(data.date) {
                    return false
                }
                seenDates.insert(data.date)
                return true
            }

            logInfo("Supply in Profit: \(supabaseData.count) Supabase + \(newApiData.count) API + \(staticData.count) static", category: .network)
            return Array(deduplicated.prefix(days))
        }
    }

    // MARK: - Supabase Methods

    private func fetchFromSupabase(days: Int) async -> [SupplyProfitData] {
        // Fail gracefully - don't block UI if Supabase is slow
        guard SupabaseManager.shared.isConfigured else { return [] }

        do {
            let dtos = try await database.getSupplyInProfitData(limit: days)
            return dtos.map { $0.toSupplyProfitData() }
        } catch {
            logWarning("Supabase fetch failed, continuing with other sources: \(error)", category: .network)
            return []
        }
    }

    private func storeToSupabase(_ data: [SupplyProfitData]) async {
        let dtos = data.map { SupplyProfitDTO(from: $0) }
        do {
            try await database.saveSupplyInProfitData(dtos)
            logInfo("Stored \(dtos.count) Supply in Profit data points to Supabase", category: .network)
        } catch {
            logWarning("Failed to store Supply in Profit to Supabase: \(error)", category: .network)
        }
    }

    // MARK: - Private Methods

    private func fetchFromAPI(days: Int) async throws -> [SupplyProfitData] {
        // Santiment free tier has a rolling ~11 month window with ~30 day lag
        // We need to clamp dates to the available range
        let effectiveDays = min(days, 330)

        // Free tier data lags ~30 days behind current date
        let freeTierEndDate = Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date()

        // Use the earlier of today or the free tier end date
        let to = min(Date(), freeTierEndDate)
        let from = Calendar.current.date(byAdding: .day, value: -effectiveDays, to: to) ?? to

        let fromString = isoFormatter.string(from: from)
        let toString = isoFormatter.string(from: to)

        // Build GraphQL query
        let query = """
        {
          getMetric(metric: "percent_of_total_supply_in_profit") {
            timeseriesData(slug: "bitcoin", from: "\(fromString)", to: "\(toString)", interval: "1d") {
              datetime
              value
            }
          }
        }
        """

        let requestBody: [String: Any] = ["query": query]

        guard let url = URL(string: baseURL) else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError(underlying: NSError(domain: "Invalid response", code: -1))
        }

        guard httpResponse.statusCode == 200 else {
            throw AppError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }

        let decoder = JSONDecoder()
        let graphQLResponse = try decoder.decode(SantimentGraphQLResponse.self, from: data)

        // Check for GraphQL errors
        if let errors = graphQLResponse.errors, !errors.isEmpty {
            let errorMessage = errors.map { $0.message }.joined(separator: ", ")
            logError("Santiment API error: \(errorMessage)", category: .network)
            throw AppError.httpError(statusCode: 400, message: errorMessage)
        }

        guard let timeseriesData = graphQLResponse.data?.getMetric.timeseriesData else {
            return []
        }

        // Convert to SupplyProfitData, newest first
        let result = timeseriesData.compactMap { point -> SupplyProfitData? in
            // Parse datetime (ISO format) to date string
            guard let date = isoFormatter.date(from: point.datetime) else { return nil }
            let dateString = dateFormatter.string(from: date)
            return SupplyProfitData(date: dateString, value: point.value)
        }

        logInfo("Santiment Supply in Profit fetched: \(result.count) days", category: .network)
        return result.reversed() // Newest first
    }
}
