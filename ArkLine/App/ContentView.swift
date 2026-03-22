import SwiftUI

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

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
        .onAppear {
            // Pre-fetch critical market data while splash plays
            DataPrefetcher.start()

            // Show splash for minimum duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !appState.isOnboarded {
            OnboardingCoordinator()
        } else if !appState.isAuthenticated {
            AuthenticationCoordinator()
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
            case .inviteCode:
                InviteCodeView(viewModel: viewModel)
            case .email:
                EnterEmailView(viewModel: viewModel)
            case .verification:
                VerificationCodeView(viewModel: viewModel)
            case .username:
                ChooseUsernameView(viewModel: viewModel)
            case .personalInfo:
                PersonalInfoView(viewModel: viewModel)
            case .careerIndustry:
                CareerIndustryView(viewModel: viewModel)
            case .careerInfo:
                CareerInfoView(viewModel: viewModel)
            case .socialLinks:
                SocialLinksView(viewModel: viewModel)
            case .profilePicture:
                ProfilePictureView(viewModel: viewModel)
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
