import Foundation
import Supabase

// MARK: - Supabase Client Manager
final class SupabaseManager {
    // MARK: - Singleton
    static let shared = SupabaseManager()

    // MARK: - Properties
    let client: SupabaseClient
    let isConfigured: Bool

    // MARK: - Init
    private init() {
        let urlString = Constants.API.supabaseURL
        let key = Constants.API.supabaseAnonKey

        // Check if Supabase is properly configured
        if urlString.isEmpty || key.isEmpty {
            logWarning("Supabase credentials not configured - using placeholder", category: .network)
            let placeholderURL = URL(string: "https://placeholder.supabase.co") ?? URL(filePath: "/")
            client = SupabaseClient(
                supabaseURL: placeholderURL,
                supabaseKey: "placeholder_key"
            )
            isConfigured = false
        } else if let url = URL(string: urlString) {
            client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: key,
                options: SupabaseClientOptions(
                    // Robust date decoder — tolerates any timestamp fractional
                    // precision so a single microsecond-precision row can't fail
                    // an entire array decode and silently blank a screen.
                    db: .init(decoder: ArkSupabaseDecoder.arkRobust),
                    auth: .init(emitLocalSessionAsInitialSession: true)
                )
            )
            isConfigured = true
            logInfo("Supabase configured successfully", category: .network)
        } else {
            logError("Invalid Supabase URL: credentials misconfigured", category: .network)
            let placeholderURL = URL(string: "https://placeholder.supabase.co") ?? URL(filePath: "/")
            client = SupabaseClient(
                supabaseURL: placeholderURL,
                supabaseKey: "placeholder_key"
            )
            isConfigured = false
        }
    }

    // MARK: - Database Reference
    var database: PostgrestClient {
        client.database
    }

    // MARK: - Auth Reference
    var auth: AuthClient {
        client.auth
    }

    // MARK: - Storage Reference
    var storage: SupabaseStorageClient {
        client.storage
    }

    // MARK: - Functions Reference
    var functions: FunctionsClient {
        client.functions
    }

    // MARK: - Realtime Reference
    var realtimeV2: RealtimeClientV2 {
        client.realtimeV2
    }
}

// MARK: - Database Tables
enum SupabaseTable: String {
    case profiles
    case portfolios
    case holdings
    case transactions
    case dcaReminders = "dca_reminders"
    case favorites
    case chatSessions = "chat_sessions"
    case chatMessages = "chat_messages"
    case communityPosts = "community_posts"
    case comments
    case chatRooms = "chat_rooms"
    case chatRoomMessages = "chat_room_messages"
    case userDevices = "user_devices"
    case appStoreRankings = "app_store_rankings"
    case sentimentHistory = "sentiment_history"
    case broadcasts
    case broadcastReads = "broadcast_reads"
    case broadcastReactions = "broadcast_reactions"
    case broadcastBookmarks = "broadcast_bookmarks"
    case memberQuestions = "member_questions"
    case memberQuestionLikes = "member_question_likes"
    case voiceNotes = "voice_notes"
    case featureRequests = "feature_requests"
    case riskBasedDcaReminders = "risk_based_dca_reminders"
    case riskDcaInvestments = "risk_dca_investments"
    case portfolioHistory = "portfolio_history"
    case supplyInProfit = "supply_in_profit"
    case googleTrendsHistory = "google_trends_history"
    case marketDataCache = "market_data_cache"
    case marketSnapshots = "market_snapshots"
    case indicatorSnapshots = "indicator_snapshots"
    case curatedNews = "curated_news"
    case operatingCosts = "operating_costs"
    case reelScripts = "reel_scripts"
    case technicalsSnapshots = "technicals_snapshots"
    case riskSnapshots = "risk_snapshots"
    case regimeSnapshots = "regime_snapshots"
    case analyticsEvents = "analytics_events"
    case dailyActiveUsers = "daily_active_users"
    case inviteCodes = "invite_codes"
    case subscriptions
    case earlyAccessSignups = "early_access_signups"
    case tradeSignals = "trade_signals"
    case fibConfluenceZones = "fib_confluence_zones"
    case ohlcCandles = "ohlc_candles"
    case economicEvents = "economic_events"
    case positioningSignals = "positioning_signals"
    case marketUpdateDecks = "market_update_decks"
    case modelPortfolios = "model_portfolios"
    case modelPortfolioNav = "model_portfolio_nav"
    case modelPortfolioTrades = "model_portfolio_trades"
    case benchmarkNav = "benchmark_nav"
    case modelPortfolioRiskHistory = "model_portfolio_risk_history"
    case dcaPlans = "dca_plans"
    case dcaEntries = "dca_entries"
    case dictionary
    case rotationSignals = "rotation_signals"
    case sectorPerformance = "sector_performance"
    case marketBreadth = "market_breadth"
    case resourceArticles = "resource_articles"
}

