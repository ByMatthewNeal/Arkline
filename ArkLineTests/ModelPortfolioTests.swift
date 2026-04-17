import XCTest
@testable import ArkLine

// MARK: - Mock Model Portfolio Service

private final class MockModelPortfolioService: ModelPortfolioServiceProtocol {
    var portfolios: [ModelPortfolio] = []
    var navHistory: [UUID: [ModelPortfolioNav]] = [:]
    var trades: [UUID: [ModelPortfolioTrade]] = [:]
    var benchmarkNavData: [BenchmarkNav] = []
    var riskHistoryData: [ModelPortfolioRiskHistory] = []
    var shouldFail = false

    func fetchPortfolios() async throws -> [ModelPortfolio] {
        if shouldFail { throw AppError.apiUnavailable }
        return portfolios
    }

    func fetchNavHistory(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioNav] {
        if shouldFail { throw AppError.apiUnavailable }
        let rows = navHistory[portfolioId] ?? []
        return Array(rows.suffix(limit))
    }

    func fetchLatestNav(portfolioId: UUID) async throws -> ModelPortfolioNav? {
        if shouldFail { throw AppError.apiUnavailable }
        return navHistory[portfolioId]?.last
    }

    func fetchTrades(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioTrade] {
        if shouldFail { throw AppError.apiUnavailable }
        let rows = trades[portfolioId] ?? []
        return Array(rows.suffix(limit))
    }

    func fetchBenchmarkNav(limit: Int) async throws -> [BenchmarkNav] {
        if shouldFail { throw AppError.apiUnavailable }
        return Array(benchmarkNavData.suffix(limit))
    }

    func fetchRiskHistory(asset: String, limit: Int) async throws -> [ModelPortfolioRiskHistory] {
        if shouldFail { throw AppError.apiUnavailable }
        return Array(riskHistoryData.suffix(limit))
    }
}

// MARK: - Test Data Builders

private let coreId = UUID()
private let edgeId = UUID()
private let alphaId = UUID()

