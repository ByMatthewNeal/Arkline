# Arkline Test Coverage Agent

You help add test coverage to the Arkline iOS app. Currently there are zero tests despite 2,373 Swift files.

## Priority Test Areas

### 1. Security-Critical (Highest Priority)
- `AuthViewModel` - Authentication logic, lockout mechanism
- `KeychainManager` (once created) - Secure storage operations
- `PasscodeManager` (once created) - Hashing verification

### 2. Business Logic (High Priority)
- `RiskCalculator` - Risk level calculations
- `AssetRiskConfig` - Asset-specific risk configurations
- `PerformanceMetricsCalculator` - Portfolio performance
- `DCACalculatorService` - DCA calculations
- `LogarithmicRegression` - Rainbow chart regression

### 3. Data Layer (Medium Priority)
- Model encoding/decoding (Codable conformance)
- Service protocol implementations
- Network request/response handling

### 4. Extensions (Medium Priority)
- `String+Extensions` - Email validation, formatting
- `Double+Extensions` - Currency formatting, percentages
- `Date+Extensions` - Date calculations, formatting

## Test Setup

### Create Test Target Structure

```
ArkLineTests/
├── Security/
│   ├── AuthViewModelTests.swift
│   ├── KeychainManagerTests.swift
│   └── PasscodeManagerTests.swift
├── Business/
│   ├── RiskCalculatorTests.swift
│   ├── AssetRiskConfigTests.swift
│   ├── PerformanceCalculatorTests.swift
│   └── DCACalculatorTests.swift
├── Models/
│   ├── UserTests.swift
│   ├── PortfolioTests.swift
│   └── CryptoAssetTests.swift
├── Extensions/
│   ├── StringExtensionsTests.swift
│   ├── DoubleExtensionsTests.swift
│   └── DateExtensionsTests.swift
└── Services/
    ├── MockServiceTests.swift
    └── APIServiceTests.swift
```

## Test Patterns

### ViewModel Tests
```swift
import XCTest
@testable import ArkLine

final class AuthViewModelTests: XCTestCase {

    var sut: AuthViewModel!

    override func setUp() {
        super.setUp()
        sut = AuthViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Passcode Validation

    func test_validatePasscode_withCorrectPasscode_returnsTrue() async {
        // Given
        let passcode = "123456"
        await sut.setPasscode(passcode)

        // When
        let result = await sut.validatePasscode(passcode)

        // Then
        XCTAssertTrue(result)
    }

    func test_validatePasscode_withIncorrectPasscode_returnsFalse() async {
        // Given
        let correctPasscode = "123456"
        let wrongPasscode = "654321"
        await sut.setPasscode(correctPasscode)

        // When
        let result = await sut.validatePasscode(wrongPasscode)

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - Lockout Mechanism

    func test_lockout_afterMaxAttempts_triggersLockout() async {
        // Given
        let wrongPasscode = "000000"
        await sut.setPasscode("123456")

        // When
        for _ in 0..<5 {
            _ = await sut.validatePasscode(wrongPasscode)
        }

        // Then
        XCTAssertTrue(sut.isLockedOut)
    }

    func test_lockout_duration_isCorrect() async {
        // Given
        await sut.triggerLockout()

        // Then
        XCTAssertEqual(sut.lockoutDuration, 300) // 5 minutes
    }
}
```

### Model Tests
```swift
import XCTest
@testable import ArkLine

final class CryptoAssetTests: XCTestCase {

    // MARK: - Codable

    func test_decode_fromValidJSON_succeeds() throws {
        // Given
        let json = """
        {
            "id": "bitcoin",
            "symbol": "btc",
            "name": "Bitcoin",
            "current_price": 45000.50,
            "price_change_percentage_24h": 2.5
        }
        """.data(using: .utf8)!

        // When
        let asset = try JSONDecoder().decode(CryptoAsset.self, from: json)

        // Then
        XCTAssertEqual(asset.id, "bitcoin")
        XCTAssertEqual(asset.symbol, "btc")
        XCTAssertEqual(asset.currentPrice, 45000.50)
    }

    func test_encode_producesValidJSON() throws {
        // Given
        let asset = CryptoAsset(
            id: "ethereum",
            symbol: "eth",
            name: "Ethereum",
            currentPrice: 3000.0
        )

        // When
        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(CryptoAsset.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, asset.id)
        XCTAssertEqual(decoded.currentPrice, asset.currentPrice)
    }
}
```

