# Claude Code Prompt — Add Password Sign-In to Onboarding

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

Add password-based sign-in to the Arkline iOS app's onboarding flow. Currently the "I already have an account" path uses email OTP only, which breaks Apple App Review because reviewers can't access the demo account's email inbox to retrieve the OTP code.

This is launch-blocking. The goal is for a fresh-install user to be able to:

1. Open the app
2. Tap "I already have an account" on the Welcome screen
3. Enter email + password
4. Land directly in `MainTabView` (skipping all 11 onboarding profile steps)

The OTP path stays as a fallback ("Use email code instead" link), but password is the primary path for returning users.

## Background and bug context

While planning this change I discovered an existing bug: `OnboardingViewModel.isReturningUser` is set to `true` in `skipToLogin()` (line 289) but is **never actually read anywhere downstream**. That means returning users who currently sign in via OTP get pushed through all 11 onboarding steps (`.username` → `.investmentInterests` → `.careerInfo` → etc.) as if they were new users, which would clobber their existing profile data.

So the new password sign-in path **must** short-circuit straight to `MainTabView` after successful auth — not advance through onboarding steps. The cleanest way is to call the existing pattern: set `viewModel.createdUser` and `viewModel.isOnboardingComplete = true`. The existing `onChange(of: viewModel.isOnboardingComplete)` in `OnboardingCoordinator` (ContentView.swift:55-61) already handles setting both `isOnboarded` and `isAuthenticated` correctly.

The legacy OTP path's similar bug (returning users via OTP get pushed through profile setup) is **out of scope** for this task — separate v1.1 fix. App Review will use password.

## Files involved

- `ArkLine/Features/Onboarding/ViewModels/OnboardingViewModel.swift` — add `.signIn` step, `password` property, `signInWithPassword()` method
- `ArkLine/Features/Onboarding/Views/SignInView.swift` — **new file**, password sign-in UI
- `ArkLine/App/ContentView.swift` — add `.signIn` case to `OnboardingFlowView` switch
- `ArkLine/Features/Onboarding/Views/WelcomeView.swift` — no change needed (already calls `skipToLogin()`)

## Existing infrastructure to use (don't reinvent)

- `SupabaseAuthManager.shared.signIn(email:password:)` — exists at `ArkLine/Data/Supabase/SupabaseAuth.swift:62`. Returns `Auth.Session`, throws mapped `AuthError`.
- `SupabaseDatabase.shared.getProfile(userId:)` — fetches profile row from DB, used in `completeOnboarding()` at OnboardingViewModel.swift:540.
- `OnboardingContainer`, `OnboardingHeader`, `OnboardingBottomActions`, `CustomTextField` — existing reusable view components used throughout onboarding screens. Match the style of `EnterEmailView.swift` exactly.
- `ArkSpacing`, `AppColors`, `AppFonts` — design tokens. **Do not hardcode** colors, fonts, or spacing values.
- `Haptics.success()`, `Haptics.error()`, `Haptics.light()` — haptic feedback patterns used elsewhere in this flow.
- `AppError.from(error).userMessage` — error mapping pattern used throughout `OnboardingViewModel`.

## Implementation steps

### 1. Update `OnboardingStep` enum

In `OnboardingViewModel.swift` (top of file, lines 3–86):

