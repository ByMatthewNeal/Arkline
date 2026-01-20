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
    var remainingAttempts: Int = 5
    var isLocked: Bool = false
    var lockoutEndTime: Date?
    var showFaceID: Bool = true

    var isAuthenticated: Bool = false
    var user: User?

    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes

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
        guard let endTime = lockoutEndTime else { return "" }
        let remaining = endTime.timeIntervalSinceNow
        if remaining <= 0 {
            return ""
        }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Initialization
    init() {
        checkLockoutStatus()
        loadUserSettings()
    }

    // MARK: - Public Methods
    func verifyPasscode() {
        guard !isLocked else {
            errorMessage = "Too many attempts. Try again in \(lockoutTimeRemaining)"
            return
        }

        authState = .authenticating

        // Simulate passcode verification (replace with actual verification)
        Task {
            do {
                let isValid = try await verifyPasscodeWithStorage(passcode)

                await MainActor.run {
                    if isValid {
                        authState = .authenticated
                        isAuthenticated = true
                        remainingAttempts = maxAttempts
                        errorMessage = nil
                    } else {
                        handleFailedAttempt()
                    }
                }
            } catch {
                await MainActor.run {
                    authState = .failed(error.localizedDescription)
                    errorMessage = error.localizedDescription
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
        remainingAttempts -= 1
        passcode = ""

        if remainingAttempts <= 0 {
            lockAccount()
        } else {
            authState = .failed("Incorrect passcode")
            errorMessage = "Incorrect passcode. \(remainingAttempts) attempts remaining."
        }
    }

    private func lockAccount() {
        isLocked = true
        lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
        errorMessage = "Too many failed attempts. Try again in 5 minutes."
        authState = .failed("Account locked")

        // Store lockout time
        UserDefaults.standard.set(lockoutEndTime, forKey: "auth_lockout_end")

        // Schedule unlock
        DispatchQueue.main.asyncAfter(deadline: .now() + lockoutDuration) { [weak self] in
            self?.unlockAccount()
        }
    }

    private func unlockAccount() {
        isLocked = false
        lockoutEndTime = nil
        remainingAttempts = maxAttempts
        errorMessage = nil
        authState = .idle
        UserDefaults.standard.removeObject(forKey: "auth_lockout_end")
    }

    private func checkLockoutStatus() {
        if let endTime = UserDefaults.standard.object(forKey: "auth_lockout_end") as? Date {
            if endTime > Date() {
                isLocked = true
                lockoutEndTime = endTime
                let remaining = endTime.timeIntervalSinceNow
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                    self?.unlockAccount()
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "auth_lockout_end")
            }
        }
    }

    private func loadUserSettings() {
        // Load Face ID preference
        showFaceID = UserDefaults.standard.bool(forKey: "face_id_enabled")
    }

    private func verifyPasscodeWithStorage(_ passcode: String) async throws -> Bool {
        // In production, this would verify against securely stored hash
        // Using Keychain or similar secure storage

        // Simulate network/storage delay
        try await Task.sleep(nanoseconds: 500_000_000)

        // For demo purposes, check against stored passcode
        // In production, use proper hash comparison
        guard let storedHash = UserDefaults.standard.string(forKey: "passcode_hash") else {
            throw AppError.invalidCredentials
        }

        // Simple comparison for demo - use proper hashing in production
        return passcode.hashValue == Int(storedHash) ?? 0
    }
}

// MARK: - Auth Error Extension
extension AppError {
    static func authError(_ message: String) -> AppError {
        return .custom(message: message)
    }
}
