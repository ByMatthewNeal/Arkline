# Claude Code Prompt — Account Setup Loading State (Stripe Webhook Race Fix)

Copy everything below the `---` line and paste into Claude Code as a single prompt. This fixes the **highest-impact bug in the pre-ship audit**: new paying users who sign in before the Stripe webhook fires are currently shown `SubscriptionExpiredView` ("Your ArkLine membership has ended") on their very first login. This prompt replaces that with a friendly polling loading state.

---

# Task

Fix the new-user lockout race condition. Right now:

1. User completes Stripe checkout on web → gets invite code via email.
2. User downloads ArkLine, signs up with invite code → profile created in Supabase with `subscription_status = 'none'` (default).
3. Stripe webhook fires asynchronously (typically 2–30 seconds later) → updates profile to `subscription_status = 'active'`.
4. Between steps 2 and 3, the user is signed in but their `isAccessGranted` returns false because `subscription_status == .none`.
5. `ContentView` routes them to `SubscriptionExpiredView` with the message **"Your ArkLine membership has ended"** — a terrible first impression for a user who literally just paid.

The fix: introduce an "account setup" loading state for users in this transient `.none` window, with auto-polling so the app moves them into the main app the moment the webhook fires. After a 2-minute timeout, switch to a friendly recovery view ("contact support") rather than the lockout. Critically: **the existing subscription-enforcement gate stays exactly as-is** for canceled/expired users — this is a new branch, not a weakening of any existing logic.

## Files involved

- **Modify:** `ArkLine/Domain/Models/User.swift` — add `isInAccountSetup` computed property.
- **Modify:** `ArkLine/App/ContentView.swift` — insert the new branch in `mainContent` before the existing `isAccessGranted` check.
- **New file:** `ArkLine/Features/Subscription/Views/AccountSetupView.swift` — the loading + recovery view.
- **No changes to:**
  - `SubscriptionExpiredView.swift` (stays for genuine canceled/expired cases)
  - `isAccessGranted` logic (stays strict — webhook-confirmed access only)
  - `AppState.refreshUserProfile()` (already does what we need)
  - `ArkLineApp.swift` (scenePhase refresh already wired)

## Existing infrastructure to use (don't reinvent)

- `User.createdAt: Date` — already present, used to define the "just signed up" window.
- `User.subscriptionStatus: SubscriptionStatus` — `.none` is the trigger state.
- `User.role: UserRole` — `.admin` must always bypass this view (your admin/reviewer accounts should never see it).
- `AppState.refreshUserProfile()` — async profile fetch; calling this updates `appState.currentUser` and triggers ContentView re-evaluation automatically via SwiftUI's `@Observable` chain.
- `AppState.setAuthenticated(false, user: nil)` — used for the "Sign Out" recovery action.
- `SupabaseAuthManager.shared.signOut()` — for full auth cleanup.
- `MeshGradientBackground` — use for consistent app background.
- `ArkSpacing`, `AppColors`, `AppFonts` — design tokens.

## The state machine

Add a single new computed property to `User`:

```swift
/// True when the user is mid-account-setup — paid via Stripe, signed in,
/// but the webhook hasn't yet updated their subscription_status to active.
/// This is a transient state that should resolve within seconds in the
/// happy path, but can stick if the webhook fails entirely.
///
/// Admins always bypass (no setup needed). Users with any non-.none status
/// have already been webhook-confirmed and route via normal isAccessGranted.
var isInAccountSetup: Bool {
    role != .admin && subscriptionStatus == .none
}
```

Note: there's **no time check inside `isInAccountSetup`**. A user in `.none` always lands in `AccountSetupView`. The "loading vs recovery" decision happens *inside* that view based on how long the polling has been running. This keeps the state machine simple — `.none` is always "account setup," whether webhook is en route or genuinely failed.

## ContentView update

In `ArkLine/App/ContentView.swift`, update `mainContent` (currently routing through `isOnboarded → isAuthenticated → isAccessGranted → MainTabView`):

