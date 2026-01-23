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

    /// Use real Coinglass API for derivatives data
    /// Set to false until Coinglass API key is configured
    var useRealCoinglass: Bool = false

    /// Use mock data for services that aren't fully implemented yet
    /// (portfolio, sentiment, news, DCA, ITC Risk)
    private let useMockForUnimplementedServices: Bool = true

    // MARK: - Lazy Services - Mock
    private lazy var _mockMarketService = MockMarketService()
    private lazy var _mockSentimentService = MockSentimentService()
    private lazy var _mockPortfolioService = MockPortfolioService()
    private lazy var _mockNewsService = MockNewsService()
    private lazy var _mockDCAService = MockDCAService()
    private lazy var _mockTechnicalAnalysisService = MockTechnicalAnalysisService()
    private lazy var _mockCoinglassService = MockCoinglassService()
    private lazy var _mockITCRiskService = MockITCRiskService()

    // MARK: - Lazy Services - API
    private lazy var _apiMarketService = APIMarketService()
    private lazy var _apiSentimentService = APISentimentService()
    private lazy var _apiPortfolioService = APIPortfolioService()
    private lazy var _apiNewsService = APINewsService()
    private lazy var _apiDCAService = APIDCAService()
    private lazy var _apiTechnicalAnalysisService = APITechnicalAnalysisService()
    private lazy var _apiCoinglassService = APICoinglassService()
    private lazy var _apiITCRiskService = APIITCRiskService()

    // MARK: - Service Accessors

    /// Market service uses real CoinGecko API for live crypto prices
    var marketService: MarketServiceProtocol {
        useRealMarketData ? _apiMarketService : _mockMarketService
    }

    /// Sentiment service - mock until real API is implemented
    var sentimentService: SentimentServiceProtocol {
        useMockForUnimplementedServices ? _mockSentimentService : _apiSentimentService
    }

    /// Portfolio service - mock until Supabase integration is complete
    var portfolioService: PortfolioServiceProtocol {
        useMockForUnimplementedServices ? _mockPortfolioService : _apiPortfolioService
    }

    /// News service - mock until real API is implemented
    var newsService: NewsServiceProtocol {
        useMockForUnimplementedServices ? _mockNewsService : _apiNewsService
    }

    /// DCA service - mock until real API is implemented
    var dcaService: DCAServiceProtocol {
        useMockForUnimplementedServices ? _mockDCAService : _apiDCAService
    }

    /// Technical Analysis service uses real Taapi.io API
    var technicalAnalysisService: TechnicalAnalysisServiceProtocol {
        useRealTechnicalAnalysis ? _apiTechnicalAnalysisService : _mockTechnicalAnalysisService
    }

    /// Coinglass service for derivatives data
    var coinglassService: CoinglassServiceProtocol {
        useRealCoinglass ? _apiCoinglassService : _mockCoinglassService
    }

    /// ITC Risk service - mock until real API is implemented
    var itcRiskService: ITCRiskServiceProtocol {
        useMockForUnimplementedServices ? _mockITCRiskService : _apiITCRiskService
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
        _mockCoinglassService = MockCoinglassService()
        _apiMarketService = APIMarketService()
        _apiSentimentService = APISentimentService()
        _apiPortfolioService = APIPortfolioService()
        _apiNewsService = APINewsService()
        _apiDCAService = APIDCAService()
        _apiTechnicalAnalysisService = APITechnicalAnalysisService()
        _apiCoinglassService = APICoinglassService()
        _mockITCRiskService = MockITCRiskService()
        _apiITCRiskService = APIITCRiskService()
    }
}
