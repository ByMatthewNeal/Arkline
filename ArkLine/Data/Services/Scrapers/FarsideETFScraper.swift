import Foundation

// MARK: - Farside ETF Scraper
/// Scrapes Bitcoin ETF net flow data from Farside Investors
/// Source: https://farside.co.uk/bitcoin-etf-flow-all-data/
/// Note: Web scraping can be fragile - the site structure may change
final class FarsideETFScraper {

    // MARK: - Constants
    private let baseURL = "https://farside.co.uk/bitcoin-etf-flow-all-data/"
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    // ETF ticker to full name mapping
    private let etfNames: [String: String] = [
        "IBIT": "iShares Bitcoin Trust (BlackRock)",
        "FBTC": "Fidelity Wise Origin Bitcoin Fund",
        "BITB": "Bitwise Bitcoin ETF",
        "ARKB": "ARK 21Shares Bitcoin ETF",
        "BTCO": "Invesco Galaxy Bitcoin ETF",
        "EZBC": "Franklin Bitcoin ETF",
        "BRRR": "Valkyrie Bitcoin Fund",
        "HODL": "VanEck Bitcoin Trust",
        "BTCW": "WisdomTree Bitcoin Fund",
        "GBTC": "Grayscale Bitcoin Trust",
        "BTC": "Grayscale Bitcoin Mini Trust"
    ]

    // MARK: - Cache
    private var cachedData: ETFNetFlow?
    private var cacheTimestamp: Date?
    private let cacheDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Public Methods

    /// Fetches the latest Bitcoin ETF net flow data
    /// - Returns: ETFNetFlow with daily and cumulative data
    func fetchETFNetFlow() async throws -> ETFNetFlow {
        // Check cache first
        if let cached = cachedData,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheDuration {
            logDebug("Using cached Farside ETF data", category: .network)
            return cached
        }

        let html = try await fetchHTML()
        let result = try parseETFData(from: html)

        // Cache the result
        cachedData = result
        cacheTimestamp = Date()

        return result
    }

    // MARK: - Private Methods

    private func fetchHTML() async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw ScraperError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 15

        logDebug("Fetching Farside ETF data from \(baseURL)", category: .network)

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScraperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logError("Farside HTTP error: \(httpResponse.statusCode)", category: .network)
            throw ScraperError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.decodingError
        }

        return html
    }

    private func parseETFData(from html: String) throws -> ETFNetFlow {
        // Farside table structure:
        // <table> with rows containing date and ETF flow values
        // The last row with data contains the most recent day's flows
        // Columns: Date, IBIT, FBTC, BITB, ARKB, BTCO, EZBC, BRRR, HODL, BTCW, GBTC, BTC, Total

        var etfData: [ETFData] = []
        var dailyTotal: Double = 0
        var cumulativeTotal: Double = 0

        // Find table rows - Farside uses a simple HTML table
        // Look for rows with numeric data (ETF flows are in millions)

        // Extract the last data row from the table
        // Pattern: <tr><td>date</td><td>value</td>...</tr>

        // Find all table rows
        let rowPattern = #"<tr[^>]*>(.*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) else {
            throw ScraperError.parsingError
        }

        let matches = rowRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        // Find the last row with actual ETF data (contains numbers)
        var lastDataRow: String?
        var totalRow: String?

        for match in matches.reversed() {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let rowContent = String(html[range])

            // Skip header rows and empty rows
            if rowContent.contains("<th") || rowContent.contains("Total") && totalRow == nil {
                if rowContent.contains("Total") && !rowContent.contains("<th") {
                    totalRow = rowContent
                }
                continue
            }

            // Check if this row has numeric data (ETF flows)
            if rowContent.contains("<td") && rowContent.matches(of: #/\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/#).count > 0 {
                lastDataRow = rowContent
                break
            }
        }

        // Parse the last data row to get individual ETF flows
        if let dataRow = lastDataRow {
            let cellPattern = #"<td[^>]*>(.*?)</td>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else {
                throw ScraperError.parsingError
            }

            let cellMatches = cellRegex.matches(in: dataRow, options: [], range: NSRange(dataRow.startIndex..., in: dataRow))

            // ETF order in Farside table: Date, IBIT, FBTC, BITB, ARKB, BTCO, EZBC, BRRR, HODL, BTCW, GBTC, BTC, Total
            let etfTickers = ["IBIT", "FBTC", "BITB", "ARKB", "BTCO", "EZBC", "BRRR", "HODL", "BTCW", "GBTC", "BTC"]

            for (index, match) in cellMatches.enumerated() {
                guard let range = Range(match.range(at: 1), in: dataRow) else { continue }
                let cellContent = String(dataRow[range])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip the date column (index 0) and total column (last)
                if index == 0 || index > etfTickers.count {
                    // Check if this is the total
                    if index == etfTickers.count + 1 {
                        dailyTotal = parseFlowValue(cellContent)
                    }
                    continue
                }

                let ticker = etfTickers[index - 1]
                let flowValue = parseFlowValue(cellContent)

                if flowValue != 0 || !cellContent.isEmpty {
                    etfData.append(ETFData(
                        ticker: ticker,
                        name: etfNames[ticker] ?? ticker,
                        netFlow: flowValue * 1_000_000, // Convert from millions
                        aum: 0 // AUM not available from Farside
                    ))
                }
            }
        }

        // Parse total row for cumulative total
        if let total = totalRow {
            let cellPattern = #"<td[^>]*>(.*?)</td>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.dotMatchesLineSeparators]) else {
                throw ScraperError.parsingError
            }

            let cellMatches = cellRegex.matches(in: total, options: [], range: NSRange(total.startIndex..., in: total))

            // Last cell should be the cumulative total
            if let lastMatch = cellMatches.last,
               let range = Range(lastMatch.range(at: 1), in: total) {
                let content = String(total[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&nbsp;", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cumulativeTotal = parseFlowValue(content) * 1_000_000
            }
        }

        // If we couldn't parse daily total from the row, sum up the individual ETFs
        if dailyTotal == 0 {
            dailyTotal = etfData.reduce(0) { $0 + $1.netFlow } / 1_000_000
        }

        // Sort ETF data by absolute flow value (largest impact first)
        etfData.sort { abs($0.netFlow) > abs($1.netFlow) }

        logDebug("Parsed Farside ETF data: Daily=$\(String(format: "%.1f", dailyTotal))M, Total=$\(String(format: "%.1f", cumulativeTotal / 1_000_000))M", category: .network)

        return ETFNetFlow(
            totalNetFlow: cumulativeTotal,
            dailyNetFlow: dailyTotal * 1_000_000,
            etfData: etfData,
            timestamp: Date()
        )
    }

    /// Parses a flow value string (e.g., "123.4", "-56.7", "(45.2)") to Double
    private func parseFlowValue(_ value: String) -> Double {
        var cleanValue = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle parentheses for negative values: (123.4) -> -123.4
        if cleanValue.hasPrefix("(") && cleanValue.hasSuffix(")") {
            cleanValue = "-" + cleanValue.dropFirst().dropLast()
        }

        // Handle dash or empty as zero
        if cleanValue == "-" || cleanValue.isEmpty {
            return 0
        }

        return Double(cleanValue) ?? 0
    }
}
