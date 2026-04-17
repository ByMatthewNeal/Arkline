# Arkline Security Audit Report

**Date:** April 16, 2026
**Scope:** iOS app (~21K lines), Supabase backend (edge functions, migrations, RLS), third-party integrations
**Methodology:** Static code review of all surfaces listed in the threat model

---

## Executive Summary

The app has solid foundations — Keychain-based passcode storage with PBKDF2 (600K iterations), dual-layer SSL pinning, no service_role key in the client, proper ATS configuration, and all Claude API calls routed server-side. However, three issues need immediate attention before App Store submission: **(1)** `Secrets.plist` ships as a plaintext file inside the IPA, exposing every paid API key (CoinGecko, FMP, Finnhub, etc.) to anyone who unzips the binary; **(2)** the Supabase profiles UPDATE policy allows any authenticated user to self-assign `role = 'admin'` or `subscription_status = 'active'`, bypassing both the paywall and admin controls; **(3)** the cron secret `arkline-cron-2026` is hardcoded in the iOS binary, allowing anyone to invoke all cron-protected edge functions.

---

## Critical Findings

### C1. Secrets.plist Ships as Plaintext in the IPA
**Severity:** Critical
**Location:** `ArkLine/Secrets.plist` (bundled via Copy Bundle Resources in `project.pbxproj` line 339)

**Description:** `Secrets.plist` is included in the Xcode "Copy Bundle Resources" build phase. The file ships unencrypted inside the `.ipa`. Anyone can download the app, unzip it, and read every key in plain text:

| Key | Risk | Cost Exposure |
|-----|------|---------------|
| `COINGECKO_API_KEY` | Billable | $35/mo plan |
| `FMP_API_KEY` | Billable | $29/mo plan |
| `COINGLASS_API_KEY` | Billable | Yes |
| `FINNHUB_API_KEY` | Billable | Yes |
| `TAAPI_API_KEY` | Billable | Yes |
| `REVENUE_CAT_API_KEY` | IAP config | Exposes offerings |
| `COLLECT_TRENDS_SECRET` | Edge function auth | Triggers compute |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Backend access | Within RLS |
| `FRED_API_KEY` | Rate-limited free | Low |

**Impact:** An attacker extracts every key and makes unlimited API calls against paid services, running up your bills. The RevenueCat key exposes IAP configuration.

**Remediation:**
1. Remove `Secrets.plist` from the Copy Bundle Resources build phase
2. For keys that must be on-device (Supabase anon key, RevenueCat), obfuscate them in compiled Swift code
3. Remove the direct fallback in `APIProxy.swift` for all paid APIs — if the proxy is down, show cached data, not direct calls with exposed keys
4. Rotate every key after implementing the fix

---

### C2. Users Can Self-Assign Admin Role and Premium Status
**Severity:** Critical
**Location:** `ArkLine/Database/schema.sql` lines 46-47; RLS UPDATE policy on `profiles`

**Description:** The profiles UPDATE policy is:
```sql
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (auth.uid() = id);
```
This allows a user to update **any column** on their own row, including `role` (to `'admin'`) and `subscription_status` (to `'active'`). A user making direct Supabase API calls can grant themselves full admin access and premium status.

**Impact:** Complete privilege escalation. Admin access grants broadcast creation, member management, market deck generation. Premium status bypasses all subscription billing.

**Remediation:** Add a `WITH CHECK` clause that prevents users from modifying protected columns:
```sql
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (
        role IS NOT DISTINCT FROM (SELECT role FROM profiles WHERE id = auth.uid())
        AND subscription_status IS NOT DISTINCT FROM (SELECT subscription_status FROM profiles WHERE id = auth.uid())
        AND trial_end IS NOT DISTINCT FROM (SELECT trial_end FROM profiles WHERE id = auth.uid())
    );
```

---

### C3. Cron Secret Hardcoded in iOS Binary
**Severity:** Critical
**Location:**
- `ArkLine/Data/Services/API/MarketUpdateDeckService.swift` line 56
- `supabase/functions/compute-model-portfolios/index.ts` line 11
- 20+ migration SQL files in `supabase/migrations/`

