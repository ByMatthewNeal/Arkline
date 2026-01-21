import Foundation

// MARK: - DCA Type
/// Distinguishes between time-based and risk-based DCA strategies.
/// TODO: [Agent 3] - Move this enum to Domain/Models/DCAReminder.swift
enum DCAType: String, Codable, CaseIterable {
    case timeBased = "time_based"
    case riskBased = "risk_based"

    var displayName: String {
        switch self {
        case .timeBased: return "Time-Based"
        case .riskBased: return "Risk-Based"
        }
    }
}

// MARK: - Risk Condition
/// Defines when a risk-based DCA should trigger.
/// TODO: [Agent 3] - Move this enum to Domain/Models/DCAReminder.swift
enum RiskCondition: String, Codable, CaseIterable {
    case above = "above"
    case below = "below"

    var displayName: String {
        switch self {
        case .above: return "Above"
        case .below: return "Below"
        }
    }

    var description: String {
        switch self {
        case .above: return "Risk rises above threshold"
        case .below: return "Risk falls below threshold"
        }
    }
}

// MARK: - Asset Risk Level
/// Represents the current risk level of an asset (0-100 scale).
/// TODO: [Agent 3] - Move this struct to Domain/Models/RiskMetrics.swift
struct AssetRiskLevel: Codable, Equatable {
    let assetId: String
    let symbol: String
    let riskScore: Double // 0-100 scale
    let riskCategory: RiskCategory
    let lastUpdated: Date

    var formattedScore: String {
        String(format: "%.0f", riskScore)
    }
}

// MARK: - Risk Category
/// Categorical representation of risk levels.
/// TODO: [Agent 3] - Move this enum to Domain/Models/RiskMetrics.swift
enum RiskCategory: String, Codable {
    case veryLow = "very_low"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"

    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    var colorName: String {
        switch self {
        case .veryLow, .low: return "success"
        case .moderate: return "warning"
        case .high, .veryHigh: return "error"
        }
    }

    static func from(score: Double) -> RiskCategory {
        switch score {
        case 0..<20: return .veryLow
        case 20..<40: return .low
        case 40..<60: return .moderate
        case 60..<80: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Risk-Based DCA Reminder
/// Extended DCA reminder with risk-based fields.
/// TODO: [Agent 3] - Add these fields to DCAReminder model:
///   - dcaType: DCAType (default: .timeBased)
///   - riskThreshold: Double? (0-100 scale, nil for time-based)
///   - riskCondition: RiskCondition? (nil for time-based)
///   - isTriggered: Bool (anti-spam flag, resets when condition no longer met)
///   - lastTriggeredRiskLevel: Double?
struct RiskBasedDCAReminder: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var symbol: String
    var name: String
    var amount: Double
    var dcaType: DCAType
    var riskThreshold: Double
    var riskCondition: RiskCondition
    var isTriggered: Bool
    var lastTriggeredRiskLevel: Double?
    var isActive: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        symbol: String,
        name: String,
        amount: Double,
        riskThreshold: Double,
        riskCondition: RiskCondition,
        isTriggered: Bool = false,
        lastTriggeredRiskLevel: Double? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.symbol = symbol
        self.name = name
        self.amount = amount
        self.dcaType = .riskBased
        self.riskThreshold = riskThreshold
        self.riskCondition = riskCondition
        self.isTriggered = isTriggered
        self.lastTriggeredRiskLevel = lastTriggeredRiskLevel
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var formattedAmount: String {
        amount.asCurrency
    }

    var triggerDescription: String {
        "When risk \(riskCondition.displayName.lowercased()) \(Int(riskThreshold))%"
    }

    func shouldTrigger(currentRisk: Double) -> Bool {
        guard isActive, !isTriggered else { return false }

        switch riskCondition {
        case .above:
            return currentRisk >= riskThreshold
        case .below:
            return currentRisk <= riskThreshold
        }
    }
}

// MARK: - Create Risk-Based DCA Request
/// Request to create a new risk-based DCA reminder.
struct CreateRiskBasedDCARequest: Encodable {
    let userId: UUID
    let symbol: String
    let name: String
    let amount: Double
    let riskThreshold: Double
    let riskCondition: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case symbol
        case name
        case amount
        case riskThreshold = "risk_threshold"
        case riskCondition = "risk_condition"
    }
}

// MARK: - Risk DCA Investment Record
/// Records when a risk-based DCA was executed.
struct RiskDCAInvestment: Codable, Identifiable {
    let id: UUID
    let reminderId: UUID
    let amount: Double
    let priceAtPurchase: Double
    let quantity: Double
    let riskLevelAtPurchase: Double
    let purchaseDate: Date