private func makePortfolio(id: UUID = UUID(), name: String, strategy: String) -> ModelPortfolio {
    let json: [String: Any] = [
        "id": id.uuidString,
        "name": name,
        "strategy": strategy,
        "description": "Test",
        "universe": ["BTC", "ETH"],
        "starting_nav": 50000,
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    return try! decoder.decode(ModelPortfolio.self, from: data)
}

private func makeNav(
    portfolioId: UUID,
    date: String,
    nav: Double,
    allocations: [String: [String: Double]] = ["BTC": ["pct": 60.0, "value": 30000, "qty": 0.5]],
    btcSignal: String = "bullish",
    macroRegime: String = "Risk-On",
    dominantAlt: String? = nil
) -> ModelPortfolioNav {
    var json: [String: Any] = [
        "id": UUID().uuidString,
        "portfolio_id": portfolioId.uuidString,
        "nav_date": date,
        "nav": nav,
        "allocations": allocations,
        "btc_signal": btcSignal,
        "btc_risk_level": 0.45,
        "btc_risk_category": "Neutral",
        "gold_signal": "neutral",
        "macro_regime": macroRegime,
    ]
    if let alt = dominantAlt {
        json["dominant_alt"] = alt
    }
    let data = try! JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    return try! decoder.decode(ModelPortfolioNav.self, from: data)
}

private func makeTrade(
    portfolioId: UUID,
    date: String,
    trigger: String = "BTC bullish → neutral"
) -> ModelPortfolioTrade {
    let json: [String: Any] = [
        "id": UUID().uuidString,
        "portfolio_id": portfolioId.uuidString,
        "trade_date": date,
        "trigger": trigger,
        "from_allocation": ["BTC": 60.0, "ETH": 40.0],
        "to_allocation": ["BTC": 30.0, "ETH": 20.0, "USDC": 50.0],
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    return try! decoder.decode(ModelPortfolioTrade.self, from: data)
}

private func makeBenchmark(date: String, nav: Double) -> BenchmarkNav {
    let json: [String: Any] = [
        "id": UUID().uuidString,
        "nav_date": date,
        "spy_price": 500.0,
        "nav": nav,
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let decoder = JSONDecoder()
    return try! decoder.decode(BenchmarkNav.self, from: data)
}

// MARK: - Model Tests

final class ModelPortfolioModelTests: XCTestCase {

    // ── A. Portfolio Identity ──

    func testIsCore() {
        let p = makePortfolio(name: "Core", strategy: "core")
        XCTAssertTrue(p.isCore)
        XCTAssertFalse(p.isEdge)
        XCTAssertFalse(p.isAlpha)
    }

    func testIsEdge() {
        let p = makePortfolio(name: "Edge", strategy: "edge")
        XCTAssertFalse(p.isCore)
        XCTAssertTrue(p.isEdge)
        XCTAssertFalse(p.isAlpha)
    }

    func testIsAlpha() {
        let p = makePortfolio(name: "Alpha", strategy: "alpha")
        XCTAssertFalse(p.isCore)
        XCTAssertFalse(p.isEdge)
        XCTAssertTrue(p.isAlpha)
    }

    func testUnknownStrategy() {
        let p = makePortfolio(name: "Unknown", strategy: "gamma")
        XCTAssertFalse(p.isCore)
        XCTAssertFalse(p.isEdge)
        XCTAssertFalse(p.isAlpha)
    }

    // ── B. NAV Return Calculation ──

    func testReturnPctPositive() {
        let nav = makeNav(portfolioId: coreId, date: "2026-01-01", nav: 150_000)
        XCTAssertEqual(nav.returnPct, 200.0, accuracy: 0.01) // (150k/50k - 1) * 100
    }

    func testReturnPctNegative() {
        let nav = makeNav(portfolioId: coreId, date: "2026-01-01", nav: 25_000)
        XCTAssertEqual(nav.returnPct, -50.0, accuracy: 0.01)
    }

    func testReturnPctZero() {
        let nav = makeNav(portfolioId: coreId, date: "2026-01-01", nav: 50_000)
        XCTAssertEqual(nav.returnPct, 0.0, accuracy: 0.01)
    }

    func testBenchmarkReturnPct() {
        let bench = makeBenchmark(date: "2026-01-01", nav: 142_000)
        XCTAssertEqual(bench.returnPct, 184.0, accuracy: 0.01)
    }

    // ── C. Allocation Decoding ──

    func testAllocationDetailDecoding() {
        let nav = makeNav(
            portfolioId: coreId,
            date: "2026-01-01",
            nav: 100_000,
            allocations: [
                "BTC": ["pct": 60.0, "value": 60000, "qty": 0.7],
                "ETH": ["pct": 40.0, "value": 40000, "qty": 12.5],
            ]
        )
        XCTAssertEqual(nav.allocations.count, 2)
        XCTAssertEqual(nav.allocations["BTC"]?.pct, 60.0)
        XCTAssertEqual(nav.allocations["ETH"]?.qty, 12.5)
    }

    func testMultiAltAllocationDecoding() {
        // Edge/Alpha can have many assets in allocation
        let nav = makeNav(
            portfolioId: edgeId,
            date: "2026-01-01",
            nav: 100_000,
            allocations: [
                "BTC": ["pct": 30.0, "value": 30000, "qty": 0.35],
                "ETH": ["pct": 25.0, "value": 25000, "qty": 7.5],
                "SOL": ["pct": 20.0, "value": 20000, "qty": 140.0],
                "SUI": ["pct": 5.4, "value": 5400, "qty": 3500.0],
                "LINK": ["pct": 5.1, "value": 5100, "qty": 340.0],
                "AAVE": ["pct": 4.5, "value": 4500, "qty": 15.0],
                "PAXG": ["pct": 4.0, "value": 4000, "qty": 1.3],
                "USDC": ["pct": 6.0, "value": 6000, "qty": 6000.0],
            ]
        )
        XCTAssertEqual(nav.allocations.count, 8)
        XCTAssertEqual(nav.allocations["SUI"]?.pct, 5.4)
        XCTAssertEqual(nav.allocations["AAVE"]?.pct, 4.5)
    }
}

// MARK: - ViewModel Tests

@MainActor
final class ModelPortfolioViewModelTests: XCTestCase {

    private func makeVM(service: MockModelPortfolioService? = nil) -> ModelPortfolioViewModel {
        let mock = service ?? MockModelPortfolioService()
        return ModelPortfolioViewModel(service: mock)
    }

    private func populatedService() -> MockModelPortfolioService {
        let svc = MockModelPortfolioService()
        svc.portfolios = [
            makePortfolio(id: coreId, name: "Arkline Core", strategy: "core"),
            makePortfolio(id: edgeId, name: "Arkline Edge", strategy: "edge"),
            makePortfolio(id: alphaId, name: "Arkline Alpha", strategy: "alpha"),
        ]
        svc.navHistory = [
            coreId: [
                makeNav(portfolioId: coreId, date: "2026-03-29", nav: 1_500_000),
                makeNav(portfolioId: coreId, date: "2026-03-30", nav: 1_588_367),
            ],
            edgeId: [
                makeNav(portfolioId: edgeId, date: "2026-03-29", nav: 540_000, dominantAlt: "SUI"),
                makeNav(portfolioId: edgeId, date: "2026-03-30", nav: 549_386, dominantAlt: "LINK"),
            ],
            alphaId: [
                makeNav(portfolioId: alphaId, date: "2026-03-29", nav: 320_000, dominantAlt: "SUI"),
                makeNav(portfolioId: alphaId, date: "2026-03-30", nav: 327_099, dominantAlt: "SUI"),
            ],
        ]
        svc.trades = [
            coreId: [makeTrade(portfolioId: coreId, date: "2026-03-28")],
            edgeId: [makeTrade(portfolioId: edgeId, date: "2026-03-27"),
                     makeTrade(portfolioId: edgeId, date: "2026-03-28")],
            alphaId: [makeTrade(portfolioId: alphaId, date: "2026-03-27")],
        ]
        svc.benchmarkNavData = [
            makeBenchmark(date: "2026-03-29", nav: 141_000),
            makeBenchmark(date: "2026-03-30", nav: 142_164),
        ]
        return svc
    }

    // ── A. Initial State ──

    func testInitialState() {
        let vm = makeVM()
        XCTAssertTrue(vm.portfolios.isEmpty)
        XCTAssertTrue(vm.coreNav.isEmpty)
        XCTAssertTrue(vm.edgeNav.isEmpty)
        XCTAssertTrue(vm.alphaNav.isEmpty)
        XCTAssertNil(vm.corePortfolio)
        XCTAssertNil(vm.edgePortfolio)
        XCTAssertNil(vm.alphaPortfolio)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    // ── B. Load Overview ──

    func testLoadOverview_populatesAllPortfolios() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertEqual(vm.portfolios.count, 3)
        XCTAssertNotNil(vm.corePortfolio)
        XCTAssertNotNil(vm.edgePortfolio)
        XCTAssertNotNil(vm.alphaPortfolio)
        XCTAssertEqual(vm.corePortfolio?.strategy, "core")
        XCTAssertEqual(vm.edgePortfolio?.strategy, "edge")
        XCTAssertEqual(vm.alphaPortfolio?.strategy, "alpha")
    }

    func testLoadOverview_populatesNav() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertFalse(vm.coreNav.isEmpty)
        XCTAssertFalse(vm.edgeNav.isEmpty)
        XCTAssertFalse(vm.alphaNav.isEmpty)
        XCTAssertFalse(vm.benchmarkNav.isEmpty)
    }

    func testLoadOverview_computesReturns() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertGreaterThan(vm.coreReturn, 0)
        XCTAssertGreaterThan(vm.edgeReturn, 0)
        XCTAssertGreaterThan(vm.alphaReturn, 0)
        XCTAssertGreaterThan(vm.benchmarkReturn, 0)
        // Core should outperform Edge in backtest
        XCTAssertGreaterThan(vm.coreReturn, vm.edgeReturn)
    }

    func testLoadOverview_latestValues() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertEqual(vm.latestCoreNav?.nav, 1_588_367)
        XCTAssertEqual(vm.latestEdgeNav?.nav, 549_386)
        XCTAssertEqual(vm.latestAlphaNav?.nav, 327_099)
        XCTAssertEqual(vm.latestBenchmark?.nav, 142_164)
    }

    func testLoadOverview_setsLoadingState() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        XCTAssertFalse(vm.isLoading)
        await vm.loadOverview()
        XCTAssertFalse(vm.isLoading) // should be false after completion
    }

    func testLoadOverview_preventsConcurrentCalls() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)

        // First call sets isLoading
        await vm.loadOverview()
        XCTAssertFalse(vm.isLoading)
    }

    // ── C. Load Detail ──

    func testLoadDetail_core() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)
        await vm.loadOverview()

        let core = vm.corePortfolio!
        await vm.loadDetail(for: core)

        XCTAssertFalse(vm.coreNav.isEmpty)
        XCTAssertFalse(vm.coreTrades.isEmpty)
        XCTAssertFalse(vm.benchmarkNav.isEmpty)
        XCTAssertFalse(vm.isLoadingDetail)
    }

    func testLoadDetail_edge() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)
        await vm.loadOverview()

        let edge = vm.edgePortfolio!
        await vm.loadDetail(for: edge)

        XCTAssertFalse(vm.edgeNav.isEmpty)
        XCTAssertFalse(vm.edgeTrades.isEmpty)
        XCTAssertEqual(vm.edgeTrades.count, 2)
    }

    func testLoadDetail_alpha() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)
        await vm.loadOverview()

        let alpha = vm.alphaPortfolio!
        await vm.loadDetail(for: alpha)

        XCTAssertFalse(vm.alphaNav.isEmpty)
        XCTAssertFalse(vm.alphaTrades.isEmpty)
        XCTAssertEqual(vm.alphaTrades.count, 1)
    }

    func testLoadDetail_doesNotCrossContaminate() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)
        await vm.loadOverview()

        // Load Core detail
        await vm.loadDetail(for: vm.corePortfolio!)
        let coreTradeCount = vm.coreTrades.count

        // Load Edge detail — core trades should be unchanged
        await vm.loadDetail(for: vm.edgePortfolio!)
        XCTAssertEqual(vm.coreTrades.count, coreTradeCount)

        // Load Alpha detail — edge trades should be unchanged
        let edgeTradeCount = vm.edgeTrades.count
        await vm.loadDetail(for: vm.alphaPortfolio!)
        XCTAssertEqual(vm.edgeTrades.count, edgeTradeCount)
    }

    // ── D. Error Handling ──

    func testLoadOverview_errorSetsMessage() async {
        let svc = MockModelPortfolioService()
        svc.shouldFail = true
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.portfolios.isEmpty)
    }

    func testLoadDetail_errorSetsMessage() async {
        let svc = populatedService()
        let vm = makeVM(service: svc)
        await vm.loadOverview()

        svc.shouldFail = true
        await vm.loadDetail(for: vm.corePortfolio!)

        XCTAssertNotNil(vm.errorMessage)
    }

    // ── E. Empty Data ──

    func testEmptyPortfolios() async {
        let svc = MockModelPortfolioService()
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertNil(vm.corePortfolio)
        XCTAssertNil(vm.edgePortfolio)
        XCTAssertNil(vm.alphaPortfolio)
        XCTAssertEqual(vm.coreReturn, 0)
        XCTAssertEqual(vm.edgeReturn, 0)
        XCTAssertEqual(vm.alphaReturn, 0)
    }

    func testTwoPortfoliosWithoutAlpha() async {
        let svc = MockModelPortfolioService()
        svc.portfolios = [
            makePortfolio(id: coreId, name: "Core", strategy: "core"),
            makePortfolio(id: edgeId, name: "Edge", strategy: "edge"),
        ]
        svc.navHistory = [
            coreId: [makeNav(portfolioId: coreId, date: "2026-03-30", nav: 100_000)],
            edgeId: [makeNav(portfolioId: edgeId, date: "2026-03-30", nav: 75_000)],
        ]
        let vm = makeVM(service: svc)

        await vm.loadOverview()

        XCTAssertNotNil(vm.corePortfolio)
        XCTAssertNotNil(vm.edgePortfolio)
        XCTAssertNil(vm.alphaPortfolio)
        XCTAssertTrue(vm.alphaNav.isEmpty)
    }

    // ── F. Computed Properties ──

    func testReturnPctCalculation() {
        // returnPct = ((nav / 50000) - 1) * 100
        let nav = makeNav(portfolioId: coreId, date: "2026-01-01", nav: 1_588_367)
        XCTAssertEqual(nav.returnPct, 3076.734, accuracy: 0.01)
    }

    func testBenchmarkReturnPctCalculation() {
        let bench = makeBenchmark(date: "2026-01-01", nav: 142_164)
        XCTAssertEqual(bench.returnPct, 184.328, accuracy: 0.01)
    }
}
