import Foundation
import Supabase

// MARK: - Supabase Database Helper
/// Database helper for Supabase operations.
/// Note: This is a stub implementation. Full implementation requires matching
/// the current Supabase Swift SDK API version.
actor SupabaseDatabase {
    // MARK: - Singleton
    static let shared = SupabaseDatabase()

    // MARK: - Init
    private init() {}

    // MARK: - Generic Select (simplified)
    func select<T: Decodable>(
        from table: SupabaseTable,
        columns: String = "*"
    ) async throws -> [T] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(table.rawValue)
            .select(columns)
            .execute()
            .value
    }

    // MARK: - Select with filter
    func selectWithFilter<T: Decodable>(
        from table: SupabaseTable,
        column: String,
        value: String,
        columns: String = "*"
    ) async throws -> [T] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(table.rawValue)
            .select(columns)
            .eq(column, value: value)
            .execute()
            .value
    }

    // MARK: - Insert
    func insert<T: Encodable>(
        into table: SupabaseTable,
        values: T
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .insert(values)
            .execute()
    }

    // MARK: - Update
    func update<T: Encodable>(
        in table: SupabaseTable,
        values: T,
        id: String
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .update(values)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Delete
    func delete(
        from table: SupabaseTable,
        id: String
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Convenience Extensions
extension SupabaseDatabase {
    // Profile Operations
    func getProfile(userId: UUID) async throws -> ProfileDTO? {
        let results: [ProfileDTO] = try await selectWithFilter(
            from: .profiles,
            column: "id",
            value: userId.uuidString
        )
        return results.first
    }

    // Portfolio Operations
    func getPortfolios(userId: UUID) async throws -> [PortfolioDTO] {
        try await selectWithFilter(
            from: .portfolios,
            column: "user_id",
            value: userId.uuidString
        )
    }

    // DCA Reminders
    func getDCAReminders(userId: UUID) async throws -> [DCAReminder] {
        try await selectWithFilter(
            from: .dcaReminders,
            column: "user_id",
            value: userId.uuidString
        )
    }

    // Chat Sessions
    func getChatSessions(userId: UUID) async throws -> [ChatSessionDTO] {
        try await selectWithFilter(
            from: .chatSessions,
            column: "user_id",
            value: userId.uuidString
        )
    }

    // MARK: - App Store Rankings

    /// Save today's ranking (upsert - update if exists, insert if not)
    func saveAppStoreRanking(_ ranking: AppStoreRankingDTO) async throws {
        guard SupabaseManager.shared.isConfigured else {
            print("⚠️ Supabase not configured - skipping save")
            return
        }
        let client = SupabaseManager.shared.client

        // Check if we already have a record for this date and app
        let existing: [AppStoreRankingDTO] = try await client
            .from(SupabaseTable.appStoreRankings.rawValue)
            .select("*")
            .eq("app_name", value: ranking.appName)
            .eq("recorded_date", value: ranking.recordedDate)
            .execute()
            .value

        if existing.isEmpty {
            // Insert new record
            try await client
                .from(SupabaseTable.appStoreRankings.rawValue)
                .insert(ranking)
                .execute()
            print("📊 Saved new App Store ranking for \(ranking.recordedDate): \(ranking.rankDisplay)")
        } else {
            print("📊 App Store ranking already exists for \(ranking.recordedDate)")
        }
    }

    /// Get historical rankings for an app (sorted by date descending)
    func getAppStoreRankings(appName: String, limit: Int = 30) async throws -> [AppStoreRankingDTO] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.appStoreRankings.rawValue)
            .select("*")
            .eq("app_name", value: appName)
            .order("recorded_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Get all historical rankings (sorted by date descending)
    func getAllAppStoreRankings(limit: Int = 90) async throws -> [AppStoreRankingDTO] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.appStoreRankings.rawValue)
            .select("*")
            .order("recorded_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Supply in Profit Data

    /// Save supply in profit data points using upsert (fast batch operation)
    func saveSupplyInProfitData(_ dataPoints: [SupplyProfitDTO]) async throws {
        guard SupabaseManager.shared.isConfigured else {
            logWarning("Supabase not configured - skipping save", category: .network)
            return
        }
        guard !dataPoints.isEmpty else { return }

        let client = SupabaseManager.shared.client

        // Use upsert with onConflict to handle duplicates efficiently
        try await client
            .from(SupabaseTable.supplyInProfit.rawValue)
            .upsert(dataPoints, onConflict: "date")
            .execute()

        logInfo("Upserted \(dataPoints.count) Supply in Profit data points", category: .network)
    }

    /// Get supply in profit data from Supabase (sorted by date descending)
    func getSupplyInProfitData(limit: Int = 365) async throws -> [SupplyProfitDTO] {
        guard SupabaseManager.shared.isConfigured else { return [] }
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.supplyInProfit.rawValue)
            .select("*")
            .order("date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Get supply in profit data for a specific date range
    func getSupplyInProfitData(from startDate: String, to endDate: String) async throws -> [SupplyProfitDTO] {
        guard SupabaseManager.shared.isConfigured else { return [] }
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.supplyInProfit.rawValue)
            .select("*")
            .gte("date", value: startDate)
            .lte("date", value: endDate)
            .order("date", ascending: false)
            .execute()
            .value
    }

    /// Get the latest supply in profit data point
    func getLatestSupplyInProfitData() async throws -> SupplyProfitDTO? {
        guard SupabaseManager.shared.isConfigured else { return nil }
        let client = SupabaseManager.shared.client
        let results: [SupplyProfitDTO] = try await client
            .from(SupabaseTable.supplyInProfit.rawValue)
            .select("*")
            .order("date", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    /// Get dates we already have in the database
    func getExistingSupplyInProfitDates() async throws -> Set<String> {
        guard SupabaseManager.shared.isConfigured else { return [] }
        let client = SupabaseManager.shared.client
        let results: [SupplyProfitDTO] = try await client
            .from(SupabaseTable.supplyInProfit.rawValue)
            .select("date")
            .execute()
            .value
        return Set(results.map { $0.date })
    }

    // MARK: - Google Trends History

    /// Save today's Google Trends data (upsert - update if exists, insert if not)
    func saveGoogleTrends(_ trends: GoogleTrendsDTO) async throws {
        guard SupabaseManager.shared.isConfigured else {
            logWarning("Supabase not configured - skipping Google Trends save", category: .network)
            return
        }
        let client = SupabaseManager.shared.client

        // Check if we already have a record for this date
        let existing: [GoogleTrendsDTO] = try await client
            .from(SupabaseTable.googleTrendsHistory.rawValue)
            .select("*")
            .eq("recorded_date", value: trends.recordedDate)
            .execute()
            .value

        if existing.isEmpty {
            // Insert new record
            try await client
                .from(SupabaseTable.googleTrendsHistory.rawValue)
                .insert(trends)
                .execute()
            logInfo("Saved new Google Trends data for \(trends.recordedDate): \(trends.searchIndex)", category: .network)
        } else if let existingRecord = existing.first, existingRecord.searchIndex != trends.searchIndex {
            // Update if value changed (rare but possible for same-day updates)
            let updateData = GoogleTrendsUpdateDTO(searchIndex: trends.searchIndex, btcPrice: trends.btcPrice)
            try await client
                .from(SupabaseTable.googleTrendsHistory.rawValue)
                .update(updateData)
                .eq("recorded_date", value: trends.recordedDate)
                .execute()
            logInfo("Updated Google Trends data for \(trends.recordedDate): \(trends.searchIndex)", category: .network)
        }
    }

    /// Get historical Google Trends data (sorted by date descending)
    func getGoogleTrendsHistory(limit: Int = 30) async throws -> [GoogleTrendsDTO] {
        guard SupabaseManager.shared.isConfigured else { return [] }
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.googleTrendsHistory.rawValue)
            .select("*")
            .order("recorded_date", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    /// Get the latest Google Trends data point
    func getLatestGoogleTrends() async throws -> GoogleTrendsDTO? {
        guard SupabaseManager.shared.isConfigured else { return nil }
        let client = SupabaseManager.shared.client
        let results: [GoogleTrendsDTO] = try await client
            .from(SupabaseTable.googleTrendsHistory.rawValue)
            .select("*")
            .order("recorded_date", ascending: false)
            .limit(1)
            .execute()
            .value
        return results.first
    }

    /// Get Google Trends data for a specific date range
    func getGoogleTrendsHistory(from startDate: String, to endDate: String) async throws -> [GoogleTrendsDTO] {
        guard SupabaseManager.shared.isConfigured else { return [] }
        let client = SupabaseManager.shared.client
        return try await client
            .from(SupabaseTable.googleTrendsHistory.rawValue)
            .select("*")
            .gte("recorded_date", value: startDate)
            .lte("recorded_date", value: endDate)
            .order("recorded_date", ascending: false)
            .execute()
            .value
    }
}

// MARK: - DTO Types for Database
struct ProfileDTO: Codable {
    let id: UUID
    let username: String?
    let email: String?
    let fullName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

struct PortfolioDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case isPublic = "is_public"
    }
}

struct ChatSessionDTO: Codable {
    let id: UUID
    let userId: UUID
    let title: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - App Store Ranking DTO
struct AppStoreRankingDTO: Codable {
    let id: UUID
    let appName: String
    let ranking: Int? // nil means not in top 200
    let btcPrice: Double?
    let recordedDate: String // YYYY-MM-DD format
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case ranking
        case btcPrice = "btc_price"
        case recordedDate = "recorded_date"
        case createdAt = "created_at"
    }

    // Create from current ranking data
    init(appName: String, ranking: Int?, btcPrice: Double?, date: Date = Date()) {
        self.id = UUID()
        self.appName = appName
        self.ranking = ranking
        self.btcPrice = btcPrice

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.recordedDate = formatter.string(from: date)
        self.createdAt = Date()
    }

    // For decoding from database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        ranking = try container.decodeIfPresent(Int.self, forKey: .ranking)
        btcPrice = try container.decodeIfPresent(Double.self, forKey: .btcPrice)
        recordedDate = try container.decode(String.self, forKey: .recordedDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // Computed properties for display
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: recordedDate) ?? Date()
    }

    var rankDisplay: String {
        if let rank = ranking, rank > 0 {
            return "#\(rank)"
        }
        return ">200"
    }

    var btcPriceDisplay: String {
        if let price = btcPrice {
            return "$\(Int(price).formatted())"
        }
        return "--"
    }

    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: recordedDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return recordedDate
    }

    var isRanked: Bool {
        guard let rank = ranking else { return false }
        return rank > 0
    }
}

// MARK: - Google Trends DTO
struct GoogleTrendsDTO: Codable {
    let id: UUID
    let searchIndex: Int // 0-100 relative search interest
    let btcPrice: Double?
    let recordedDate: String // YYYY-MM-DD format
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case searchIndex = "search_index"
        case btcPrice = "btc_price"
        case recordedDate = "recorded_date"
        case createdAt = "created_at"
    }

    // Create from current data
    init(searchIndex: Int, btcPrice: Double?, date: Date = Date()) {
        self.id = UUID()
        self.searchIndex = searchIndex
        self.btcPrice = btcPrice

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.recordedDate = formatter.string(from: date)
        self.createdAt = Date()
    }

    // For decoding from database
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        searchIndex = try container.decode(Int.self, forKey: .searchIndex)
        btcPrice = try container.decodeIfPresent(Double.self, forKey: .btcPrice)
        recordedDate = try container.decode(String.self, forKey: .recordedDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // Computed properties for display
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: recordedDate) ?? Date()
    }

    var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: recordedDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return recordedDate
    }

    var shortDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: recordedDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d"
            return displayFormatter.string(from: date)
        }
        return recordedDate
    }

    var btcPriceDisplay: String {
        if let price = btcPrice {
            return "$\(Int(price).formatted())"
        }
        return "--"
    }
}

// MARK: - Google Trends Update DTO (for partial updates)
struct GoogleTrendsUpdateDTO: Codable {
    let searchIndex: Int
    let btcPrice: Double?

    enum CodingKeys: String, CodingKey {
        case searchIndex = "search_index"
        case btcPrice = "btc_price"
    }
}
