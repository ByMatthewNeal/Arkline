import Foundation
import SwiftUI

// MARK: - Asset Update Data
/// Lightweight struct holding the data shown per asset on the Telegram card
struct AssetUpdateData: Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let price: Double
    let change24h: Double
    let sparkline: [Double]?
    let trend1H: AssetTrendDirection
    let trend4H: AssetTrendDirection
    let trend1D: AssetTrendDirection
    let rsi: Double
    let riskScore: MultiFactorRiskPoint?

    var isPositive: Bool { change24h >= 0 }
}

// MARK: - Daily Market Update ViewModel
@MainActor
@Observable
class DailyMarketUpdateViewModel {
    // MARK: - Dependencies
    private let marketService: MarketServiceProtocol
    private let technicalAnalysisService: TechnicalAnalysisServiceProtocol
    private let sentimentService: SentimentServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol
    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol

    // MARK: - State
    var isLoading = false
    var errorMessage: String?

    // Asset data
    var btcData: AssetUpdateData?
    var ethData: AssetUpdateData?

    // Market overview
    var fearGreedIndex: FearGreedIndex?
    var vixValue: Double?
    var vixDirection: TrendArrow = .flat
    var dxyValue: Double?
    var dxyDirection: TrendArrow = .flat

    enum TrendArrow: String {
        case up = "arrow.up"
        case down = "arrow.down"
        case flat = "arrow.right"

        var label: String {
            switch self {
            case .up: return "Up"
            case .down: return "Down"
            case .flat: return "Flat"
            }
        }

        var color: Color {
            switch self {
            case .up: return AppColors.success
            case .down: return AppColors.error
            case .flat: return AppColors.warning
            }
        }
    }

    enum CardSize: String, CaseIterable {
        case short = "Short"
        case medium = "Medium"
        case long = "Long"
    }

    enum AssetFilter: String, CaseIterable {
        case btcOnly = "BTC Only"
        case btcEth = "BTC + ETH"
    }

    // MARK: - Init
    init() {
        let container = ServiceContainer.shared
        self.marketService = container.marketService
        self.technicalAnalysisService = container.technicalAnalysisService
        self.sentimentService = container.sentimentService
        self.itcRiskService = container.itcRiskService
        self.vixService = container.vixService
        self.dxyService = container.dxyService
    }

    // MARK: - Load All Data
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadAssetData() }
            group.addTask { await self.loadMarketOverview() }
        }
    }

    // MARK: - Asset Data (BTC + ETH)
    private func loadAssetData() async {
        async let btcMarket = fetchAssetPrice(id: "bitcoin")
        async let ethMarket = fetchAssetPrice(id: "ethereum")
        async let btcTrends = fetchTrends(symbol: "BTC/USDT")
        async let ethTrends = fetchTrends(symbol: "ETH/USDT")
        async let btcRisk = fetchRiskScore(coin: "BTC")
        async let ethRisk = fetchRiskScore(coin: "ETH")

        let (btcAsset, ethAsset) = await (btcMarket, ethMarket)
        let (btcTrendData, ethTrendData) = await (btcTrends, ethTrends)
        let (btcRiskScore, ethRiskScore) = await (btcRisk, ethRisk)

        if let asset = btcAsset {
            btcData = AssetUpdateData(
                symbol: "BTC",
                name: "Bitcoin",
                price: asset.currentPrice,
                change24h: asset.priceChangePercentage24h,
                sparkline: asset.sparklinePrices,
                trend1H: btcTrendData.oneHour,
                trend4H: btcTrendData.fourHour,
                trend1D: btcTrendData.daily,
                rsi: btcTrendData.rsi,
                riskScore: btcRiskScore
            )
        }

        if let asset = ethAsset {
            ethData = AssetUpdateData(
                symbol: "ETH",
                name: "Ethereum",
                price: asset.currentPrice,
                change24h: asset.priceChangePercentage24h,
                sparkline: asset.sparklinePrices,
                trend1H: ethTrendData.oneHour,
                trend4H: ethTrendData.fourHour,
                trend1D: ethTrendData.daily,
                rsi: ethTrendData.rsi,
                riskScore: ethRiskScore
            )
        }
    }

    private func fetchRiskScore(coin: String) async -> MultiFactorRiskPoint? {
        do {
            return try await itcRiskService.calculateMultiFactorRisk(coin: coin)
        } catch {
            logWarning("Failed to fetch \(coin) risk score: \(error)", category: .network)
            return nil
        }
    }

    private func fetchAssetPrice(id: String) async -> CryptoAsset? {
        do {
            let assets = try await marketService.fetchCryptoAssets(page: 1, perPage: 10)
            return assets.first { $0.id == id }
        } catch {
            logWarning("Failed to fetch \(id) price: \(error)", category: .network)
            return nil
        }
    }

    private struct TrendResult {
        let oneHour: AssetTrendDirection
        let fourHour: AssetTrendDirection
        let daily: AssetTrendDirection
        let rsi: Double
    }

    private func fetchTrends(symbol: String) async -> TrendResult {
        async let ta1H = fetchTrend(symbol: symbol, interval: .oneHour)
        async let ta4H = fetchTrend(symbol: symbol, interval: .fourHour)
        async let ta1D = fetchTrend(symbol: symbol, interval: .daily)

        let (trend1H, trend4H, trend1D) = await (ta1H, ta4H, ta1D)

        return TrendResult(
            oneHour: trend1H?.trend.direction ?? .sideways,
            fourHour: trend4H?.trend.direction ?? .sideways,
            daily: trend1D?.trend.direction ?? .sideways,
            rsi: trend1D?.rsi.value ?? 50
        )
    }

    private func fetchTrend(symbol: String, interval: AnalysisTimeframe) async -> TechnicalAnalysis? {
        do {
            return try await technicalAnalysisService.fetchTechnicalAnalysis(
                symbol: symbol,
                exchange: "binance",
                interval: interval
            )
        } catch {
            logWarning("Failed to fetch \(symbol) \(interval.label) trend: \(error)", category: .network)
            return nil
        }
    }

    // MARK: - Market Overview
    private func loadMarketOverview() async {
        async let fgTask = loadFearGreed()
        async let macroTask = loadMacroIndicators()

        _ = await (fgTask, macroTask)
    }

    private func loadFearGreed() async {
        do {
            fearGreedIndex = try await sentimentService.fetchFearGreedIndex()
        } catch {
            logWarning("Failed to fetch Fear & Greed: \(error)", category: .network)
        }
    }

    private func loadMacroIndicators() async {
        do {
            if let vixData = try await vixService.fetchLatestVIX() {
                let vixHistory = try await vixService.fetchVIXHistory(days: 7)
                self.vixValue = vixData.value
                if let prev = vixHistory.dropLast().last {
                    self.vixDirection = vixData.value > prev.value ? .up : (vixData.value < prev.value ? .down : .flat)
                }
            }
        } catch {
            logWarning("Failed to fetch VIX: \(error)", category: .network)
        }

        do {
            if let dxyData = try await dxyService.fetchLatestDXY() {
                let dxyHistory = try await dxyService.fetchDXYHistory(days: 7)
                self.dxyValue = dxyData.value
                if let prev = dxyHistory.dropLast().last {
                    self.dxyDirection = dxyData.value > prev.value ? .up : (dxyData.value < prev.value ? .down : .flat)
                }
            }
        } catch {
            logWarning("Failed to fetch DXY: \(error)", category: .network)
        }
    }
}
