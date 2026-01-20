import Foundation

// MARK: - App Constants
enum Constants {
    // MARK: - API Keys (to be replaced with actual keys or environment variables)
    enum API {
        static let supabaseURL = "https://your-project.supabase.co"
        static let supabaseAnonKey = "your-anon-key"
        static let claudeAPIKey = "your-claude-api-key"
        static let coinGeckoAPIKey = "your-coingecko-api-key"
        static let alphaVantageAPIKey = "your-alphavantage-api-key"
        static let metalsAPIKey = "your-metals-api-key"
    }

    // MARK: - API Endpoints
    enum Endpoints {
        static let coinGeckoBase = "https://api.coingecko.com/api/v3"
        static let alphaVantageBase = "https://www.alphavantage.co"
        static let metalsAPIBase = "https://metals-api.com/api"
        static let claudeBase = "https://api.anthropic.com/v1"
    }

    // MARK: - App Configuration
    enum App {
        static let name = "ArkLine"
        static let bundleIdentifier = "com.arkline.app"
        static let appStoreID = "000000000"
        static let minimumIOSVersion = "17.0"
        static let defaultCurrency = "USD"
        static let defaultRiskCoins = ["BTC", "ETH"]
    }

    // MARK: - Cache Configuration
    enum Cache {
        static let priceDataTTL: TimeInterval = 60 // 1 minute
        static let sentimentDataTTL: TimeInterval = 300 // 5 minutes
        static let newsDataTTL: TimeInterval = 900 // 15 minutes
        static let portfolioDataTTL: TimeInterval = 60 // 1 minute
    }

    // MARK: - Pagination
    enum Pagination {
        static let defaultPageSize = 20
        static let maxPageSize = 100
        static let chatHistoryLimit = 50
        static let communityPostsLimit = 20
    }

    // MARK: - UI Configuration
    enum UI {
        static let animationDuration: Double = 0.3
        static let longAnimationDuration: Double = 0.5
        static let debounceInterval: Double = 0.5
        static let maxRetryAttempts = 3
    }

    // MARK: - Validation
    enum Validation {
        static let minUsernameLength = 3
        static let maxUsernameLength = 20
        static let minPasswordLength = 8
        static let maxBioLength = 300
        static let maxPostLength = 2000
        static let passcodeLength = 6
    }

    // MARK: - Keychain Keys
    enum Keychain {
        static let accessToken = "arkline.accessToken"
        static let refreshToken = "arkline.refreshToken"
        static let passcodeHash = "arkline.passcodeHash"
        static let biometricEnabled = "arkline.biometricEnabled"
    }

    // MARK: - UserDefaults Keys
    enum UserDefaults {
        static let isOnboarded = "isOnboarded"
        static let userId = "userId"
        static let preferredCurrency = "preferredCurrency"
        static let darkModePreference = "darkModePreference"
        static let riskCoins = "riskCoins"
        static let notificationsEnabled = "notificationsEnabled"
        static let biometricEnabled = "biometricEnabled"
        static let lastSyncTimestamp = "lastSyncTimestamp"
    }

    // MARK: - Notification Names
    enum Notifications {
        static let authStateChanged = Notification.Name("authStateChanged")
        static let portfolioUpdated = Notification.Name("portfolioUpdated")
        static let marketDataUpdated = Notification.Name("marketDataUpdated")
        static let sentimentDataUpdated = Notification.Name("sentimentDataUpdated")
        static let themeChanged = Notification.Name("themeChanged")
    }

    // MARK: - Date Formats
    enum DateFormat {
        static let iso8601 = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        static let dateOnly = "yyyy-MM-dd"
        static let timeOnly = "HH:mm"
        static let displayDate = "MMM d, yyyy"
        static let displayDateTime = "MMM d, yyyy 'at' h:mm a"
        static let displayTime = "h:mm a"
        static let chartDate = "MMM d"
        static let chartDateTime = "MMM d, h:mm a"
    }

    // MARK: - Currency Symbols
    enum CurrencySymbol {
        static let usd = "$"
        static let eur = "€"
        static let gbp = "£"
        static let jpy = "¥"
        static let btc = "₿"
        static let eth = "Ξ"
    }

    // MARK: - Asset Types
    enum AssetType: String, CaseIterable {
        case crypto = "crypto"
        case stock = "stock"
        case metal = "metal"

        var displayName: String {
            switch self {
            case .crypto: return "Cryptocurrency"
            case .stock: return "Stock"
            case .metal: return "Precious Metal"
            }
        }
    }

    // MARK: - Transaction Types
    enum TransactionType: String, CaseIterable {
        case buy = "buy"
        case sell = "sell"
        case transferIn = "transfer_in"
        case transferOut = "transfer_out"

        var displayName: String {
            switch self {
            case .buy: return "Buy"
            case .sell: return "Sell"
            case .transferIn: return "Transfer In"
            case .transferOut: return "Transfer Out"
            }
        }
    }

    // MARK: - DCA Frequency
    enum DCAFrequency: String, CaseIterable {
        case daily = "daily"
        case twiceWeekly = "twice_weekly"
        case weekly = "weekly"
        case biweekly = "biweekly"
        case monthly = "monthly"

        var displayName: String {
            switch self {
            case .daily: return "Daily"
            case .twiceWeekly: return "Twice Weekly"
            case .weekly: return "Weekly"
            case .biweekly: return "Bi-weekly"
            case .monthly: return "Monthly"
            }
        }
    }

    // MARK: - Dark Mode Preference
    enum DarkModePreference: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case automatic = "automatic"

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .automatic: return "Automatic"
            }
        }
    }

    // MARK: - Post Categories
    enum PostCategory: String, CaseIterable {
        case news = "news"
        case analysis = "analysis"
        case discussion = "discussion"

        var displayName: String {
            switch self {
            case .news: return "News"
            case .analysis: return "Analysis"
            case .discussion: return "Discussion"
            }
        }
    }
}
