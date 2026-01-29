import Foundation

extension Double {
    // MARK: - Currency Formatting
    func formatAsCurrency(
        currencyCode: String = "USD",
        minimumFractionDigits: Int = 2,
        maximumFractionDigits: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var asCurrency: String {
        formatAsCurrency()
    }

    /// Format as currency with a specific currency code
    func asCurrency(code: String) -> String {
        formatAsCurrency(currencyCode: code)
    }

    var asCurrencyCompact: String {
        asCurrencyCompact(code: "USD")
    }

    /// Compact currency format with specific currency code
    func asCurrencyCompact(code: String) -> String {
        if abs(self) >= 1_000_000_000 {
            return formatAsCurrency(currencyCode: code, maximumFractionDigits: 1)
                .replacingOccurrences(of: ",000,000,000", with: "B")
                .replacingOccurrences(of: "000,000,000", with: "B")
        } else if abs(self) >= 1_000_000 {
            return formatAsCurrency(currencyCode: code, maximumFractionDigits: 1)
                .replacingOccurrences(of: ",000,000", with: "M")
                .replacingOccurrences(of: "000,000", with: "M")
        } else if abs(self) >= 1_000 {
            return formatAsCurrency(currencyCode: code, maximumFractionDigits: 1)
                .replacingOccurrences(of: ",000", with: "K")
        }
        return formatAsCurrency(currencyCode: code)
    }

    // MARK: - Crypto Price Formatting
    var asCryptoPrice: String {
        asCryptoPrice(code: "USD")
    }

    /// Format as crypto price with specific currency code
    func asCryptoPrice(code: String) -> String {
        if abs(self) >= 1 {
            return formatAsCurrency(currencyCode: code, minimumFractionDigits: 2, maximumFractionDigits: 2)
        } else if abs(self) >= 0.01 {
            return formatAsCurrency(currencyCode: code, minimumFractionDigits: 4, maximumFractionDigits: 4)
        } else if abs(self) >= 0.0001 {
            return formatAsCurrency(currencyCode: code, minimumFractionDigits: 6, maximumFractionDigits: 6)
        } else {
            return formatAsCurrency(currencyCode: code, minimumFractionDigits: 8, maximumFractionDigits: 8)
        }
    }

    // MARK: - Percentage Formatting
    var asPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: self / 100)) ?? "0%"
    }

    var asPercentageNoSign: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self / 100)) ?? "0%"
    }

    var asPercentageOneDecimal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self / 100)) ?? "0%"
    }

    // MARK: - Number Formatting
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }

    var formattedWithDecimals: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "0.00"
    }

    var formattedCompact: String {
        if abs(self) >= 1_000_000_000_000 {
            return String(format: "%.2fT", self / 1_000_000_000_000)
        } else if abs(self) >= 1_000_000_000 {
            return String(format: "%.2fB", self / 1_000_000_000)
        } else if abs(self) >= 1_000_000 {
            return String(format: "%.2fM", self / 1_000_000)
        } else if abs(self) >= 1_000 {
            return String(format: "%.2fK", self / 1_000)
        }
        return formatted
    }

    // MARK: - Quantity Formatting (for crypto amounts)
    var asQuantity: String {
        if self == 0 {
            return "0"
        } else if abs(self) >= 1_000_000 {
            return formattedCompact
        } else if abs(self) >= 1 {
            return String(format: "%.4f", self)
        } else if abs(self) >= 0.0001 {
            return String(format: "%.6f", self)
        } else {
            return String(format: "%.8f", self)
        }
    }

    // MARK: - Sign Prefix
    var withSign: String {
        if self > 0 {
            return "+\(formatted)"
        }
        return formatted
    }

    var withSignCurrency: String {
        withSignCurrency(code: "USD")
    }

    /// Currency with sign prefix and specific currency code
    func withSignCurrency(code: String) -> String {
        if self > 0 {
            return "+\(asCurrency(code: code))"
        }
        return asCurrency(code: code)
    }

    // MARK: - Rounding
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    // MARK: - Clamping
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }

    // MARK: - Safe Division
    func safeDivide(by divisor: Double) -> Double {
        guard divisor != 0 else { return 0 }
        return self / divisor
    }

    // MARK: - Percentage Change
    func percentageChange(from previous: Double) -> Double {
        guard previous != 0 else { return 0 }
        return ((self - previous) / abs(previous)) * 100
    }

    // MARK: - Boolean Checks
    var isPositive: Bool {
        self > 0
    }

    var isNegative: Bool {
        self < 0
    }

    var isZero: Bool {
        abs(self) < Double.ulpOfOne
    }
}

// MARK: - Int Extensions
extension Int {
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "0"
    }

    var formattedCompact: String {
        Double(self).formattedCompact
    }

    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Decimal Extensions
extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    var asCurrency: String {
        doubleValue.asCurrency
    }
}
