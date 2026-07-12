# Arkline Project Context

## Project Overview

Arkline is an iOS financial app (iOS 17+/macOS 14+) built with SwiftUI and Swift 5.9. It provides cryptocurrency and traditional market tracking, portfolio management, DCA reminders, and AI-powered chat.

## Business Model

**TL;DR: Single-tier subscription with dual-track billing — web Stripe checkout AND App Store IAP via RevenueCat. Supabase is the authoritative subscription source of truth.**

> Historical note: the app originally shipped web-paid-only with zero IAP code
> (reader-app model). That changed when RevenueCat + the in-app paywall were
> added. If you see older docs/comments claiming "no IAP code," they are stale.

- **Pricing:** Single subscription tier ("Arkline Pro"). Every paying user gets full access — no free tier, no feature gating.
- **Billing track 1 — Web (Stripe):** Users pay via Stripe checkout on the web. Tracked in Supabase `subscriptions` with `source='stripe'`. These users never touch RevenueCat billing; they simply sign in to the app.
- **Billing track 2 — App Store (IAP via RevenueCat):** Users can purchase in-app through `ArkPaywallSheet` (presented from `WelcomeView` during onboarding and `SubscriptionExpiredView` on lapse). RevenueCat forwards purchase events to the `revenuecat-webhook` Supabase edge function, which writes `source='apple'` rows into `subscriptions`.
- **Source of truth:** The Supabase RPC `is_user_subscribed(uuid)` is the authoritative access gate. `RevenueCatService.isPro` is only a fast local signal for paywall presentation — it reflects IAP customers only, never Stripe customers.
- **RevenueCat wiring:** SDK configured at app launch (`RevenueCatService.configure()`); the Supabase user id is used as the RevenueCat `appUserID` so webhook events attribute to the right account. Entitlement id: `"Arkline Pro"` (see `Constants.RevenueCat`). Settings includes Restore Purchases and IAP-aware subscription management.
- **Invite codes:** The onboarding flow still contains an invite-code step (format: `ARK-XXXXXX`). KNOWN TRANSITIONAL GAP: IAP purchasers are currently routed through the invite-code step too — there is a TODO in `WelcomeView` to conditionalize this and add post-purchase account creation (linking `apple_original_transaction_id` to a Supabase user).

**Important architectural rules for the current model:**

- **IAP code is intentional — do NOT remove it.** `RevenueCatService`, `ArkPaywallSheet`, and the RevenueCat package in `project.yml` are load-bearing. (Older guidance said the opposite; it is obsolete.)
- **Never bypass RevenueCat for IAP** — no raw StoreKit purchase calls. All IAP goes through the RevenueCat SDK so the webhook → Supabase attribution keeps working.
- **Anti-steering still applies to the IAP context:** do not add in-app links or copy steering users to the cheaper web/Stripe checkout. Stripe checkout is reached from the web only.
- **Never collect card details or embed Stripe payment UI in the iOS app.** Stripe remains web-only.
- **`AppState.isPro` is hardcoded to `true` for all authenticated users.** Access is binary (subscribed or not — enforced at auth/subscription level, not per-feature). Do not introduce tier-based feature gating without an explicit business decision.
- **`User.role` includes `.premium` and `subscriptionStatus` has multiple states** — forward-compatible scaffolding, not currently used to restrict features.
- **Do not commit `.p8` keys** (APNs / subscription keys). They are gitignored — keep it that way.

## Legal Entity

The product is operated by **Arkline Technologies LLC** (Wyoming-formed single-member LLC, EIN issued May 2026, physically operated from New York, NY). Detailed entity / EIN / banking info is in `memory/business-info.md` (gitignored).

## Tech Stack

- **UI:** SwiftUI with @Observable macro
- **Architecture:** MVVM with Protocol-based services
- **Backend:** Supabase (Auth, PostgreSQL, Storage)
- **Dependencies:** Supabase Swift SDK, Kingfisher, RevenueCat (IAP)
- **External APIs:** CoinGecko, Alpha Vantage, Claude, FRED, FMP, Taapi.io, and more

## Directory Structure

```
ArkLine/
├── App/                    # Entry point (ArkLineApp.swift, ContentView.swift)
├── Core/
│   ├── Extensions/         # Swift extensions
│   ├── Theme/             # Design system (Colors, Typography, Spacing)
│   └── Utilities/         # Constants, Logger, Cache, Error types
├── Data/
│   ├── Network/           # NetworkManager, APIEndpoint protocol
│   ├── Services/
│   │   ├── API/          # Real API service implementations
│   │   ├── Mock/         # Mock services for development
│   │   └── Protocols/    # Service protocol definitions
│   └── Supabase/         # Supabase client configuration
├── Domain/Models/         # Data models (User, Portfolio, CryptoAsset, etc.)
├── Features/              # Feature modules
│   ├── Authentication/
│   ├── Home/
│   ├── Market/
│   ├── Portfolio/
│   ├── DCAReminder/
│   ├── AIChat/
│   ├── Community/
│   ├── Profile/
│   ├── Settings/
│   └── Onboarding/
└── SharedComponents/      # Reusable UI components
```

## Security & Code Quality Audit (All 12 Items Resolved)

### Critical
1. **Hardcoded API Keys** - Keys loaded from Secrets.plist, backend proxy for sensitive APIs
2. **Weak Passcode Hashing** - PBKDF2 (10k iterations, SHA256-HMAC) via PasscodeManager
3. **Sensitive Data in UserDefaults** - Migrated to Keychain via KeychainManager
4. **Test Coverage** - 396 unit tests across 13 test files

### High
5. **API Keys in URL Query Params** - Moved to HTTP headers
6. **Force Unwraps** - Safe defaults (`safeDate()`, nil coalescing)
7. **SSL Certificate Pinning** - SPKI pinning for Binance domains via PinnedURLSession

### Medium
8. **Debug Print Statements** - Unified logger, only `#if DEBUG` prints remain
9. **API Keys Logged** - All credential logging removed
10. **Large Monolithic Files** - All files under 830 lines (HomeView 4,208→580, PortfolioView 1,406→177)
11. **Input Validation** - URLComponents used throughout
12. **Bypassable Lockout** - Lockout state stored in Keychain

## Coding Standards

### ViewModels
```swift
@Observable
class FeatureViewModel {
    private let service: ServiceProtocol

    var isLoading = false
    var errorMessage: String?

    init() {
        self.service = ServiceContainer.shared.serviceInstance
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // fetch data
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Design Tokens
Always use design system tokens, never hardcode values:
```swift
// Correct
ArkColors.primary(for: colorScheme)
ArkTypography.headline
ArkSpacing.md

// Incorrect
Color(hex: "#3369FF")
Font.system(size: 20)
.padding(16)
```

### Network Calls
Use async/await with proper error handling:
```swift
func fetchData() async throws -> [Model] {
    let endpoint = SomeEndpoint.list
    return try await networkManager.request(endpoint)
}
```

## Sensitive Files

Do not modify without explicit approval:
- `Constants.swift` - Contains API configuration
- `Secrets.plist` - API keys (should not be in git)
- `*.xcodeproj` - Project settings

## Agent Ownership

See `CLAUDE_AGENTS.md` for multi-agent coordination rules and file ownership matrix.
