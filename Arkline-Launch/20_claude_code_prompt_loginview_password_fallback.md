# Claude Code Prompt — LoginView Password Fallback (App Review Critical)

Copy everything below the `---` line and paste into Claude Code as a single prompt. This unblocks Apple App Review by ensuring the reviewer can always sign in via email + password, even if their cached session is cleared.

---

# Task

`LoginView` (the "Welcome back" screen shown to returning users with a cached profile) currently only offers Face ID and Passcode as sign-in methods. There is **no way to sign in as a different account** from this screen. Once the previously-signed-in user's session is cached, a different user — including Apple's App Review tester if their session somehow clears — is stuck at this screen with no path forward.

This is a blocking issue for App Review. The reviewer must always be able to sign in via the credentials in App Store Connect's review notes (`reviewer@arkline.io` + password). Currently they cannot if they ever hit this screen with a different cached user.

Add a "Sign in with a different account" affordance on `LoginView` that opens a sheet with email + password fields. On successful auth, the cached state of any previously-signed-in user is cleared so the new user gets a clean session.

## Files involved

- **Modify:** `ArkLine/Features/Authentication/Views/LoginView.swift` — add the affordance and the sheet presentation.
- **Modify:** `ArkLine/Features/Authentication/ViewModels/AuthViewModel.swift` — add `signInWithPassword(email:password:)` method.
- **New file:** `ArkLine/Features/Authentication/Views/EmailPasswordSignInSheet.swift` — the sheet UI.
- **No changes to:** `OnboardingViewModel` / `SignInView` (those handle the new-user flow, which is separate).

## Existing infrastructure to use

- `SupabaseAuthManager.shared.signIn(email:password:)` — exists at `ArkLine/Data/Supabase/SupabaseAuth.swift:62`. Returns `Auth.Session`, throws mapped `AuthError`. Same method used by the onboarding `SignInView.signInWithPassword()`.
- `SupabaseDatabase.shared.getProfile(userId:)` — fetches the profile after auth.
- `AppError.from(error).userMessage` — error mapping pattern used throughout the auth flow.
- `Haptics.success()`, `Haptics.error()`, `Haptics.light()` — haptic patterns.
- `CustomTextField`, `OnboardingContainer`, `OnboardingHeader`, `OnboardingBottomActions` — existing reusable components. Use `CustomTextField` directly for the sheet; the Onboarding components are too coupled to that flow. The sheet should look more like a standard iOS sign-in sheet than an onboarding step.
- `Constants.UserDefaults.currentUser` — key for the cached User JSON.
- `KeychainManager` (or equivalent) — used for the passcode hash. Grep to find the exact API.
- `AppColors`, `AppFonts`, `ArkSpacing` — design tokens.

## Behavioral spec

### On `LoginView` (returning-user "Welcome back" screen)

Below the existing Face ID + Passcode buttons (currently around lines 94-104), add a smaller, more subdued affordance:

```swift
Button {
    showPasswordSignIn = true
} label: {
    Text("Sign in with a different account")
        .font(AppFonts.body14Medium)
        .foregroundColor(AppColors.accent)
        .underline(false)
}
.padding(.top, ArkSpacing.lg)
```

This sits visually subordinate to the biometric and passcode buttons (cached user is the primary path; switching accounts is the escape hatch) but is unambiguously discoverable. No icon needed.

Add `@State private var showPasswordSignIn = false` near the existing `@State` declarations, and present the sheet:

```swift
.sheet(isPresented: $showPasswordSignIn) {
    EmailPasswordSignInSheet(viewModel: viewModel)
}
```

### `EmailPasswordSignInSheet`

New view, presented modally. Structure:

- Drag indicator at top (standard iOS sheet behavior).
- Header: "Sign in" (left-aligned, large title style — `AppFonts.title30` or similar).
- Subhead: "Enter your email and password to switch accounts."
- Two `CustomTextField` rows: Email, Password (with `isSecure: true`).
- Error message below the password field, in `AppColors.error` if `viewModel.passwordSignInError` is non-nil.
- Primary button: "Sign In", calling `Task { await viewModel.signInWithPassword(...) }`. Disabled if email or password is empty, shows loading spinner when in flight.
- Cancel button (top-right of nav bar, or as a text button) — dismisses the sheet.
- Auto-focus the email field on appearance.

Visual style: clean, native iOS sheet. Match the calm aesthetic of `SubscriptionExpiredView` rather than the marketing-heavy onboarding screens.

### `AuthViewModel.signInWithPassword(email:password:)`

New method. Async, throws via state changes (not async throws — match the existing biometric pattern):

