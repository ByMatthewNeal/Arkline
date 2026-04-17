import SwiftUI

// MARK: - Onboarding Step
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case inviteCode
    case email
    case verification
    case username
    case investmentInterests   // NEW: What do you invest in?
    case careerInfo            // Experience level + portfolio size
    case cryptoApproach        // NEW: How you approach crypto
    case portfolioGoals        // NEW: What matters most to you?
    case createPasscode
    case confirmPasscode
    case faceIDSetup
    case notifications

    /// Gate steps excluded from progress tracking
    private static let gateSteps: Set<OnboardingStep> = [.welcome, .inviteCode]

    /// Progress excluding gate steps (0.0 to 1.0)
    var progress: Double {
        guard !Self.gateSteps.contains(self) else { return 0 }
        let numberedSteps = OnboardingStep.allCases.filter { !Self.gateSteps.contains($0) }
        guard let index = numberedSteps.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(numberedSteps.count)
    }

    /// Current step number (1-based, excludes gate steps)
    var stepNumber: Int {
        guard !Self.gateSteps.contains(self) else { return 0 }
        let numberedSteps = OnboardingStep.allCases.filter { !Self.gateSteps.contains($0) }
        guard let index = numberedSteps.firstIndex(of: self) else { return 0 }
        return index + 1
    }

    /// Total steps (excludes gate steps)
    static var totalSteps: Int {
        OnboardingStep.allCases.filter { !gateSteps.contains($0) }.count
    }

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .inviteCode: return "Invite Code"
        case .email: return "Enter Email"
        case .verification: return "Verify Email"
        case .username: return "Your Name"
        case .investmentInterests: return "Investments"
        case .careerInfo: return "Experience"
        case .cryptoApproach: return "Approach"
        case .portfolioGoals: return "Goals"
        case .createPasscode: return "Create Passcode"
        case .confirmPasscode: return "Confirm Passcode"
        case .faceIDSetup: return "Face ID"
        case .notifications: return "Notifications"
        }
    }

    /// Whether this step can be skipped
    var isSkippable: Bool {
        switch self {
        case .investmentInterests, .careerInfo, .cryptoApproach, .portfolioGoals, .notifications:
            return true
        default:
            return false
        }
    }

    /// Category for grouping steps in UI
    var category: StepCategory {
        switch self {
        case .welcome, .inviteCode:
            return .intro
        case .email, .verification:
            return .authentication
        case .username, .investmentInterests, .careerInfo, .cryptoApproach, .portfolioGoals:
            return .profile
        case .createPasscode, .confirmPasscode, .faceIDSetup:
            return .security
        case .notifications:
            return .setup
        }
    }
}

// MARK: - Investment Interest
enum InvestmentInterest: String, CaseIterable, Identifiable {
    case crypto = "Crypto"
    case stocks = "Stocks & ETFs"
    case commodities = "Commodities"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .commodities: return "leaf.fill"
        }
    }
}

// MARK: - Portfolio Size Range
enum PortfolioSizeRange: String, CaseIterable, Identifiable {
    case under1k = "Under $1K"
    case from1kTo10k = "$1K – $10K"
    case from10kTo50k = "$10K – $50K"
    case from50kTo250k = "$50K – $250K"
    case over250k = "$250K+"

    var id: String { rawValue }
}

// MARK: - Crypto Approach
enum CryptoApproach: String, CaseIterable, Identifiable {
    case longTermHolder = "Long-term holder"
    case activeTrader = "Active trader"
    case systematicDCA = "Systematic DCA"
    case buildingConviction = "Building conviction"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .longTermHolder: return "Spot positions, multi-year horizon"
        case .activeTrader: return "Swing setups and short-term moves"
        case .systematicDCA: return "Scheduled or risk-adjusted accumulation"
        case .buildingConviction: return "Getting started, learning the signals"
        }
    }

    var icon: String {
        switch self {
        case .longTermHolder: return "hourglass"
        case .activeTrader: return "bolt.fill"
        case .systematicDCA: return "calendar.badge.clock"
        case .buildingConviction: return "lightbulb.fill"
        }
    }
}

