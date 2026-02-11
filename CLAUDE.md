# Arkline Project Context

## Project Overview

Arkline is an iOS financial app (iOS 17+/macOS 14+) built with SwiftUI and Swift 5.9. It provides cryptocurrency and traditional market tracking, portfolio management, DCA reminders, and AI-powered chat.

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

## Known Issues (Audit Findings)

### Critical Security Issues (All Resolved)

1. ~~**Hardcoded API Keys**~~ - Fixed: keys loaded only from Secrets.plist
2. ~~**Weak Passcode Hashing**~~ - Fixed: PBKDF2 (10k iterations, SHA256-HMAC) in PasscodeManager
3. ~~**UserDefaults for Auth Data**~~ - Fixed: migrated to Keychain via KeychainManager

### Open Issues

1. ~~**Force Unwraps**~~ - Fixed: AssetRiskConfig already uses safe `safeDate()`, remaining production unwrap in Broadcast.swift fixed
2. ~~**No Tests**~~ - Fixed: 247 unit tests across 7 test files (extensions, statistics, risk, DCA, performance)
3. **Large Files** - `HomeView.swift` (4,208 lines) needs decomposition
4. **Unimplemented Services** - `APIDCAService`, `APIPortfolioService` throw `.notImplemented`
5. ~~**Bypassable Lockout**~~ - Fixed: lockout state stored in Keychain (persists across reinstalls)
5. ~~**No SSL Certificate Pinning**~~ - Fixed: NSPinnedDomains in Info.plist for supabase.co and web.arkline.io
6. ~~**API Keys in URL Query Params**~~ - Fixed: moved to HTTP headers in FMPService and APINewsService
7. ~~**Debug Print Statements / API Key Logging**~~ - Fixed: only intentional `#if DEBUG` print remains in Logger

### Use `/audit-fix` command

Run `/audit-fix` for guided assistance with fixing these issues.

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
