import Foundation

// MARK: - API Portfolio Service
/// Real API implementation of PortfolioServiceProtocol.
/// Uses Supabase for portfolio data storage.
final class APIPortfolioService: PortfolioServiceProtocol {
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared
    private let marketService: MarketServiceProtocol

    // MARK: - Initialization
    init(marketService: MarketServiceProtocol = APIMarketService()) {
        self.marketService = marketService
    }

    // MARK: - PortfolioServiceProtocol

    func fetchPortfolio(userId: UUID) async throws -> Portfolio? {
        // TODO: Implement with Supabase
        // Query: select * from portfolios where user_id = userId limit 1
        throw AppError.notImplemented
    }

    func fetchHoldings(portfolioId: UUID) async throws -> [PortfolioHolding] {
        // TODO: Implement with Supabase
        // Query: select * from portfolio_holdings where portfolio_id = portfolioId
        throw AppError.notImplemented
    }

    func fetchTransactions(portfolioId: UUID) async throws -> [Transaction] {
        // TODO: Implement with Supabase
        // Query: select * from transactions where portfolio_id = portfolioId order by transaction_date desc
        throw AppError.notImplemented
    }

    func fetchPortfolioHistory(portfolioId: UUID, days: Int) async throws -> [PortfolioHistoryPoint] {
        // TODO: Implement with Supabase
        // Query: select * from portfolio_history where portfolio_id = portfolioId and date >= (now - days)
        throw AppError.notImplemented
    }

    func createPortfolio(_ portfolio: Portfolio) async throws -> Portfolio {
        // TODO: Implement with Supabase
        // Insert into portfolios table
        throw AppError.notImplemented
    }

    func updatePortfolio(_ portfolio: Portfolio) async throws {
        // TODO: Implement with Supabase
        // Update portfolios where id = portfolio.id
        throw AppError.notImplemented
    }

    func deletePortfolio(portfolioId: UUID) async throws {
        // TODO: Implement with Supabase
        // Delete cascade: holdings and transactions first, then portfolio
        throw AppError.notImplemented
    }

    func addHolding(_ holding: PortfolioHolding) async throws -> PortfolioHolding {
        // TODO: Implement with Supabase
        // Insert into portfolio_holdings
        throw AppError.notImplemented
    }

    func updateHolding(_ holding: PortfolioHolding) async throws {
        // TODO: Implement with Supabase
        // Update portfolio_holdings where id = holding.id
        throw AppError.notImplemented
    }

    func deleteHolding(holdingId: UUID) async throws {
        // TODO: Implement with Supabase
        // Delete from portfolio_holdings where id = holdingId
        throw AppError.notImplemented
    }

    func addTransaction(_ transaction: Transaction) async throws -> Transaction {
        // TODO: Implement with Supabase
        // Insert into transactions and update holding accordingly
        throw AppError.notImplemented
    }

    func deleteTransaction(transactionId: UUID) async throws {
        // TODO: Implement with Supabase
        // Delete from transactions where id = transactionId
        throw AppError.notImplemented
    }

    func refreshHoldingPrices(holdings: [PortfolioHolding]) async throws -> [PortfolioHolding] {
        // Group holdings by asset type
        var updatedHoldings = holdings

        // Separate by asset type
        let cryptoSymbols = holdings.filter { $0.assetType == "crypto" }.map { $0.symbol.lowercased() }
        let stockSymbols = holdings.filter { $0.assetType == "stock" }.map { $0.symbol }
        let metalSymbols = holdings.filter { $0.assetType == "metal" }.map { $0.symbol }

        // Fetch prices concurrently
        async let cryptoPrices = fetchCryptoPrices(symbols: cryptoSymbols)
        async let stockPrices = fetchStockPrices(symbols: stockSymbols)
        async let metalPrices = fetchMetalPrices(symbols: metalSymbols)

        let (crypto, stocks, metals) = try await (cryptoPrices, stockPrices, metalPrices)

        // Update holdings with live prices
        for i in updatedHoldings.indices {
            let holding = updatedHoldings[i]

            switch holding.assetType {
            case "crypto":
                if let priceData = crypto[holding.symbol.lowercased()] {
                    updatedHoldings[i].currentPrice = priceData.price
                    updatedHoldings[i].priceChangePercentage24h = priceData.change24h
                }
            case "stock":
                if let priceData = stocks[holding.symbol.uppercased()] {
                    updatedHoldings[i].currentPrice = priceData.price
                    updatedHoldings[i].priceChangePercentage24h = priceData.change24h
                }
            case "metal":
                if let priceData = metals[holding.symbol.uppercased()] {
                    updatedHoldings[i].currentPrice = priceData.price
                    updatedHoldings[i].priceChangePercentage24h = priceData.change24h
                }
            default:
                break
            }
        }

        return updatedHoldings
    }

    // MARK: - Private Helpers

    private func fetchCryptoPrices(symbols: [String]) async throws -> [String: (price: Double, change24h: Double)] {
        guard !symbols.isEmpty else { return [:] }

        let assets = try await marketService.fetchCryptoAssets(page: 1, perPage: 100)
        var prices: [String: (price: Double, change24h: Double)] = [:]

        for asset in assets {
            if symbols.contains(asset.id) || symbols.contains(asset.symbol.lowercased()) {
                prices[asset.id] = (asset.currentPrice, asset.priceChangePercentage24h)
            }
        }

        return prices
    }

    private func fetchStockPrices(symbols: [String]) async throws -> [String: (price: Double, change24h: Double)] {
        guard !symbols.isEmpty else { return [:] }

        let assets = try await marketService.fetchStockAssets(symbols: symbols)
        var prices: [String: (price: Double, change24h: Double)] = [:]

        for asset in assets {
            prices[asset.symbol] = (asset.currentPrice, asset.priceChangePercentage24h)
        }

        return prices
    }

    private func fetchMetalPrices(symbols: [String]) async throws -> [String: (price: Double, change24h: Double)] {
        guard !symbols.isEmpty else { return [:] }

        let assets = try await marketService.fetchMetalAssets(symbols: symbols)
        var prices: [String: (price: Double, change24h: Double)] = [:]

        for asset in assets {
            prices[asset.symbol] = (asset.currentPrice, asset.priceChangePercentage24h)
        }

        return prices
    }
}
