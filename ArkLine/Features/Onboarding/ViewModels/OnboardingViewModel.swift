import SwiftUI

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome
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

    /// Progress excluding the welcome step (0.0 to 1.0)
    var progress: Double {
        guard self != .welcome else { return 0 }
        // Exclude welcome from progress calculation
        let stepsWithoutWelcome = OnboardingStep.allCases.filter { $0 != .welcome }
        guard let index = stepsWithoutWelcome.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(stepsWithoutWelcome.count)
    }

    /// Current step number (1-based, excludes welcome)
    var stepNumber: Int {
        guard self != .welcome else { return 0 }
        let stepsWithoutWelcome = OnboardingStep.allCases.filter { $0 != .welcome }
        guard let index = stepsWithoutWelcome.firstIndex(of: self) else { return 0 }
        return index + 1
    }

    /// Total steps (excludes welcome)
    static var totalSteps: Int {
        OnboardingStep.allCases.filter { $0 != .welcome }.count
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .email: return "Enter Email"
        case .verification: return "Verify Email"
        case .username: return "Your Name"
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

    /// Whether this step can be skipped
    var isSkippable: Bool {
        switch self {
        case .careerIndustry, .careerInfo, .socialLinks, .profilePicture:
            return true
        default:
            return false
        }
    }

    /// Category for grouping steps in UI
    var category: StepCategory {
        switch self {
        case .welcome:
            return .intro
        case .email, .verification:
            return .authentication
        case .username, .personalInfo, .careerIndustry, .careerInfo, .socialLinks, .profilePicture:
            return .profile
        case .createPasscode, .confirmPasscode, .faceIDSetup:
            return .security
        }
    }
}

// MARK: - Step Category
enum StepCategory: String {
    case intro = "Welcome"
    case authentication = "Account"
    case profile = "Profile"
    case security = "Security"
}

// MARK: - Onboarding View Model
@MainActor
@Observable
class OnboardingViewModel {
    // MARK: - State
    var currentStep: OnboardingStep = .welcome
    var isLoading = false
    var errorMessage: String?
    var isOnboardingComplete = false

    // MARK: - User Data
    var email = ""
    var verificationCode = ""
    var firstName = ""
    var lastName = ""
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
        verificationCode.count == 8
    }

    var isNameValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isPersonalInfoValid: Bool {
        !fullName.isEmpty
    }

    var isPasscodeValid: Bool {
        passcode.count == 4 || passcode.count == 6
    }

    /// The length of the created passcode (used for confirmation)
    var passcodeLength: Int {
        passcode.count
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
            errorMessage = "Please enter the 8-digit code"
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

    func saveName() {
        guard isNameValid else {
            errorMessage = "Please enter your first name"
            return
        }
        // Combine first and last name for fullName
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        fullName = trimmedLast.isEmpty ? trimmedFirst : "\(trimmedFirst) \(trimmedLast)"
        // Skip personalInfo step, go directly to careerIndustry
        currentStep = .careerIndustry
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
            errorMessage = "Passcode must be 4 or 6 digits"
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

                // Generate username from email (part before @) since we no longer collect username
                let generatedUsername = email.components(separatedBy: "@").first ?? "user"

                let user = User(
                    id: userId,
                    username: generatedUsername,
                    email: email,
                    fullName: fullName,
                    dateOfBirth: dateOfBirth,
                    careerIndustry: careerIndustry?.rawValue,
                    experienceLevel: experienceLevel?.rawValue,
                    socialLinks: socialLinks,
                    passcodeHash: hashPasscode(passcode),
                    faceIdEnabled: isFaceIDEnabled
                )

                // Try to create profile in database (non-blocking if tables don't exist yet)
                do {
                    try await SupabaseDatabase.shared.insert(into: .profiles, values: user)

                    // Create default portfolio
                    let portfolio = Portfolio(userId: userId, name: "Main Portfolio")
                    try await SupabaseDatabase.shared.insert(into: .portfolios, values: portfolio)
                } catch {
                    // Log error but don't block onboarding - tables may not exist yet
                    print("Database insert failed (tables may not exist): \(error.localizedDescription)")
                }

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
