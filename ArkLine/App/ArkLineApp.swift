import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@main
struct ArkLineApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    setupAppearance()
                    setupNotifications()
                    Task {
                        await appState.refreshUserProfile()
                        await AnalyticsService.shared.trackAppOpen()
                    }
                }
                .onOpenURL { url in
                    Task {
                        await handleDeepLink(url)
                    }
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await AnalyticsService.shared.flush() }
            } else if newPhase == .active {
                Task { await appState.refreshUserProfile() }
            }
        }
    }

    private func setupNotifications() {
        // Register notification categories
        BroadcastNotificationService.shared.registerNotificationCategories()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = appDelegate
    }

    private func handleDeepLink(_ url: URL) async {
        guard url.scheme == "arkline" else { return }

        if url.host == "invite" {
            // Handle invite deep link: arkline://invite?code=ARK-XXXXXX
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else { return }

            await MainActor.run {
                NotificationCenter.default.post(
                    name: .inviteCodeDeepLink,
                    object: nil,
                    userInfo: ["code": code]
                )
            }
        } else if url.host == "auth" || url.path.contains("callback") {
            // Handle Supabase auth callback
            do {
                let session = try await SupabaseManager.shared.client.auth.session(from: url)
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: Notification.Name("DeepLinkAuthSuccess"),
                        object: nil,
                        userInfo: ["session": session]
                    )
                }
            } catch {
                logError("Error handling auth callback: \(error)", category: .network)
            }
        }
    }

    private func setupAppearance() {
        #if canImport(UIKit)
        // Configure UIKit appearance for components that need it
        // Use label color which adapts to light/dark mode automatically
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UIRefreshControl.appearance().tintColor = UIColor(AppColors.accent)
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let inviteCodeDeepLink = Notification.Name("InviteCodeDeepLink")
}