### Extension Tests
```swift
import XCTest
@testable import ArkLine

final class StringExtensionsTests: XCTestCase {

    // MARK: - Email Validation

    func test_isValidEmail_withValidEmail_returnsTrue() {
        XCTAssertTrue("user@example.com".isValidEmail)
        XCTAssertTrue("test.name+tag@domain.co.uk".isValidEmail)
    }

    func test_isValidEmail_withInvalidEmail_returnsFalse() {
        XCTAssertFalse("notanemail".isValidEmail)
        XCTAssertFalse("missing@domain".isValidEmail)
        XCTAssertFalse("@nodomain.com".isValidEmail)
        XCTAssertFalse("spaces in@email.com".isValidEmail)
    }

    // MARK: - Nil If Empty

    func test_nilIfEmpty_withEmptyString_returnsNil() {
        XCTAssertNil("".nilIfEmpty)
    }

    func test_nilIfEmpty_withNonEmptyString_returnsString() {
        XCTAssertEqual("hello".nilIfEmpty, "hello")
    }

    func test_nilIfBlank_withWhitespaceOnly_returnsNil() {
        XCTAssertNil("   ".nilIfBlank)
        XCTAssertNil("\t\n".nilIfBlank)
    }
}
```

### Service Tests with Mocks
```swift
import XCTest
@testable import ArkLine

final class MarketServiceTests: XCTestCase {

    var mockService: MockMarketService!

    override func setUp() {
        super.setUp()
        mockService = MockMarketService()
    }

    func test_fetchCryptoAssets_returnsMockData() async throws {
        // When
        let assets = try await mockService.fetchCryptoAssets()

        // Then
        XCTAssertFalse(assets.isEmpty)
        XCTAssertTrue(assets.contains { $0.symbol == "btc" })
    }

    func test_fetchAssetDetails_withValidId_returnsAsset() async throws {
        // When
        let asset = try await mockService.fetchAssetDetails(id: "bitcoin")

        // Then
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.id, "bitcoin")
    }
}
```

## Risk Calculator Tests (Critical)

```swift
import XCTest
@testable import ArkLine

final class RiskCalculatorTests: XCTestCase {

    var sut: RiskCalculator!

    override func setUp() {
        super.setUp()
        sut = RiskCalculator()
    }

    func test_calculateRiskLevel_forBitcoin_returnsValidLevel() {
        // Given
        let price: Double = 45000
        let config = AssetRiskConfig.bitcoin

        // When
        let riskLevel = sut.calculateRiskLevel(price: price, config: config)

        // Then
        XCTAssertGreaterThanOrEqual(riskLevel, 0)
        XCTAssertLessThanOrEqual(riskLevel, 100)
    }

    func test_calculateRiskLevel_atAllTimeHigh_returnsHighRisk() {
        // Given
        let price: Double = 100000 // Hypothetical ATH
        let config = AssetRiskConfig.bitcoin

        // When
        let riskLevel = sut.calculateRiskLevel(price: price, config: config)

        // Then
        XCTAssertGreaterThan(riskLevel, 70) // Should be high risk
    }

    func test_calculateRiskLevel_atCycleLow_returnsLowRisk() {
        // Given
        let price: Double = 15000 // Cycle low
        let config = AssetRiskConfig.bitcoin

        // When
        let riskLevel = sut.calculateRiskLevel(price: price, config: config)

        // Then
        XCTAssertLessThan(riskLevel, 30) // Should be low risk
    }
}
```

## Workflow

1. Ask which area to add tests for
2. Read the source code to understand the logic
3. Create appropriate test file structure
4. Write tests following the patterns above
5. Run tests to verify they pass
6. Add edge case tests for robustness

## Running Tests

```bash
# Run all tests
xcodebuild test -scheme ArkLine -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -scheme ArkLine -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ArkLineTests/AuthViewModelTests
```
