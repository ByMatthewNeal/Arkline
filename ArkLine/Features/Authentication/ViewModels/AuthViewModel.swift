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
@Observable
class AuthViewModel {
    // MARK: - Properties
    var passcode: String = ""
    var authState: AuthState = .idle
    var errorMessage: String?
    var showFaceID: Bool = true

    var isAuthenticated: Bool = false
    var user: User?

    private let passcodeManager = PasscodeManager.shared

    // MARK: - Computed Properties from PasscodeManager
    var remainingAttempts: Int {
        5 - (getFailedAttemptCount())
    }

    var isLocked: Bool {
        passcodeManager.isLockedOut
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
    init() {
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
            DispatchQueue.main.async {
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
                        self.authState = .failed(error.localizedDescription)
                        self.errorMessage = error.localizedDescription
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
            errorMessage = "Too many failed attempts. Try again in 5 minutes."
            authState = .failed("Account locked")
        }
    }

    private func loadUserSettings() {
        // Load Face ID preference from secure storage
        showFaceID = passcodeManager.isBiometricEnabled
    }
}

// MARK: - Auth Error Extension
extension AppError {
    static func authError(_ message: String) -> AppError {
        return .custom(message: message)
    }
}
