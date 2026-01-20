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
