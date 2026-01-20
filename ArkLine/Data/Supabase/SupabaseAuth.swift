import Foundation
import Supabase
import Auth

// MARK: - Supabase Auth Manager
@MainActor
@Observable
final class SupabaseAuthManager {
    // MARK: - Singleton
    static let shared = SupabaseAuthManager()

    // MARK: - Properties
    private(set) var currentAuthUser: Auth.User?
    private(set) var currentSession: Auth.Session?
    private(set) var isAuthenticated = false
    private(set) var isLoading = false

    private let auth: AuthClient

    // MARK: - Init
    private init() {
        auth = SupabaseManager.shared.auth
        Task {
            await checkSession()
        }
    }

    // MARK: - Session Management
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentSession = try await auth.session
            currentAuthUser = currentSession?.user
            isAuthenticated = currentSession != nil
        } catch {
            logError(error, context: "Check Session", category: .auth)
            isAuthenticated = false
        }
    }

    // MARK: - Sign Up with Email
    func signUp(email: String, password: String) async throws -> Auth.User {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await auth.signUp(email: email, password: password)
            currentAuthUser = response.user
            return response.user
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Sign In with Email
    func signIn(email: String, password: String) async throws -> Auth.Session {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await auth.signIn(email: email, password: password)
            self.currentSession = session
            self.currentAuthUser = session.user
            self.isAuthenticated = true
            return session
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Sign In with OTP (Magic Link)
    func signInWithOTP(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.signInWithOTP(email: email)
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Verify OTP
    func verifyOTP(email: String, token: String) async throws -> Auth.Session {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await auth.verifyOTP(email: email, token: token, type: .email)
            self.currentSession = response.session
            self.currentAuthUser = response.user
            self.isAuthenticated = true
            guard let session = response.session else {
                throw AppError.unknown(message: "No session returned")
            }
            return session
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Sign Out
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.signOut()
            self.currentSession = nil
            self.currentAuthUser = nil
            self.isAuthenticated = false
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Reset Password
    func resetPassword(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.resetPasswordForEmail(email)
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Update User
    func updateUser(email: String? = nil, password: String? = nil, data: [String: AnyJSON]? = nil) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let attributes = UserAttributes(
                email: email,
                password: password,
                data: data
            )
            let user = try await auth.update(user: attributes)
            self.currentAuthUser = user
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Get Current User ID
    var currentUserId: UUID? {
        currentAuthUser?.id
    }

    // MARK: - Get Access Token
    var accessToken: String? {
        currentSession?.accessToken
    }

    // MARK: - Error Mapping
    private func mapAuthError(_ error: AuthError) -> AppError {
        // Map to generic errors since specific cases may vary by SDK version
        return .supabaseError(message: error.localizedDescription)
    }
}

// MARK: - Auth State Listener
extension SupabaseAuthManager {
    func startAuthStateListener() {
        Task {
            for await (event, session) in auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedIn:
                        self.currentSession = session
                        self.currentAuthUser = session?.user
                        self.isAuthenticated = true
                    case .signedOut:
                        self.currentSession = nil
                        self.currentAuthUser = nil
                        self.isAuthenticated = false
                    case .tokenRefreshed:
                        self.currentSession = session
                    case .userUpdated:
                        self.currentAuthUser = session?.user
                    default:
                        break
                    }

                    NotificationCenter.default.post(name: Constants.Notifications.authStateChanged, object: nil)
                }
            }
        }
    }
}
