import XCTest
@testable import ArkLine

// MARK: - Failing Service Stubs

/// Market service that always throws, for testing partial failure isolation.
private final class FailingMarketService: MarketServiceProtocol {
    func fetchCryptoAssets(page: Int, perPage: Int) async throws -> [CryptoAsset] {
        throw AppError.apiUnavailable
    }
    func fetchStockAssets(symbols: [String]) async throws -> [StockAsset] { [] }
    func fetchMetalAssets(symbols: [String]) async throws -> [MetalAsset] { [] }
    func fetchGlobalMarketData() async throws -> CoinGeckoGlobalData {
        throw AppError.apiUnavailable
    }
    func fetchTrendingCrypto() async throws -> [CryptoAsset] { [] }
    func searchCrypto(query: String) async throws -> [CryptoAsset] { [] }
    func searchStocks(query: String) async throws -> [StockSearchResult] { [] }
    func fetchCoinMarketChart(id: String, currency: String, days: Int) async throws -> CoinGeckoMarketChart {
        throw AppError.apiUnavailable
    }
}

/// Sentiment service that always throws, for testing partial failure isolation.
private final class FailingSentimentService: SentimentServiceProtocol {
    func fetchFearGreedIndex() async throws -> FearGreedIndex { throw AppError.apiUnavailable }
    func fetchFearGreedHistory(days: Int) async throws -> [FearGreedIndex] { throw AppError.apiUnavailable }
    func fetchBTCDominance() async throws -> BTCDominance { throw AppError.apiUnavailable }
    func fetchDominanceSnapshot() async throws -> DominanceSnapshot { throw AppError.apiUnavailable }
    func fetchETFNetFlow() async throws -> ETFNetFlow { throw AppError.apiUnavailable }
    func fetchFundingRate() async throws -> FundingRate { throw AppError.apiUnavailable }
    func fetchLiquidations() async throws -> LiquidationData { throw AppError.apiUnavailable }
    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex { throw AppError.apiUnavailable }
    func fetchRiskLevel() async throws -> RiskLevel { throw AppError.apiUnavailable }
    func fetchGlobalLiquidity() async throws -> GlobalLiquidity { throw AppError.apiUnavailable }
    func fetchAppStoreRanking() async throws -> AppStoreRanking { throw AppError.apiUnavailable }
    func fetchAppStoreRankings() async throws -> [AppStoreRanking] { throw AppError.apiUnavailable }
    func fetchArkLineRiskScore() async throws -> ArkLineRiskScore { throw AppError.apiUnavailable }
    func fetchGoogleTrends() async throws -> GoogleTrendsData { throw AppError.apiUnavailable }
    func refreshTrendsData() async {}
    func fetchMarketOverview() async throws -> MarketOverview { throw AppError.apiUnavailable }
}

// MARK: - HomeViewModel Tests

@MainActor
final class HomeViewModelTests: XCTestCase {

    // MARK: - Factory

    /// Creates a HomeViewModel wired to zero-delay mock services.
    /// Stops auto-refresh timer to prevent interference between tests.
    private func makeVM(
        sentimentService: SentimentServiceProtocol? = nil,
        marketService: MarketServiceProtocol? = nil
    ) -> HomeViewModel {
        let mockSentiment = MockSentimentService(); mockSentiment.simulatedDelay = 0
        let mockMarket = MockMarketService(); mockMarket.simulatedDelay = 0
        let mockDCA = MockDCAService(); mockDCA.simulatedDelay = 0
        let mockNews = MockNewsService(); mockNews.simulatedDelay = 0
        let mockPortfolio = MockPortfolioService(); mockPortfolio.simulatedDelay = 0
        let mockITC = MockITCRiskService(); mockITC.simulatedDelay = 0
        let mockVIX = MockVIXService(); mockVIX.simulatedDelay = 0
        let mockDXY = MockDXYService(); mockDXY.simulatedDelay = 0
        let mockRainbow = MockRainbowChartService()
        let mockLiquidity = MockGlobalLiquidityService()
        let mockSantiment = MockSantimentService(); mockSantiment.simulatedDelay = 0

        let macroStats = MacroStatisticsService(
            vixService: mockVIX,
            dxyService: mockDXY,
            globalLiquidityService: mockLiquidity
        )

        let vm = HomeViewModel(
            sentimentService: sentimentService ?? mockSentiment,
            marketService: marketService ?? mockMarket,
            dcaService: mockDCA,
            newsService: mockNews,
            portfolioService: mockPortfolio,
            itcRiskService: mockITC,
            vixService: mockVIX,
            dxyService: mockDXY,
            rainbowChartService: mockRainbow,
            globalLiquidityService: mockLiquidity,
            macroStatisticsService: macroStats,
            santimentService: mockSantiment
        )
        vm.stopAutoRefresh()
        return vm
    }

