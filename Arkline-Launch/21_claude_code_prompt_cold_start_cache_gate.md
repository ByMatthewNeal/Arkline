# Claude Code Prompt — Cold-Start Cached-Status Bypass Fix

Copy everything below the `---` line and paste into Claude Code as a single prompt. This fixes the cold-start security gap flagged in the pre-ship audit.

---

# Task

On every cold app launch, `ContentView` currently shows the splash screen for exactly 2 seconds, then routes to `mainContent` based on the **cached** user state from UserDefaults. A separate background task refreshes the user profile from Supabase, but that refresh happens in parallel — it doesn't gate the routing decision.

This creates a 3–5 second window every cold start where a user with stale cached state can access content their current real state doesn't permit. Most concerning case: a user whose subscription was canceled while the app was closed gets ~3–5 seconds of `MainTabView` access on every relaunch before the refresh completes and re-routes them to the lockout. An offline canceled user retains access indefinitely.

The fix: extend the splash to wait for the first profile refresh to complete (or time out at 5 seconds for offline users) before evaluating gates. The result is that every cold-start routing decision is based on either fresh data or a deliberate offline fallback — never on potentially-stale cache alone.

## Files involved

- **Modify:** `ArkLine/App/ContentView.swift` — replace `.onAppear` with `.task` and gate splash dismissal on first refresh.
- **Modify (minor):** `ArkLine/App/ArkLineApp.swift` — remove the duplicate `await appState.refreshUserProfile()` from the WindowGroup `.onAppear` block, since ContentView now owns that responsibility. Leave the other setup calls (notifications, analytics, crash reporting) untouched.
- **No new files.**
- **No changes to:** `AppState`, gate logic in `mainContent`, `isAccessGranted`, `isInAccountSetup`, `refreshUserProfile()` itself. The fix is purely in *when* and *whether* `refreshUserProfile()` is awaited before routing.

## Existing infrastructure to use

- `appState.refreshUserProfile()` — already exists, already async. Returns silently on error (logs internally). Safe to call when unauthenticated (early-returns).
- `appState.isAuthenticated` — used to decide whether to await refresh. If false, no cached session to verify; skip the wait.
- `DataPrefetcher.start()` — already called in `.onAppear`. Keep it; it's pre-fetching market data, unrelated to the auth gate.
- `withTimeout(seconds:operation:)` — utility used elsewhere (e.g., inside `refreshUserProfile` itself around line 588). Use it here for the 5s cap.

## Implementation

### ContentView changes

Replace the current `.onAppear` block with a `.task` modifier and break the startup sequence into a clear async function:

```swift
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    private let minSplashDuration: TimeInterval = 2.0
    private let maxRefreshWait: TimeInterval = 5.0

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .toastContainer()
        .animation(.easeInOut(duration: 0.5), value: showSplash)
        .task {
            await runStartupSequence()
        }
    }

    private func runStartupSequence() async {
        // Kick off market-data prefetch immediately (doesn't gate the splash)
        DataPrefetcher.start()

        let startTime = Date()

        // If there's a cached authenticated session, refresh it BEFORE routing.
        // This prevents a user with stale cached state (e.g. recently canceled
        // subscription) from getting brief access on cold start.
        if appState.isAuthenticated {
            _ = try? await withTimeout(seconds: maxRefreshWait) {
                await appState.refreshUserProfile()
            }
        }

        // Maintain minimum splash duration for UX continuity
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < minSplashDuration {
            try? await Task.sleep(for: .seconds(minSplashDuration - elapsed))
        }

        await MainActor.run {
            withAnimation {
                showSplash = false
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        // Unchanged — keep the existing gate ordering exactly as-is
    }
}
```

### ArkLineApp changes

In `ArkLine/App/ArkLineApp.swift`, find the `.onAppear` block on the `ContentView()` inside the `WindowGroup` (currently around line 26–35). The block currently looks roughly like:

```swift
.onAppear {
    setupAppearance()
    setupNotifications()
    migrateNotificationKeys()
    CrashReportingService.shared.register()
    Task {
        await appState.refreshUserProfile()
        await BroadcastNotificationService.shared.syncDeviceTokenIfNeeded()
        await AnalyticsService.shared.trackAppOpen()
    }
}
```

Remove **only** the `await appState.refreshUserProfile()` line — ContentView's new `.task` owns the gating refresh. Keep everything else. The new shape:

```swift
.onAppear {
    setupAppearance()
    setupNotifications()
    migrateNotificationKeys()
    CrashReportingService.shared.register()
    Task {
        await BroadcastNotificationService.shared.syncDeviceTokenIfNeeded()
        await AnalyticsService.shared.trackAppOpen()
    }
}
```

This avoids a redundant refresh call and centralizes auth-state-gating logic in ContentView where it belongs.

