import Foundation
import Observation

/// Tracks which news articles the user has read, keyed by URL.
@Observable
final class ReadArticlesStore {
    static let shared = ReadArticlesStore()

    private let key = "user_read_article_urls"
    private var cache: Set<String>

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let urls = try? JSONDecoder().decode(Set<String>.self, from: data) {
            cache = urls
        } else {
            cache = []
        }
    }

    func isRead(_ url: String) -> Bool {
        cache.contains(url)
    }

    func markRead(_ url: String) {
        guard !url.isEmpty else { return }
        cache.insert(url)
        save()
    }

    func toggleRead(_ url: String) {
        guard !url.isEmpty else { return }
        if cache.contains(url) {
            cache.remove(url)
        } else {
            cache.insert(url)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