```swift
@MainActor
func signInWithPassword(email: String, password: String) async {
    guard !email.isEmpty, !password.isEmpty else { return }

    passwordSignInError = nil
    isPasswordSignInLoading = true
    defer { isPasswordSignInLoading = false }

    do {
        let session = try await SupabaseAuthManager.shared.signIn(email: email, password: password)
        let newUserId = session.user.id

        // If signing in as a different user than the cached one,
        // clear stale local state so the new user gets a clean session.
        clearCachedSessionDataIfDifferentUser(newUserId: newUserId)

        // Fetch the new user's profile
        guard let profile = try await SupabaseDatabase.shared.getProfile(userId: newUserId) else {
            throw AuthError.profileNotFound  // or appropriate existing error
        }

        // Build the User object from the profile (match SignInView's pattern)
        let newUser = User(/* fields from profile */)

        self.user = newUser
        self.authState = .authenticated
        self.isAuthenticated = true   // This triggers AuthenticationCoordinator's onChange
        Haptics.success()
    } catch {
        passwordSignInError = AppError.from(error).userMessage
        authState = .unauthenticated
        Haptics.error()
    }
}

private func clearCachedSessionDataIfDifferentUser(newUserId: UUID) {
    // Only wipe local state if a different user is signing in.
    // Same user signing in via password (e.g. forgot passcode) keeps their
    // existing passcode hash and Face ID setting.
    let cachedUserData = UserDefaults.standard.data(forKey: Constants.UserDefaults.currentUser)
    if let data = cachedUserData,
       let cached = try? JSONDecoder().decode(User.self, from: data),
       cached.id != newUserId {
        // Different user — clear the previous user's local state
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.currentUser)
        // Clear passcode hash from Keychain (whatever the actual API is)
        KeychainManager.shared.clearPasscodeHash()   // adapt if the actual API is different
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.faceIDEnabled)
        logInfo("Cleared cached state from previous user before switching accounts", category: .auth)
    }
    // Same user (or no cached user) — leave state intact
}
```

Add the supporting properties:

```swift
var passwordSignInError: String?
var isPasswordSignInLoading: Bool = false
```

### Wiring into the existing flow

The `AuthenticationCoordinator` in `ContentView.swift` already has the right `onChange(of: viewModel.isAuthenticated)` handler:

```swift
.onChange(of: viewModel.isAuthenticated) { _, isAuthenticated in
    if isAuthenticated {
        appState.setAuthenticated(true, user: viewModel.user ?? appState.currentUser)
        Task { await appState.refreshUserProfile() }
    }
}
```

This automatically picks up the new user when `signInWithPassword` succeeds. **No changes to `ContentView` or `AuthenticationCoordinator` should be needed.** Verify this in your implementation.

### After successful sign-in

`isAuthenticated = true` → AuthenticationCoordinator routes the user. If the user has access (`isAccessGranted`), they land in MainTabView. If they're in setup (`.none` status, ~just-signed-up), they land in `AccountSetupView`. If their subscription is canceled+expired, they land in `SubscriptionExpiredView`. This is correct existing behavior — don't override it.

## Out of scope (do NOT do)

- **Do not** add an "Email code fallback" link in the sheet (like SignInView has). Apple reviewers need password sign-in specifically; email code requires inbox access they don't have.
- **Do not** add "Forgot password?" recovery in this prompt. Add as a future task.
- **Do not** modify `OnboardingViewModel.signInWithPassword()` or `SignInView`. Those handle a different surface (onboarding, never-signed-in users) and should remain independent.
- **Do not** auto-sign-out the cached user when the sheet appears. The clear-cached-state-on-different-user logic happens only on *successful* auth of a different user, not on sheet presentation. (If user opens sheet, types an email, then cancels — cached user remains intact.)
- **Do not** change biometric or passcode flows on `LoginView`. They stay as the primary paths.
- **Do not** add this affordance to the Welcome screen (the cold-start, never-signed-in flow). The existing `OnboardingCoordinator → WelcomeView → SignInView` path already handles password sign-in for fresh users.
- **Do not** rebuild `AuthViewModel` from scratch. Add the new method and properties without touching biometric / passcode logic.

## Test plan

1. **Same-user smoke test:** Sign in as user A. Sign out. On the LoginView, tap "Sign in with a different account", enter user A's email + password. Should succeed and land in MainTabView. **Verify:** passcode hash NOT cleared (the user can still use Face ID / passcode on next sign-in).

2. **Different-user switch test:** Sign in as user A (your admin account). Sign out. On the LoginView, tap "Sign in with a different account", enter user B's credentials (the reviewer account or a test user). Should:
   - Successfully authenticate
   - Clear user A's cached profile from UserDefaults
   - Clear user A's passcode hash from Keychain
   - Clear user A's Face ID setting
   - Land in MainTabView as user B with user B's data
   - Force-quit and reopen the app: passcode/Face ID buttons should NOT be visible (since user B hasn't set them up yet) — LoginView should be different, or it should route to AccountSetupView depending on user B's subscription state.

3. **Bad credentials test:** Tap "Sign in with a different account", enter a wrong password. Should show an error message ("Invalid login credentials" or similar) and NOT clear any state.

4. **Cancel test:** Tap "Sign in with a different account", type partial credentials, tap Cancel. Sheet dismisses, cached user state is intact, no auth state changed.

5. **App Review simulation:** Use `reviewer@arkline.io` + their password (the one set in Supabase Auth dashboard). Should land in MainTabView with the demo data. This is the path Apple's reviewer will actually take.

Take screenshots of:
- The LoginView showing the new affordance
- The presented sheet
- The error state when wrong password is entered

## Reporting

When done:

1. Files created/modified with line ranges.
2. Confirmation that `signInWithPassword` correctly clears different-user cached state via UserDefaults + Keychain (specify exact APIs used).
3. Confirmation that `AuthenticationCoordinator` was not modified (existing onChange handles new auth).
4. Screenshots of: (a) LoginView with new affordance, (b) the sheet, (c) the success and error states.
5. Any unexpected friction (e.g., if `KeychainManager.shared.clearPasscodeHash()` doesn't exist by that exact name, what you used instead).

Keep the report under 250 words.
