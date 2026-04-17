import Foundation

// MARK: - API Model Portfolio Service

final class APIModelPortfolioService: ModelPortfolioServiceProtocol {

    private let supabase = SupabaseManager.shared

    init() {}

    func fetchPortfolios() async throws -> [ModelPortfolio] {
        guard supabase.isConfigured else { return [] }

        let portfolios: [ModelPortfolio] = try await supabase.database
            .from(SupabaseTable.modelPortfolios.rawValue)
            .select()
            .order("strategy", ascending: true)
            .execute()
            .value

        return portfolios
    }

    func fetchNavHistory(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioNav] {
        guard supabase.isConfigured else { return [] }

        // Supabase caps at 1000 rows per request — paginate for larger fetches
        if limit <= 1000 {
            let rows: [ModelPortfolioNav] = try await supabase.database
                .from(SupabaseTable.modelPortfolioNav.rawValue)
                .select()
                .eq("portfolio_id", value: portfolioId.uuidString)
                .order("nav_date", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.reversed()
        }

        var allRows: [ModelPortfolioNav] = []
        var offset = 0
        let pageSize = 1000
        while offset < limit {
            let rows: [ModelPortfolioNav] = try await supabase.database
                .from(SupabaseTable.modelPortfolioNav.rawValue)
                .select()
                .eq("portfolio_id", value: portfolioId.uuidString)
                .order("nav_date", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            allRows.append(contentsOf: rows)
            if rows.count < pageSize { break }
            offset += pageSize
        }
        return allRows.reversed()
    }

    func fetchLatestNav(portfolioId: UUID) async throws -> ModelPortfolioNav? {
        guard supabase.isConfigured else { return nil }

        let rows: [ModelPortfolioNav] = try await supabase.database
            .from(SupabaseTable.modelPortfolioNav.rawValue)
            .select()
            .eq("portfolio_id", value: portfolioId.uuidString)
            .order("nav_date", ascending: false)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchTrades(portfolioId: UUID, limit: Int) async throws -> [ModelPortfolioTrade] {
        guard supabase.isConfigured else { return [] }

        let rows: [ModelPortfolioTrade] = try await supabase.database
            .from(SupabaseTable.modelPortfolioTrades.rawValue)
            .select()
            .eq("portfolio_id", value: portfolioId.uuidString)
            .order("trade_date", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows
    }

    func fetchBenchmarkNav(limit: Int) async throws -> [BenchmarkNav] {
        guard supabase.isConfigured else { return [] }

        if limit <= 1000 {
            let rows: [BenchmarkNav] = try await supabase.database
                .from(SupabaseTable.benchmarkNav.rawValue)
                .select()
                .order("nav_date", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.reversed()
        }

        var allRows: [BenchmarkNav] = []
        var offset = 0
        let pageSize = 1000
        while offset < limit {
            let rows: [BenchmarkNav] = try await supabase.database
                .from(SupabaseTable.benchmarkNav.rawValue)
                .select()
                .order("nav_date", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            allRows.append(contentsOf: rows)
            if rows.count < pageSize { break }
            offset += pageSize
        }
        return allRows.reversed()
    }

    func fetchRiskHistory(asset: String, limit: Int) async throws -> [ModelPortfolioRiskHistory] {
        guard supabase.isConfigured else { return [] }

        if limit <= 1000 {
            let rows: [ModelPortfolioRiskHistory] = try await supabase.database
                .from(SupabaseTable.modelPortfolioRiskHistory.rawValue)
                .select()
                .eq("asset", value: asset)
                .order("risk_date", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.reversed()
        }

        var allRows: [ModelPortfolioRiskHistory] = []
        var offset = 0
        let pageSize = 1000
        while offset < limit {
            let rows: [ModelPortfolioRiskHistory] = try await supabase.database
                .from(SupabaseTable.modelPortfolioRiskHistory.rawValue)
                .select()
                .eq("asset", value: asset)
                .order("risk_date", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)
                .execute()
                .value
            allRows.append(contentsOf: rows)
            if rows.count < pageSize { break }
            offset += pageSize
        }
        return allRows.reversed()
    }
}
