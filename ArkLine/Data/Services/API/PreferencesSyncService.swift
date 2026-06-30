import Foundation

// MARK: - Preferences Sync Service
/// Reads/writes the user's app-preferences blob on their profile row.
/// RLS already restricts profile updates to the owner, and the protected
/// columns (role/subscription/trial) are untouched here.
final class PreferencesSyncService {
    static let shared = PreferencesSyncService()
    private init() {}

    private let supabase = SupabaseManager.shared

    struct Remote {
        let prefs: SyncedPreferences
        let updatedAt: Date
    }

    private struct ProfilePrefsRow: Decodable {
        let appPreferences: SyncedPreferences?
        let appPreferencesUpdatedAt: Date?
        enum CodingKeys: String, CodingKey {
            case appPreferences = "app_preferences"
            case appPreferencesUpdatedAt = "app_preferences_updated_at"
        }
    }

    private struct PrefsUpdate: Encodable {
        let appPreferences: SyncedPreferences
        let appPreferencesUpdatedAt: Date
        enum CodingKeys: String, CodingKey {
            case appPreferences = "app_preferences"
            case appPreferencesUpdatedAt = "app_preferences_updated_at"
        }
    }

    /// Fetch the cloud preferences blob, or nil if the user has none yet.
    func fetch(userId: UUID) async throws -> Remote? {
        guard supabase.isConfigured else { return nil }
        let rows: [ProfilePrefsRow] = try await supabase.database
            .from(SupabaseTable.profiles.rawValue)
            .select("app_preferences, app_preferences_updated_at")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first,
              let prefs = row.appPreferences,
              let updatedAt = row.appPreferencesUpdatedAt else {
            return nil
        }
        return Remote(prefs: prefs, updatedAt: updatedAt)
    }

    /// Upsert the preferences blob + its timestamp onto the user's profile.
    func upload(_ prefs: SyncedPreferences, updatedAt: Date, userId: UUID) async throws {
        guard supabase.isConfigured else { return }
        try await supabase.database
            .from(SupabaseTable.profiles.rawValue)
            .update(PrefsUpdate(appPreferences: prefs, appPreferencesUpdatedAt: updatedAt))
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
