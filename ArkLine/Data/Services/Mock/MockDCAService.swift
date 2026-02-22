import Foundation

// MARK: - Mock DCA Service
/// Mock implementation of DCAServiceProtocol for development and testing.
final class MockDCAService: DCAServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 300_000_000

    // MARK: - Mock Storage
    private var mockReminders: [DCAReminder] = []
    private var mockInvestments: [DCAInvestment] = []
    private var mockRiskBasedReminders: [RiskBasedDCAReminder] = []
    private var mockRiskBasedInvestments: [RiskDCAInvestment] = []
    private var mockRiskLevels: [String: AssetRiskLevel] = [:]

    // MARK: - Initialization
    init() {
        setupMockData()
        setupRiskBasedMockData()
    }

    // MARK: - DCAServiceProtocol

    func fetchReminders(userId: UUID) async throws -> [DCAReminder] {
        try await simulateNetworkDelay()
        return mockReminders.filter { $0.userId == userId }
    }

    func fetchActiveReminders(userId: UUID) async throws -> [DCAReminder] {
        try await simulateNetworkDelay()
        return mockReminders.filter { $0.userId == userId && $0.isActive }
    }

    func fetchTodayReminders(userId: UUID) async throws -> [DCAReminder] {
        try await simulateNetworkDelay()
        return mockReminders.filter { reminder in
            guard let nextDate = reminder.nextReminderDate,
                  reminder.isActive else { return false }
            return Calendar.current.isDateInToday(nextDate)
        }
    }

    func createReminder(_ request: CreateDCARequest) async throws -> DCAReminder {
        try await simulateNetworkDelay()

        let reminder = DCAReminder(
            userId: request.userId,
            symbol: request.symbol,
            name: request.name,
            amount: request.amount,
            frequency: DCAFrequency(rawValue: request.frequency) ?? .weekly,
            totalPurchases: request.totalPurchases,
            completedPurchases: 0,
            notificationTime: {
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f.date(from: request.notificationTime) ?? Date()
            }(),
            startDate: request.startDate,
            nextReminderDate: request.nextReminderDate,
            isActive: true
        )

        mockReminders.append(reminder)
        return reminder
    }

    func updateReminder(_ reminder: DCAReminder) async throws {
        try await simulateNetworkDelay()
        if let index = mockReminders.firstIndex(where: { $0.id == reminder.id }) {
            mockReminders[index] = reminder
        }
    }

    func deleteReminder(id: UUID) async throws {
        try await simulateNetworkDelay()
        mockReminders.removeAll { $0.id == id }
    }

    func markAsInvested(id: UUID) async throws -> DCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        var reminder = mockReminders[index]
        reminder.completedPurchases += 1
        reminder.nextReminderDate = calculateNextDate(for: reminder)
        mockReminders[index] = reminder

        // Create investment record
        let investment = DCAInvestment(
            id: UUID(),
            reminderId: id,
            amount: reminder.amount,
            priceAtPurchase: getMockPrice(for: reminder.symbol),
            quantity: reminder.amount / getMockPrice(for: reminder.symbol),
            purchaseDate: Date()
        )
        mockInvestments.append(investment)

        return reminder
    }

    func skipReminder(id: UUID) async throws -> DCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        var reminder = mockReminders[index]
        reminder.nextReminderDate = calculateNextDate(for: reminder)
        mockReminders[index] = reminder

        return reminder
    }

    func toggleReminder(id: UUID) async throws -> DCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        mockReminders[index].isActive.toggle()
        return mockReminders[index]
    }

    func fetchInvestmentHistory(reminderId: UUID) async throws -> [DCAInvestment] {
        try await simulateNetworkDelay()
        return mockInvestments.filter { $0.reminderId == reminderId }
    }

    // MARK: - Private Helpers

    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)
    }

    private func setupMockData() {
        let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        mockReminders = [
            DCAReminder(
                userId: userId,
                symbol: "BTC",
                name: "Bitcoin",
                amount: 100,
                frequency: .weekly,
                totalPurchases: 52,
                completedPurchases: 12,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 84),
                nextReminderDate: Date(),
                isActive: true
            ),
            DCAReminder(
                userId: userId,
                symbol: "ETH",
                name: "Ethereum",
                amount: 50,
                frequency: .biweekly,
                totalPurchases: 24,
                completedPurchases: 8,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 0)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 112),
                nextReminderDate: Date().addingTimeInterval(86400 * 3),
                isActive: true
            ),
            DCAReminder(
                userId: userId,
                symbol: "SOL",
                name: "Solana",
                amount: 25,
                frequency: .monthly,
                totalPurchases: 12,
                completedPurchases: 3,
                notificationTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date(),
                startDate: Date().addingTimeInterval(-86400 * 90),
                nextReminderDate: Date().addingTimeInterval(86400 * 15),
                isActive: true
            )
        ]

        // Generate some mock investment history
        for reminder in mockReminders {
            for i in 0..<reminder.completedPurchases {
                let purchaseDate = Calendar.current.date(
                    byAdding: .day,
                    value: -(reminder.frequency.daysInterval * (reminder.completedPurchases - i)),
                    to: Date()
                ) ?? Date()

                let price = getMockPrice(for: reminder.symbol) * Double.random(in: 0.85...1.15)

                mockInvestments.append(DCAInvestment(
                    id: UUID(),
                    reminderId: reminder.id,
                    amount: reminder.amount,
                    priceAtPurchase: price,
                    quantity: reminder.amount / price,
                    purchaseDate: purchaseDate
                ))
            }
        }
    }

    private func calculateNextDate(for reminder: DCAReminder) -> Date? {
        let calendar = Calendar.current
        guard let current = reminder.nextReminderDate else { return nil }

        switch reminder.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: current)
        case .twiceWeekly:
            return calendar.date(byAdding: .day, value: 3, to: current)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: current)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: current)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: current)
        }
    }

    private func getMockPrice(for symbol: String) -> Double {
        let prices: [String: Double] = [
            "BTC": 67234.50,
            "ETH": 3456.78,
            "SOL": 145.67,
            "XRP": 0.52,
            "ADA": 0.45,
            "DOGE": 0.12
        ]
        return prices[symbol.uppercased()] ?? 100.0
    }

    // MARK: - Risk-Based Mock Data Setup

    private func setupRiskBasedMockData() {
        let userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        // Setup mock risk levels for various assets
        mockRiskLevels = [
            "BTC": AssetRiskLevel(
                assetId: "bitcoin",
                symbol: "BTC",
                riskScore: 35.0,
                riskCategory: .low,
                lastUpdated: Date()
            ),
            "ETH": AssetRiskLevel(
                assetId: "ethereum",
                symbol: "ETH",
                riskScore: 42.0,
                riskCategory: .moderate,
                lastUpdated: Date()
            ),
            "SOL": AssetRiskLevel(
                assetId: "solana",
                symbol: "SOL",
                riskScore: 65.0,
                riskCategory: .high,
                lastUpdated: Date()
            ),
            "XRP": AssetRiskLevel(
                assetId: "ripple",
                symbol: "XRP",
                riskScore: 55.0,
                riskCategory: .moderate,
                lastUpdated: Date()
            ),
            "ADA": AssetRiskLevel(
                assetId: "cardano",
                symbol: "ADA",
                riskScore: 48.0,
                riskCategory: .moderate,
                lastUpdated: Date()
            ),
            "DOGE": AssetRiskLevel(
                assetId: "dogecoin",
                symbol: "DOGE",
                riskScore: 78.0,
                riskCategory: .high,
                lastUpdated: Date()
            )
        ]

        // Setup mock risk-based DCA reminders
        mockRiskBasedReminders = [
            RiskBasedDCAReminder(
                userId: userId,
                symbol: "BTC",
                name: "Bitcoin",
                amount: 500,
                riskThreshold: 30.0,
                riskCondition: .below,
                isTriggered: false,
                isActive: true
            ),
            RiskBasedDCAReminder(
                userId: userId,
                symbol: "ETH",
                name: "Ethereum",
                amount: 200,
                riskThreshold: 40.0,
                riskCondition: .below,
                isTriggered: true,
                lastTriggeredRiskLevel: 38.5,
                isActive: true
            ),
            RiskBasedDCAReminder(
                userId: userId,
                symbol: "SOL",
                name: "Solana",
                amount: 100,
                riskThreshold: 70.0,
                riskCondition: .above,
                isTriggered: false,
                isActive: true
            )
        ]

        // Setup mock investment history for risk-based reminders
        for reminder in mockRiskBasedReminders where reminder.isTriggered {
            mockRiskBasedInvestments.append(RiskDCAInvestment(
                id: UUID(),
                reminderId: reminder.id,
                amount: reminder.amount,
                priceAtPurchase: getMockPrice(for: reminder.symbol),
                quantity: reminder.amount / getMockPrice(for: reminder.symbol),
                riskLevelAtPurchase: reminder.lastTriggeredRiskLevel ?? 0,
                purchaseDate: Date().addingTimeInterval(-86400 * 2)
            ))
        }
    }

    // MARK: - Risk-Based DCA Methods

    func fetchRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        try await simulateNetworkDelay()
        return mockRiskBasedReminders.filter { $0.userId == userId }
    }

    func fetchActiveRiskBasedReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        try await simulateNetworkDelay()
        return mockRiskBasedReminders.filter { $0.userId == userId && $0.isActive }
    }

    func fetchTriggeredReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        try await simulateNetworkDelay()
        return mockRiskBasedReminders.filter { $0.userId == userId && $0.isActive && $0.isTriggered }
    }

    func createRiskBasedReminder(_ request: CreateRiskBasedDCARequest) async throws -> RiskBasedDCAReminder {
        try await simulateNetworkDelay()

        guard let condition = RiskCondition(rawValue: request.riskCondition) else {
            throw AppError.custom(message: "Invalid risk condition")
        }

        let reminder = RiskBasedDCAReminder(
            userId: request.userId,
            symbol: request.symbol,
            name: request.name,
            amount: request.amount,
            riskThreshold: request.riskThreshold,
            riskCondition: condition,
            isTriggered: false,
            isActive: true
        )

        mockRiskBasedReminders.append(reminder)
        return reminder
    }

    func updateRiskBasedReminder(_ reminder: RiskBasedDCAReminder) async throws {
        try await simulateNetworkDelay()
        if let index = mockRiskBasedReminders.firstIndex(where: { $0.id == reminder.id }) {
            mockRiskBasedReminders[index] = reminder
        }
    }

    func deleteRiskBasedReminder(id: UUID) async throws {
        try await simulateNetworkDelay()
        mockRiskBasedReminders.removeAll { $0.id == id }
        mockRiskBasedInvestments.removeAll { $0.reminderId == id }
    }

    func markRiskBasedAsInvested(id: UUID) async throws -> RiskBasedDCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockRiskBasedReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        var reminder = mockRiskBasedReminders[index]

        // Create investment record
        let investment = RiskDCAInvestment(
            id: UUID(),
            reminderId: id,
            amount: reminder.amount,
            priceAtPurchase: getMockPrice(for: reminder.symbol),
            quantity: reminder.amount / getMockPrice(for: reminder.symbol),
            riskLevelAtPurchase: reminder.lastTriggeredRiskLevel ?? 0,
            purchaseDate: Date()
        )
        mockRiskBasedInvestments.append(investment)

        // Reset triggered state
        reminder.isTriggered = false
        reminder.lastTriggeredRiskLevel = nil
        mockRiskBasedReminders[index] = reminder

        return reminder
    }

    func resetTrigger(id: UUID) async throws -> RiskBasedDCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockRiskBasedReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        mockRiskBasedReminders[index].isTriggered = false
        mockRiskBasedReminders[index].lastTriggeredRiskLevel = nil

        return mockRiskBasedReminders[index]
    }

    func toggleRiskBasedReminder(id: UUID) async throws -> RiskBasedDCAReminder {
        try await simulateNetworkDelay()
        guard let index = mockRiskBasedReminders.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound
        }

        mockRiskBasedReminders[index].isActive.toggle()
        return mockRiskBasedReminders[index]
    }

    func fetchRiskBasedInvestmentHistory(reminderId: UUID) async throws -> [RiskDCAInvestment] {
        try await simulateNetworkDelay()
        return mockRiskBasedInvestments.filter { $0.reminderId == reminderId }
    }

    func fetchRiskLevel(symbol: String) async throws -> AssetRiskLevel {
        try await simulateNetworkDelay()

        let upperSymbol = symbol.uppercased()

        // Read existing level (if any) without modification
        if let existingLevel = mockRiskLevels[upperSymbol] {
            // Create a new level with variance (don't mutate the dictionary in async context)
            let variance = Double.random(in: -5...5)
            let newScore = max(0, min(100, existingLevel.riskScore + variance))
            return AssetRiskLevel(
                assetId: existingLevel.assetId,
                symbol: existingLevel.symbol,
                riskScore: newScore,
                riskCategory: RiskCategory.from(score: newScore),
                lastUpdated: Date()
            )
        }

        // Generate a random risk level for unknown assets
        let randomScore = Double.random(in: 20...80)
        return AssetRiskLevel(
            assetId: symbol.lowercased(),
            symbol: upperSymbol,
            riskScore: randomScore,
            riskCategory: RiskCategory.from(score: randomScore),
            lastUpdated: Date()
        )
    }

    func checkAndTriggerReminders(userId: UUID) async throws -> [RiskBasedDCAReminder] {
        try await simulateNetworkDelay()

        var triggeredReminders: [RiskBasedDCAReminder] = []

        for index in mockRiskBasedReminders.indices {
            var reminder = mockRiskBasedReminders[index]

            guard reminder.userId == userId,
                  reminder.isActive,
                  !reminder.isTriggered else { continue }

            // Fetch current risk level
            let riskLevel = try await fetchRiskLevel(symbol: reminder.symbol)

            // Check if condition is met
            if reminder.shouldTrigger(currentRisk: riskLevel.riskScore) {
                reminder.isTriggered = true
                reminder.lastTriggeredRiskLevel = riskLevel.riskScore
                mockRiskBasedReminders[index] = reminder
                triggeredReminders.append(reminder)
            }
        }

        return triggeredReminders
    }
}
