import Foundation
import Observation

/// Persists user's favorite asset IDs via UserDefaults.
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private let key = "user_favorite_asset_ids"
    private var cache: Set<String>

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            cache = ids
        } else {
            cache = []
        }
    }

    func isFavorite(_ assetId: String) -> Bool {
        cache.contains(assetId)
    }

    func setFavorite(_ assetId: String, isFavorite: Bool) {
        if isFavorite {
            cache.insert(assetId)
        } else {
            cache.remove(assetId)
        }
        save()
    }

    func allFavoriteIds() -> Set<String> {
        cache
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
