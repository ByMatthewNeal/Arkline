import Foundation

// MARK: - Service Container
/// Central dependency injection container for all services.
/// Use `useMockData` flag to switch between mock and real API implementations.
final class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()

    // MARK: - Configuration
    /// Set to `false` to use real API implementations for general services
    var useMockData: Bool = true

    /// Use real Taapi.io API for technical analysis (separate from general mock data)
    var useRealTechnicalAnalysis: Bool = true

    // MARK: - Lazy Services - Mock
    private lazy var _mockMarketService = MockMarketService()
    private lazy var _mockSentimentService = MockSentimentService()
    private lazy var _mockPortfolioService = MockPortfolioService()
    private lazy var _mockNewsService = MockNewsService()
    private lazy var _mockDCAService = MockDCAService()
    private lazy var _mockTechnicalAnalysisService = MockTechnicalAnalysisService()

    // MARK: - Lazy Services - API
    private lazy var _apiMarketService = APIMarketService()
    private lazy var _apiSentimentService = APISentimentService()
    private lazy var _apiPortfolioService = APIPortfolioService()
    private lazy var _apiNewsService = APINewsService()
    private lazy var _apiDCAService = APIDCAService()
    private lazy var _apiTechnicalAnalysisService = APITechnicalAnalysisService()

    // MARK: - Service Accessors
    var marketService: MarketServiceProtocol {
        useMockData ? _mockMarketService : _apiMarketService
    }

    var sentimentService: SentimentServiceProtocol {
        useMockData ? _mockSentimentService : _apiSentimentService
    }

    var portfolioService: PortfolioServiceProtocol {
        useMockData ? _mockPortfolioService : _apiPortfolioService
    }

    var newsService: NewsServiceProtocol {
        useMockData ? _mockNewsService : _apiNewsService
    }

    var dcaService: DCAServiceProtocol {
        useMockData ? _mockDCAService : _apiDCAService
    }

    var technicalAnalysisService: TechnicalAnalysisServiceProtocol {
        useRealTechnicalAnalysis ? _apiTechnicalAnalysisService : _mockTechnicalAnalysisService
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
        _apiMarketService = APIMarketService()
        _apiSentimentService = APISentimentService()
        _apiPortfolioService = APIPortfolioService()
        _apiNewsService = APINewsService()
        _apiDCAService = APIDCAService()
        _apiTechnicalAnalysisService = APITechnicalAnalysisService()
    }
}
