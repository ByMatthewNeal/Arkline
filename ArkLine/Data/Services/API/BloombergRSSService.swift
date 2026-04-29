import Foundation

// MARK: - Bloomberg RSS Service
/// Fetches and parses Bloomberg RSS feeds for financial news
final class BloombergRSSService {

    // MARK: - RSS Feed URLs
    enum Feed: String, CaseIterable {
        case markets = "https://feeds.bloomberg.com/markets/news.rss"
        case economics = "https://feeds.bloomberg.com/economics/news.rss"
        case technology = "https://feeds.bloomberg.com/technology/news.rss"
        case politics = "https://feeds.bloomberg.com/politics/news.rss"
        case wealth = "https://feeds.bloomberg.com/wealth/news.rss"

        var category: String {
            switch self {
            case .markets: return "Markets"
            case .economics: return "Economics"
            case .technology: return "Technology"
            case .politics: return "Politics"
            case .wealth: return "Wealth"
            }
        }
    }

    // MARK: - Topic Mapping

    /// Map user-selected news topics to relevant Bloomberg feeds
    static func feeds(for topics: Set<Constants.NewsTopic>?) -> [Feed] {
        guard let topics = topics, !topics.isEmpty else {
            // Default: markets + economics + politics
            return [.markets, .economics, .politics]
        }

        var feeds = Set<Feed>()

        for topic in topics {
            switch topic {
            case .crypto, .defi, .nfts:
                feeds.insert(.markets)      // Crypto covered under Bloomberg Markets
            case .macroEconomy:
                feeds.insert(.economics)
            case .stocks:
                feeds.insert(.markets)
                feeds.insert(.wealth)
            case .techAI:
                feeds.insert(.technology)
            case .geopolitics, .regulation:
                feeds.insert(.politics)
            }
        }

        // Always include markets as a baseline
        feeds.insert(.markets)
        return Array(feeds)
    }

    // MARK: - Public Methods

    /// Fetch from Bloomberg feeds matching the given topics, deduplicated and sorted
    func fetchNews(for topics: Set<Constants.NewsTopic>? = nil, limit: Int = 20) async -> [NewsItem] {
        let feeds = Self.feeds(for: topics)

        var allItems: [NewsItem] = []

        await withTaskGroup(of: [NewsItem].self) { group in
            for feed in feeds {
                group.addTask { [weak self] in
                    guard let self else { return [] }
                    return await self.fetchFeed(feed, limit: limit)
                }
            }
            for await items in group {
                allItems.append(contentsOf: items)
            }
        }

        // Deduplicate by title
        var seen = Set<String>()
        var deduplicated: [NewsItem] = []
        for item in allItems {
            let key = item.title.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                deduplicated.append(item)
            }
        }

        deduplicated.sort { $0.publishedAt > $1.publishedAt }
        return Array(deduplicated.prefix(limit))
    }

    /// Fetch a single Bloomberg RSS feed
    func fetchFeed(_ feed: Feed, limit: Int = 15) async -> [NewsItem] {
        guard let url = URL(string: feed.rawValue) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await PinnedURLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logWarning("Bloomberg RSS \(feed.category) returned non-200", category: .network)
                return []
            }

            let items = parseRSS(data: data)

            let newsItems = items.prefix(limit).map { item -> NewsItem in
                NewsItem(
                    id: UUID(),
                    title: item.title,
                    source: "Bloomberg",
                    publishedAt: parseRSSDate(item.pubDate) ?? Date(),
                    imageUrl: nil,
                    url: item.link,
                    sourceType: .bloomberg,
                    twitterHandle: nil,
                    isVerified: false,
                    description: cleanDescription(item.description)
                )
            }

            logDebug("[Bloomberg:\(feed.category)] Fetched \(newsItems.count) items", category: .network)
            return Array(newsItems)

        } catch {
            logWarning("Bloomberg RSS \(feed.category) fetch failed: \(error.localizedDescription)", category: .network)
            return []
        }
    }

    // MARK: - Private Methods

    private func parseRSS(data: Data) -> [BloombergRSSItem] {
        let delegate = BloombergRSSParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.newsItems
    }

    private func cleanDescription(_ description: String) -> String {
        description
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseRSSDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

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
}

// MARK: - RSS Parser Delegate (isolated per-parse instance — thread safe)

private class BloombergRSSParserDelegate: NSObject, XMLParserDelegate {
    var newsItems: [BloombergRSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentDescription = ""
    private var isInItem = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
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
        case "description":
            currentDescription += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false

            let item = BloombergRSSItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if !item.title.isEmpty && !item.link.isEmpty {
                newsItems.append(item)
            }
        }
    }
}

// MARK: - Bloomberg RSS Item
private struct BloombergRSSItem {
    let title: String
    let link: String
    let pubDate: String
    let description: String
}