**Description:** The cron secret `arkline-cron-2026` is a string literal in the iOS binary, an edge function, and committed SQL migrations. It protects all 15+ cron-triggered edge functions.

**Evidence:**
```swift
// MarketUpdateDeckService.swift:56
request.setValue("arkline-cron-2026", forHTTPHeaderField: "x-cron-secret")
```

**Impact:** An attacker can invoke fibonacci-pipeline, compute-positioning-signals, generate-market-deck, sync-crypto-prices, compute-model-portfolios, and every other cron function at will — causing compute costs and potentially manipulating data.

**Remediation:**
1. Remove the cron secret from the iOS client entirely — use admin JWT auth for admin-initiated operations
2. Replace the hardcoded value in `compute-model-portfolios` with `Deno.env.get("CRON_SECRET")`
3. Rotate the cron secret to a new cryptographically random value
4. Remove the query parameter fallback in `compute-model-portfolios` (line 475)

---

## High-Priority Findings

### H1. API Proxy Direct Fallback Exposes Keys
**Severity:** High
**Location:** `ArkLine/Data/Network/APIProxy.swift` lines 91-142, 256-274

**Description:** When the proxy is unavailable (no auth session, circuit breaker open), the app falls back to direct HTTP calls using the bundled API keys. Four services put keys in URL query parameters during fallback:

| Service | Parameter | Line |
|---------|-----------|------|
| FRED | `api_key` | 103 |
| Metals API | `access_key` | 109 |
| Taapi.io | `secret` | 115 |
| FMP | `apikey` | 121 |

**Impact:** Keys in query params are logged by proxies, CDNs, and server access logs. The fallback also means every paid key must be bundled in the binary.

**Remediation:** Remove the direct fallback for paid APIs. Fail gracefully with cached data or a "service unavailable" message.

---

### H2. No Server-Side Enforcement of Premium on Data Tables
**Severity:** High
**Location:** `supabase/migrations/20260306000002_create_fibonacci_tables.sql` line 165; `supabase/migrations/20260318000001_create_positioning_signals.sql` line 28

**Description:** RLS SELECT policies on premium data tables (`trade_signals`, `positioning_signals`, `ohlc_candles`, `fib_levels`, etc.) allow any authenticated user to read all rows:
```sql
CREATE POLICY "Authenticated users can read trade_signals"
  ON public.trade_signals FOR SELECT
  USING (auth.role() = 'authenticated');
```
No premium status check.

**Impact:** Even with a working client-side paywall, a user with a free account can query all premium data directly via the Supabase REST API.

**Remediation:** Add `AND public.is_premium_user()` to SELECT policies on premium tables, or implement a tiered approach (e.g., free users see only BTC signals).

---

### H3. `briefing-tts` Edge Function Has No Authentication
**Severity:** High
**Location:** `supabase/functions/briefing-tts/index.ts`

**Description:** This function accepts any POST request with `briefingKey` and `summaryText`. No JWT verification, no cron secret, no rate limiting. It calls the OpenAI TTS API and uploads audio to Supabase Storage with `upsert: true`.

**Impact:** Anyone who discovers the endpoint can generate arbitrary TTS audio at your expense (OpenAI billing), overwrite cached audio files with arbitrary content, and generate signed URLs.

**Remediation:** Add JWT verification or cron secret check. If only called server-to-server from `market-summary`, use cron secret auth.

---

### H4. No App Switcher Snapshot Protection
**Severity:** High
**Location:** `ArkLine/App/ArkLineApp.swift` lines 54-62

**Description:** When the app enters background/inactive state, there is no overlay to obscure the UI before iOS takes its app switcher snapshot. The app shows portfolio values, trade signals, and leverage positions.

**Impact:** Anyone who can see the device's app switcher sees the user's financial data without authenticating.

