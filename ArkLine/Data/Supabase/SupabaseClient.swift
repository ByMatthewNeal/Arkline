import Foundation
import Supabase

// MARK: - Supabase Client Manager
final class SupabaseManager {
    // MARK: - Singleton
    static let shared = SupabaseManager()

    // MARK: - Properties
    let client: SupabaseClient

    // MARK: - Init
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Constants.API.supabaseURL)!,
            supabaseKey: Constants.API.supabaseAnonKey
        )
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
}

// MARK: - Storage Buckets
enum SupabaseBucket: String {
    case avatars
    case postImages = "post-images"
    case attachments
}