### Important: scenePhase resume is NOT affected

The existing `.onChange(of: scenePhase)` handler in `ArkLineApp.swift` that calls `appState.refreshUserProfileCancellable()` on `.active` should remain **completely unchanged**. That handler covers the background→foreground refresh case (which we tested as Scenario 6 of the subscription enforcement test plan). Cold-start gating is a separate concern, handled exclusively in ContentView's `.task`.

## Behavioral outcomes

| User state on cold start | Old behavior | New behavior |
|---|---|---|
| Unauthenticated | 2s splash → onboarding/login | 2s splash → onboarding/login *(unchanged)* |
| Authenticated, active sub, online | 2s splash → MainTabView, refresh happens in background | 2s splash → refresh completes (~200-500ms) → MainTabView |
| Authenticated, canceled+expired, online | 2s splash → MainTabView for 3-5s → re-routes to SubscriptionExpiredView | 2s splash → refresh completes → SubscriptionExpiredView immediately |
| Authenticated, canceled+expired, offline | 2s splash → MainTabView indefinitely | 2s + up to 5s splash → MainTabView (cached state used after timeout — see trade-off) |

### Trade-off acknowledged

The offline-canceled case still gets access after the 5s timeout (refresh fails, cached state is used). This is intentional: the alternative is to lock out *any* user with a flaky network during cold start, which would be worse UX for the vast majority of legitimate users. The audit's main concern was the always-reproducible 3-5s window on every cold start, which this fix fully eliminates. The offline edge case is mitigated by the foreground-refresh handler — the moment the user has network, the next foreground transition will catch the stale state.

If future requirements demand stricter offline behavior, the right place to add it is in `mainContent` (e.g., a `"⚠️ Offline mode"` banner overlay), not the splash gate.

## Out of scope (do NOT do)

- **Do not** change the gates in `mainContent`. The new fix is only about *when* mainContent evaluates; the gates themselves (`isInAccountSetup` → `isAccessGranted` → MainTabView) stay correct as-is.
- **Do not** add a "Verifying session…" intermediate state between splash and mainContent. The splash IS the verification UI — adding another transient state would feel laggy. The splash already runs for at least 2s; the refresh fits inside that window in the happy path.
- **Do not** modify `refreshUserProfile()` itself. Its internal timeout is 10s (for slow Supabase responses); the new outer 5s splash timeout is independent and looser.
- **Do not** add the `hasCompletedInitialRefresh` property to AppState. The dismissal logic is contained in ContentView's `.task` — no shared state needed.
- **Do not** force a re-auth or sign-out on refresh failure. Cached state is the correct fallback for transient network issues.
- **Do not** call `refreshUserProfile()` if `appState.isAuthenticated` is false. Wasteful and the function early-returns anyway, but more importantly: unauthenticated users have no cached state to verify.

## Test plan

1. **Happy path — active subscriber, online:** Cold-start the app while signed in with an active subscription. Splash shows for ~2s (refresh completes well within that). Lands in MainTabView. No visible "stutter" or re-routing.

2. **Stale-cache canceled case:** While signed in, run this SQL to simulate a backend-side cancellation:
   ```sql
   update profiles
   set subscription_status = 'canceled',
       current_period_end = now() - interval '1 day'
   where email = 'YOUR_TEST_EMAIL';
   ```
   Force-quit the app (don't background — full kill via simulator menu or swipe-up). Cold start.
   - **Old behavior:** ~3s of MainTabView access, then re-routes to SubscriptionExpiredView.
   - **New behavior:** Splash → SubscriptionExpiredView directly. No MainTabView flash.

3. **Offline timeout:** Enable airplane mode on the simulator (Hardware → Network Link Conditioner: 100% loss, or simulator-specific airplane mode). Cold-start while signed in.
   - Splash should hold for ~5s (the timeout) then proceed with cached state.
   - User lands in whatever their cached state warrants (likely MainTabView). Not ideal, but acceptable — once network returns and the user backgrounds/foregrounds, the existing `scenePhase == .active` handler catches up.

4. **Unauthenticated cold start:** Delete and reinstall the app. Cold start. Splash should hide at exactly 2s (no refresh wait). User lands on the welcome/onboarding flow.

5. **Regression smoke test:** Run the existing 6-scenario subscription enforcement plan mentally — all should still work identically. Specifically the foreground-refresh case (Scenario 6) is independent of this fix.

## Reporting

When done:

1. Files modified with line ranges.
2. Confirmation that `runStartupSequence` correctly awaits refresh only when authenticated.
3. Confirmation that `ArkLineApp.swift`'s onAppear no longer has the duplicate `refreshUserProfile` call.
4. Build status.
5. Any unexpected friction (e.g., if `withTimeout(seconds:operation:)` is named differently in the codebase).

Keep the report under 200 words.