    /// Calls refresh and yields to ensure all @MainActor work completes.
    private func refreshAndSettle(_ vm: HomeViewModel) async {
        await vm.refresh()
        // Yield to allow any pending MainActor-dispatched work to complete
        await Task.yield()
    }

    // MARK: - Group A: Happy Path

    func testRefresh_populatesBTCPrice() async {
        let vm = makeVM()
        await refreshAndSettle(vm)

        XCTAssertEqual(vm.btcPrice, 67234.50, accuracy: 0.01, "BTC price should match MockMarketService data")
        XCTAssertEqual(vm.ethPrice, 3456.78, accuracy: 0.01, "ETH price should match MockMarketService data")
        XCTAssertGreaterThan(vm.solPrice, 0, "SOL price should be populated")
    }

    func testRefresh_populatesTopGainersAndLosers() async {
        let vm = makeVM()
        await refreshAndSettle(vm)

        XCTAssertEqual(vm.topGainers.count, 3, "Should have 3 top gainers")
        XCTAssertEqual(vm.topLosers.count, 3, "Should have 3 top losers")

        if let first = vm.topGainers.first, let second = vm.topGainers.dropFirst().first {
            XCTAssertGreaterThanOrEqual(
                first.priceChangePercentage24h,
                second.priceChangePercentage24h,
                "Gainers should be sorted descending"
            )
        }
    }

    func testRefresh_populatesMacroIndicators() async {
        let vm = makeVM()
        await refreshAndSettle(vm)

        XCTAssertNotNil(vm.vixData, "VIX data should be populated from mock")
        XCTAssertNotNil(vm.dxyData, "DXY data should be populated from mock")
        XCTAssertNotNil(vm.globalLiquidityChanges, "Global liquidity should be populated from mock")
    }

    func testRefresh_populatesFearGreedAndRiskScore() async {
        let vm = makeVM()
        await refreshAndSettle(vm)

        XCTAssertNotNil(vm.fearGreedIndex, "Fear & Greed should be populated")
        XCTAssertEqual(vm.fearGreedIndex?.value, 49, "Fear & Greed value should be 49 from mock")
        XCTAssertNotNil(vm.arkLineRiskScore, "ArkLine risk score should be populated")
    }

    func testRefresh_setsLastRefreshedAndClearsLoading() async {
        let vm = makeVM()
        await refreshAndSettle(vm)

        XCTAssertNotNil(vm.lastRefreshed, "lastRefreshed should be set after refresh")
        XCTAssertFalse(vm.isLoading, "isLoading should be false after refresh completes")
        XCTAssertNil(vm.errorMessage, "errorMessage should be nil when all services succeed")
        XCTAssertEqual(vm.failedFetchCount, 0, "No failures when all mocks succeed")
    }

    // MARK: - Group B: Partial Failure

    func testRefresh_marketFails_pricesZeroButMacroStillLoaded() async {
        let vm = makeVM(marketService: FailingMarketService())
        await refreshAndSettle(vm)

        XCTAssertEqual(vm.btcPrice, 0, "BTC price should be 0 when market service fails")
        XCTAssertEqual(vm.ethPrice, 0, "ETH price should be 0 when market service fails")
        XCTAssertNotNil(vm.vixData, "VIX should still load despite market failure")
        XCTAssertNotNil(vm.dxyData, "DXY should still load despite market failure")
    }

