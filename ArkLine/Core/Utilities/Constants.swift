import Foundation

// MARK: - App Constants
enum Constants {
    // MARK: - API Keys (loaded from Secrets.plist - gitignored)
    // TEMPORARY: Hardcoded keys until plist bundle issue is resolved
    private static let secrets: [String: Any] = {
        // Try loading from bundle first
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            print("✅ Secrets.plist loaded from bundle with \(plist.count) keys")
            return plist
        }

        // Fallback: hardcoded keys (TEMPORARY - remove after fixing plist)
        print("⚠️ Using hardcoded API keys (Secrets.plist not in bundle)")
        return [
            "ALPHA_VANTAGE_API_KEY": "MBSPLHGZOUELTCOJ",
            "COINGECKO_API_KEY": "CG-Ggho8wQf8mXQeyPUzcgTJc3B",
            "COINGLASS_API_KEY": "1164e763b82f474e87b4e0276feef926",
            "TAAPI_API_KEY": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbHVlIjoiNjk3MjRmMzlhZWVjODgxNjBhNTkzNjE2IiwiaWF0IjoxNzY5MDk5MDY1LCJleHAiOjMzMjczNTYzMDY1fQ.zmhZHgsYk5fmYJVhvltS1WczaLejZqrisVmoG3vExaw",
            "METALS_API_KEY": "",
            "CLAUDE_API_KEY": "",
            "FRED_API_KEY": "",
            "FINNHUB_API_KEY": "d5qo0r9r01qhn30gst1gd5qo0r9r01qhn30gst20",
            "FMP_API_KEY": "paZFjsoaxMRSmSR82AbYHskweit7aCd8",
            "SUPABASE_URL": "https://mprbbjgrshfbupheuscn.supabase.co",
            "SUPABASE_ANON_KEY": "sb_publishable_OD56MqP74dT54PEDZNpcrQ_PPm5ug0P"
        ]
    }()

    enum API {
        static let supabaseURL = Constants.secrets["SUPABASE_URL"] as? String ?? ""
        static let supabaseAnonKey = Constants.secrets["SUPABASE_ANON_KEY"] as? String ?? ""
        static let claudeAPIKey = Constants.secrets["CLAUDE_API_KEY"] as? String ?? ""
        static let coinGeckoAPIKey = Constants.secrets["COINGECKO_API_KEY"] as? String ?? ""
        static let alphaVantageAPIKey = Constants.secrets["ALPHA_VANTAGE_API_KEY"] as? String ?? ""
        static let metalsAPIKey = Constants.secrets["METALS_API_KEY"] as? String ?? ""
        static let taapiAPIKey = Constants.secrets["TAAPI_API_KEY"] as? String ?? ""
        static let coinglassAPIKey = Constants.secrets["COINGLASS_API_KEY"] as? String ?? ""
        static let fredAPIKey = Constants.secrets["FRED_API_KEY"] as? String ?? ""
        static let finnhubAPIKey = Constants.secrets["FINNHUB_API_KEY"] as? String ?? ""
        static let fmpAPIKey = Constants.secrets["FMP_API_KEY"] as? String ?? ""
    }

    // MARK: - Coinglass API Key (accessed from root for convenience)
    static var coinglassAPIKey: String {
        API.coinglassAPIKey
    }

    // MARK: - API Endpoints
    enum Endpoints {
        static let coinGeckoBase = "https://api.coingecko.com/api/v3"
        static let alphaVantageBase = "https://www.alphavantage.co"
        static let metalsAPIBase = "https://metals-api.com/api"
        static let claudeBase = "https://api.anthropic.com/v1"
        static let taapiBase = "https://api.taapi.io"
        static let arklineBackendBase = "https://web.arkline.io/api/v1"
        static let fredBase = "https://api.stlouisfed.org/fred"
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

    // MARK: - Mock Data (for development/testing)
    enum Mock {
        /// Consistent user ID for mock data during development
        /// This ensures DCA reminders created in one view appear in others
        static let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
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
        static let currentUser = "currentUser"
        static let preferredCurrency = "preferredCurrency"
        static let darkModePreference = "darkModePreference"
        static let avatarColorTheme = "avatarColorTheme"
        static let riskCoins = "riskCoins"
        static let notificationsEnabled = "notificationsEnabled"
        static let biometricEnabled = "biometricEnabled"
        static let lastSyncTimestamp = "lastSyncTimestamp"
        static let widgetConfiguration = "widgetConfiguration"
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
        case realEstate = "real_estate"

        var displayName: String {
            switch self {
            case .crypto: return "Cryptocurrency"
            case .stock: return "Stock"
            case .metal: return "Precious Metal"
            case .realEstate: return "Real Estate"
            }
        }

        var icon: String {
            switch self {
            case .crypto: return "bitcoinsign.circle.fill"
            case .stock: return "chart.line.uptrend.xyaxis"
            case .metal: return "cube.fill"
            case .realEstate: return "house.fill"
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

    // MARK: - Avatar Color Theme (Blue Variations)
    enum AvatarColorTheme: String, CaseIterable {
        case ocean = "ocean"
        case sky = "sky"
        case royal = "royal"
        case midnight = "midnight"
        case teal = "teal"
        case indigo = "indigo"

        var displayName: String {
            switch self {
            case .ocean: return "Ocean"
            case .sky: return "Sky"
            case .royal: return "Royal"
            case .midnight: return "Midnight"
            case .teal: return "Teal"
            case .indigo: return "Indigo"
            }
        }

        var gradientHexColors: (light: String, dark: String) {
            switch self {
            case .ocean:
                return ("0077B6", "00B4D8")
            case .sky:
                return ("38BDF8", "7DD3FC")
            case .royal:
                return ("3B82F6", "60A5FA")
            case .midnight:
                return ("1E3A8A", "3B82F6")
            case .teal:
                return ("0D9488", "2DD4BF")
            case .indigo:
                return ("4F46E5", "818CF8")
            }
        }

        var icon: String {
            switch self {
            case .ocean: return "water.waves"
            case .sky: return "cloud.sun"
            case .royal: return "crown"
            case .midnight: return "moon.stars"
            case .teal: return "leaf"
            case .indigo: return "sparkles"
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