```swift
@ViewBuilder
private var mainContent: some View {
    if !appState.isOnboarded {
        OnboardingCoordinator()
    } else if !appState.isAuthenticated {
        AuthenticationCoordinator()
    } else if let user = appState.currentUser, user.isInAccountSetup {
        AccountSetupView()              // NEW — webhook hasn't fired yet, OR genuinely failed
    } else if let user = appState.currentUser, !user.isAccessGranted {
        SubscriptionExpiredView()       // existing — canceled/expired (Apple 3.1.2 grace already honored)
    } else {
        MainTabView()
    }
}
```

The new branch is **inserted between** `isAuthenticated` and `isAccessGranted`. This ordering matters: setup-state takes priority over the lockout, because a `.none` user could be either (a) just-signed-up (legitimate, needs setup view) or (b) genuinely never-paid (also setup view but with recovery copy — see below). Neither case should hit the harsh lockout.

## `AccountSetupView` spec

Create new file at `ArkLine/Features/Subscription/Views/AccountSetupView.swift`. Full-screen takeover with two internal states: **loading** (initial) and **recovery** (after timeout).

### Visual structure

- `MeshGradientBackground` behind everything (matches `SubscriptionExpiredView`).
- Centered VStack: icon → headline → body → button(s).
- No nav bar.
- `@EnvironmentObject var appState: AppState`.

### Loading state (first ~2 minutes)

- **Icon:** large `progress.indicator` or a custom rotating ArkLine-logo loader at ~40pt. Calm, not anxious.
- **Headline:** "Setting up your account…"
- **Body:** "This usually takes a few seconds. We're confirming your payment with Stripe."
- **No primary button.** The user just waits.
- **Tertiary footer link:** "Having trouble? Contact support@arkline.io" → `mailto:support@arkline.io?subject=ArkLine%20account%20setup`.

### Recovery state (after timeout, ~2 minutes)

- **Icon:** `exclamationmark.circle` at ~40pt, color `AppColors.warning` (amber, not red — this is "let's get this sorted," not "you're banned").
- **Headline:** "We're having trouble setting up your account"
- **Body:** "Don't worry — your payment went through. Email support@arkline.io and we'll get you in within a few hours."
- **Primary button:** "Email support" → mailto with prefilled subject and body containing the user's email so support can look them up. Subject: "Account setup help — [user.email]". Body: "Hi Arkline team, my account isn't activating. My signup email is [user.email]. Thanks."
- **Secondary button:** "Try Again" — resets `attemptCount` to 0, switches back to loading state, restarts polling.
- **Tertiary link below buttons:** "Sign Out" — calls `SupabaseAuthManager.shared.signOut()` then `appState.setAuthenticated(false, user: nil)`. Drops them back to the welcome flow.

### Polling logic

Inside `AccountSetupView`:

```swift
struct AccountSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var attemptCount: Int = 0
    @State private var hasTimedOut: Bool = false

    private let pollInterval: Duration = .seconds(3)
    private let maxAttempts: Int = 40   // ~2 minutes

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if hasTimedOut {
                recoveryView
            } else {
                loadingView
            }
        }
        .task(id: hasTimedOut) {
            guard !hasTimedOut else { return }
            await pollUntilResolved()
        }
    }

    private func pollUntilResolved() async {
        // First refresh immediately on appearance (covers the case where
        // the user opened the app after webhook already fired but cached
        // profile is stale).
        await appState.refreshUserProfile()

        // If the refresh resolved it, ContentView will re-route us out of
        // this view before this Task gets to its next iteration.
        while attemptCount < maxAttempts && !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            attemptCount += 1
            await appState.refreshUserProfile()

            // No need to manually check state here — if the profile updated,
            // SwiftUI re-evaluates ContentView, this view unmounts, and the
            // Task is cancelled automatically.
        }

        if !Task.isCancelled {
            hasTimedOut = true
        }
    }

    private var loadingView: some View {
        // Implementation as spec'd above
    }

    private var recoveryView: some View {
        // Implementation as spec'd above
    }
}
```

**Important:** the polling Task is automatically cancelled when the view unmounts (which happens when `currentUser.subscriptionStatus` flips to `.active` and ContentView re-routes). No manual lifecycle wiring needed beyond what's shown.

