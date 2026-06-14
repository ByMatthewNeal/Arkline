# Claude Code Prompt — Sweep `URLSession.shared` → `PinnedURLSession.shared`

Copy everything below the `---` line and paste into Claude Code as a single prompt. Last item from the pre-ship audit. Small, mechanical, safe.

---

# Task

Replace all remaining call sites that use `URLSession.shared` with `PinnedURLSession.shared` so that future pin additions automatically extend to all network requests. The audit identified at least 5 known offenders, but grep the whole codebase to catch anything else that's drifted in.

This change is **safe and low-risk** even though pinning currently only enforces Binance — unpinned domains pass through with standard TLS validation (per `PinnedURLSession.swift`'s file comment). So switching from `URLSession.shared` to `PinnedURLSession.shared` is functionally equivalent today, with the benefit that adding new pins to `SSLPinningConfiguration` later automatically protects these call sites without another sweep.

## Files involved (likely — verify via grep)

- `ArkLine/Features/Market/Views/SignalDetailView.swift` (~line 269)
- `ArkLine/Features/Home/ViewModels/SwingSetupsViewModel.swift` (~line 127)
- `ArkLine/Features/Admin/Views/APIHealthService.swift` (~line 381)
- `ArkLine/Data/Network/APIEndpoint.swift` (~lines 598, 655)
- `ArkLine/Data/Services/BriefingAudioService.swift` (~line 158)

Plus anything else `grep "URLSession.shared"` finds in the `ArkLine/` directory.

## What to do

### 1. Find all call sites

Run a grep for `URLSession.shared` across `/Users/matt/Arkline/ArkLine/`. List every hit — file, line, surrounding context.

**Exclude from scope:**
- Test files (`*Tests.swift`)
- Code inside `PinnedURLSession.swift` itself (obviously)
- Code that legitimately needs `URLSession.shared` for some specific reason (e.g., background URL sessions for downloads — unlikely but check). If you find one, note it in the report and leave it.

### 2. Replace each occurrence

Swap `URLSession.shared` → `PinnedURLSession.shared`. The two have the same `data(for:)`, `data(from:)`, `downloadTask(with:)`, etc. API, so the replacement should be one-token. No surrounding code should need to change.

If you find a call site doing something the `PinnedURLSession.shared` API doesn't support directly (e.g., creating a custom session with delegate-based callbacks), don't force the change — note it and leave as-is.

### 3. Verify the build

After the sweep, build for iOS Simulator. Build must succeed. No new warnings.

## Out of scope (do NOT do)

- **Do NOT add new pins** to `SSLPinningConfiguration.pinnedDomains`. The audit recommended adding `*.supabase.co` and `api.stripe.com`, but adding pins without a monitoring/rotation strategy creates real operational risk — if the domain rotates its cert without our awareness, the app breaks for all users. This is being explicitly deferred to v1.1 when we can set up cert-expiry monitoring. The pinning sweep itself (this prompt) prepares the codebase so future pin additions are zero-touch.
- Do not refactor `PinnedURLSession` or `SSLPinningConfiguration`. Architecture is sound.
- Do not change the `enforcePinningInDebug` default. Stays `false`.
- Do not modify `NetworkManager`'s usage (it already uses `PinnedURLSession.shared` per the file comment at line 23).
- Do not modify the `APIProxy.swift` direct fallback path (already uses `PinnedURLSession.shared`).

## Test plan

1. **Build succeeds** for iOS Simulator and physical device builds.
2. **Existing pinned domains still work:** open the app, trigger a Binance API call (e.g., view market data that uses Binance ticker). Should succeed — confirms the pinning delegate is still wired correctly.
3. **Newly-swept domains still work:** for each file changed, identify what feature triggers that network call and exercise it. E.g., if `SignalDetailView` was updated, open a signal detail screen and confirm the data loads.
4. **No regression on auth flow:** sign out + sign back in (covers any auth-side URL session usage).

You can't easily test "pinning would now apply if we added a pin" without actually adding a pin — that's intentional. The point of this sweep is to make future pin additions zero-touch.

## Reporting

Briefly:

1. List of files changed with line ranges.
2. Total count of `URLSession.shared` → `PinnedURLSession.shared` replacements.
3. Any call sites you skipped and why (e.g., "BackgroundDownloadService.swift uses a custom URLSessionConfiguration, leaving as-is").
4. Confirmation that the build succeeded and Binance market data still loads correctly.
5. Final `grep "URLSession.shared" .` count (should be near-zero — only test files and `PinnedURLSession.swift` itself should remain).

Keep the report under 200 words.
