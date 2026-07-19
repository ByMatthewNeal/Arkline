import Foundation

// MARK: - Synced Preferences
/// The full bundle of a user's dashboard layout + app settings, mirrored to
/// their profile in Supabase so it survives reinstalls and stays in sync across
/// devices. All fields optional so partial/older blobs decode safely.
struct SyncedPreferences: Codable, Equatable {
    var darkModePreference: String?
    var avatarColorTheme: String?
    var chartColorPalette: String?
    var preferredCurrency: String?
    var widgetConfiguration: WidgetConfiguration?
    var marketWidgetConfiguration: MarketWidgetConfiguration?
    var enabledCoreAssets: [CoreAsset]?
    var dashboardPresets: [DashboardPreset]?
    var activePresetId: String?
    var tickerPreferences: TickerPreferences?
    /// Key ("summaryDate_slot") of the most recent briefing the user has read, so
    /// the Daily Digest's caught-up suppression is consistent across their devices.
    var lastReadBriefingKey: String?
}