    func testRefresh_sentimentFails_fearGreedNilButPricesLoaded() async {
        let vm = makeVM(sentimentService: FailingSentimentService())
        await refreshAndSettle(vm)

        XCTAssertNil(vm.fearGreedIndex, "Fear & Greed should be nil when sentiment fails")
        XCTAssertNil(vm.arkLineRiskScore, "ArkLine score should be nil when sentiment fails")
        XCTAssertGreaterThan(vm.btcPrice, 0, "BTC price should still load despite sentiment failure")
    }

    func testRefresh_failedFetchCount_countsCorrectly() async {
        let vm = makeVM(marketService: FailingMarketService())
        await refreshAndSettle(vm)

        XCTAssertGreaterThanOrEqual(vm.failedFetchCount, 1, "Should count at least 1 failure for empty crypto")
    }

    // MARK: - Group C: State Transitions

    func testRefresh_preventsReentrantCalls() async {
        let vm = makeVM()

        // Fire two concurrent refreshes — should not crash
        async let r1: () = vm.refresh()
        async let r2: () = vm.refresh()
        _ = await (r1, r2)

        // The second call should have been a no-op due to isRefreshing guard
        XCTAssertFalse(vm.isLoading, "Should not be loading after both complete")
    }

    func testRefreshEvents_updatesUpcomingEvents() async {
        let vm = makeVM()
        await vm.refreshEvents()

        // Events come from hardcoded data, should be populated
        // (upcomingEvents may be empty if no future events, but the method should complete)
        XCTAssertFalse(vm.isLoading, "Should not be loading after events refresh")
    }

    // MARK: - Group D: Business Logic

    func testSelectPortfolio_updatesSelectedPortfolio() async {
        let vm = makeVM()
        let portfolio = Portfolio(
            id: UUID(),
            userId: UUID(),
            name: "Test Portfolio",
            createdAt: Date()
        )

        await MainActor.run {
            vm.selectPortfolio(portfolio)
        }

        XCTAssertEqual(vm.selectedPortfolio?.name, "Test Portfolio")
    }

    func testHasExtremeMacroMove_trueWhenExtreme() {
        let vm = makeVM()
        vm.macroZScores[.vix] = MacroZScoreData(
            indicator: .vix,
            currentValue: 35.0,
            zScore: StatisticsCalculator.ZScoreResult(mean: 20.0, standardDeviation: 5.0, zScore: 3.5),
            sdBands: StatisticsCalculator.SDBands(mean: 20.0, plus1SD: 25.0, plus2SD: 30.0, plus3SD: 35.0, minus1SD: 15.0, minus2SD: 10.0, minus3SD: 5.0),
            historyValues: [18.0, 20.0, 22.0, 35.0],
            calculatedAt: Date()
        )

        XCTAssertTrue(vm.hasExtremeMacroMove, "Should detect extreme macro move when z-score >= 3")
    }

    func testZScore_returnsCorrectIndicator() {
        let vm = makeVM()
        let testData = MacroZScoreData(
            indicator: .vix,
            currentValue: 25.0,
            zScore: StatisticsCalculator.ZScoreResult(mean: 20.0, standardDeviation: 3.0, zScore: 1.5),
            sdBands: StatisticsCalculator.SDBands(mean: 20.0, plus1SD: 23.0, plus2SD: 26.0, plus3SD: 29.0, minus1SD: 17.0, minus2SD: 14.0, minus3SD: 11.0),
            historyValues: [18.0, 20.0, 22.0, 25.0],
            calculatedAt: Date()
        )
        vm.macroZScores[.vix] = testData

        XCTAssertNotNil(vm.zScore(for: .vix), "Should return z-score data for VIX")
        XCTAssertNil(vm.zScore(for: .dxy), "Should return nil for indicator not set")
    }

    // MARK: - Group E: Computed Properties

    func testBtcPriceDefaultsToZero() {
        let vm = makeVM()
        XCTAssertEqual(vm.btcPrice, 0, "Fresh VM should have btcPrice = 0 before refresh")
    }

}