**Remediation:**
```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .inactive || newPhase == .background {
        showPrivacyOverlay = true
    } else if newPhase == .active {
        showPrivacyOverlay = false
    }
}
```
Overlay with the app logo or a blur view.

---

## Medium-Priority Findings

### M1. Account Enumeration via Email Existence Check
**Severity:** Medium
**Location:** `ArkLine/Features/Onboarding/ViewModels/OnboardingViewModel.swift` lines 352-355

**Description:** Returning user flow queries the profiles table and shows "No account found with this email" if the email doesn't exist.

**Impact:** Enables enumeration of which emails have accounts — useful for phishing/credential stuffing.

**Remediation:** Show a generic message: "If an account exists, we'll send a verification code." Send the OTP regardless.

---

### M2. Incomplete Data Cleanup on Sign-Out
**Severity:** Medium
**Location:** `ArkLine/App/ArkLineApp.swift` lines 517-534

**Description:** Sign-out clears `APICache` and `URLCache` but does NOT clear:
- `currentUser` in UserDefaults (email, username, role, subscription status)
- File-based caches (RiskDataCache, StockPriceStore, ConfidenceTracker, etc.)
- Voice recordings in Documents directory
- `leverageWalletSize` in UserDefaults
- FavoritesStore data

**Impact:** Previous user's PII and financial data persist on device after sign-out.

**Remediation:** On full sign-out, clear file caches, user-specific UserDefaults keys, and voice recordings. On account deletion, also call `KeychainManager.shared.clearAll()`.

---

### M3. Wallet Size Stored in UserDefaults
**Severity:** Medium
**Location:** `ArkLine/Core/Utilities/Constants.swift` line 157