// MARK: - Storage Buckets
enum SupabaseBucket: String {
    case avatars
    case postImages = "post-images"
    case attachments
    case broadcastMedia = "broadcast-media"
}

// MARK: - Robust Supabase Date Decoder
//
// The Supabase Swift SDK's default PostgREST decoder parses timestamptz strings
// with a strategy that only accepts **0 or exactly 3** fractional-second digits.
// PostgREST, however, serializes whatever precision Postgres stored — and any
// column with `DEFAULT now()` (or a SQL-side `now()` update) carries **6-digit
// microseconds**. Such a value fails the SDK parser, which returns nil and makes
// the *entire* array decode throw. The symptom is a screen that silently goes
// blank even though the rows exist and RLS allows the read (this is exactly what
// happened to the Trade Signals History/Performance tabs).
//
// `arkRobust` is a **strict superset** of the SDK behavior: it first tries the
// same formats the SDK uses (so every currently-working date decodes byte-for-
// byte identically — zero regression risk), and only for strings that would
// otherwise throw does it normalize the fractional component to 3 digits and
// retry. This immunizes every table/query in the app against precision drift.
//
// Kept in this file (rather than its own) so it's always in the compiled target
// without needing an XcodeGen regen.
enum ArkSupabaseDecoder {

    /// Drop-in replacement for `PostgrestClient.Configuration.jsonDecoder` that
    /// tolerates any timestamp fractional precision (0–9 digits), 'Z' or numeric
    /// offsets, and either 'T' or space date/time separators.
    static let arkRobust: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parse(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(raw)"
            )
        }
        return decoder
    }()

    /// Parse a PostgREST timestamp. Primary path mirrors the SDK exactly; the
    /// fallback normalizes fractional seconds to 3 digits before retrying.
    static func parse(_ input: String) -> Date? {
        // Primary: exactly what the SDK accepts (fractional .SSS, then whole).
        if let date = fractionalFormatter.date(from: input) { return date }
        if let date = wholeFormatter.date(from: input) { return date }

        // Fallback: normalize separator + fractional precision, then retry.
        let normalized = normalize(input)
        if normalized != input {
            if let date = fractionalFormatter.date(from: normalized) { return date }
            if let date = wholeFormatter.date(from: normalized) { return date }
        }

        // Last resort: ISO8601DateFormatter variants (handles odd offsets).
        // Local instances — ISO8601DateFormatter is not safe to mutate across the
        // concurrent decodes that PostgREST array parsing can trigger.
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFrac.date(from: normalized) { return date }
        let isoWhole = ISO8601DateFormatter()
        isoWhole.formatOptions = [.withInternetDateTime]
        return isoWhole.date(from: normalized)
    }

    /// Convert `"2026-07-06 21:54:53.413482+00"` style strings into a form the
    /// fixed formatters accept: 'T' separator, fractional seconds padded/truncated
    /// to exactly 3 digits, and a colon in the timezone offset.
    private static func normalize(_ input: String) -> String {
        var s = input

        // Space -> 'T' between date and time.
        if !s.contains("T"), let r = s.range(of: " ") {
            s.replaceSubrange(r, with: "T")
        }

        // Split off timezone (Z, or +/-HH[:]MM) so we can safely touch the fraction.
        var body = s
        var tz = ""
        // Only look for an offset sign *after* the date portion (index 11+), so we
        // never mistake the date's own hyphens for a timezone offset.
        if let zIdx = body.firstIndex(where: { $0 == "Z" }) {
            tz = String(body[zIdx...])
            body = String(body[..<zIdx])
        } else if body.count > 11,
                  let searchStart = body.index(body.startIndex, offsetBy: 11, limitedBy: body.endIndex),
                  let sign = body.range(of: "[+-]", options: [.regularExpression], range: searchStart..<body.endIndex) {
            tz = String(body[sign.lowerBound...])
            body = String(body[..<sign.lowerBound])
        }

        // Normalize fractional seconds in `body` to exactly 3 digits.
        if let dot = body.firstIndex(of: ".") {
            let fracStart = body.index(after: dot)
            let frac = String(body[fracStart...])
            let digits = frac.prefix(while: { $0.isNumber })
            var norm = String(digits.prefix(3))
            while norm.count < 3 { norm += "0" }
            body = String(body[..<fracStart]) + norm
        }

        // Normalize timezone: "+00" -> "+00:00", "+0000" -> "+00:00".
        if tz != "Z", tz.first == "+" || tz.first == "-" {
            var digits = tz.dropFirst().filter { $0.isNumber }
            while digits.count < 4 { digits += "0" }
            let hh = digits.prefix(2)
            let mm = digits.dropFirst(2).prefix(2)
            tz = "\(tz.first!)\(hh):\(mm)"
        }

        return body + tz
    }

    // MARK: - Formatters

    private static let fractionalFormatter = fixed("yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX")
    private static let wholeFormatter = fixed("yyyy-MM-dd'T'HH:mm:ssXXXXX")

    private static func fixed(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = pattern
        return f
    }
}
