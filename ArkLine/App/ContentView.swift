import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var updateChecker = AppUpdateChecker()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var showSplash = true

    private let minSplashDuration: TimeInterval = 2.0
    private let maxRefreshWait: TimeInterval = 5.0

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }

            // Soft "update available" nudge — top of screen, signed-in app only.
            if !showSplash, appState.isAuthenticated,
               updateChecker.updateAvailable, !updateChecker.softBannerDismissed {
                VStack {
                    UpdateBannerView(
                        message: updateChecker.config?.updateMessage
                            ?? "A new version of Arkline is available.",
                        onUpdate: { if let url = updateChecker.appStoreURL { openURL(url) } },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                updateChecker.softBannerDismissed = true
                            }
                        }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1)
            }

            // Hard gate — blocks the app entirely. Only appears if we raise the
            // minimum supported version in Supabase (off by default).
            if !showSplash, updateChecker.updateRequired {
                UpdateRequiredView(
                    message: updateChecker.config?.forceMessage
                        ?? "This version of Arkline is out of date. Please update to continue.",
                    onUpdate: { if let url = updateChecker.appStoreURL { openURL(url) } }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .toastContainer()
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: updateChecker.updateAvailable)
        .animation(.easeInOut(duration: 0.3), value: updateChecker.updateRequired)
        .task {
            await runStartupSequence()
        }
        .task {
            await updateChecker.check()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await updateChecker.check() }
            }
        }
    }

    private func runStartupSequence() async {
        DataPrefetcher.start()

        let startTime = Date()

        // If there's a cached authenticated session, refresh it BEFORE routing.
        // This prevents a user with stale cached state (e.g. recently canceled
        // subscription) from getting brief access on cold start.
        if appState.isAuthenticated {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await appState.refreshUserProfile()
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(maxRefreshWait))
                }
                // Return as soon as either completes
                await group.next()
                group.cancelAll()
            }
        }

        // Maintain minimum splash duration for UX continuity
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minSplashDuration {
            try? await Task.sleep(for: .seconds(minSplashDuration - elapsed))
        }

        withAnimation {
            showSplash = false
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !appState.isOnboarded {
            OnboardingCoordinator()
        } else if !appState.isAuthenticated {
            AuthenticationCoordinator()
        } else if let user = appState.currentUser, !user.isAccessGranted {
            SubscriptionExpiredView()
        } else {
            MainTabView()
        }
    }
}

// MARK: - App Update Prompt
//
// Lets users on an outdated build know an update is available, and — only if we
// deliberately raise the minimum supported version in Supabase — can hard-block
// a known-bad build. Config lives in the `app_version_config` table (platform
// 'ios'); the app compares its own CFBundleShortVersionString against it.

/// Remote version config (app_version_config, one row per platform).
struct AppVersionConfig: Codable {
    let platform: String
    let latestVersion: String
    let minSupportedVersion: String
    let appStoreId: String?
    let updateMessage: String?
    let forceMessage: String?

    enum CodingKeys: String, CodingKey {
        case platform
        case latestVersion = "latest_version"
        case minSupportedVersion = "min_supported_version"
        case appStoreId = "app_store_id"
        case updateMessage = "update_message"
        case forceMessage = "force_message"
    }
}

/// Dotted-numeric version comparison (e.g. "1.2.0" older than "1.10.0").
enum AppVersionCompare {
    static func isOlder(_ lhs: String, than rhs: String) -> Bool {
        let a = components(lhs), b = components(rhs)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    private static func components(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

/// Fetches the remote version config and decides whether to nudge (soft) or
/// block (hard). Never throws into the UI — a config failure just does nothing.
@MainActor
final class AppUpdateChecker: ObservableObject {
    @Published var updateAvailable = false   // current < latest_version
    @Published var updateRequired = false    // current < min_supported_version
    @Published var softBannerDismissed = false
    @Published private(set) var config: AppVersionConfig?

    private let fallbackAppStoreId = "6760355430"
    private var lastCheck: Date?

    func check() async {
        // Don't hammer the network on every foreground — at most once / 5 min.
        if let last = lastCheck, Date().timeIntervalSince(last) < 300 { return }
        let supabase = SupabaseManager.shared
        guard supabase.isConfigured else { return }
        lastCheck = Date()
        do {
            let rows: [AppVersionConfig] = try await supabase.database
                .from("app_version_config")
                .select()
                .eq("platform", value: "ios")
                .limit(1)
                .execute()
                .value
            guard let cfg = rows.first else { return }
            config = cfg
            let current = AppVersionCompare.current
            let mustUpdate = AppVersionCompare.isOlder(current, than: cfg.minSupportedVersion)
            updateRequired = mustUpdate
            updateAvailable = !mustUpdate && AppVersionCompare.isOlder(current, than: cfg.latestVersion)
        } catch {
            // Fail silent — never block the app because a config read failed.
        }
    }

    var appStoreURL: URL? {
        let id = config?.appStoreId ?? fallbackAppStoreId
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }
}

/// Dismissible top banner shown when a newer version is on the App Store.
struct UpdateBannerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Update available")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(action: onUpdate) {
                Text("Update")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .cornerRadius(8)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.accent)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}

/// Full-screen blocking gate for a required update (off by default).
struct UpdateRequiredView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: String
    let onUpdate: () -> Void

    var body: some View {
        ZStack {
            AppColors.background(colorScheme).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.accent)
                Text("Update Required")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                Button(action: onUpdate) {
                    Text("Update Now")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: - Onboarding Coordinator
struct OnboardingCoordinator: View {
    @EnvironmentObject var appState: AppState
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            OnboardingFlowView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isOnboardingComplete) { _, isComplete in
            if isComplete {
                appState.setOnboarded(true)
                appState.setAuthenticated(true, user: viewModel.createdUser)
                appState.justOnboarded = true
                Task { await appState.refreshUserProfile() }
            }
        }
    }
}

// MARK: - Authentication Coordinator
struct AuthenticationCoordinator: View {
    @EnvironmentObject var appState: AppState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            LoginView(viewModel: viewModel)
        }
        .onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Keep existing cached user if viewModel.user is nil (passcode/biometric-only auth)
                appState.setAuthenticated(true, user: viewModel.user ?? appState.currentUser)
                appState.selectedTab = .home
                Task { await appState.refreshUserProfile() }
            }
        }
    }
}

// MARK: - Onboarding Flow View
struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: viewModel.isMovingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: viewModel.isMovingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(viewModel: viewModel)
            case .signIn:
                SignInView(viewModel: viewModel)
            case .paywall:
                PaywallStepView(viewModel: viewModel)
            case .email:
                EnterEmailView(viewModel: viewModel)
            case .verification:
                VerificationCodeView(viewModel: viewModel)
            case .username:
                ChooseUsernameView(viewModel: viewModel)
            case .investmentInterests:
                InvestmentInterestsView(viewModel: viewModel)
            case .careerInfo:
                CareerInfoView(viewModel: viewModel)
            case .cryptoApproach:
                CryptoApproachView(viewModel: viewModel)
            case .portfolioGoals:
                PortfolioGoalsView(viewModel: viewModel)
            case .createPasscode:
                CreatePasscodeView(viewModel: viewModel)
            case .confirmPasscode:
                ConfirmPasscodeView(viewModel: viewModel)
            case .faceIDSetup:
                FaceIDSetupView(viewModel: viewModel)
            case .notifications:
                NotificationSetupView(viewModel: viewModel)
            }
        }
        .id(viewModel.currentStep)
        .transition(stepTransition)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.currentStep)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
}