- Add `case signIn` as a new case in the enum. Insert it right after `case welcome` (before `case inviteCode`) so the ordering reflects user flow.
- Add `.signIn` to the `gateSteps` static set (line 20) so it's excluded from "Step X of 11" progress tracking. Returning users don't see a step counter.
- Add `title` case: `case .signIn: return "Sign In"`
- Add `category` case: `case .signIn: return .intro` (group with welcome/inviteCode since it's a gate step)
- `isSkippable` should default to false for `.signIn` (no change needed if you let the switch fall through, but verify).

### 2. Add password state + sign-in logic to `OnboardingViewModel`

In `OnboardingViewModel.swift`:

- Add a published property near the other auth fields (around line 285):
  ```swift
  var password: String = ""
  ```
- Add a computed property for validation:
  ```swift
  var isPasswordValid: Bool {
      password.count >= 8
  }
  ```
- Modify `skipToLogin()` (currently at lines 287–291) to route to the new `.signIn` step instead of `.email`:
  ```swift
  func skipToLogin() {
      isMovingForward = true
      isReturningUser = true
      currentStep = .signIn
  }
  ```
- Add a new function `useEmailCodeFallback()` that the SignInView's "Use email code instead" link calls — switches to the existing OTP flow:
  ```swift
  func useEmailCodeFallback() {
      isMovingForward = true
      currentStep = .email
  }
  ```
- Add the password sign-in method. Match the style of `verifyCode()` (line 363) and `completeOnboarding()` (line 455). Place it near `verifyCode()`:

  ```swift
  func signInWithPassword() async {
      guard isEmailValid else {
          errorMessage = "Please enter a valid email"
          return
      }
      guard isPasswordValid else {
          errorMessage = "Password must be at least 8 characters"
          return
      }

      isLoading = true
      errorMessage = nil

      do {
          // Authenticate
          _ = try await SupabaseAuthManager.shared.signIn(email: email, password: password)

          guard let userId = SupabaseAuthManager.shared.currentUserId else {
              throw AppError.authenticationRequired
          }

          // Fetch existing profile from DB
          guard let profile = try await SupabaseDatabase.shared.getProfile(userId: userId) else {
              errorMessage = "Account found but profile is missing. Please contact support."
              isLoading = false
              return
          }

          // Construct User from existing profile data
          var user = User(
              id: userId,
              username: profile.username ?? email.components(separatedBy: "@").first ?? "user",
              email: email,
              fullName: profile.fullName,
              faceIdEnabled: false
          )
          if let role = profile.role {
              user.role = UserRole(rawValue: role) ?? .user
          }
          if let subStatus = profile.subscriptionStatus {
              user.subscriptionStatus = SubscriptionStatus(rawValue: subStatus) ?? .none
          }
          user.trialEnd = profile.trialEnd

          createdUser = user
          Haptics.success()
          isOnboardingComplete = true
      } catch {
          errorMessage = AppError.from(error).userMessage
          Haptics.error()
      }

      isLoading = false
  }
  ```

  **Note on the profile fetch:** verify the actual return type / field names of `SupabaseDatabase.shared.getProfile(userId:)` by reading its definition. The exact fields (`username`, `fullName`, `role`, `subscriptionStatus`, `trialEnd`) may have different names — adjust to whatever the function actually returns. The pattern I'm modeling is from lines 540–548 of `completeOnboarding()`.

### 3. Create `SignInView.swift`

New file at `ArkLine/Features/Onboarding/Views/SignInView.swift`. Match the visual style of `EnterEmailView.swift` exactly — same `OnboardingContainer`, `OnboardingHeader`, `OnboardingBottomActions`, `CustomTextField`, padding tokens.

Requirements:

- Header icon: `lock.circle.fill` (or `person.circle.fill`)
- Header title: `"Welcome back"`
- Header subtitle: `"Sign in with your email and password"`
- Email field: `CustomTextField` with `.emailAddress` keyboard, `.emailAddress` textContentType, `.never` autocapitalization, bound to `viewModel.email`
- Password field: `CustomTextField` with `isSecure: true` (or equivalent — check existing CustomTextField API for secure entry support; if it doesn't have secure entry, use `SecureField` styled to match)
- Password field bound to `viewModel.password`
- Below password field: a small inline link "Use email code instead" that calls `viewModel.useEmailCodeFallback()`. Style as `AppFonts.body14Medium` color `AppColors.fillPrimary` or similar — match the style of the "I already have an account" link in `WelcomeView.swift` (line 71–75).
- Bottom action: `OnboardingBottomActions` with primaryTitle `"Sign In"`, primaryAction `Task { await viewModel.signInWithPassword() }`, `isLoading: viewModel.isLoading`, `isDisabled: !viewModel.isEmailValid || !viewModel.isPasswordValid`, errorMessage binding.
- Use `@FocusState` to auto-focus the email field on appear (match `EnterEmailView.swift:62`).
- Add the standard `.onboardingBackButton { viewModel.previousStep() }` modifier.
- Include a `#Preview` block matching the pattern in `EnterEmailView.swift:67–73`.

### 4. Wire `.signIn` into `OnboardingFlowView`

In `ArkLine/App/ContentView.swift`, the `OnboardingFlowView` switch statement (around lines 96–124) routes each `OnboardingStep` to its view. Add:

```swift
case .signIn:
    SignInView(viewModel: viewModel)
```

Place it right after `case .welcome:` for logical ordering.

## Testing

After implementation:

1. Run `xcodebuild -scheme ArkLine -destination 'platform=iOS Simulator,name=iPhone 15' build` — verify clean build.
2. If there's an existing test target, run the relevant subset to confirm no regressions: `xcodebuild test -scheme ArkLine -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ArkLineTests/OnboardingViewModelTests` (if such a test exists — otherwise skip).
3. Launch on simulator. Fresh-install (delete app first if needed).
4. From Welcome screen, tap "I already have an account" → confirm new `SignInView` appears (NOT the email OTP screen, NOT the "Step X of 11" progress indicator).
5. Enter test credentials:
   - Email: `reviewer@arkline.io`
   - Password: `Reviewer2026!`
6. Tap Sign In → confirm lands directly on `MainTabView` (Home tab), no profile setup steps in between.
7. Tap "Use email code instead" link → confirm it switches to the email OTP screen.
8. Test error path: bad password → confirm error message displays, no crash.

## Code conventions to follow

- `@Observable` macro pattern is used for ViewModels (see existing code).
- Use `async`/`await`; no completion handlers.
- All user-facing strings should be inline (no localization file at this stage).
- No force-unwraps. Use `guard let` / nil-coalescing.
- Match indentation (4 spaces) and brace style of surrounding code.
- Add `// MARK: -` comments for new sections in `OnboardingViewModel` (look at existing MARK comments for style).
- Don't add new dependencies. Use only what's already imported.

## Out of scope (do not change)

- Don't touch the OTP code path (`sendVerificationCode`, `verifyCode`).
- Don't refactor the new-user onboarding flow.
- Don't change passcode logic — fresh-install returning users will need to deal with passcode setup separately, but that's not blocking this task.
- Don't add a "forgot password" flow.
- Don't add password reset UI.
- Don't change `SupabaseAuthManager` or `SupabaseDatabase`.

## When done

Reply with:
1. Confirmation that the build passed.
2. Any deviations from this spec (and why).
3. Any TODOs you noticed but didn't fix (e.g., the OTP-returning-user bug — leave it, just note it).
