import Foundation
import Observation

/// Persists user's favorite asset IDs via UserDefaults.
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private let key = "user_favorite_asset_ids"
    private var cache: Set<String>
    private var saveTask: DispatchWorkItem?

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
            guard !cache.contains(assetId) else { return }
            cache.insert(assetId)
        } else {
            guard cache.contains(assetId) else { return }
            cache.remove(assetId)
        }
        debouncedSave()
    }

    func allFavoriteIds() -> Set<String> {
        cache
    }

    private func debouncedSave() {
        saveTask?.cancel()
        let snapshot = cache
        let key = self.key
        let work = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
        saveTask = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}
