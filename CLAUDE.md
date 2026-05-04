# Arkline Project Context

## Project Overview

Arkline is an iOS financial app (iOS 17+/macOS 14+) built with SwiftUI and Swift 5.9. It provides cryptocurrency and traditional market tracking, portfolio management, DCA reminders, and AI-powered chat.

## Business Model

**TL;DR: Invite-only, web-paid, single-tier. The iOS app is a client to a paid service — it does NOT collect payments.**

- **Access model:** Invite-only. Every user must enter a valid invite code (format: `ARK-XXXXXX`) during onboarding.
- **Pricing:** Single subscription tier. Every paying user gets full access — no free tier, no premium tier, no feature gating.
- **Payment processing:** Stripe (web only, never in-app).
- **Signup flow:**
  1. Prospective user receives an invite code + a unique Stripe checkout link
  2. User completes payment on the web via Stripe
  3. User downloads the iOS app
  4. User enters invite code → email verification → profile setup → in
- **No In-App Purchase (IAP):** The app contains zero StoreKit / IAP code. This is intentional — Apple's 30% commission is avoided by handling all payments off-platform.
- **Compliance posture:** Architecture mirrors Spotify / Notion / 1Password ("reader app" / SaaS client model). Apple permits this so long as no in-app payment UI exists and no anti-steering language is shown.

**Important architectural rules to preserve this model:**

- **NEVER add StoreKit, SKProduct, Product.purchase, Transaction, or any IAP-related code** to the iOS app. It would void the entire model and require Apple's 30% cut.
- **NEVER add a sign-up flow inside the iOS app** — sign-up is web-only via Stripe checkout. The app has sign-in only.
- **NEVER add in-app pricing displays, "Upgrade" buttons, or links to external payment pages** — Apple's anti-steering rules still apply.
- **`isPro` is hardcoded to `true` for all authenticated users.** Do not introduce tier-based feature gating without an explicit business decision (would require restructuring everything from User model onward).
- **`User.role` includes `.premium` and `subscriptionStatus` has multiple states** — these exist for future flexibility but are NOT currently used to restrict features. Treat as forward-compatible scaffolding only.

## Legal Entity

The product is operated by **Arkline Technologies LLC** (Wyoming-formed single-member LLC, EIN issued May 2026, physically operated from New York, NY). Detailed entity / EIN / banking info is in `memory/business-info.md` (gitignored).

## Tech Stack

- **UI:** SwiftUI with @Observable macro
- **Architecture:** MVVM with Protocol-based services
- **Backend:** Supabase (Auth, PostgreSQL, Storage)
- **Dependencies:** Supabase Swift SDK, Kingfisher
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
