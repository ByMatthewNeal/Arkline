import XCTest
@testable import ArkLine

final class StringExtensionsTests: XCTestCase {

    // MARK: - isValidEmail

    func testIsValidEmail_valid() {
        XCTAssertTrue("user@example.com".isValidEmail)
        XCTAssertTrue("first.last@domain.co.uk".isValidEmail)
        XCTAssertTrue("user+tag@gmail.com".isValidEmail)
    }

    func testIsValidEmail_invalid() {
        XCTAssertFalse("".isValidEmail)
        XCTAssertFalse("notanemail".isValidEmail)
        XCTAssertFalse("@domain.com".isValidEmail)
        XCTAssertFalse("user@".isValidEmail)
        XCTAssertFalse("user@.com".isValidEmail)
    }

    // MARK: - isValidUsername

    func testIsValidUsername_valid() {
        XCTAssertTrue("user123".isValidUsername)
        XCTAssertTrue("my_name".isValidUsername)
        XCTAssertTrue("abc".isValidUsername)
        XCTAssertTrue("A_long_username_20ch".isValidUsername) // 20 chars
    }

    func testIsValidUsername_invalid() {
        XCTAssertFalse("ab".isValidUsername)  // Too short (< 3)
        XCTAssertFalse("a_very_long_username_here".isValidUsername) // Too long (> 20)
        XCTAssertFalse("user name".isValidUsername) // Spaces
        XCTAssertFalse("user@name".isValidUsername) // Special chars
        XCTAssertFalse("".isValidUsername)
    }

    // MARK: - isValidPassword

    func testIsValidPassword_valid() {
        XCTAssertTrue("Password1".isValidPassword)
        XCTAssertTrue("MyStr0ng!".isValidPassword)
        XCTAssertTrue("Abcdefg1".isValidPassword)
    }

    func testIsValidPassword_invalid() {
        XCTAssertFalse("short1A".isValidPassword) // < 8 chars
        XCTAssertFalse("alllowercase1".isValidPassword) // No uppercase
        XCTAssertFalse("ALLUPPERCASE1".isValidPassword) // No lowercase
        XCTAssertFalse("NoNumbers!".isValidPassword) // No digit
        XCTAssertFalse("".isValidPassword)
    }

    // MARK: - isValidURL

    func testIsValidURL_valid() {
        XCTAssertTrue("https://example.com".isValidURL)
        XCTAssertTrue("http://test.io/path".isValidURL)
        XCTAssertTrue("ftp://files.server.com".isValidURL)
    }

    func testIsValidURL_invalid() {
        XCTAssertFalse("not a url".isValidURL)
        XCTAssertFalse("".isValidURL)
        XCTAssertFalse("example.com".isValidURL) // No scheme
    }

    // MARK: - isNumeric

    func testIsNumeric_valid() {
        XCTAssertTrue("12345".isNumeric)
        XCTAssertTrue("0".isNumeric)
    }

    func testIsNumeric_invalid() {
        XCTAssertFalse("12.34".isNumeric) // Dots not in decimalDigits
        XCTAssertFalse("abc".isNumeric)
        XCTAssertFalse("12a34".isNumeric)
        XCTAssertFalse("".isNumeric)
    }

    // MARK: - trimmed

    func testTrimmed() {
        XCTAssertEqual("  hello  ".trimmed, "hello")
        XCTAssertEqual("\n\ttext\n".trimmed, "text")
        XCTAssertEqual("nochange".trimmed, "nochange")
    }

    func testTrimmedOrNil() {
        XCTAssertEqual("  hello  ".trimmedOrNil, "hello")
        XCTAssertNil("   ".trimmedOrNil)
        XCTAssertNil("".trimmedOrNil)
    }

    // MARK: - camelCaseToWords

    func testCamelCaseToWords() {
        XCTAssertEqual("camelCase".camelCaseToWords, "Camel Case")
        XCTAssertEqual("myVariableName".camelCaseToWords, "My Variable Name")
        XCTAssertEqual("simple".camelCaseToWords, "Simple")
    }

    // MARK: - truncated

    func testTruncated_shorterThanLimit() {
        XCTAssertEqual("hi".truncated(to: 10), "hi")
    }

    func testTruncated_longerThanLimit() {
        XCTAssertEqual("Hello, World!".truncated(to: 5), "Hello...")
    }

    func testTruncated_customTrailing() {
        XCTAssertEqual("Hello, World!".truncated(to: 5, trailing: "…"), "Hello…")
    }

    // MARK: - initials

