import XCTest
@testable import ArkLine

// MARK: - Mock Passcode Verifier

private class MockPasscodeVerifier: PasscodeVerifying {
    var verifyResult = false
    var recordFailedAttemptResult: Int? = 4
    var isLockedOutValue = false
    var lockoutTimeRemainingValue = ""
    var isBiometricEnabledValue = false
    var lockoutEndTimeValue: Date? = nil
    var storedPasscodeLengthValue = 6
    var resetFailedAttemptsCalled = false

    func verify(_ passcode: String) -> Bool { verifyResult }

    func resetFailedAttempts() {
        resetFailedAttemptsCalled = true
    }

    func recordFailedAttempt() -> Int? { recordFailedAttemptResult }

    var isLockedOut: Bool { isLockedOutValue }
    var lockoutTimeRemaining: String { lockoutTimeRemainingValue }
    var isBiometricEnabled: Bool { isBiometricEnabledValue }
    var lockoutEndTime: Date? { lockoutEndTimeValue }
    var storedPasscodeLength: Int { storedPasscodeLengthValue }
}

// MARK: - AuthViewModel Tests

final class AuthViewModelTests: XCTestCase {

    // MARK: - Passcode Verification

    func testVerifyPasscode_correct_setsAuthenticated() async {
        let mock = MockPasscodeVerifier()
        mock.verifyResult = true
        let vm = AuthViewModel(passcodeManager: mock)
        vm.passcode = "1234"

        vm.verifyPasscode()

        // verifyPasscode() fires a Task with 100ms delay — wait generously
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.authState, .authenticated, "Should be authenticated on correct passcode")
        XCTAssertTrue(vm.isAuthenticated, "isAuthenticated should be true")
        XCTAssertNil(vm.errorMessage, "No error on success")
        XCTAssertTrue(mock.resetFailedAttemptsCalled, "Should reset failed attempts on success")
    }

    func testVerifyPasscode_incorrect_setsFailedState() async {
        let mock = MockPasscodeVerifier()
        mock.verifyResult = false
        mock.recordFailedAttemptResult = 4
        let vm = AuthViewModel(passcodeManager: mock)
        vm.passcode = "9999"

        vm.verifyPasscode()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.authState, .failed("Incorrect passcode"), "Should show failed state")
        XCTAssertFalse(vm.isAuthenticated, "Should not be authenticated")
        XCTAssertTrue(vm.errorMessage?.contains("4 attempts remaining") ?? false,
                      "Error should mention remaining attempts, got: \(vm.errorMessage ?? "nil")")
        XCTAssertEqual(vm.passcode, "", "Passcode should be cleared on failure")
    }

    func testVerifyPasscode_lockedOut_showsLockMessage() {
        let mock = MockPasscodeVerifier()
        mock.isLockedOutValue = true
        mock.lockoutTimeRemainingValue = "4:30"
        let vm = AuthViewModel(passcodeManager: mock)
        vm.passcode = "1234"

        vm.verifyPasscode()

        // Lockout check is synchronous — no need to wait
        XCTAssertTrue(vm.errorMessage?.contains("Too many attempts") ?? false,
                      "Should show lockout message, got: \(vm.errorMessage ?? "nil")")
        XCTAssertNotEqual(vm.authState, .authenticating, "Should not enter authenticating state when locked")
    }

    func testVerifyPasscode_triggersLockout() async {
        let mock = MockPasscodeVerifier()
        mock.verifyResult = false
        mock.recordFailedAttemptResult = nil // nil signals lockout
        let vm = AuthViewModel(passcodeManager: mock)
        vm.passcode = "9999"

        vm.verifyPasscode()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(vm.errorMessage?.contains("5 minutes") ?? false,
                      "Should show lockout duration, got: \(vm.errorMessage ?? "nil")")
        XCTAssertEqual(vm.authState, .failed("Account locked"), "Should show account locked state")
    }

    // MARK: - State Management

    func testResetPasscode_clearsState() {
        let mock = MockPasscodeVerifier()
        let vm = AuthViewModel(passcodeManager: mock)
        vm.passcode = "1234"
        vm.errorMessage = "Some error"
        vm.authState = .failed("test")

        vm.resetPasscode()

        XCTAssertEqual(vm.passcode, "", "Passcode should be cleared")
        XCTAssertNil(vm.errorMessage, "Error should be cleared")
        XCTAssertEqual(vm.authState, .idle, "State should be idle")
    }

    func testLogout_clearsAuthentication() {
        let mock = MockPasscodeVerifier()
        let vm = AuthViewModel(passcodeManager: mock)
        vm.isAuthenticated = true
        vm.passcode = "1234"

        vm.logout()

        XCTAssertFalse(vm.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(vm.user, "User should be nil after logout")
        XCTAssertEqual(vm.passcode, "", "Passcode should be cleared")
        XCTAssertEqual(vm.authState, .idle, "State should be idle")
    }

    func testRemainingAttempts_defaultsToFive() {
        let mock = MockPasscodeVerifier()
        let vm = AuthViewModel(passcodeManager: mock)

        // In test environment, Keychain has no failed attempts, so remaining = 5
        XCTAssertEqual(vm.remainingAttempts, 5, "Fresh VM should have 5 remaining attempts")
    }

    func testShowFaceID_loadedFromPasscodeManager() {
        let mock = MockPasscodeVerifier()
        mock.isBiometricEnabledValue = true
        let vm = AuthViewModel(passcodeManager: mock)

        XCTAssertTrue(vm.showFaceID, "showFaceID should reflect passcodeManager.isBiometricEnabled")

        let mock2 = MockPasscodeVerifier()
        mock2.isBiometricEnabledValue = false
        let vm2 = AuthViewModel(passcodeManager: mock2)

        XCTAssertFalse(vm2.showFaceID, "showFaceID should be false when biometrics disabled")
    }
}