**Description:** `leverageWalletSize` (the user's trading capital) is stored in plain UserDefaults — unencrypted plist on disk.

**Remediation:** Move to Keychain via `KeychainManager`.

---

### M4. StoreKit 2 Purchase Verification Incomplete
**Severity:** Medium
**Location:** `ArkLine/Features/Settings/Views/PaywallView.swift` lines 692-710

**Description:** The StoreKit 2 direct purchase path checks `result == .success` but discards the `VerificationResult<Transaction>` without verifying the JWS signature or calling `transaction.finish()`.

**Remediation:**
```swift
case .success(let verification):
    guard case .verified(let transaction) = verification else {
        errorMessage = "Purchase verification failed."
        return
    }
    await transaction.finish()
    await SubscriptionService.shared.refreshStatus()
```

---

### M5. Unsanitized Admin Feedback in Claude Prompts
**Severity:** Medium
**Location:** `supabase/functions/generate-market-deck/index.ts` lines 853, 919, 978

**Description:** `slide_feedback` and `feedbackHistory` from admins are interpolated directly into Claude prompts without sanitization. The `market-summary` function sanitizes its feedback (lines 129-132), but `generate-market-deck` does not.

**Impact:** A compromised admin account could inject prompt instructions to manipulate published market deck content.

**Remediation:** Apply the same sanitization patterns from `market-summary` to all feedback text in `generate-market-deck`.

---

### M6. Tables Potentially Missing RLS
**Severity:** Medium
**Location:** `ArkLine/Data/Supabase/SupabaseClient.swift` — `SupabaseTable` enum references tables not found in any migration with `ENABLE ROW LEVEL SECURITY`

**Description:** Tables including `analytics_events`, `daily_active_users`, `sentiment_history`, `google_trends_history`, `market_data_cache`, `market_snapshots`, `portfolio_history`, and others may not have RLS enabled. They may have been created via the Supabase dashboard.

**Impact:** Without RLS, the anon key grants unrestricted read/write access to these tables.

**Remediation:** Run `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public'` on production and enable RLS on every table.

---

### M7. SSRF Protection Incomplete in article-summary
**Severity:** Medium
**Location:** `supabase/functions/article-summary/index.ts` lines 148-163

**Description:** The SSRF check blocks private IPs by hostname prefix but misses IPv6 addresses (`::1`, `fc00::`), doesn't handle DNS rebinding, doesn't re-validate redirect targets, and over-blocks the entire `172.x.x.x` range instead of just `172.16.0.0/12`.

**Remediation:** Add IPv6 checks, validate final redirect URL hostname, use proper CIDR range checking.

---

### M8. RevenueCat Never Initialized
**Severity:** Medium
**Location:** `ArkLine/App/ArkLineApp.swift` — `SubscriptionService.shared.configure()` never called

**Description:** RevenueCat SDK is a dependency but `configure()` is never invoked at app launch, and `login(userId:)` is never called after auth. `isPro` is hardcoded to `true` (intentional for invite-only phase), but when the paywall is activated, RevenueCat won't work without initialization.

**Remediation:** Before activating the paywall, add `SubscriptionService.shared.configure()` to `ArkLineApp.onAppear` and `login(userId:)` after authentication.

---

## Low-Priority / Hardening Suggestions

### L1. No Screenshot Detection
**Location:** No screenshot-related code found

For a financial app with proprietary trade signals, consider detecting screenshots (`UIApplication.userDidTakeScreenshotNotification`) and screen recording (`UIScreen.capturedDidChangeNotification`). At minimum, log to analytics. For premium content, consider watermarking with user ID.

---

### L2. Keychain Persists Across Reinstalls
**Location:** `ArkLine/Core/Utilities/KeychainManager.swift`

iOS Keychain items survive app reinstalls. A user who reinstalls could be prompted for a passcode from a previous install. Add a "fresh install" marker in UserDefaults (which IS cleared on reinstall) — if absent on launch, call `KeychainManager.shared.clearAll()`.

---

### L3. OpenAI API Key Partially Logged
**Location:** `supabase/functions/briefing-tts/index.ts` line 54

First 7 and last 4 characters of the OpenAI key are logged. Change to a boolean: `console.log("OPENAI_API_KEY present: true")`.

---

### L4. Unpinned Edge Function Dependencies
**Location:** All edge functions import `@supabase/supabase-js@2` and `stripe@17` without exact versions

Pin to exact versions (e.g., `@supabase/supabase-js@2.49.1`, `stripe@17.5.0`) to prevent automatically pulling in a broken or malicious minor release.

---

### L5. SSL Pinning Coverage Gap
**Location:** `ArkLine/Data/Network/SSLPinningConfiguration.swift` lines 28-39

Runtime SPKI pinning only covers Binance. OS-level `NSPinnedDomains` covers Supabase and Arkline but not CoinGecko or FMP. Consider adding `NSPinnedDomains` entries for the highest-traffic third-party APIs.

---

### L6. Trial Expiration Not Enforced Client-Side
**Location:** `ArkLine/Domain/Models/User.swift` lines 348-359

`User.isAccessGranted` checks `subscriptionStatus == .trialing` but doesn't verify `trialEnd > Date()`. Add: `(subscriptionStatus == .trialing && (trialEnd ?? .distantFuture) > Date())`.

---

### L7. URLSession.shared Bypasses SSL Pinning in Some Calls
**Location:** `APIEndpoint.swift` lines 598, 655; `APITechnicalAnalysisService.swift` line 170; `MarketUpdateDeckService.swift` line 58; `SwingSetupsViewModel.swift` line 127; `SignalDetailView.swift` line 269

Six call sites use `URLSession.shared` instead of `PinnedURLSession.shared`, bypassing cert pinning.

**Remediation:** Replace with `PinnedURLSession.shared`.

---

## What I Verified Is Secure

| Surface | Status | Notes |
|---------|--------|-------|
| **No service_role key in iOS code** | Pass | Only anon key used client-side |
| **Passcode hashing** | Pass | PBKDF2, 600K iterations, SHA256-HMAC, random salt, constant-time comparison, Keychain storage |
| **Keychain implementation** | Pass | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, proper service scoping |
| **ATS configuration** | Pass | No `NSAllowsArbitraryLoads`, no domain exceptions, HTTPS everywhere |
| **SSL pinning (Supabase, Binance, Arkline)** | Pass | Dual-layer: OS-level NSPinnedDomains + runtime SPKI verification |
| **No raw SQL** | Pass | All DB ops use Supabase SDK query builder |
| **No eval/dynamic code execution** | Pass | Zero instances of eval, NSExpression, JSContext |
| **No WebViews** | Pass | No WKWebView or UIWebView |
| **Claude API calls server-side only** | Pass | All 5 Claude-calling functions are edge functions, zero direct calls from iOS |
| **No user PII sent to Claude** | Pass | Prompts contain only market data, prices, signals — no emails, names, or portfolio data |
| **No user PII sent to third-party APIs** | Pass | All third-party calls send only market symbols and date ranges |
| **API proxy authentication** | Pass | Verifies JWT via `getUser()`, validates paths against traversal |
| **Admin edge functions** | Pass | All verify JWT + check `role === 'admin'` from profiles table |
| **Stripe webhook** | Pass | Proper signature verification via `constructEventAsync` |
| **Deep link input validation** | Pass | Invite codes validated with regex, broadcast IDs validated as UUID |
| **Form input validation** | Pass | Email, username, feature request — all have regex/length validation |
| **Secrets.plist not in git** | Pass | `.gitignore` covers it, only `.example` file tracked |
| **Analytics consent gating** | Pass | Custom first-party analytics, gated behind explicit consent |
| **PrivacyInfo.xcprivacy** | Pass | Complete and accurate declaration of collected data types |
| **No force unwraps** | Pass | One instance on a compile-time constant URL, properly safe |
| **Secure deserialization** | Pass | All API responses decoded via typed Decodable models |
| **Session handling** | Pass | Supabase SDK auto-refresh, OTP-based auth (no session fixation risk) |
| **Dependencies** | Pass | Only 3 direct deps (Supabase SDK, Kingfisher, RevenueCat), all actively maintained, no known CVEs |

---

## Out of Scope / Needs Human Review

| Item | Why |
|------|-----|
| **Supabase dashboard settings** | RLS may be enabled/disabled at the dashboard level independently of migrations. Run `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public'` to verify. |
| **Supabase Storage bucket policies** | The `briefing-audio` bucket permissions should be reviewed in the dashboard — `briefing-tts` uploads with `upsert: true`. |
| **Render backend** | Not present in this repo. If scheduled jobs run there, they need separate audit. |
| **Stripe dashboard configuration** | Webhook endpoint URLs, signing secret rotation, and product/price configuration are dashboard-level. |
| **RevenueCat dashboard** | Entitlement configuration, offering setup, and sandbox vs. production keys. |
| **Apple App Store Connect** | In-app purchase configuration, sandbox testing accounts. |
| **DNS/domain security** | DNSSEC, CAA records for arkline.io — affects cert pinning resilience. |
| **Supabase Edge Function environment variables** | Verify all secrets are set correctly in the Supabase dashboard (CRON_SECRET, OPENAI_API_KEY, ANTHROPIC_API_KEY, etc.). |

---

## Priority Remediation Order

| Priority | Finding | Effort |
|----------|---------|--------|
| 1 | **C2** — RLS: block self-assign of role/subscription_status | 1 migration |
| 2 | **C1** — Remove Secrets.plist from bundle, obfuscate on-device keys | Half day |
| 3 | **C3** — Remove cron secret from iOS, rotate it | 1-2 hours |
| 4 | **H1** — Remove API proxy direct fallback for paid APIs | 2-3 hours |
| 5 | **H3** — Add auth to briefing-tts | 30 min |
| 6 | **H4** — Add app switcher privacy overlay | 1 hour |
| 7 | **H2** — Add premium check to RLS on signal tables | 1 migration |
| 8 | **M1** — Fix account enumeration | 15 min |
| 9 | **M2** — Expand sign-out cleanup | 1-2 hours |
| 10 | **M6** — Verify RLS on all tables in production | 30 min |
