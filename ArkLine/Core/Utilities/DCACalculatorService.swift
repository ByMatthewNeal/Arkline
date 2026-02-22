import Foundation

/// Service for calculating DCA investment schedules
struct DCACalculatorService {

    // MARK: - Purchase Count Calculation

    /// Calculates the total number of purchases based on frequency and duration
    static func purchaseCount(
        frequency: DCAFrequency,
        duration: DCADuration,
        selectedDays: Set<Weekday>
    ) -> Int {
        switch frequency {
        case .daily:
            return duration.approximateDays

        case .twiceWeekly:
            // 2 purchases per week
            return duration.approximateWeeks * 2

        case .weekly:
            // Number of selected days per week
            let daysPerWeek = max(selectedDays.count, 1)
            return duration.approximateWeeks * daysPerWeek

        case .biweekly:
            // Every 2 weeks
            return duration.approximateWeeks / 2

        case .monthly:
            return duration.months
        }
    }

    // MARK: - Purchase Dates Generation

    /// Generates all purchase dates based on the schedule
    static func generatePurchaseDates(
        frequency: DCAFrequency,
        duration: DCADuration,
        startDate: Date,
        selectedDays: Set<Weekday>
    ) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        // Calculate end date
        guard let endDate = calendar.date(byAdding: .month, value: duration.months, to: startDate) else {
            return []
        }

        switch frequency {
        case .daily:
            var current = startDate
            while current <= endDate {
                dates.append(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }

        case .twiceWeekly:
            // Tuesday and Friday by default
            let targetDays: Set<Weekday> = [.tuesday, .friday]
            dates = generateWeeklyDates(
                startDate: startDate,
                endDate: endDate,
                targetDays: targetDays,
                calendar: calendar
            )

        case .weekly:
            let targetDays = selectedDays.isEmpty ? [Weekday.monday] : selectedDays
            dates = generateWeeklyDates(
                startDate: startDate,
                endDate: endDate,
                targetDays: Set(targetDays),
                calendar: calendar
            )

        case .biweekly:
            // Every 2 weeks on the same day as start
            var current = startDate
            while current <= endDate {
                dates.append(current)
                guard let next = calendar.date(byAdding: .weekOfYear, value: 2, to: current) else { break }
                current = next
            }

        case .monthly:
            // Same day each month
            var current = startDate
            while current <= endDate {
                dates.append(current)
                guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
                current = next
            }
        }

        return dates
    }

    // MARK: - Helper Methods

    private static func generateWeeklyDates(
        startDate: Date,
        endDate: Date,
        targetDays: Set<Weekday>,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var current = startDate

        while current <= endDate {
            let weekday = calendar.component(.weekday, from: current)

            // Check if this weekday is one of our target days
            if let day = Weekday(rawValue: weekday), targetDays.contains(day) {
                dates.append(current)
            }

            // Move to next day
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    // MARK: - Calculation Builder

    /// Creates a time-based DCACalculation
    static func calculateTimeBased(
        totalAmount: Double,
        asset: DCAAsset,
        frequency: DCAFrequency,
        duration: DCADuration,
        startDate: Date,
        selectedDays: Set<Weekday>,
        targetPortfolioId: UUID?,
        targetPortfolioName: String?
    ) -> DCACalculation {
        return DCACalculation(
            totalAmount: totalAmount,
            asset: asset,
            strategyType: .timeBased,
            targetPortfolioId: targetPortfolioId,
            targetPortfolioName: targetPortfolioName,
            frequency: frequency,
            duration: duration,
            startDate: startDate,
            selectedDays: selectedDays,
            riskBands: [],
            scoreType: .regression // Not used for time-based
        )
    }

    /// Creates a risk-based DCACalculation
    static func calculateRiskBased(
        totalAmount: Double,
        asset: DCAAsset,
        riskBands: Set<DCABTCRiskBand>,
        scoreType: DCAScoreType,
        targetPortfolioId: UUID?,
        targetPortfolioName: String?
    ) -> DCACalculation {
        return DCACalculation(
            totalAmount: totalAmount,
            asset: asset,
            strategyType: .riskBased,
            targetPortfolioId: targetPortfolioId,
            targetPortfolioName: targetPortfolioName,
            frequency: .weekly, // Not used for risk-based
            duration: .oneYear, // Not used for risk-based
            startDate: Date(),
            selectedDays: [],
            riskBands: riskBands,
            scoreType: scoreType
        )
    }

    // MARK: - Summary Helpers

    /// Returns a human-readable frequency description
    static func frequencyDescription(
        frequency: DCAFrequency,
        selectedDays: Set<Weekday>
    ) -> String {
        switch frequency {
        case .daily:
            return "Every day"

        case .twiceWeekly:
            return "Twice a week"

        case .weekly:
            if selectedDays.isEmpty {
                return "Every week"
            } else if selectedDays.count == 1, let day = selectedDays.first {
                return "Every \(day.fullName)"
            } else {
                let dayNames = selectedDays.sorted { $0.rawValue < $1.rawValue }
                    .map { $0.shortName }
                    .joined(separator: ", ")
                return "Every \(dayNames)"
            }

        case .biweekly:
            return "Every 2 weeks"

        case .monthly:
            return "Every month"
        }
    }

    /// Validates if the calculation is valid
    static func validate(totalAmount: Double, asset: DCAAsset?, duration: DCADuration?) -> [String] {
        var errors: [String] = []

        if totalAmount <= 0 {
            errors.append("Please enter a valid investment amount")
        }

        if totalAmount < 100 {
            errors.append("Minimum investment amount is $100")
        }

        if asset == nil {
            errors.append("Please select an asset to invest in")
        }

        if duration == nil {
            errors.append("Please select a duration for your DCA plan")
        }

        return errors
    }
}

// MARK: - Quick Amount Presets
extension DCACalculatorService {
    static var quickAmountPresets: [Double] {
        [10_000, 25_000, 50_000, 100_000]
    }

    static func formatQuickAmount(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(Int(amount / 1_000_000))M"
        } else if amount >= 1_000 {
            return "$\(Int(amount / 1_000))K"
        }
        return "$\(Int(amount))"
    }
}
