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
                .onOpenURL { url in
                    Task {
                        await handleDeepLink(url)
                    }
                }
        }
    }

    private func handleDeepLink(_ url: URL) async {
        // Handle Supabase auth callback
        guard url.scheme == "arkline" else { return }

        if url.host == "auth" || url.path.contains("callback") {
            // Let Supabase handle the auth callback
            do {
                let session = try await SupabaseManager.shared.client.auth.session(from: url)
                // Notify that auth succeeded via deep link
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("DeepLinkAuthSuccess"),
                        object: nil,
                        userInfo: ["session": session]
                    )
                }
            } catch {
                print("Error handling auth callback: \(error)")
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
    @Published var avatarColorTheme: Constants.AvatarColorTheme = .ocean
    @Published var widgetConfiguration: WidgetConfiguration = WidgetConfiguration()

    // Navigation reset triggers - increment to pop to root
    @Published var homeNavigationReset = UUID()
    @Published var marketNavigationReset = UUID()
    @Published var portfolioNavigationReset = UUID()
    @Published var chatNavigationReset = UUID()
    @Published var profileNavigationReset = UUID()

    // Tab navigation
    @Published var selectedTab: AppTab = .home
    @Published var shouldShowPortfolioCreation = false

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

        // Load avatar color theme
        if let avatarColorValue = UserDefaults.standard.string(forKey: Constants.UserDefaults.avatarColorTheme),
           let theme = Constants.AvatarColorTheme(rawValue: avatarColorValue) {
            avatarColorTheme = theme
        }

        // Load widget configuration
        if let data = UserDefaults.standard.data(forKey: Constants.UserDefaults.widgetConfiguration),
           var config = try? JSONDecoder().decode(WidgetConfiguration.self, from: data) {
            // Migration: Add any new widget types that aren't in the saved order
            let savedWidgetSet = Set(config.widgetOrder)
            for widgetType in HomeWidgetType.allCases {
                if !savedWidgetSet.contains(widgetType) {
                    // Insert new widgets after marketMovers (Core) if it exists, otherwise at position 4
                    if let marketMoversIndex = config.widgetOrder.firstIndex(of: .marketMovers) {
                        config.widgetOrder.insert(widgetType, at: marketMoversIndex + 1)
                    } else {
                        config.widgetOrder.insert(widgetType, at: min(4, config.widgetOrder.count))
                    }
                    // Enable new widgets by default if they're in the default enabled set
                    if HomeWidgetType.defaultEnabled.contains(widgetType) {
                        config.enabledWidgets.insert(widgetType)
                    }
                }
            }

            // Ensure upcomingEvents is always enabled and first (key feature)
            config.enabledWidgets.insert(.upcomingEvents)
            // Move to top of order
            if let index = config.widgetOrder.firstIndex(of: .upcomingEvents) {
                if index > 0 {
                    config.widgetOrder.remove(at: index)
                    config.widgetOrder.insert(.upcomingEvents, at: 0)
                }
            } else {
                config.widgetOrder.insert(.upcomingEvents, at: 0)
            }

            widgetConfiguration = config
            // Save migrated config
            setWidgetConfiguration(config)
        }

        // Load current user
        if let userData = UserDefaults.standard.data(forKey: Constants.UserDefaults.currentUser),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = true
        }
    }

    func setAuthenticated(_ authenticated: Bool, user: User? = nil) {
        isAuthenticated = authenticated
        currentUser = user

        // Persist user to UserDefaults
        if let user = user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaults.currentUser)
        } else if !authenticated {
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUser)
        }
    }

    func setOnboarded(_ onboarded: Bool) {
        isOnboarded = onboarded
        UserDefaults.standard.set(onboarded, forKey: Constants.UserDefaults.isOnboarded)
    }

    func setDarkModePreference(_ preference: Constants.DarkModePreference) {
        darkModePreference = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Constants.UserDefaults.darkModePreference)
    }

    func setAvatarColorTheme(_ theme: Constants.AvatarColorTheme) {
        avatarColorTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: Constants.UserDefaults.avatarColorTheme)
    }

    func setWidgetConfiguration(_ config: WidgetConfiguration) {
        widgetConfiguration = config
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Constants.UserDefaults.widgetConfiguration)
        }
    }

    func toggleWidget(_ widget: HomeWidgetType) {
        widgetConfiguration.toggleWidget(widget)
        setWidgetConfiguration(widgetConfiguration)
    }

    func isWidgetEnabled(_ widget: HomeWidgetType) -> Bool {
        widgetConfiguration.isEnabled(widget)
    }

    func widgetSize(_ widget: HomeWidgetType) -> WidgetSize {
        widgetConfiguration.sizeFor(widget)
    }

    func setWidgetSize(_ size: WidgetSize, for widget: HomeWidgetType) {
        widgetConfiguration.setSize(size, for: widget)
        setWidgetConfiguration(widgetConfiguration)
    }

    func updateWidgetOrder(_ newOrder: [HomeWidgetType]) {
        widgetConfiguration.widgetOrder = newOrder
        setWidgetConfiguration(widgetConfiguration)
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        var order = widgetConfiguration.widgetOrder
        order.move(fromOffsets: source, toOffset: destination)
        widgetConfiguration.widgetOrder = order
        setWidgetConfiguration(widgetConfiguration)
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUser)
    }
}
