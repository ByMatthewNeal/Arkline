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

            #if DEBUG
            // Dev button to skip login (top right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        skipToMainApp()
                    }) {
                        Text("DEV")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(4)
                    }
                    .padding(.trailing, 4)
                    .padding(.top, 60)
                }
                Spacer()
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .onAppear {
            // Show splash for minimum duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }

    #if DEBUG
    private func skipToMainApp() {
        // Create a mock user for development
        let mockUser = User(
            id: UUID(),
            username: "devuser",
            email: "dev@arkline.app",
            fullName: "Dev User",
            dateOfBirth: nil,
            careerIndustry: nil,
            experienceLevel: nil,
            socialLinks: nil,
            passcodeHash: nil,
            faceIdEnabled: false
        )

        withAnimation {
            showSplash = false
            appState.setOnboarded(true)
            appState.setAuthenticated(true, user: mockUser)
        }
    }
    #endif

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
                appState.setAuthenticated(true, user: viewModel.user)
            }
        }
    }
}

// MARK: - Onboarding Flow View
struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                WelcomeView(viewModel: viewModel)
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
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
}
