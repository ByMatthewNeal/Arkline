import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
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

        }
        .toastContainer()
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .task {
            await runStartupSequence()
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
        } else if let user = appState.currentUser, user.isInAccountSetup {
            AccountSetupView()
        } else if let user = appState.currentUser, !user.isAccessGranted {
            SubscriptionExpiredView()
        } else {
            MainTabView()
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
            case .inviteCode:
                InviteCodeView(viewModel: viewModel)
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