    enum CodingKeys: String, CodingKey {
        case id
        case reminderId = "reminder_id"
        case amount
        case priceAtPurchase = "price_at_purchase"
        case quantity
        case riskLevelAtPurchase = "risk_level_at_purchase"
        case purchaseDate = "purchase_date"
    }

    var formattedAmount: String {
        amount.asCurrency
    }

    var formattedRiskLevel: String {
        String(format: "%.0f%%", riskLevelAtPurchase)
    }
}

// MARK: - DCA Service Protocol
/// Protocol defining DCA (Dollar Cost Averaging) reminder operations.
protocol DCAServiceProtocol {
    /// Fetches all DCA reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of DCAReminder
    func fetchReminders(userId: UUID) async throws -> [DCAReminder]

    /// Fetches active DCA reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of active DCAReminder
    func fetchActiveReminders(userId: UUID) async throws -> [DCAReminder]

    /// Fetches reminders due today
    /// - Parameter userId: User identifier
    /// - Returns: Array of DCAReminder due today
    func fetchTodayReminders(userId: UUID) async throws -> [DCAReminder]

    /// Creates a new DCA reminder
    /// - Parameter request: CreateDCARequest with reminder details
    /// - Returns: Created DCAReminder
    func createReminder(_ request: CreateDCARequest) async throws -> DCAReminder

    /// Updates an existing DCA reminder
    /// - Parameter reminder: DCAReminder with updated values
    func updateReminder(_ reminder: DCAReminder) async throws

    /// Deletes a DCA reminder
    /// - Parameter id: Reminder identifier to delete
    func deleteReminder(id: UUID) async throws

    /// Marks a reminder as invested (increments completed purchases)
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder
    func markAsInvested(id: UUID) async throws -> DCAReminder

    /// Skips the current reminder occurrence
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder with next date calculated
    func skipReminder(id: UUID) async throws -> DCAReminder

    /// Toggles the active state of a reminder
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated DCAReminder
    func toggleReminder(id: UUID) async throws -> DCAReminder

    /// Fetches investment history for a reminder
    /// - Parameter reminderId: Reminder identifier
    /// - Returns: Array of DCAInvestment
    func fetchInvestmentHistory(reminderId: UUID) async throws -> [DCAInvestment]

    // MARK: - Risk-Based DCA Methods

    /// Fetches all risk-based DCA reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of RiskBasedDCAReminder
    func fetchRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder]

    /// Fetches active risk-based reminders for a user
    /// - Parameter userId: User identifier
    /// - Returns: Array of active RiskBasedDCAReminder
    func fetchActiveRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder]

    /// Fetches triggered risk-based reminders (ready for investment action)
    /// - Parameter userId: User identifier
    /// - Returns: Array of triggered RiskBasedDCAReminder
    func fetchTriggeredReminders(userId: UUID) async throws -> [RiskBasedDCAReminder]

    /// Creates a new risk-based DCA reminder
    /// - Parameter request: CreateRiskBasedDCARequest with reminder details
    /// - Returns: Created RiskBasedDCAReminder
    func createRiskBasedReminder(_ request: CreateRiskBasedDCARequest) async throws -> RiskBasedDCAReminder

    /// Updates an existing risk-based DCA reminder
    /// - Parameter reminder: RiskBasedDCAReminder with updated values
    func updateRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async throws

    /// Deletes a risk-based DCA reminder
    /// - Parameter id: Reminder identifier to delete
    func deleteRiskBasedReminder(id: UUID) async throws

    /// Marks a risk-based reminder as invested and resets the trigger
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated RiskBasedDCAReminder
    func markRiskBasedAsInvested(id: UUID) async throws -> RiskBasedDCAReminder

    /// Resets the triggered state (used when risk condition no longer met)
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated RiskBasedDCAReminder
    func resetTrigger(id: UUID) async throws -> RiskBasedDCAReminder

    /// Toggles the active state of a risk-based reminder
    /// - Parameter id: Reminder identifier
    /// - Returns: Updated RiskBasedDCAReminder
    func toggleRiskBasedReminder(id: UUID) async throws -> RiskBasedDCAReminder

    /// Fetches investment history for a risk-based reminder
    /// - Parameter reminderId: Reminder identifier
    /// - Returns: Array of RiskDCAInvestment
    func fetchRiskBasedInvestmentHistory(reminderId: UUID) async throws -> [RiskDCAInvestment]

    /// Fetches current risk level for an asset
    /// - Parameter symbol: Asset symbol
    /// - Returns: RiskLevel for the asset
    func fetchRiskLevel(symbol: String) async throws -> AssetRiskLevel

    /// Checks all active risk-based reminders against current risk levels
    /// and triggers those that meet their conditions
    /// - Parameter userId: User identifier
    /// - Returns: Array of newly triggered RiskBasedDCAReminder
    func checkAndTriggerReminders(userId: UUID) async throws -> [RiskBasedDCAReminder]
}
