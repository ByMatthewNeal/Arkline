import Foundation

// MARK: - Google News RSS Service
/// Fetches and parses Google News RSS feeds for crypto and geopolitical news
final class GoogleNewsRSSService: NSObject, XMLParserDelegate {

    // MARK: - RSS Feed URLs
    private enum FeedURL {
        static let crypto = "https://news.google.com/rss/search?q=cryptocurrency+OR+bitcoin+OR+ethereum+OR+crypto&hl=en-US&gl=US&ceid=US:en"
        static let geopolitics = "https://news.google.com/rss/search?q=geopolitics+OR+world+news+OR+international+relations+OR+global+politics&hl=en-US&gl=US&ceid=US:en"
        static let world = "https://news.google.com/rss/topics/CAAqJggKIiBDQkFTRWdvSUwyMHZNRGx1YlY4U0FtVnVHZ0pWVXlnQVAB?hl=en-US&gl=US&ceid=US:en"

        static func search(_ query: String) -> String {
            guard var components = URLComponents(string: "https://news.google.com/rss/search") else { return "" }
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "hl", value: "en-US"),
                URLQueryItem(name: "gl", value: "US"),
                URLQueryItem(name: "ceid", value: "US:en")
            ]
            return components.string ?? ""
        }

        /// Build a combined query URL from user-selected topics and custom keywords
        static func fromTopics(_ topics: Set<Constants.NewsTopic>, customKeywords: [String]) -> String {
            var queryParts: [String] = []

            // Add search queries for each selected topic
            for topic in topics {
                queryParts.append("(\(topic.searchQuery))")
            }

            // Add custom keywords
            for keyword in customKeywords {
                let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    queryParts.append("\"\(cleaned)\"")
                }
            }

            // Join with OR — URLComponents handles encoding
            let combinedQuery = queryParts.joined(separator: " OR ")
            guard var components = URLComponents(string: "https://news.google.com/rss/search") else { return "" }
            components.queryItems = [
                URLQueryItem(name: "q", value: combinedQuery),
                URLQueryItem(name: "hl", value: "en-US"),
                URLQueryItem(name: "gl", value: "US"),
                URLQueryItem(name: "ceid", value: "US:en")
            ]
            return components.string ?? ""
        }
    }

    // MARK: - Parser State
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentSource = ""
    private var currentDescription = ""
    private var newsItems: [GoogleNewsRSSItem] = []
    private var isInItem = false

    // MARK: - Public Methods

    /// Fetch crypto news from Google News RSS
    func fetchCryptoNews(limit: Int = 20) async throws -> [NewsItem] {
        return try await fetchFromURL(FeedURL.crypto, category: "Crypto", limit: limit)
    }

    /// Fetch geopolitical/world news from Google News RSS
    func fetchGeopoliticalNews(limit: Int = 20) async throws -> [NewsItem] {
        // Combine world topic feed with geopolitics search for broader coverage
        async let worldNews = fetchFromURL(FeedURL.world, category: "World", limit: limit)
        async let geoNews = fetchFromURL(FeedURL.geopolitics, category: "Geopolitics", limit: limit)

        let (world, geo) = try await (worldNews, geoNews)

        // Combine and deduplicate by title
        var seen = Set<String>()
        var combined: [NewsItem] = []

        for item in (world + geo) {
            let normalizedTitle = item.title.lowercased()
            if !seen.contains(normalizedTitle) {
                seen.insert(normalizedTitle)
                combined.append(item)
            }
        }

        // Sort by date and limit
        combined.sort { $0.publishedAt > $1.publishedAt }
        return Array(combined.prefix(limit))
    }

    /// Fetch news for a custom search query
    func fetchNews(query: String, limit: Int = 20) async throws -> [NewsItem] {
        return try await fetchFromURL(FeedURL.search(query), category: "Search", limit: limit)
    }

    /// Fetch personalized news based on user-selected topics and custom keywords
    func fetchPersonalizedNews(
        topics: Set<Constants.NewsTopic>,
        customKeywords: [String],
        limit: Int = 20
    ) async throws -> [NewsItem] {
        var allNews: [NewsItem] = []

        // Calculate how to distribute the limit
        let hasCustomKeywords = !customKeywords.isEmpty
        let topicsLimit = hasCustomKeywords ? (limit * 2 / 3) : limit  // 2/3 for topics
        let keywordsLimit = hasCustomKeywords ? (limit / 3) : 0        // 1/3 for custom keywords

        // Fetch news for pre-defined topics
        if !topics.isEmpty {
            do {
                let topicNews = try await fetchFromURL(
                    FeedURL.fromTopics(topics, customKeywords: []),
                    category: "Topics",
                    limit: topicsLimit
                )
                allNews.append(contentsOf: topicNews)
                logDebug("Fetched \(topicNews.count) items for topics", category: .network)
            } catch {
                logWarning("Failed to fetch topic news: \(error)", category: .network)
            }
        }

        // Fetch news for EACH custom keyword separately to ensure representation
        if hasCustomKeywords {
            let perKeywordLimit = max(3, keywordsLimit / customKeywords.count)

            for keyword in customKeywords {
                do {
                    let keywordNews = try await fetchFromURL(
                        FeedURL.search(keyword),
                        category: "Keyword:\(keyword)",
                        limit: perKeywordLimit
                    )
                    allNews.append(contentsOf: keywordNews)
                    logDebug("Fetched \(keywordNews.count) items for keyword '\(keyword)'", category: .network)
                } catch {
                    logWarning("Failed to fetch news for keyword '\(keyword)': \(error)", category: .network)
                }
            }
        }

        // Deduplicate by title
        var seen = Set<String>()
        var deduplicated: [NewsItem] = []

        for item in allNews {
            let normalizedTitle = item.title.lowercased()
            if !seen.contains(normalizedTitle) {
                seen.insert(normalizedTitle)
                deduplicated.append(item)
            }
        }

        // Sort by date and limit
        deduplicated.sort { $0.publishedAt > $1.publishedAt }
        return Array(deduplicated.prefix(limit))
    }

    // MARK: - Private Methods

    private func fetchFromURL(_ urlString: String, category: String, limit: Int) async throws -> [NewsItem] {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            logWarning("Google News RSS returned status \(httpResponse.statusCode)", category: .network)
            throw URLError(.badServerResponse)
        }

        // Parse RSS XML
        let items = parseRSS(data: data)

        // Convert to NewsItem
        let newsItems = items.prefix(limit).map { item -> NewsItem in
            NewsItem(
                id: UUID(),
                title: cleanTitle(item.title),
                source: item.source.isEmpty ? "Google News" : item.source,
                publishedAt: parseRSSDate(item.pubDate) ?? Date(),
                imageUrl: nil, // Google News RSS doesn't include images
                url: item.link,
                sourceType: .googleNews,
                twitterHandle: nil,
                isVerified: false,
                description: cleanDescription(item.description)
            )
        }

        logDebug("[\(category)] Fetched \(newsItems.count) items from Google News RSS", category: .network)
        return Array(newsItems)
    }

    private func parseRSS(data: Data) -> [GoogleNewsRSSItem] {
        // Reset state
        newsItems = []
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentPubDate = ""
        currentSource = ""
        currentDescription = ""
        isInItem = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        return newsItems
    }

    private func cleanTitle(_ title: String) -> String {
        // Remove " - Source Name" suffix that Google News adds
        if let dashRange = title.range(of: " - ", options: .backwards) {
            return String(title[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanDescription(_ description: String) -> String {
        // Remove HTML tags
        let cleaned = description
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func parseRSSDate(_ dateString: String) -> Date? {
        // Google News uses RFC 822 date format: "Fri, 24 Jan 2026 12:30:00 GMT"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Try multiple formats
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentSource = ""
            currentDescription = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }

        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubDate += string
        case "source":
            currentSource += string
        case "description":
            currentDescription += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false

            // Extract source from title if not in source element
            var source = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
            if source.isEmpty {
                // Google News format: "Title - Source Name"
                if let dashRange = currentTitle.range(of: " - ", options: .backwards) {
                    source = String(currentTitle[dashRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let item = GoogleNewsRSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            // Only add if we have a title and link
            if !item.title.isEmpty && !item.link.isEmpty {
                newsItems.append(item)
            }
        }
    }
}

// MARK: - Google News RSS Item
private struct GoogleNewsRSSItem {
    let title: String
    let link: String
    let pubDate: String
    let source: String
    let description: String
}
