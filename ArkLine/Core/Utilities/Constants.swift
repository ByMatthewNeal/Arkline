import Foundation
import SwiftUI

// MARK: - App Constants
enum Constants {
    // MARK: - API Keys (loaded from Secrets.plist - gitignored)
    // SECURITY: Keys are ONLY loaded from Secrets.plist - no hardcoded fallbacks
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            AppLogger.shared.error("Secrets.plist not found in bundle. API features will be unavailable.")
            return [:]
        }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            AppLogger.shared.error("Failed to parse Secrets.plist. API features will be unavailable.")
            return [:]
        }

        AppLogger.shared.debug("Secrets.plist loaded with \(plist.count) keys")
        return plist
    }()

    enum API {
        static let supabaseURL = Constants.secrets["SUPABASE_URL"] as? String ?? ""
        static let supabaseAnonKey = Constants.secrets["SUPABASE_ANON_KEY"] as? String ?? ""
        static let coinGeckoAPIKey = Constants.secrets["COINGECKO_API_KEY"] as? String ?? ""
        static let metalsAPIKey = Constants.secrets["METALS_API_KEY"] as? String ?? ""
        static let taapiAPIKey = Constants.secrets["TAAPI_API_KEY"] as? String ?? ""
        static let coinglassAPIKey = Constants.secrets["COINGLASS_API_KEY"] as? String ?? ""
        static let fredAPIKey = Constants.secrets["FRED_API_KEY"] as? String ?? ""
        static let finnhubAPIKey = Constants.secrets["FINNHUB_API_KEY"] as? String ?? ""
        static let revenueCatAPIKey = Constants.secrets["REVENUE_CAT_API_KEY"] as? String ?? ""
    }

    // MARK: - Coinglass API Key (accessed from root for convenience)
    static var coinglassAPIKey: String {
        API.coinglassAPIKey
    }

    // MARK: - API Endpoints
    enum Endpoints {
        static let coinGeckoBase = "https://api.coingecko.com/api/v3"
        static let metalsAPIBase = "https://metals-api.com/api"
        static let taapiBase = "https://api.taapi.io"
        static let arklineBackendBase = "https://web.arkline.io/api/v1"
        static let fredBase = "https://api.stlouisfed.org/fred"
    }

    // MARK: - App Configuration
    enum App {
        static let name = "ArkLine"
        static let bundleIdentifier = "com.arkline.app"
        static let appStoreID = "" // Set after app is created in App Store Connect
        static let minimumIOSVersion = "17.0"
        static let defaultCurrency = "USD"
        static let defaultRiskCoins = ["BTC", "ETH"]
    }

    // MARK: - Mock Data (for development/testing)
    #if DEBUG
    enum Mock {
        /// Consistent user ID for mock data during development
        /// This ensures DCA reminders created in one view appear in others
        static let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }
    #endif

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
        static let chartColorPalette = "chartColorPalette"
        static let riskCoins = "riskCoins"
        static let notificationsEnabled = "notificationsEnabled"
        static let biometricEnabled = "biometricEnabled"
        static let lastSyncTimestamp = "lastSyncTimestamp"
        static let widgetConfiguration = "widgetConfiguration"
        static let selectedNewsTopics = "selectedNewsTopics"
        static let customNewsTopics = "customNewsTopics"
        static let notificationsPrompted = "arkline_notifications_prompted"
    }

    // MARK: - Notification Names
    enum Notifications {
        static let authStateChanged = Notification.Name("authStateChanged")
        static let portfolioUpdated = Notification.Name("portfolioUpdated")
        static let marketDataUpdated = Notification.Name("marketDataUpdated")
        static let sentimentDataUpdated = Notification.Name("sentimentDataUpdated")
        static let themeChanged = Notification.Name("themeChanged")
        static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
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

    // MARK: - Chart Color Palette
    enum ChartColorPalette: String, CaseIterable {
        case classic = "classic"
        case vibrant = "vibrant"
        case pastel = "pastel"
        case neon = "neon"

        var displayName: String {
            switch self {
            case .classic: return "Classic"
            case .vibrant: return "Vibrant"
            case .pastel: return "Pastel"
            case .neon: return "Neon"
            }
        }

        var description: String {
            switch self {
            case .classic: return "Traditional colors for clear data visualization"
            case .vibrant: return "Bold, saturated colors that pop"
            case .pastel: return "Soft, muted tones for a calm look"
            case .neon: return "Electric colors for a modern feel"
            }
        }

        var icon: String {
            switch self {
            case .classic: return "chart.pie"
            case .vibrant: return "paintpalette"
            case .pastel: return "cloud"
            case .neon: return "bolt"
            }
        }

        /// Asset type colors for this palette
        var colors: ChartColors {
            switch self {
            case .classic:
                return ChartColors(
                    crypto: "#6366F1",  // Indigo
                    stock: "#22C55E",   // Green
                    metal: "#F59E0B",   // Amber
                    realEstate: "#3B82F6", // Blue
                    other: "#6B7280"    // Gray
                )
            case .vibrant:
                return ChartColors(
                    crypto: "#8B5CF6",  // Violet
                    stock: "#10B981",   // Emerald
                    metal: "#F97316",   // Orange
                    realEstate: "#0EA5E9", // Sky
                    other: "#64748B"    // Slate
                )
            case .pastel:
                return ChartColors(
                    crypto: "#A5B4FC",  // Indigo-200
                    stock: "#86EFAC",   // Green-200
                    metal: "#FDE68A",   // Amber-200
                    realEstate: "#93C5FD", // Blue-200
                    other: "#D1D5DB"    // Gray-300
                )
            case .neon:
                return ChartColors(
                    crypto: "#A855F7",  // Purple
                    stock: "#22D3EE",   // Cyan
                    metal: "#FACC15",   // Yellow
                    realEstate: "#F472B6", // Pink
                    other: "#94A3B8"    // Slate-400
                )
            }
        }

        /// Preview colors for the settings UI
        var previewColors: [Color] {
            [
                Color(hex: colors.crypto),
                Color(hex: colors.stock),
                Color(hex: colors.metal),
                Color(hex: colors.realEstate)
            ]
        }
    }

    /// Color definitions for chart elements
    struct ChartColors {
        let crypto: String
        let stock: String
        let metal: String
        let realEstate: String
        let other: String

        func color(for assetType: String) -> Color {
            switch assetType.lowercased() {
            case "crypto": return Color(hex: crypto)
            case "stock", "stocks": return Color(hex: stock)
            case "metal", "metals": return Color(hex: metal)
            case "real_estate", "realestate": return Color(hex: realEstate)
            default: return Color(hex: other)
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

    // MARK: - News Topics (for personalized news feed)
    enum NewsTopic: String, CaseIterable, Codable {
        case crypto = "crypto"
        case macroEconomy = "macro"
        case stocks = "stocks"
        case techAI = "tech_ai"
        case geopolitics = "geopolitics"
        case defi = "defi"
        case nfts = "nfts"
        case regulation = "regulation"

        var displayName: String {
            switch self {
            case .crypto: return "Crypto"
            case .macroEconomy: return "Macro/Economy"
            case .stocks: return "Stocks"
            case .techAI: return "Tech/AI"
            case .geopolitics: return "Geopolitics"
            case .defi: return "DeFi"
            case .nfts: return "NFTs"
            case .regulation: return "Regulation"
            }
        }

        var icon: String {
            switch self {
            case .crypto: return "bitcoinsign.circle"
            case .macroEconomy: return "chart.bar"
            case .stocks: return "chart.line.uptrend.xyaxis"
            case .techAI: return "cpu"
            case .geopolitics: return "globe"
            case .defi: return "lock.shield"
            case .nfts: return "photo.artframe"
            case .regulation: return "building.columns"
            }
        }

        var searchQuery: String {
            switch self {
            case .crypto: return "cryptocurrency OR bitcoin OR ethereum OR crypto"
            case .macroEconomy: return "federal reserve OR interest rates OR inflation OR economy"
            case .stocks: return "stock market OR S&P 500 OR nasdaq OR equities"
            case .techAI: return "artificial intelligence OR AI OR tech stocks OR nvidia"
            case .geopolitics: return "geopolitics OR world news OR international relations"
            case .defi: return "DeFi OR decentralized finance OR yield farming"
            case .nfts: return "NFT OR non-fungible token OR digital collectibles"
            case .regulation: return "crypto regulation OR SEC OR cryptocurrency law"
            }
        }
    }
}
