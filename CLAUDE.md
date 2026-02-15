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
