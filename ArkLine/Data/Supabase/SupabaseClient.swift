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
            print("⚠️ Supabase credentials not configured - using placeholder")
            // Use a placeholder that won't crash but won't work either
            client = SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder_key"
            )
            isConfigured = false
        } else {
            client = SupabaseClient(
                supabaseURL: URL(string: urlString)!,
                supabaseKey: key
            )
            isConfigured = true
            print("✅ Supabase configured: \(urlString)")
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

    // MARK: - Realtime Reference
    var realtime: RealtimeClient {
        client.realtime
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
    case featureRequests = "feature_requests"
    case riskBasedDcaReminders = "risk_based_dca_reminders"
    case riskDcaInvestments = "risk_dca_investments"
    case portfolioHistory = "portfolio_history"
}

// MARK: - Storage Buckets
enum SupabaseBucket: String {
    case avatars
    case postImages = "post-images"
    case attachments
    case broadcastMedia = "broadcast-media"
}
