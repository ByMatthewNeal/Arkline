import Foundation

// MARK: - Mock DCA Service
/// Mock implementation of DCAServiceProtocol for development and testing.
final class MockDCAService: DCAServiceProtocol {
    // MARK: - Configuration
    var simulatedDelay: UInt64 = 300_000_000

    // MARK: - Mock Storage
    private var mockReminders: [DCAReminder] = []
    private var mockInvestments: [DCAInvestment] = []

    // MARK: - Initialization
    init() {
        setupMockData()
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
            notificationTime: request.notificationTime,
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
        let userId = UUID()

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
}
