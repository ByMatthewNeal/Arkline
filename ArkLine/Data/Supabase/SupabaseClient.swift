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
    case featureRequests = "feature_requests"
    case riskBasedDcaReminders = "risk_based_dca_reminders"
    case riskDcaInvestments = "risk_dca_investments"
    case portfolioHistory = "portfolio_history"
    case supplyInProfit = "supply_in_profit"
    case googleTrendsHistory = "google_trends_history"
    case marketDataCache = "market_data_cache"
    case marketSnapshots = "market_snapshots"
    case indicatorSnapshots = "indicator_snapshots"
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
}

// MARK: - Storage Buckets
enum SupabaseBucket: String {
    case avatars
    case postImages = "post-images"
    case attachments
    case broadcastMedia = "broadcast-media"
}
