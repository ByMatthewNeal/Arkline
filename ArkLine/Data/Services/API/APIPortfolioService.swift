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

    // MARK: - Fetch Portfolios

    func fetchPortfolios(userId: UUID) async throws -> [Portfolio] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let portfolios: [Portfolio] = try await supabase.database
                .from(SupabaseTable.portfolios.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(portfolios.count) portfolios", category: .data)
            return portfolios
        } catch {
            logError(error, context: "Fetch portfolios", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    func fetchPortfolio(userId: UUID) async throws -> Portfolio? {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return nil
        }

        do {
            let portfolios: [Portfolio] = try await supabase.database
                .from(SupabaseTable.portfolios.rawValue)
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: true)
                .limit(1)
                .execute()
                .value

            return portfolios.first
        } catch {
            logError(error, context: "Fetch primary portfolio", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Fetch Holdings

    func fetchHoldings(portfolioId: UUID) async throws -> [PortfolioHolding] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let holdings: [PortfolioHolding] = try await supabase.database
                .from(SupabaseTable.holdings.rawValue)
                .select()
                .eq("portfolio_id", value: portfolioId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(holdings.count) holdings for portfolio", category: .data)
            return holdings
        } catch {
            logError(error, context: "Fetch holdings", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Fetch Transactions

    func fetchTransactions(portfolioId: UUID) async throws -> [Transaction] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured", category: .network)
            return []
        }

        do {
            let transactions: [Transaction] = try await supabase.database
                .from(SupabaseTable.transactions.rawValue)
                .select()
                .eq("portfolio_id", value: portfolioId.uuidString)
                .order("transaction_date", ascending: false)
                .execute()
                .value

            logInfo("Fetched \(transactions.count) transactions", category: .data)
            return transactions
        } catch {
            logError(error, context: "Fetch transactions", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Fetch Portfolio History

    func fetchPortfolioHistory(portfolioId: UUID, days: Int) async throws -> [PortfolioHistoryPoint] {
        // Portfolio history tracking requires a separate table or can be computed
        // For now, return empty array - can be implemented with a portfolio_history table later
        logInfo("Portfolio history not yet implemented - returning empty", category: .data)
        return []
    }

    // MARK: - Create Portfolio

    func createPortfolio(_ portfolio: Portfolio) async throws -> Portfolio {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let createdPortfolios: [Portfolio] = try await supabase.database
                .from(SupabaseTable.portfolios.rawValue)
                .insert(portfolio)
                .select()
                .execute()
                .value

            guard let created = createdPortfolios.first else {
                throw AppError.custom(message: "Failed to create portfolio")
            }

            logInfo("Created portfolio: \(created.name)", category: .data)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Create portfolio", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Update Portfolio

    func updatePortfolio(_ portfolio: Portfolio) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.portfolios.rawValue)
                .update(portfolio)
                .eq("id", value: portfolio.id.uuidString)
                .execute()

            logInfo("Updated portfolio: \(portfolio.name)", category: .data)
        } catch {
            logError(error, context: "Update portfolio", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Delete Portfolio

    func deletePortfolio(portfolioId: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            // Holdings and transactions cascade delete due to ON DELETE CASCADE
            try await supabase.database
                .from(SupabaseTable.portfolios.rawValue)
                .delete()
                .eq("id", value: portfolioId.uuidString)
                .execute()

            logInfo("Deleted portfolio: \(portfolioId)", category: .data)
        } catch {
            logError(error, context: "Delete portfolio", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Add Holding

    func addHolding(_ holding: PortfolioHolding) async throws -> PortfolioHolding {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let createdHoldings: [PortfolioHolding] = try await supabase.database
                .from(SupabaseTable.holdings.rawValue)
                .insert(holding)
                .select()
                .execute()
                .value

            guard let created = createdHoldings.first else {
                throw AppError.custom(message: "Failed to create holding")
            }

            logInfo("Added holding: \(created.symbol)", category: .data)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Add holding", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Update Holding

    func updateHolding(_ holding: PortfolioHolding) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.holdings.rawValue)
                .update(holding)
                .eq("id", value: holding.id.uuidString)
                .execute()

            logInfo("Updated holding: \(holding.symbol)", category: .data)
        } catch {
            logError(error, context: "Update holding", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Delete Holding

    func deleteHolding(holdingId: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.holdings.rawValue)
                .delete()
                .eq("id", value: holdingId.uuidString)
                .execute()

            logInfo("Deleted holding: \(holdingId)", category: .data)
        } catch {
            logError(error, context: "Delete holding", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Add Transaction

    func addTransaction(_ transaction: Transaction) async throws -> Transaction {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            let createdTransactions: [Transaction] = try await supabase.database
                .from(SupabaseTable.transactions.rawValue)
                .insert(transaction)
                .select()
                .execute()
                .value

            guard let created = createdTransactions.first else {
                throw AppError.custom(message: "Failed to create transaction")
            }

            logInfo("Added transaction: \(created.type.rawValue) \(created.symbol)", category: .data)
            return created
        } catch let error as AppError {
            throw error
        } catch {
            logError(error, context: "Add transaction", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Delete Transaction

    func deleteTransaction(transactionId: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.networkError(underlying: NSError(domain: "SupabaseNotConfigured", code: 0))
        }

        do {
            try await supabase.database
                .from(SupabaseTable.transactions.rawValue)
                .delete()
                .eq("id", value: transactionId.uuidString)
                .execute()

            logInfo("Deleted transaction: \(transactionId)", category: .data)
        } catch {
            logError(error, context: "Delete transaction", category: .data)
            throw AppError.networkError(underlying: error)
        }
    }

    // MARK: - Refresh Holding Prices

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
