import SwiftUI
import Foundation

// MARK: - Settings View Model
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

        notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
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
        UserDefaults.standard.set(enabled, forKey: "notifications_enabled")
    }

    func toggleBiometric(_ enabled: Bool) {
        biometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "biometric_enabled")
    }

    func signOut() async {
        isLoading = true
        // TODO: Call Supabase signOut
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }

    func deleteAccount() async {
        isLoading = true
        // TODO: Call Supabase delete account
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}

// MARK: - Settings Section
enum SettingsSection: String, CaseIterable {
    case general = "General"
    case notifications = "Notifications"
    case security = "Security"
    case support = "Support"
    case account = "Account"
}

// MARK: - Settings Item
struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    let section: SettingsSection
    var value: String? = nil
    var isDestructive = false
}
