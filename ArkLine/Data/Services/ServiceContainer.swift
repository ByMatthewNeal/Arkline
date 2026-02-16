import Foundation

// MARK: - Service Container
/// Central dependency injection container for all services.
/// Use `useMockData` flag to switch between mock and real API implementations.
final class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()

    // MARK: - Configuration
    /// Use real CoinGecko API for market data (crypto prices, trending, etc.)
    var useRealMarketData: Bool = true

    /// Use real Taapi.io API for technical analysis
    var useRealTechnicalAnalysis: Bool = true

    /// Use real Google News RSS feeds for news
    var useRealNews: Bool = true

    /// Use mock data for macro services (VIX, DXY, liquidity, ITC risk)
    private let useMockMacroServices: Bool = false

    /// Use real Supabase data for Portfolio and DCA
    /// Set to false for screenshots/promotional materials
    var useRealPortfolioData: Bool = true

    // MARK: - Lazy Services - Mock
    private lazy var _mockMarketService = MockMarketService()
    private lazy var _mockSentimentService = MockSentimentService()
    private lazy var _mockPortfolioService = MockPortfolioService()
    private lazy var _mockNewsService = MockNewsService()
    private lazy var _mockDCAService = MockDCAService()
    private lazy var _mockTechnicalAnalysisService = MockTechnicalAnalysisService()
    private lazy var _mockITCRiskService = MockITCRiskService()
    private lazy var _mockVIXService = MockVIXService()
    private lazy var _mockDXYService = MockDXYService()
    private lazy var _mockRainbowChartService = MockRainbowChartService()
    private lazy var _mockGlobalLiquidityService = MockGlobalLiquidityService()
    private lazy var _mockSantimentOnChainService = MockSantimentService()

    // MARK: - Lazy Services - API
    private lazy var _apiMarketService = APIMarketService()
    private lazy var _apiSentimentService = APISentimentService()
    private lazy var _apiPortfolioService = APIPortfolioService()
    private lazy var _apiNewsService = APINewsService()
    private lazy var _apiDCAService = APIDCAService()
    private lazy var _apiTechnicalAnalysisService = APITechnicalAnalysisService()
    private lazy var _apiITCRiskService = APIITCRiskService()
    private lazy var _apiRainbowChartService = APIRainbowChartService()
    private lazy var _apiGlobalLiquidityService = APIGlobalLiquidityService()
    private lazy var _apiSantimentOnChainService = APISantimentService()

    // MARK: - Lazy Services - Yahoo Finance (better rate limits than Alpha Vantage)
    private lazy var _yahooVIXService = YahooVIXService()
    private lazy var _yahooDXYService = YahooDXYService()

    // MARK: - Lazy Services - Coinglass (Derivatives)
    private lazy var _apiCoinglassService = APICoinglassService()
    private lazy var _mockCoinglassService = MockCoinglassService()

    // MARK: - Lazy Services - Statistics
    private lazy var _macroStatisticsService = MacroStatisticsService()
    private lazy var _historicalContextService = HistoricalContextService()

    // MARK: - Lazy Services - Broadcast
    private lazy var _broadcastService = BroadcastService()

    // MARK: - Service Accessors

    /// Market service uses real CoinGecko API for live crypto prices
    var marketService: MarketServiceProtocol {
        useRealMarketData ? _apiMarketService : _mockMarketService
    }

    /// Sentiment service - uses real APIs for Fear & Greed, BTC Dominance
    var sentimentService: SentimentServiceProtocol {
        useRealMarketData ? _apiSentimentService : _mockSentimentService
    }

    /// Portfolio service - uses Supabase for real data
    var portfolioService: PortfolioServiceProtocol {
        useRealPortfolioData ? _apiPortfolioService : _mockPortfolioService
    }

    /// News service - uses real Google News RSS when enabled
    var newsService: NewsServiceProtocol {
        useRealNews ? _apiNewsService : _mockNewsService
    }

    /// DCA service - uses Supabase for real data
    var dcaService: DCAServiceProtocol {
        useRealPortfolioData ? _apiDCAService : _mockDCAService
    }

    /// Technical Analysis service uses real Taapi.io API
    var technicalAnalysisService: TechnicalAnalysisServiceProtocol {
        useRealTechnicalAnalysis ? _apiTechnicalAnalysisService : _mockTechnicalAnalysisService
    }

    /// ITC Risk service - uses CoinGecko data with logarithmic regression
    var itcRiskService: ITCRiskServiceProtocol {
        useMockMacroServices ? _mockITCRiskService : _apiITCRiskService
    }

    /// VIX service - uses Yahoo Finance (no rate limits)
    var vixService: VIXServiceProtocol {
        // Yahoo Finance has no strict rate limits unlike Alpha Vantage (25/day)
        useMockMacroServices ? _mockVIXService : _yahooVIXService
    }

    /// DXY service - uses Yahoo Finance (no rate limits)
    var dxyService: DXYServiceProtocol {
        // Yahoo Finance has no strict rate limits unlike Alpha Vantage (25/day)
        useMockMacroServices ? _mockDXYService : _yahooDXYService
    }

    /// Rainbow Chart service - calculation-based (uses market service for BTC price)
    var rainbowChartService: RainbowChartServiceProtocol {
        useRealMarketData ? _apiRainbowChartService : _mockRainbowChartService
    }

    /// Global Liquidity service - uses FRED API for M2 money supply data
    var globalLiquidityService: GlobalLiquidityServiceProtocol {
        useMockMacroServices ? _mockGlobalLiquidityService : _apiGlobalLiquidityService
    }

    /// Santiment service - uses free GraphQL API for on-chain metrics (Supply in Profit)
    var santimentService: SantimentServiceProtocol {
        useMockMacroServices ? _mockSantimentOnChainService : _apiSantimentOnChainService
    }

    /// Coinglass derivatives service - OI, funding rates, liquidations, L/S ratios
    var coinglassService: CoinglassServiceProtocol {
        useRealMarketData ? _apiCoinglassService : _mockCoinglassService
    }

    /// Macro Statistics service - calculates z-scores for VIX, DXY, M2
    var macroStatisticsService: MacroStatisticsServiceProtocol {
        _macroStatisticsService
    }

    /// Historical Context service - finds similar historical occurrences
    var historicalContextService: HistoricalContextService {
        _historicalContextService
    }

    /// Broadcast service - manages broadcasts for the Broadcast Studio
    var broadcastService: BroadcastServiceProtocol {
        _broadcastService
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Reset
    func reset() {
        _mockMarketService = MockMarketService()
        _mockSentimentService = MockSentimentService()
        _mockPortfolioService = MockPortfolioService()
        _mockNewsService = MockNewsService()
        _mockDCAService = MockDCAService()
        _mockTechnicalAnalysisService = MockTechnicalAnalysisService()
        _mockITCRiskService = MockITCRiskService()
        _mockVIXService = MockVIXService()
        _mockDXYService = MockDXYService()
        _mockRainbowChartService = MockRainbowChartService()
        _mockGlobalLiquidityService = MockGlobalLiquidityService()
        _mockSantimentOnChainService = MockSantimentService()
        _mockCoinglassService = MockCoinglassService()
        _apiMarketService = APIMarketService()
        _apiSentimentService = APISentimentService()
        _apiPortfolioService = APIPortfolioService()
        _apiNewsService = APINewsService()
        _apiDCAService = APIDCAService()
        _apiTechnicalAnalysisService = APITechnicalAnalysisService()
        _apiITCRiskService = APIITCRiskService()
        _apiRainbowChartService = APIRainbowChartService()
        _apiGlobalLiquidityService = APIGlobalLiquidityService()
        _apiSantimentOnChainService = APISantimentService()
        _apiCoinglassService = APICoinglassService()
    }
}
