import Foundation

// MARK: - Ticker Preferences
/// User's choices for the Home market ticker: which content categories appear
/// and how fast it scrolls. Persisted locally and cloud-synced via SyncedPreferences.
struct TickerPreferences: Codable, Equatable {
    var showCryptoPrices: Bool = true
    var showRiskScore: Bool = true
    var showFearGreed: Bool = true
    var showRegime: Bool = true
    var showNews: Bool = true

    /// Scroll speed in points per second.
    var speed: Double = 30

    static let minSpeed: Double = 10
    static let maxSpeed: Double = 90
    static let `default` = TickerPreferences()

    /// The ticker must show at least one category, or it would render empty.
    var hasAnyContent: Bool {
        showCryptoPrices || showRiskScore || showFearGreed || showRegime || showNews
    }
}
