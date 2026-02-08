import SwiftUI
import Foundation
import Supabase
import UserNotifications

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
            logInfo(" Loaded \(topics.count) saved news topics: \(topics.map { $0.displayName })")
        } else {
            logInfo(" No saved news topics found, using defaults")
        }

        // Load custom keywords
        if let custom = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.customNewsTopics) {
            customNewsTopics = custom
            logInfo(" Loaded \(custom.count) custom keywords: \(custom)")
        } else {
            logInfo(" No custom keywords found")
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
            logInfo(" Saved \(selectedNewsTopics.count) news topics: \(selectedNewsTopics.map { $0.displayName })")
        }
    }

    private func saveCustomTopics() {
        UserDefaults.standard.set(customNewsTopics, forKey: Constants.UserDefaults.customNewsTopics)
        logInfo("Saved \(customNewsTopics.count) custom news keywords")
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

        if enabled {
            Task {
                let center = UNUserNotificationCenter.current()
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        await MainActor.run {
                            self.notificationsEnabled = false
                            UserDefaults.standard.set(false, forKey: Constants.UserDefaults.notificationsEnabled)
                        }
                    }
                } catch {
                    logError("Push notification request failed: \(error)", category: .auth)
                    await MainActor.run {
                        self.notificationsEnabled = false
                        UserDefaults.standard.set(false, forKey: Constants.UserDefaults.notificationsEnabled)
                    }
                }
            }
        }
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
            guard let userId = SupabaseAuthManager.shared.currentUserId else {
                try await SupabaseAuthManager.shared.signOut()
                return
            }

            let db = SupabaseManager.shared.database
            let uid = userId.uuidString

            // Delete user data from all tables (order matters for foreign keys)
            let userTables: [(table: String, column: String)] = [
                (SupabaseTable.riskDcaInvestments.rawValue, "user_id"),
                (SupabaseTable.riskBasedDcaReminders.rawValue, "user_id"),
                (SupabaseTable.dcaReminders.rawValue, "user_id"),
                (SupabaseTable.chatMessages.rawValue, "user_id"),
                (SupabaseTable.chatSessions.rawValue, "user_id"),
                (SupabaseTable.broadcastReads.rawValue, "user_id"),
                (SupabaseTable.broadcastReactions.rawValue, "user_id"),
                (SupabaseTable.communityPosts.rawValue, "user_id"),
                (SupabaseTable.portfolioHistory.rawValue, "portfolio_id"),
                (SupabaseTable.transactions.rawValue, "portfolio_id"),
                (SupabaseTable.holdings.rawValue, "portfolio_id"),
                (SupabaseTable.portfolios.rawValue, "user_id"),
                (SupabaseTable.userDevices.rawValue, "user_id"),
                (SupabaseTable.featureRequests.rawValue, "user_id"),
                (SupabaseTable.favorites.rawValue, "user_id"),
                (SupabaseTable.profiles.rawValue, "id"),
            ]

            // For portfolio-scoped tables, first get portfolio IDs
            let portfolioIds: [String] = await {
                do {
                    struct IdRow: Codable { let id: UUID }
                    let rows: [IdRow] = try await db
                        .from(SupabaseTable.portfolios.rawValue)
                        .select("id")
                        .eq("user_id", value: uid)
                        .execute()
                        .value
                    return rows.map { $0.id.uuidString }
                } catch {
                    return []
                }
            }()

            for (table, column) in userTables {
                do {
                    if ["portfolio_id"].contains(column) {
                        // Delete by portfolio IDs
                        for pid in portfolioIds {
                            try await db.from(table).delete().eq(column, value: pid).execute()
                        }
                    } else {
                        // Delete by user ID
                        let value = column == "id" ? uid : uid
                        try await db.from(table).delete().eq(column, value: value).execute()
                    }
                } catch {
                    // Continue cleanup even if individual table delete fails
                    logError("Failed to delete from \(table): \(error)", category: .auth)
                }
            }

            // Clear local data
            try? PasscodeManager.shared.clearPasscode()

            // Sign out (Supabase doesn't support client-side auth user deletion,
            // this should be handled by a server-side function in production)
            try await SupabaseAuthManager.shared.signOut()
        } catch {
            logError(error, context: "Delete Account", category: .auth)
        }
    }
}
