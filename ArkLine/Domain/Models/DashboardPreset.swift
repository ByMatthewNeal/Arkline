import Foundation

/// A named snapshot of a user's home screen widget layout.
/// Users can save up to 2 presets and switch between them.
struct DashboardPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var configuration: WidgetConfiguration
    var coreAssets: Set<CoreAsset>
    let createdAt: Date

    init(name: String, configuration: WidgetConfiguration, coreAssets: Set<CoreAsset>) {
        self.id = UUID()
        self.name = name
        self.configuration = configuration
        self.coreAssets = coreAssets
        self.createdAt = Date()
    }

    /// Maximum number of user-created presets
    static let maxPresets = 2
}
