import SwiftUI
import LocalAuthentication

// MARK: - Auth State
enum AuthState: Equatable {
    case idle
    case authenticating
    case authenticated
    case failed(String)
}

// MARK: - Auth View Model
@MainActor
@Observable
class AuthViewModel {
    // MARK: - Properties
    var passcode: String = ""
    var authState: AuthState = .idle
    var errorMessage: String?
    var showFaceID: Bool = true

    var isAuthenticated: Bool = false
    var user: User?

    // Password sign-in (different account)
    var passwordSignInError: String?
    var isPasswordSignInLoading: Bool = false

    private let passcodeManager: PasscodeVerifying

    // MARK: - Computed Properties from PasscodeManager
    var remainingAttempts: Int {
        5 - (getFailedAttemptCount())
    }

    var isLocked: Bool {
        passcodeManager.isLockedOut
    }

    var passcodeLength: Int {
        passcodeManager.storedPasscodeLength
    }

    var lockoutEndTime: Date? {
        passcodeManager.lockoutEndTime
    }

    private func getFailedAttemptCount() -> Int {
        // Access via keychain (read-only check)
        if let data = KeychainManager.shared.loadOptional(forKey: KeychainManager.Keys.failedAttempts),
           data.count == MemoryLayout<Int>.size {
            return data.withUnsafeBytes { $0.load(as: Int.self) }
        }
        return 0
    }

    // MARK: - Computed Properties
    var canUseBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return "Biometrics"
        }
    }

    var lockoutTimeRemaining: String {
        passcodeManager.lockoutTimeRemaining
    }

    // MARK: - Initialization
    init(passcodeManager: PasscodeVerifying = PasscodeManager.shared) {
        self.passcodeManager = passcodeManager
        loadUserSettings()
    }

    // MARK: - Public Methods
    func verifyPasscode() {
        guard !isLocked else {
            errorMessage = "Too many attempts. Try again in \(lockoutTimeRemaining)"
            return
        }

        authState = .authenticating

        // Verify using secure PBKDF2 hashing
        Task {
            // Small delay to prevent timing attacks
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                if passcodeManager.verify(passcode) {
                    authState = .authenticated
                    isAuthenticated = true
                    passcodeManager.resetFailedAttempts()
                    errorMessage = nil
                } else {
                    handleFailedAttempt()
                }
            }
        }
    }

    func authenticateWithBiometrics() {
        guard canUseBiometrics else {
            errorMessage = "\(biometricName) is not available"
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"

        authState = .authenticating

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock ArkLine"
        ) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if success {
                    self.authState = .authenticated
                    self.isAuthenticated = true
                    self.errorMessage = nil
                } else if let error = error as? LAError {
                    switch error.code {
                    case .userCancel, .userFallback:
                        self.authState = .idle
                        self.showFaceID = false
                    case .biometryLockout:
                        self.errorMessage = "\(self.biometricName) is locked. Use passcode instead."
                        self.showFaceID = false
                        self.authState = .idle
                    default:
                        let message = AppError.from(error).userMessage
                        self.authState = .failed(message)
                        self.errorMessage = message
                    }
                }
            }
        }
    }

    func resetPasscode() {
        passcode = ""
        errorMessage = nil
        authState = .idle
    }

    func logout() {
        isAuthenticated = false
        user = nil
        resetPasscode()
    }

    // MARK: - Private Methods
    private func handleFailedAttempt() {
        passcode = ""

        if let remaining = passcodeManager.recordFailedAttempt() {
            authState = .failed("Incorrect passcode")
            errorMessage = "Incorrect passcode. \(remaining) attempts remaining."
        } else {
            // Locked out
            errorMessage = "Too many failed attempts. Try again in 15 minutes."
            authState = .failed("Account locked")
        }
    }

    private func loadUserSettings() {
        // Load Face ID preference from secure storage
        showFaceID = passcodeManager.isBiometricEnabled
    }

    // MARK: - Password Sign-In (Different Account)

    func signInWithPassword(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else { return }

        passwordSignInError = nil
        isPasswordSignInLoading = true
        defer { isPasswordSignInLoading = false }

        do {
            let session = try await SupabaseAuthManager.shared.signIn(email: email, password: password)
            let newUserId = session.user.id

            clearCachedStateIfDifferentUser(newUserId: newUserId)

            guard let profile = try await SupabaseDatabase.shared.getProfile(userId: newUserId) else {
                passwordSignInError = "Account found but profile is missing. Contact support@arkline.io."
                Haptics.error()
                return
            }

            var newUser = User(
                id: newUserId,
                username: profile.username ?? email.components(separatedBy: "@").first ?? "user",
                email: email,
                fullName: profile.fullName,
                faceIdEnabled: false
            )
            if let role = profile.role {
                newUser.role = UserRole(rawValue: role) ?? .user
            }
            if let subStatus = profile.subscriptionStatus {
                newUser.subscriptionStatus = SubscriptionStatus(rawValue: subStatus) ?? .none
            }
            newUser.trialEnd = profile.trialEnd
            newUser.currentPeriodEnd = profile.currentPeriodEnd

            self.user = newUser
            self.authState = .authenticated
            self.isAuthenticated = true
            Haptics.success()
        } catch {
            passwordSignInError = AppError.from(error).userMessage
            authState = .failed(passwordSignInError ?? "Sign in failed")
            Haptics.error()
        }
    }

    private func clearCachedStateIfDifferentUser(newUserId: UUID) {
        let cachedData = UserDefaults.standard.data(forKey: Constants.UserDefaults.currentUser)
        if let data = cachedData,
           let cached = try? JSONDecoder().decode(User.self, from: data),
           cached.id != newUserId {
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUser)
            try? PasscodeManager.shared.clearPasscode()
            UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.biometricEnabled)
            logInfo("Cleared cached state from previous user before switching accounts", category: .auth)
        }
    }
}

// MARK: - Auth Error Extension
extension AppError {
    static func authError(_ message: String) -> AppError {
        return .custom(message: message)
    }
}