// MARK: - Portfolio Goal
enum PortfolioGoal: String, CaseIterable, Identifiable {
    case riskManagement = "Risk Management"
    case entrySignals = "Finding Entries"
    case portfolioTracking = "Portfolio Tracking"
    case marketIntelligence = "Market Intelligence"
    case dcaStrategy = "DCA Strategy"
    case macroAnalysis = "Macro Analysis"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .riskManagement: return "shield.checkered"
        case .entrySignals: return "scope"
        case .portfolioTracking: return "chart.pie.fill"
        case .marketIntelligence: return "sparkles"
        case .dcaStrategy: return "calendar.badge.clock"
        case .macroAnalysis: return "globe.americas.fill"
        }
    }

    var description: String {
        switch self {
        case .riskManagement: return "Know when to size up or de-risk"
        case .entrySignals: return "Fibonacci-based trade signals"
        case .portfolioTracking: return "Track holdings and performance"
        case .marketIntelligence: return "Daily briefings and sentiment"
        case .dcaStrategy: return "Systematic accumulation plans"
        case .macroAnalysis: return "VIX, DXY, liquidity cycles"
        }
    }
}

// MARK: - Step Category
enum StepCategory: String {
    case intro = "Welcome"
    case authentication = "Account"
    case profile = "Profile"
    case security = "Security"
    case setup = "Setup"
}

// MARK: - Onboarding View Model
@MainActor
@Observable
class OnboardingViewModel {
    // MARK: - State
    var currentStep: OnboardingStep = .welcome
    var isMovingForward = true
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
    var uploadedAvatarUrl: String?
    var passcode = ""
    var confirmPasscode = ""
    var isFaceIDEnabled = false

    // MARK: - New Onboarding Data
    var investmentInterests: Set<InvestmentInterest> = []
    var portfolioSizeRange: PortfolioSizeRange?
    var cryptoApproach: CryptoApproach?
    var portfolioGoals: Set<PortfolioGoal> = []

    // MARK: - Invite Code
    var inviteCode = ""
    var inviteCodeError: String?
    var validatedInviteCode: InviteCode?
    private let inviteCodeService: InviteCodeServiceProtocol = InviteCodeService()

    // MARK: - Created User
    var createdUser: User?

