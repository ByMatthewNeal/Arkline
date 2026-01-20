import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct ArkLineApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        #if canImport(UIKit)
        // Configure UIKit appearance for components that need it
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        #endif
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isOnboarded = false
    @Published var currentUser: User?
    @Published var darkModePreference: Constants.DarkModePreference = .automatic

    var colorScheme: ColorScheme? {
        switch darkModePreference {
        case .light: return .light
        case .dark: return .dark
        case .automatic: return nil
        }
    }

    init() {
        loadPersistedState()
    }

    private func loadPersistedState() {
        isOnboarded = UserDefaults.standard.bool(forKey: Constants.UserDefaults.isOnboarded)

        if let darkModeValue = UserDefaults.standard.string(forKey: Constants.UserDefaults.darkModePreference),
           let preference = Constants.DarkModePreference(rawValue: darkModeValue) {
            darkModePreference = preference
        }
    }

    func setAuthenticated(_ authenticated: Bool, user: User? = nil) {
        isAuthenticated = authenticated
        currentUser = user
    }

    func setOnboarded(_ onboarded: Bool) {
        isOnboarded = onboarded
        UserDefaults.standard.set(onboarded, forKey: Constants.UserDefaults.isOnboarded)
    }

    func setDarkModePreference(_ preference: Constants.DarkModePreference) {
        darkModePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Constants.UserDefaults.darkModePreference)
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
    }
}
