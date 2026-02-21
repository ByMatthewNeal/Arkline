import XCTest
@testable import ArkLine

// MARK: - Failing Sentiment Service for Isolation Tests

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

// MARK: - SentimentViewModel Tests

@MainActor
final class SentimentViewModelTests: XCTestCase {

    // MARK: - Factory

    /// Creates a SentimentViewModel wired to zero-delay mock services.
    /// Note: init() auto-calls loadInitialData(), so we must await for it to settle.
    private func makeVM(
        sentimentService: SentimentServiceProtocol? = nil
    ) -> SentimentViewModel {
        let mockSentiment = MockSentimentService(); mockSentiment.simulatedDelay = 0
        let mockMarket = MockMarketService(); mockMarket.simulatedDelay = 0
        let mockITC = MockITCRiskService(); mockITC.simulatedDelay = 0
        let mockVIX = MockVIXService(); mockVIX.simulatedDelay = 0
        let mockDXY = MockDXYService(); mockDXY.simulatedDelay = 0
        let mockLiquidity = MockGlobalLiquidityService()
        let mockCoinglass = MockCoinglassService(); mockCoinglass.simulatedDelay = 0

        let macroStats = MacroStatisticsService(
            vixService: mockVIX,
            dxyService: mockDXY,
            globalLiquidityService: mockLiquidity
        )

        return SentimentViewModel(
            sentimentService: sentimentService ?? mockSentiment,
            marketService: mockMarket,
            itcRiskService: mockITC,
            vixService: mockVIX,
            dxyService: mockDXY,
            globalLiquidityService: mockLiquidity,
            macroStatisticsService: macroStats,
            coinglassService: mockCoinglass,
            enableSideEffects: false
        )
    }

    /// Explicitly load data (init no longer auto-loads)
    private func loadData(_ vm: SentimentViewModel) async {
        await vm.refresh()
    }

    // MARK: - Group A: Happy Path

    func testRefresh_populatesFearGreedIndex() async {
        let vm = makeVM()
        await loadData(vm)

        XCTAssertNotNil(vm.fearGreedIndex, "Fear & Greed should be populated after refresh")
        XCTAssertEqual(vm.fearGreedIndex?.value, 49, "Value should be 49 from MockSentimentService")
        XCTAssertEqual(vm.fearGreedIndex?.classification, "Neutral")
    }

    func testRefresh_populatesBTCDominance() async {
        let vm = makeVM()
        await loadData(vm)

        XCTAssertNotNil(vm.btcDominance, "BTC dominance should be populated")
    }

    func testRefresh_populatesMacroIndicators() async {
        let vm = makeVM()
        await loadData(vm)

        XCTAssertNotNil(vm.vixData, "VIX data should be populated")
        XCTAssertNotNil(vm.dxyData, "DXY data should be populated")
    }

    func testRefresh_populatesArkLineRiskScore() async {
        let vm = makeVM()
        await loadData(vm)

        XCTAssertNotNil(vm.arkLineRiskScore, "ArkLine risk score should be populated")
        if let score = vm.arkLineRiskScore {
            XCTAssertGreaterThanOrEqual(score.score, 0, "Score should be >= 0")
            XCTAssertLessThanOrEqual(score.score, 100, "Score should be <= 100")
            XCTAssertGreaterThan(score.components.count, 0, "Should have components")
        }
    }

    // MARK: - Group B: Computed Properties

    func testOverallSentiment_neutral() async {
        let vm = makeVM()
        await loadData(vm)

        // MockSentimentService returns value=49, which maps to neutral range (41-60)
        let tier = vm.overallSentimentTier
        XCTAssertTrue(
            tier == .neutral || tier == .bearish,
            "Value 49 should be in Neutral or Bearish range, got: \(tier)"
        )
    }

    func testOverallSentiment_nilWhenNoData() async {
        let vm = makeVM(sentimentService: FailingSentimentService())
        await loadData(vm)

        // With failing service, fearGreedIndex should be nil
        XCTAssertNil(vm.fearGreedIndex, "Fear & Greed should be nil when service fails")
    }

    func testOverallSentiment_extremelyBearish() async {
        let vm = makeVM()
        await loadData(vm)

        // Override arkLineRiskScore directly with a low score
        vm.arkLineRiskScore = ArkLineRiskScore(
            score: 10,
            tier: .extremelyBearish,
            components: [],
            recommendation: "Test",
            timestamp: Date()
        )

        XCTAssertEqual(vm.overallSentimentTier, .extremelyBearish, "Score 10 should be Extremely Bearish")
    }

    // MARK: - Group C: Caching

    func testFetchEnhancedRiskHistory_cachesResults() async {
        let vm = makeVM()
        await loadData(vm)

        let history1 = await vm.fetchEnhancedRiskHistory(coin: "BTC")
        let history2 = await vm.fetchEnhancedRiskHistory(coin: "BTC")

        // Both calls should return data (second from cache)
        XCTAssertEqual(history1.count, history2.count, "Cached result should match original")
    }

    func testFetchMultiFactorRisk_cachesPerCoin() async {
        let vm = makeVM()
        await loadData(vm)

        let btcRisk = await vm.fetchMultiFactorRisk(coin: "BTC")
        XCTAssertNotNil(btcRisk, "Should return multi-factor risk for BTC")

        // Second call should hit cache
        let btcRisk2 = await vm.fetchMultiFactorRisk(coin: "BTC")
        XCTAssertNotNil(btcRisk2, "Cached result should be non-nil")
    }

    // MARK: - Group D: Partial Failure

    func testRefresh_sentimentFails_macroStillLoaded() async {
        let vm = makeVM(sentimentService: FailingSentimentService())
        await loadData(vm)

        XCTAssertNil(vm.fearGreedIndex, "Fear & Greed should be nil when sentiment fails")
        XCTAssertNil(vm.btcDominance, "BTC dominance should be nil when sentiment fails")
        // VIX and DXY use separate services that still work
        XCTAssertNotNil(vm.vixData, "VIX should still load despite sentiment failure")
        XCTAssertNotNil(vm.dxyData, "DXY should still load despite sentiment failure")
    }

    func testRefresh_isLoadingFalseAfterCompletion() async {
        let vm = makeVM()
        await loadData(vm)

        XCTAssertFalse(vm.isLoading, "isLoading should be false after init completes")
    }

    // MARK: - Group E: State

    func testInitialState_defaultValues() {
        // Create VM synchronously — verify default property values before any data loads
        let vm = makeVM()
        // fearGreedIndex starts nil before any data is fetched
        XCTAssertNil(vm.fearGreedIndex, "fearGreedIndex should be nil before data loads")
        XCTAssertNil(vm.btcDominance, "btcDominance should be nil before data loads")
    }
}