    // MARK: - Security
    private let passcodeManager = PasscodeManager.shared

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
        isMovingForward = true
        Haptics.light()
        currentStep = OnboardingStep.allCases[nextIndex + 1]
    }

    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        isMovingForward = false
        Haptics.light()
        currentStep = OnboardingStep.allCases[currentIndex - 1]
    }

    var isReturningUser = false

    func skipToLogin() {
        isMovingForward = true
        isReturningUser = true
        currentStep = .email
    }

    func skipStep() {
        nextStep()
    }

    // MARK: - Invite Code Validation

    var isInviteCodeFormatValid: Bool {
        let cleaned = inviteCode.uppercased().trimmingCharacters(in: .whitespaces)
        return cleaned.count >= 10 && cleaned.hasPrefix("ARK-")
    }

    func validateInviteCode() async {
        guard isInviteCodeFormatValid else {
            inviteCodeError = "Please enter a valid invite code (ARK-XXXXXX)"
            return
        }

        isLoading = true
        inviteCodeError = nil

        do {
            if let code = try await inviteCodeService.validateCode(inviteCode) {
                validatedInviteCode = code
                // Pre-fill email if the code has one
                if let codeEmail = code.email, !codeEmail.isEmpty, email.isEmpty {
                    email = codeEmail
                }
                nextStep()
            } else {
                inviteCodeError = "This invite code is invalid, expired, or has already been used"
            }
        } catch {
            inviteCodeError = AppError.from(error).userMessage
        }

        isLoading = false
    }

    /// Handle an invite code received via deep link.
    func handleDeepLinkCode(_ code: String) {
        inviteCode = code
        if currentStep != .inviteCode {
            currentStep = .inviteCode
        }
        Task { await validateInviteCode() }
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
            // If returning user, verify the account exists before sending OTP
            if isReturningUser {
                let exists = try await SupabaseDatabase.shared.emailExists(email)
                if !exists {
                    errorMessage = "No account found with this email"
                    isLoading = false
                    return
                }
            }

            try await SupabaseAuthManager.shared.signInWithOTP(email: email)
            // Only advance if we're not already on the verification step (i.e. not a resend)
            if currentStep != .verification {
                nextStep()
            }
        } catch {
            errorMessage = AppError.from(error).userMessage
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
            errorMessage = AppError.from(error).userMessage
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
        nextStep()
    }

    func saveInvestmentInterests() {
        nextStep()
    }

    func saveCareerInfo() {
        nextStep()
    }

    func saveCryptoApproach() {
        nextStep()
    }

    func savePortfolioGoals() {
        nextStep()
    }

    // MARK: - Legacy (views still in project but not in flow)
    func savePersonalInfo() { nextStep() }
    func saveCareerIndustry() { nextStep() }
    func saveSocialLinks() { nextStep() }
    func saveProfilePicture() async { nextStep() }

    func createPasscode() {
        guard isPasscodeValid else {
            errorMessage = "Passcode must be 4 or 6 digits"
            return
        }
        nextStep()
    }

    func confirmPasscodeEntry() {
        guard doPasscodesMatch else {
            Haptics.error()
            errorMessage = "Passcodes do not match"
            confirmPasscode = ""
            return
        }
        nextStep()
    }

    func setupFaceID(enabled: Bool) {
        isFaceIDEnabled = enabled
        passcodeManager.isBiometricEnabled = enabled
        nextStep()
    }

    func skipFaceID() {
        isFaceIDEnabled = false
        passcodeManager.isBiometricEnabled = false
        nextStep()
    }

    func enableNotifications() {
        completeOnboarding()
    }

    func skipNotifications() {
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

                // Store passcode securely using PBKDF2 hashing in Keychain
                try passcodeManager.setPasscode(passcode)

                let socialLinks: SocialLinks? = nil // Collected in Profile settings now

                // Generate username from email (part before @) since we no longer collect username
                let generatedUsername = email.components(separatedBy: "@").first ?? "user"

                // Note: passcodeHash is no longer stored in User model or database
                // It's securely stored in Keychain via PasscodeManager
                let user = User(
                    id: userId,
                    username: generatedUsername,
                    email: email,
                    fullName: fullName,
                    avatarUrl: uploadedAvatarUrl,
                    dateOfBirth: dateOfBirth,
                    careerIndustry: careerIndustry?.rawValue,
                    experienceLevel: experienceLevel?.rawValue,
                    socialLinks: socialLinks,
                    passcodeHash: nil, // No longer stored in DB - using Keychain
                    faceIdEnabled: isFaceIDEnabled
                )

                // Upsert profile in database — uses CreateUserRequest which excludes
                // server-managed fields (role, subscription_status, trial_end) so
                // returning users get their new info saved without clobbering admin role.
                let profileRequest = CreateUserRequest(
                    id: userId,
                    username: generatedUsername,
                    email: email,
                    fullName: fullName,
                    dateOfBirth: dateOfBirth,
                    careerIndustry: careerIndustry?.rawValue,
                    experienceLevel: experienceLevel?.rawValue,
                    socialLinks: socialLinks,
                    avatarUrl: uploadedAvatarUrl,
                    faceIdEnabled: isFaceIDEnabled
                )

                do {
                    try await SupabaseDatabase.shared.upsert(into: .profiles, values: profileRequest)

                    // Create default portfolio only if user doesn't have one yet
                    let existingPortfolios = try await SupabaseDatabase.shared.getPortfolios(userId: userId)
                    if existingPortfolios.isEmpty {
                        let portfolio = Portfolio(userId: userId, name: "Main Portfolio")
                        try await SupabaseDatabase.shared.insert(into: .portfolios, values: portfolio)
                    }

                    // Redeem the invite code
                    if validatedInviteCode != nil {
                        do {
                            try await inviteCodeService.redeemCode(inviteCode, userId: userId)

                            // If this was a paid invite (trial or full), link the Stripe subscription
                            if validatedInviteCode?.paymentStatus == "paid" {
                                do {
                                    let _ = try await AdminService().activateSubscription(inviteCode: inviteCode)
                                } catch {
                                    AppLogger.shared.error("Failed to activate subscription: \(error.localizedDescription)")
                                }
                            }
                        } catch {
                            AppLogger.shared.error("Failed to redeem invite code: \(error.localizedDescription)")
                        }
                    }
                } catch {
                    // Log error but don't block onboarding - tables may not exist yet
                    AppLogger.shared.error("Database upsert failed (tables may not exist): \(error.localizedDescription)")
                }

                // Fetch the authoritative profile from DB to get server-managed fields
                // (e.g. admin role set via migration, subscription status from Stripe)
                var finalUser = user
                if let profile = try? await SupabaseDatabase.shared.getProfile(userId: userId) {
                    if let role = profile.role {
                        finalUser.role = UserRole(rawValue: role) ?? .user
                    }
                    if let subStatus = profile.subscriptionStatus {
                        finalUser.subscriptionStatus = SubscriptionStatus(rawValue: subStatus) ?? .none
                    }
                    finalUser.trialEnd = profile.trialEnd
                }

                createdUser = finalUser
                Haptics.success()
                isOnboardingComplete = true
            } catch {
                errorMessage = AppError.from(error).userMessage
            }

            isLoading = false
        }
    }
}