    func testInitials_twoWords() {
        XCTAssertEqual("John Doe".initials, "JD")
    }

    func testInitials_singleWord() {
        XCTAssertEqual("Alice".initials, "A")
    }

    func testInitials_threeWords() {
        XCTAssertEqual("John Middle Doe".initials, "JM") // Only first 2
    }

    // MARK: - masked

    func testMasked_longString() {
        let result = "1234567890".masked
        XCTAssertTrue(result.hasSuffix("890") || result.hasSuffix("7890"))
        XCTAssertTrue(result.contains("*"))
    }

    func testMasked_shortString() {
        XCTAssertEqual("abc".masked, "***")
    }

    // MARK: - maskedEmail

    func testMaskedEmail_standard() {
        let result = "username@example.com".maskedEmail
        XCTAssertTrue(result.hasSuffix("@example.com"))
        XCTAssertTrue(result.contains("*"))
    }

    func testMaskedEmail_shortUsername() {
        let result = "ab@test.com".maskedEmail
        XCTAssertEqual(result, "ab@test.com")
    }

    func testMaskedEmail_noAtSign() {
        XCTAssertEqual("noemail".maskedEmail, "noemail")
    }

    // MARK: - extractedNumbers

    func testExtractedNumbers() {
        XCTAssertEqual("Price: $123.45".extractedNumbers, "123.45")
        XCTAssertEqual("abc".extractedNumbers, "")
        XCTAssertEqual("-50.5%".extractedNumbers, "-50.5")
    }

    // MARK: - hashtags & mentions

    func testHashtags() {
        let text = "Check out #bitcoin and #ethereum today"
        let tags = text.hashtags
        XCTAssertEqual(tags.count, 2)
        XCTAssertTrue(tags.contains("#bitcoin"))
        XCTAssertTrue(tags.contains("#ethereum"))
    }

    func testHashtags_none() {
        XCTAssertEqual("no tags here".hashtags, [])
    }

    func testMentions() {
        let text = "Hello @alice and @bob"
        let mentions = text.mentions
        XCTAssertEqual(mentions.count, 2)
        XCTAssertTrue(mentions.contains("@alice"))
        XCTAssertTrue(mentions.contains("@bob"))
    }

    // MARK: - isBlank

    func testIsBlank() {
        XCTAssertTrue("".isBlank)
        XCTAssertTrue("   ".isBlank)
        XCTAssertTrue("\n\t".isBlank)
        XCTAssertFalse("hello".isBlank)
    }

    // MARK: - nilIfEmpty / nilIfBlank

    func testNilIfEmpty() {
        XCTAssertNil("".nilIfEmpty)
        XCTAssertEqual("hello".nilIfEmpty, "hello")
        XCTAssertEqual(" ".nilIfEmpty, " ") // Space is not empty
    }

    func testNilIfBlank() {
        XCTAssertNil("".nilIfBlank)
        XCTAssertNil("   ".nilIfBlank)
        XCTAssertEqual("hello".nilIfBlank, "hello")
    }

    // MARK: - Safe Subscript

    func testSafeSubscript_validIndex() {
        XCTAssertEqual("hello"[safe: 0], "h")
        XCTAssertEqual("hello"[safe: 4], "o")
    }

    func testSafeSubscript_invalidIndex() {
        XCTAssertNil("hello"[safe: 10])
        XCTAssertNil("hello"[safe: -1])
        XCTAssertNil(""[safe: 0])
    }

    func testSafeRangeSubscript_valid() {
        XCTAssertEqual("hello"[safe: 0..<3], "hel")
    }

    func testSafeRangeSubscript_invalid() {
        XCTAssertNil("hello"[safe: 0..<10])
    }

    // MARK: - Optional String Extensions

    func testOptionalString_orEmpty() {
        let nilString: String? = nil
        XCTAssertEqual(nilString.orEmpty, "")
        let someString: String? = "test"
        XCTAssertEqual(someString.orEmpty, "test")
    }

    func testOptionalString_isNilOrEmpty() {
        let nilString: String? = nil
        XCTAssertTrue(nilString.isNilOrEmpty)
        XCTAssertTrue(("" as String?).isNilOrEmpty)
        XCTAssertFalse(("hello" as String?).isNilOrEmpty)
    }

    func testOptionalString_isNilOrBlank() {
        let nilString: String? = nil
        XCTAssertTrue(nilString.isNilOrBlank)
        XCTAssertTrue(("   " as String?).isNilOrBlank)
        XCTAssertFalse(("hello" as String?).isNilOrBlank)
    }
}
