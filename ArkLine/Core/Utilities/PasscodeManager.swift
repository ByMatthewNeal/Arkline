import Foundation
import CommonCrypto

// MARK: - PasscodeVerifying Protocol
/// Abstraction for passcode verification, enabling dependency injection in tests.
protocol PasscodeVerifying {
    func verify(_ passcode: String) -> Bool
    func resetFailedAttempts()
    func recordFailedAttempt() -> Int?
    var isLockedOut: Bool { get }
    var lockoutTimeRemaining: String { get }
    var isBiometricEnabled: Bool { get }
    var lockoutEndTime: Date? { get }
}

// MARK: - Passcode Manager
/// Secure passcode management using PBKDF2 hashing
final class PasscodeManager: PasscodeVerifying {

    // MARK: - Configuration

    /// Number of PBKDF2 iterations (higher = more secure but slower)
    private static let iterations: UInt32 = 10_000

    /// Length of derived key in bytes
    private static let keyLength = 32

    /// Length of salt in bytes
    private static let saltLength = 16

    // MARK: - Singleton

    static let shared = PasscodeManager()

    private let keychain = KeychainManager.shared

    private init() {}

    // MARK: - Public Methods

    /// Hash a passcode with a new random salt and store both in Keychain
    /// - Parameter passcode: The passcode to hash
    /// - Throws: KeychainError if storage fails
    func setPasscode(_ passcode: String) throws {
        let salt = generateSalt()
        let hash = hashPasscode(passcode, salt: salt)

        try keychain.save(hash, forKey: KeychainManager.Keys.passcodeHash)
        try keychain.save(salt, forKey: KeychainManager.Keys.passcodeSalt)
    }

    /// Verify a passcode against the stored hash
    /// - Parameter passcode: The passcode to verify
    /// - Returns: true if the passcode matches, false otherwise
    func verify(_ passcode: String) -> Bool {
        guard let storedHash = keychain.loadOptional(forKey: KeychainManager.Keys.passcodeHash),
              let storedSalt = keychain.loadOptional(forKey: KeychainManager.Keys.passcodeSalt) else {
            return false
        }

        let computedHash = hashPasscode(passcode, salt: storedSalt)
        return constantTimeCompare(computedHash, storedHash)
    }

    /// Check if a passcode has been set
    var hasPasscode: Bool {
        keychain.exists(forKey: KeychainManager.Keys.passcodeHash)
    }

    /// Remove the stored passcode
    func clearPasscode() throws {
        try keychain.delete(forKey: KeychainManager.Keys.passcodeHash)
        try keychain.delete(forKey: KeychainManager.Keys.passcodeSalt)
    }

    /// Hash a passcode for storage (used during onboarding before final save)
    /// Returns the hash and salt as a combined Data for temporary storage
    func createHash(for passcode: String) -> (hash: Data, salt: Data) {
        let salt = generateSalt()
        let hash = hashPasscode(passcode, salt: salt)
        return (hash, salt)
    }

    /// Verify a passcode against provided hash and salt (for temporary verification)
    func verify(_ passcode: String, against hash: Data, salt: Data) -> Bool {
        let computedHash = hashPasscode(passcode, salt: salt)
        return constantTimeCompare(computedHash, hash)
    }

    // MARK: - Private Methods

    /// Generate a cryptographically secure random salt
    private func generateSalt() -> Data {
        var salt = Data(count: Self.saltLength)
        let result = salt.withUnsafeMutableBytes { saltPtr -> OSStatus in
            guard let baseAddress = saltPtr.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, Self.saltLength, baseAddress)
        }

        // If secure random fails, fall back to arc4random (still secure on Apple platforms)
        if result != errSecSuccess {
            salt = Data((0..<Self.saltLength).map { _ in UInt8.random(in: 0...255) })
        }

        return salt
    }

    /// Hash a passcode using PBKDF2
    private func hashPasscode(_ passcode: String, salt: Data) -> Data {
        let passcodeData = Data(passcode.utf8)
        var derivedKey = Data(count: Self.keyLength)

        _ = derivedKey.withUnsafeMutableBytes { derivedKeyPtr in
            salt.withUnsafeBytes { saltPtr in
                passcodeData.withUnsafeBytes { passcodePtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passcodePtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passcodeData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        Self.iterations,
                        derivedKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Self.keyLength
                    )
                }
            }
        }

        return derivedKey
    }

    /// Constant-time comparison to prevent timing attacks
    private func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }

        var result: UInt8 = 0
        for (byte1, byte2) in zip(a, b) {
            result |= byte1 ^ byte2
        }

        return result == 0
    }
}

// MARK: - Lockout Management
extension PasscodeManager {

    /// Maximum number of failed attempts before lockout
    private static let maxAttempts = 5

    /// Lockout duration in seconds (5 minutes)
    private static let lockoutDuration: TimeInterval = 300

    /// Record a failed passcode attempt
    /// - Returns: Number of remaining attempts, or nil if locked out
    func recordFailedAttempt() -> Int? {
        let currentAttempts = getFailedAttempts() + 1

        if currentAttempts >= Self.maxAttempts {
            setLockout()
            return nil
        }

        setFailedAttempts(currentAttempts)
        return Self.maxAttempts - currentAttempts
    }

    /// Reset failed attempts counter (call after successful auth)
    func resetFailedAttempts() {
        try? keychain.delete(forKey: KeychainManager.Keys.failedAttempts)
    }

    /// Check if currently locked out
    var isLockedOut: Bool {
        guard let endTime = keychain.loadDate(forKey: KeychainManager.Keys.lockoutEndTime) else {
            return false
        }

        if endTime > Date() {
            return true
        }

        // Lockout expired, clean up
        clearLockout()
        return false
    }

    /// Get lockout end time
    var lockoutEndTime: Date? {
        guard isLockedOut else { return nil }
        return keychain.loadDate(forKey: KeychainManager.Keys.lockoutEndTime)
    }

    /// Get remaining lockout time as formatted string
    var lockoutTimeRemaining: String {
        guard let endTime = lockoutEndTime else { return "" }

        let remaining = endTime.timeIntervalSinceNow
        if remaining <= 0 { return "" }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Clear lockout state
    func clearLockout() {
        try? keychain.delete(forKey: KeychainManager.Keys.lockoutEndTime)
        try? keychain.delete(forKey: KeychainManager.Keys.failedAttempts)
    }

    // MARK: - Private Lockout Helpers

    private func getFailedAttempts() -> Int {
        guard let data = keychain.loadOptional(forKey: KeychainManager.Keys.failedAttempts),
              data.count == MemoryLayout<Int>.size else {
            return 0
        }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }

    private func setFailedAttempts(_ count: Int) {
        var value = count
        let data = Data(bytes: &value, count: MemoryLayout<Int>.size)
        try? keychain.save(data, forKey: KeychainManager.Keys.failedAttempts)
    }

    private func setLockout() {
        let endTime = Date().addingTimeInterval(Self.lockoutDuration)
        try? keychain.saveDate(endTime, forKey: KeychainManager.Keys.lockoutEndTime)
    }
}

// MARK: - Biometric Settings
extension PasscodeManager {

    /// Check if biometric authentication is enabled
    var isBiometricEnabled: Bool {
        get { keychain.loadBool(forKey: KeychainManager.Keys.biometricEnabled) }
        set { try? keychain.saveBool(newValue, forKey: KeychainManager.Keys.biometricEnabled) }
    }
}
