import Foundation

// MARK: - App Store Ranking Service
/// Fetches Coinbase app ranking from Apple's iTunes RSS feed (US All Free Apps)
final class APIAppStoreRankingService {

    // MARK: - Public Methods

    /// Fetch current Coinbase ranking from US App Store (All Free Apps)
    func fetchCoinbaseRanking() async throws -> AppStoreRankingResult {
        let coinbaseAppId = "886427730"
        let ranking = await fetchOverallRank(appId: coinbaseAppId)

        return AppStoreRankingResult(
            appName: "Coinbase",
            appId: coinbaseAppId,
            ranking: ranking,
            timestamp: Date()
        )
    }

    /// Fetch ranking in overall free apps (top 200)
    private func fetchOverallRank(appId: String) async -> Int? {
        let urlString = "https://itunes.apple.com/us/rss/topfreeapplications/limit=200/json"
        return await fetchRankFromFeed(urlString: urlString, appId: appId)
    }

    /// Generic feed fetcher
    private func fetchRankFromFeed(urlString: String, appId: String) async -> Int? {
        guard let url = URL(string: urlString) else {
            logError("Invalid iTunes RSS URL", category: .network)
            return nil
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logError("iTunes RSS error: bad response", category: .network)
                return nil
            }

            let feed = try JSONDecoder().decode(ITunesFeedResponse.self, from: data)

            // Find the app's position in the chart
            for (index, app) in feed.feed.entry.enumerated() {
                if app.id.attributes.imId == appId {
                    let rank = index + 1
                    logDebug("Found Coinbase at rank #\(rank) in US App Store", category: .network)
                    return rank
                }
            }

            // App not in top 200
            logWarning("Coinbase not found in top 200 apps", category: .network)
            return nil

        } catch {
            logError("iTunes RSS fetch error: \(error)", category: .network)
            return nil
        }
    }
}

// MARK: - iTunes RSS Response Models
struct ITunesFeedResponse: Codable {
    let feed: ITunesFeed
}

struct ITunesFeed: Codable {
    let entry: [ITunesAppEntry]
}

struct ITunesAppEntry: Codable {
    let id: ITunesAppId
    let imName: ITunesLabel

    enum CodingKeys: String, CodingKey {
        case id
        case imName = "im:name"
    }
}

struct ITunesAppId: Codable {
    let attributes: ITunesIdAttributes
}

struct ITunesIdAttributes: Codable {
    let imId: String

    enum CodingKeys: String, CodingKey {
        case imId = "im:id"
    }
}

struct ITunesLabel: Codable {
    let label: String
}

// MARK: - Domain Models

/// Result from App Store ranking fetch
struct AppStoreRankingResult {
    let appName: String
    let appId: String
    let ranking: Int?  // nil means not in top 200
    let timestamp: Date

    var displayRanking: String {
        if let rank = ranking {
            return "#\(rank)"
        }
        return ">200"
    }

    var isRanked: Bool {
        ranking != nil
    }
}
