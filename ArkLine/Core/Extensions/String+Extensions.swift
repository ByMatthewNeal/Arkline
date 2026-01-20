import Foundation

extension String {
    // MARK: - Validation
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    var isValidUsername: Bool {
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: self)
    }

    var isValidPassword: Bool {
        // At least 8 characters, one uppercase, one lowercase, one number
        let passwordRegex = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)[a-zA-Z\\d@$!%*?&]{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: self)
    }

    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }

    var isNumeric: Bool {
        !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }

    // MARK: - Trimming
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOrNil: String? {
        let result = trimmed
        return result.isEmpty ? nil : result
    }

    // MARK: - Case Conversion
    var capitalizedFirstLetter: String {
        prefix(1).capitalized + dropFirst()
    }

    var camelCaseToWords: String {
        unicodeScalars.reduce("") { result, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar) {
                return result + " " + String(scalar)
            }
            return result + String(scalar)
        }.trimmed.capitalizedFirstLetter
    }

    // MARK: - Truncation
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }

    // MARK: - Initials
    var initials: String {
        let words = components(separatedBy: .whitespaces)
        let initials = words.compactMap { $0.first }.prefix(2)
        return String(initials).uppercased()
    }

    // MARK: - Safe Subscripting
    subscript(safe index: Int) -> Character? {
        guard index >= 0 && index < count else { return nil }
        return self[self.index(startIndex, offsetBy: index)]
    }

    subscript(safe range: Range<Int>) -> String? {
        guard range.lowerBound >= 0 && range.upperBound <= count else { return nil }
        let startIndex = self.index(self.startIndex, offsetBy: range.lowerBound)
        let endIndex = self.index(self.startIndex, offsetBy: range.upperBound)
        return String(self[startIndex..<endIndex])
    }

    // MARK: - Masking
    var masked: String {
        guard count > 4 else { return String(repeating: "*", count: count) }
        let visibleCount = min(4, count / 3)
        let maskedCount = count - visibleCount
        return String(repeating: "*", count: maskedCount) + suffix(visibleCount)
    }

    var maskedEmail: String {
        guard let atIndex = firstIndex(of: "@") else { return self }
        let username = String(self[..<atIndex])
        let domain = String(self[atIndex...])

        if username.count <= 2 {
            return username + domain
        }

        let visibleChars = min(3, username.count / 2)
        let maskedChars = username.count - visibleChars
        let maskedUsername = String(username.prefix(visibleChars)) + String(repeating: "*", count: maskedChars)
        return maskedUsername + domain
    }

    // MARK: - Crypto Symbols
    var cryptoSymbol: String {
        uppercased()
    }

    var displaySymbol: String {
        if count <= 5 {
            return uppercased()
        }
        return uppercased().truncated(to: 5, trailing: "")
    }

    // MARK: - URL Encoding
    var urlEncoded: String? {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    // MARK: - Hash Tag / Mention Detection
    var hashtags: [String] {
        let regex = try? NSRegularExpression(pattern: "#\\w+", options: [])
        let range = NSRange(startIndex..., in: self)
        let matches = regex?.matches(in: self, options: [], range: range) ?? []
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }

    var mentions: [String] {
        let regex = try? NSRegularExpression(pattern: "@\\w+", options: [])
        let range = NSRange(startIndex..., in: self)
        let matches = regex?.matches(in: self, options: [], range: range) ?? []
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: self) else { return nil }
            return String(self[range])
        }
    }

    // MARK: - Localization
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }

    // MARK: - Empty Check
    var isBlank: Bool {
        trimmed.isEmpty
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }

    // MARK: - Number Extraction
    var extractedNumbers: String {
        filter { $0.isNumber || $0 == "." || $0 == "-" }
    }

    var asDouble: Double? {
        Double(extractedNumbers)
    }

    var asInt: Int? {
        Int(filter { $0.isNumber || $0 == "-" })
    }
}

// MARK: - Optional String Extensions
extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }

    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }

    var isNilOrBlank: Bool {
        self?.isBlank ?? true
    }
}
