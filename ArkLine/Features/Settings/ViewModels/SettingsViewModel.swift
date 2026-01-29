import SwiftUI
import Foundation
import Supabase

// MARK: - Settings View Model
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Preferences
    var preferredCurrency: String = "USD"
    var darkModePreference: Constants.DarkModePreference = .automatic
    var notificationsEnabled = true
    var biometricEnabled = true
    var riskCoins: [String] = ["BTC", "ETH"]

    // MARK: - News Topics
    var selectedNewsTopics: Set<Constants.NewsTopic> = [.crypto, .geopolitics]
    var customNewsTopics: [String] = []

    // MARK: - State
    var isLoading = false
    var showSignOutAlert = false
    var showDeleteAccountAlert = false

    // MARK: - Currency Options
    let currencyOptions = [
        ("USD", "US Dollar"),
        ("EUR", "Euro"),
        ("GBP", "British Pound"),
        ("JPY", "Japanese Yen"),
        ("CHF", "Swiss Franc"),
        ("AUD", "Australian Dollar"),
        ("CAD", "Canadian Dollar")
    ]

    // MARK: - Initialization
    init() {
        loadSettings()
    }

    // MARK: - Settings Management
    func loadSettings() {
        if let currency = UserDefaults.standard.string(forKey: Constants.UserDefaults.preferredCurrency) {
            preferredCurrency = currency
        }

        if let darkMode = UserDefaults.standard.string(forKey: Constants.UserDefaults.darkModePreference),
           let preference = Constants.DarkModePreference(rawValue: darkMode) {
            darkModePreference = preference
        }

        notificationsEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.notificationsEnabled)
        biometricEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.biometricEnabled)

        // Load risk coins
        if let savedCoins = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.riskCoins) {
            riskCoins = savedCoins
        }

        // Load news topic preferences
        loadNewsTopicSettings()
    }

    // MARK: - News Topics Management
    private func loadNewsTopicSettings() {
        // Load selected topics
        if let data = UserDefaults.standard.data(forKey: Constants.UserDefaults.selectedNewsTopics),
           let topics = try? JSONDecoder().decode(Set<Constants.NewsTopic>.self, from: data) {
            selectedNewsTopics = topics
            print("📰 Loaded \(topics.count) saved news topics: \(topics.map { $0.displayName })")
        } else {
            print("📰 No saved news topics found, using defaults")
        }

        // Load custom keywords
        if let custom = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.customNewsTopics) {
            customNewsTopics = custom
            print("📰 Loaded \(custom.count) custom keywords: \(custom)")
        } else {
            print("📰 No custom keywords found")
        }
    }

    func toggleNewsTopic(_ topic: Constants.NewsTopic) {
        if selectedNewsTopics.contains(topic) {
            selectedNewsTopics.remove(topic)
        } else {
            selectedNewsTopics.insert(topic)
        }
        saveNewsTopics()
    }

    func addCustomTopic(_ keyword: String) {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customNewsTopics.contains(trimmed) else { return }
        customNewsTopics.append(trimmed)
        saveCustomTopics()
    }

    func removeCustomTopic(_ keyword: String) {
        customNewsTopics.removeAll { $0 == keyword }
        saveCustomTopics()
    }

    private func saveNewsTopics() {
        if let data = try? JSONEncoder().encode(selectedNewsTopics) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaults.selectedNewsTopics)
            print("📰 Saved \(selectedNewsTopics.count) news topics: \(selectedNewsTopics.map { $0.displayName })")
        }
    }

    private func saveCustomTopics() {
        UserDefaults.standard.set(customNewsTopics, forKey: Constants.UserDefaults.customNewsTopics)
        print("📰 Saved \(customNewsTopics.count) custom keywords: \(customNewsTopics)")
    }

    func saveCurrency(_ currency: String) {
        preferredCurrency = currency
        UserDefaults.standard.set(currency, forKey: Constants.UserDefaults.preferredCurrency)
    }

    func saveDarkMode(_ preference: Constants.DarkModePreference) {
        darkModePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Constants.UserDefaults.darkModePreference)
    }

    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Constants.UserDefaults.notificationsEnabled)
    }

    func toggleBiometric(_ enabled: Bool) {
        biometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Constants.UserDefaults.biometricEnabled)
    }

    func toggleRiskCoin(_ coin: String) {
        if riskCoins.contains(coin) {
            riskCoins.removeAll { $0 == coin }
        } else {
            riskCoins.append(coin)
        }
        UserDefaults.standard.set(riskCoins, forKey: Constants.UserDefaults.riskCoins)
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseAuthManager.shared.signOut()
        } catch {
            logError(error, context: "Sign Out", category: .auth)
        }
    }

    func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete user profile from database first
            if let userId = SupabaseAuthManager.shared.currentUserId {
                try await SupabaseManager.shared.database
                    .from(SupabaseTable.profiles.rawValue)
                    .delete()
                    .eq("id", value: userId.uuidString)
                    .execute()
            }

            // Sign out (Supabase doesn't support client-side account deletion,
            // this should be handled by a server-side function in production)
            try await SupabaseAuthManager.shared.signOut()
        } catch {
            logError(error, context: "Delete Account", category: .auth)
        }
    }
}
