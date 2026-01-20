import SwiftUI

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case email
    case verification
    case username
    case personalInfo
    case careerIndustry
    case careerInfo
    case socialLinks
    case profilePicture
    case createPasscode
    case confirmPasscode
    case faceIDSetup

    var progress: Double {
        Double(rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    var title: String {
        switch self {
        case .email: return "Enter Email"
        case .verification: return "Verify Email"
        case .username: return "Choose Username"
        case .personalInfo: return "Personal Info"
        case .careerIndustry: return "Industry"
        case .careerInfo: return "Experience"
        case .socialLinks: return "Social Links"
        case .profilePicture: return "Profile Picture"
        case .createPasscode: return "Create Passcode"
        case .confirmPasscode: return "Confirm Passcode"
        case .faceIDSetup: return "Face ID"
        }
    }
}

// MARK: - Onboarding View Model
@MainActor
@Observable
class OnboardingViewModel {
    // MARK: - State
    var currentStep: OnboardingStep = .email
    var isLoading = false
    var errorMessage: String?
    var isOnboardingComplete = false

    // MARK: - User Data
    var email = ""
    var verificationCode = ""
    var username = ""
    var fullName = ""
    var dateOfBirth: Date?
    var careerIndustry: CareerIndustry?
    var experienceLevel: ExperienceLevel?
    var twitterHandle = ""
    var linkedinUrl = ""
    var telegramHandle = ""
    var websiteUrl = ""
    var profileImageData: Data?
    var passcode = ""
    var confirmPasscode = ""
    var isFaceIDEnabled = false

    // MARK: - Created User
    var createdUser: User?

    // MARK: - Validation
    var isEmailValid: Bool {
        email.isValidEmail
    }

    var isVerificationCodeValid: Bool {
        verificationCode.count == 6
    }

    var isUsernameValid: Bool {
        username.count >= 3 && username.count <= 20 && username.isValidUsername
    }

    var isPersonalInfoValid: Bool {
        !fullName.isEmpty
    }

    var isPasscodeValid: Bool {
        passcode.count == 6
    }

    var doPasscodesMatch: Bool {
        passcode == confirmPasscode && isPasscodeValid
    }

    // MARK: - Navigation
    func nextStep() {
        guard let nextIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              nextIndex + 1 < OnboardingStep.allCases.count else {
            completeOnboarding()
            return
        }
        currentStep = OnboardingStep.allCases[nextIndex + 1]
    }

    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        currentStep = OnboardingStep.allCases[currentIndex - 1]
    }

    func skipStep() {
        nextStep()
    }

    // MARK: - Actions
    func sendVerificationCode() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await SupabaseAuthManager.shared.signInWithOTP(email: email)
            nextStep()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyCode() async {
        guard isVerificationCodeValid else {
            errorMessage = "Please enter the 6-digit code"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await SupabaseAuthManager.shared.verifyOTP(email: email, token: verificationCode)
            nextStep()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func validateUsername() async {
        guard isUsernameValid else {
            errorMessage = "Username must be 3-20 characters, letters, numbers, and underscores only"
            return
        }

        isLoading = true
        errorMessage = nil

        // Check if username is available
        do {
            let existingUsers: [User] = try await SupabaseDatabase.shared.selectWithFilter(
                from: .profiles,
                column: "username",
                value: username,
                columns: "id"
            )

            if existingUsers.isEmpty {
                nextStep()
            } else {
                errorMessage = "Username is already taken"
            }
        } catch {
            // If error, assume username is available
            nextStep()
        }

        isLoading = false
    }

    func savePersonalInfo() {
        guard isPersonalInfoValid else {
            errorMessage = "Please enter your name"
            return
        }
        nextStep()
    }

    func saveCareerIndustry() {
        nextStep()
    }

    func saveCareerInfo() {
        nextStep()
    }

    func saveSocialLinks() {
        nextStep()
    }

    func saveProfilePicture() async {
        // Upload image if provided
        if let _ = profileImageData {
            // TODO: Upload to Supabase Storage
        }
        nextStep()
    }

    func createPasscode() {
        guard isPasscodeValid else {
            errorMessage = "Passcode must be 6 digits"
            return
        }
        nextStep()
    }

    func confirmPasscodeEntry() {
        guard doPasscodesMatch else {
            errorMessage = "Passcodes do not match"
            confirmPasscode = ""
            return
        }
        nextStep()
    }

    func setupFaceID(enabled: Bool) {
        isFaceIDEnabled = enabled
        completeOnboarding()
    }

    func skipFaceID() {
        isFaceIDEnabled = false
        completeOnboarding()
    }

    // MARK: - Complete Onboarding
    private func completeOnboarding() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                guard let userId = SupabaseAuthManager.shared.currentUserId else {
                    throw AppError.authenticationRequired
                }

                let socialLinks = SocialLinks(
                    twitter: twitterHandle.nilIfEmpty,
                    linkedin: linkedinUrl.nilIfEmpty,
                    telegram: telegramHandle.nilIfEmpty,
                    website: websiteUrl.nilIfEmpty
                )

                let user = User(
                    id: userId,
                    username: username,
                    email: email,
                    fullName: fullName,
                    dateOfBirth: dateOfBirth,
                    careerIndustry: careerIndustry?.rawValue,
                    experienceLevel: experienceLevel?.rawValue,
                    socialLinks: socialLinks,
                    passcodeHash: hashPasscode(passcode),
                    faceIdEnabled: isFaceIDEnabled
                )

                // Create profile in database
                try await SupabaseDatabase.shared.insert(into: .profiles, values: user)

                // Create default portfolio
                let portfolio = Portfolio(userId: userId, name: "Main Portfolio")
                try await SupabaseDatabase.shared.insert(into: .portfolios, values: portfolio)

                createdUser = user
                isOnboardingComplete = true
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func hashPasscode(_ passcode: String) -> String {
        // In production, use proper hashing (e.g., bcrypt or Keychain)
        // This is a simplified version
        return passcode.data(using: .utf8)?.base64EncodedString() ?? ""
    }
}