### "Try Again" handler

Resets state:

```swift
Button("Try Again") {
    attemptCount = 0
    hasTimedOut = false   // Triggers task(id:) re-evaluation, restarts polling
}
```

### Haptics

Trigger `Haptics.warning()` once on appearance of the recovery view (not on the loading view — that would be alarmist for what should be a smooth few-second wait). Trigger `Haptics.light()` on entering the loading state.

## Out of scope (do NOT do)

- **Do not modify `isAccessGranted`** — it must stay strict (webhook-confirmed only). The setup view is a *separate* gate before isAccessGranted is even consulted.
- **Do not modify `SubscriptionExpiredView`** — it remains correct for genuine canceled/expired states.
- **Do not add a time check to `isInAccountSetup`** — the time logic lives in the view, not the model. A user in `.none` is always in setup; whether we show them loading or recovery is a UI concern.
- **Do not add an admin override for the setup view** — `isInAccountSetup` already returns false for admins (the `role != .admin` clause).
- **Do not weaken any other gate.** No "if recent signup, grant access" shortcuts. The user must wait for the webhook to fire — but in a friendly loading state.
- **Do not poll more aggressively than 3 seconds.** Stripe webhooks usually fire within 2-10 seconds; 3-second polling catches the happy path quickly without hammering Supabase.
- **Do not add a "Skip setup" button** to the loading view. There's no skip — we genuinely need the webhook to confirm payment before granting access.

## Test plan

You can't easily simulate the webhook race in dev. Instead, simulate the state directly via Supabase SQL:

### Test 1 — Loading state

Run on a test account (not your admin, not the reviewer):

```sql
update profiles
set subscription_status = 'none',
    current_period_end = null,
    created_at = now()
where email = 'YOUR_TEST_EMAIL';
```

Sign in as that user. **Expected:** lands on `AccountSetupView` loading state. Spinner visible, "Setting up your account…" copy.

Now simulate the webhook firing (5 seconds in):

```sql
update profiles
set subscription_status = 'active',
    current_period_end = now() + interval '1 year'
where email = 'YOUR_TEST_EMAIL';
```

**Expected:** within ~3 seconds (the next poll tick), the view transitions to `MainTabView`. Smooth handoff, no jarring screen change.

### Test 2 — Recovery state

Set the test user back to `.none`:

```sql
update profiles
set subscription_status = 'none',
    current_period_end = null
where email = 'YOUR_TEST_EMAIL';
```

Sign in. Wait ~2 minutes without touching anything. **Expected:** loading state transitions to recovery state. Warning icon, "We're having trouble..." copy, Email Support / Try Again / Sign Out buttons visible.

Tap **Email Support** — verify mailto opens with prefilled subject including the user's email.

Tap **Try Again** — verify it returns to loading state and resumes polling.

Tap **Sign Out** — verify it drops to the welcome/login flow.

### Test 3 — Admin bypass

Sign in as your admin account (with any subscription status). **Expected:** never sees `AccountSetupView`. Goes straight to MainTabView.

### Test 4 — Regression smoke test

Run the existing 6-scenario subscription enforcement test plan from `09_claude_code_prompt_subscription_enforcement.md` — all six must still pass identically. Specifically:
- Canceled + expired → `SubscriptionExpiredView` (unchanged behavior)
- Canceled + period not yet ended → MainTabView with banner (unchanged)
- Active → MainTabView (unchanged)
- Past-due grace → MainTabView with banner (unchanged)
- Live foreground refresh → still works

## Reporting

When done:

1. List of files created/modified with line ranges.
2. Whether you used `Image(systemName:)` SF Symbols or a custom loader/animation for the loading state — and what you chose.
3. Verification that the polling Task properly cancels when the view unmounts (no leaked background task after the user transitions to MainTabView).
4. Screenshot of the loading state and recovery state.
5. Confirmation that the existing 6-scenario subscription enforcement tests still pass logically (don't need to re-run all 6 manually — just verify the code paths still route correctly).

Keep the report under 250 words.