// MARK: - App State
// MARK: - Core Asset Type
/// Represents the core cryptocurrency assets that can be displayed in the Core widget
enum CoreAsset: String, CaseIterable, Codable, Identifiable {
    case btc = "BTC"
    case eth = "ETH"
    case sol = "SOL"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .btc: return "Bitcoin"
        case .eth: return "Ethereum"
        case .sol: return "Solana"
        }
    }

    var coinGeckoId: String {
        switch self {
        case .btc: return "bitcoin"
        case .eth: return "ethereum"
        case .sol: return "solana"
        }
    }

    var icon: String {
        switch self {
        case .btc: return "bitcoinsign.circle.fill"
        case .eth: return "diamond.fill"
        case .sol: return "solana-logo" // Image asset name
        }
    }

    /// Whether the icon is an SF Symbol (true) or an image asset (false)
    var isSystemIcon: Bool {
        switch self {
        case .btc, .eth: return true
        case .sol: return false
        }
    }

    static var defaultEnabled: Set<CoreAsset> {
        [.btc, .eth]
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isOnboarded = false
    @Published var currentUser: User?
    @Published var darkModePreference: Constants.DarkModePreference = .automatic
    @Published var avatarColorTheme: Constants.AvatarColorTheme = .ocean
    @Published var chartColorPalette: Constants.ChartColorPalette = .classic
    @Published var preferredCurrency: String = "USD"
    @Published var widgetConfiguration: WidgetConfiguration = WidgetConfiguration()
    @Published var enabledCoreAssets: Set<CoreAsset> = CoreAsset.defaultEnabled

    // Navigation reset triggers - increment to pop to root
    @Published var homeNavigationReset = UUID()
    @Published var marketNavigationReset = UUID()
    @Published var portfolioNavigationReset = UUID()
    @Published var insightsNavigationReset = UUID()
    @Published var profileNavigationReset = UUID()

    // All users get full access (invite-only app, no subscription)
    var isPro: Bool { true }

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

        // Load chart color palette
        if let chartPaletteValue = UserDefaults.standard.string(forKey: Constants.UserDefaults.chartColorPalette),
           let palette = Constants.ChartColorPalette(rawValue: chartPaletteValue) {
            chartColorPalette = palette
        }

        // Load preferred currency
        if let currency = UserDefaults.standard.string(forKey: Constants.UserDefaults.preferredCurrency) {
            preferredCurrency = currency
        }

        // Load enabled core assets
        if let data = UserDefaults.standard.data(forKey: "enabledCoreAssets"),
           let assets = try? JSONDecoder().decode(Set<CoreAsset>.self, from: data) {
            enabledCoreAssets = assets.isEmpty ? CoreAsset.defaultEnabled : assets
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

        // Persist user to UserDefaults (strip sensitive fields)
        if let user = user {
            var sanitized = user
            sanitized.passcodeHash = nil
            if let data = try? JSONEncoder().encode(sanitized) {
                UserDefaults.standard.set(data, forKey: Constants.UserDefaults.currentUser)
            }
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

    func setChartColorPalette(_ palette: Constants.ChartColorPalette) {
        chartColorPalette = palette
        UserDefaults.standard.set(palette.rawValue, forKey: Constants.UserDefaults.chartColorPalette)
    }

    func setPreferredCurrency(_ currency: String) {
        preferredCurrency = currency
        UserDefaults.standard.set(currency, forKey: Constants.UserDefaults.preferredCurrency)
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

    // MARK: - Core Assets

    func toggleCoreAsset(_ asset: CoreAsset) {
        if enabledCoreAssets.contains(asset) {
            // Don't allow disabling the last asset
            if enabledCoreAssets.count > 1 {
                enabledCoreAssets.remove(asset)
            }
        } else {
            enabledCoreAssets.insert(asset)
        }
        saveCoreAssets()
    }

    func setCoreAssets(_ assets: Set<CoreAsset>) {
        enabledCoreAssets = assets.isEmpty ? CoreAsset.defaultEnabled : assets
        saveCoreAssets()
    }

    func isCoreAssetEnabled(_ asset: CoreAsset) -> Bool {
        enabledCoreAssets.contains(asset)
    }

    private func saveCoreAssets() {
        if let data = try? JSONEncoder().encode(enabledCoreAssets) {
            UserDefaults.standard.set(data, forKey: "enabledCoreAssets")
        }
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUser)
        PasscodeManager.shared.clearLockout()
    }

    // MARK: - Profile Refresh

    func refreshUserProfile() async {
        guard SupabaseManager.shared.isConfigured else { return }

        // Determine the user ID: prefer cached user, fall back to Supabase auth session
        let userId: UUID
        if let existingId = currentUser?.id {
            userId = existingId
        } else if let authId = SupabaseAuthManager.shared.currentUserId {
            userId = authId
        } else {
            return
        }

        do {
            guard let profile = try await SupabaseDatabase.shared.getProfile(userId: userId) else { return }

            // Build user from existing cached user or create a new one from the DB profile
            var updatedUser = currentUser ?? User(
                id: userId,
                username: profile.username ?? "user",
                email: profile.email ?? ""
            )
            if let role = profile.role {
                updatedUser.role = UserRole(rawValue: role) ?? updatedUser.role
            }
            if let subStatus = profile.subscriptionStatus {
                updatedUser.subscriptionStatus = SubscriptionStatus(rawValue: subStatus) ?? updatedUser.subscriptionStatus
            }
            updatedUser.trialEnd = profile.trialEnd
            if let fullName = profile.fullName {
                updatedUser.fullName = fullName
            }
            if let username = profile.username {
                updatedUser.username = username
            }
            if let avatarUrl = profile.avatarUrl {
                updatedUser.avatarUrl = avatarUrl
            }

            self.currentUser = updatedUser
            var sanitized = updatedUser
            sanitized.passcodeHash = nil
            if let data = try? JSONEncoder().encode(sanitized) {
                UserDefaults.standard.set(data, forKey: Constants.UserDefaults.currentUser)
            }
        } catch {
            logError("Failed to refresh profile: \(error.localizedDescription)", category: .auth)
        }
    }
}

// MARK: - App Delegate

#if canImport(UIKit)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Controls which orientations are currently allowed. Default is portrait only.
    /// Set to `.allButUpsideDown` temporarily when a fullscreen chart is shown.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    // MARK: - Push Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        BroadcastNotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        BroadcastNotificationService.shared.handleDeviceTokenError(error)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .badge, .sound])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification response
        if let result = BroadcastNotificationService.shared.handleNotificationResponse(response) {
            // Post notification for navigation
            NotificationCenter.default.post(
                name: Notification.Name("BroadcastNotificationTapped"),
                object: nil,
                userInfo: ["type": result.type, "id": result.id]
            )
        }

        // Clear badge
        BroadcastNotificationService.shared.clearBadge()

        completionHandler()
    }
}
#else
class AppDelegate: NSObject {
    // macOS stub
}
#endif
