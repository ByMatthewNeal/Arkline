import Foundation

// MARK: - Service Container
/// Central dependency injection container for all services.
/// Use `useMockData` flag to switch between mock and real API implementations.
final class ServiceContainer {
    // MARK: - Singleton
    static let shared = ServiceContainer()

    // MARK: - Configuration
    /// Set to `false` to use real API implementations
    var useMockData: Bool = true

    // MARK: - Lazy Services (Mock only for now)
    private lazy var _mockMarketService = MockMarketService()
    private lazy var _mockSentimentService = MockSentimentService()
    private lazy var _mockPortfolioService = MockPortfolioService()
    private lazy var _mockNewsService = MockNewsService()
    private lazy var _mockDCAService = MockDCAService()

    // MARK: - Service Accessors
    var marketService: MarketServiceProtocol {
        _mockMarketService
    }

    var sentimentService: SentimentServiceProtocol {
        _mockSentimentService
    }

    var portfolioService: PortfolioServiceProtocol {
        _mockPortfolioService
    }

    var newsService: NewsServiceProtocol {
        _mockNewsService
    }

    var dcaService: DCAServiceProtocol {
        _mockDCAService
    }

    // MARK: - Initialization
    private init() {}

    // MARK: - Reset
    /// Resets all services. Useful for testing.
    func reset() {
        _mockMarketService = MockMarketService()
        _mockSentimentService = MockSentimentService()
        _mockPortfolioService = MockPortfolioService()
        _mockNewsService = MockNewsService()
        _mockDCAService = MockDCAService()
    }
}

// MARK: - Testing Support
extension ServiceContainer {
    /// Creates a new container for testing purposes with custom services
    static func forTesting(
        marketService: MarketServiceProtocol? = nil,
        sentimentService: SentimentServiceProtocol? = nil,
        portfolioService: PortfolioServiceProtocol? = nil,
        newsService: NewsServiceProtocol? = nil,
        dcaService: DCAServiceProtocol? = nil
    ) -> TestServiceContainer {
        TestServiceContainer(
            marketService: marketService ?? MockMarketService(),
            sentimentService: sentimentService ?? MockSentimentService(),
            portfolioService: portfolioService ?? MockPortfolioService(),
            newsService: newsService ?? MockNewsService(),
            dcaService: dcaService ?? MockDCAService()
        )
    }
}

// MARK: - Test Service Container
/// A testable service container that allows injecting custom service implementations
final class TestServiceContainer {
    let marketService: MarketServiceProtocol
    let sentimentService: SentimentServiceProtocol
    let portfolioService: PortfolioServiceProtocol
    let newsService: NewsServiceProtocol
    let dcaService: DCAServiceProtocol

    init(
        marketService: MarketServiceProtocol,
        sentimentService: SentimentServiceProtocol,
        portfolioService: PortfolioServiceProtocol,
        newsService: NewsServiceProtocol,
        dcaService: DCAServiceProtocol
    ) {
        self.marketService = marketService
        self.sentimentService = sentimentService
        self.portfolioService = portfolioService
        self.newsService = newsService
        self.dcaService = dcaService
    }
}
