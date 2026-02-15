import Foundation
import RevenueCat

actor SubscriptionService {
    // MARK: - Singleton
    static let shared = SubscriptionService()

    // MARK: - Constants
    private static let premiumEntitlementID = "premium"

    // MARK: - State
    private var customerInfo: CustomerInfo?

    // MARK: - Init
    private init() {}

    // MARK: - Configuration

    /// Call once at app launch (from ArkLineApp.onAppear)
    func configure() {
        let apiKey = Constants.API.revenueCatAPIKey
        guard !apiKey.isEmpty else {
            logWarning("RevenueCat API key not found in Secrets.plist", category: .network)
            return
        }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: apiKey)
    }

    // MARK: - User Identity

    /// Sync RevenueCat user with Supabase user ID
    func login(userId: String) async throws {
        let (info, _) = try await Purchases.shared.logIn(userId)
        self.customerInfo = info
    }

    func logout() async throws {
        let info = try await Purchases.shared.logOut()
        self.customerInfo = info
    }

    // MARK: - Entitlement Check

    var isPro: Bool {
        customerInfo?.entitlements[Self.premiumEntitlementID]?.isActive == true
    }

    /// Refresh subscription status from RevenueCat server
    @discardableResult
    func refreshStatus() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            return info.entitlements[Self.premiumEntitlementID]?.isActive == true
        } catch {
            logError("Failed to refresh subscription status: \(error)", category: .network)
            return isPro
        }
    }

    // MARK: - Offerings

    func getOfferings() async throws -> Offerings {
        try await Purchases.shared.offerings()
    }

    // MARK: - Purchase

    func purchase(package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        self.customerInfo = result.customerInfo
        return !result.userCancelled
    }

    // MARK: - Restore

    func restorePurchases() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        return info.entitlements[Self.premiumEntitlementID]?.isActive == true
    }

    // MARK: - Subscription Details

    var expirationDate: Date? {
        customerInfo?.entitlements[Self.premiumEntitlementID]?.expirationDate
    }

    var willRenew: Bool {
        customerInfo?.entitlements[Self.premiumEntitlementID]?.willRenew == true
    }
}
