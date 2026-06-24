import Foundation
import RevenueCat

/// Wraps the RevenueCat SDK and bridges its customer-info state to the rest of
/// the app. The Supabase user id is used as the RevenueCat `appUserID` so when
/// a purchase happens, the RevenueCat → Supabase webhook can attribute the
/// transaction to the correct Arkline account.
///
/// Subscription source of truth notes:
/// - Web-Stripe customers continue to be tracked via Supabase `subscriptions`
///   (source='stripe'). They do not log in to RevenueCat for billing — they
///   just sign in to the app with their Supabase credentials.
/// - App-Store IAP customers transact via RevenueCat → Apple, RevenueCat
///   forwards the event to our `revenuecat-webhook` Supabase edge function,
///   which writes a row with source='apple' into `subscriptions`.
/// - The iOS app gate uses the Supabase RPC `is_user_subscribed(uuid)` for the
///   final authoritative check. RevenueCat's `isPro` here is a fast local
///   signal we use for paywall presentation, not the authoritative gate.
@MainActor
@Observable
final class RevenueCatService {
    // MARK: - Singleton
    static let shared = RevenueCatService()

    // MARK: - Properties

    /// Latest customer info from RevenueCat. nil until the first fetch returns.
    private(set) var customerInfo: CustomerInfo?

    /// Fast local subscription check based on the RevenueCat "Arkline Pro"
    /// entitlement. Returns false until `customerInfo` is loaded.
    /// NOTE: This only reflects App-Store IAP purchases. Web-Stripe customers
    /// are tracked separately in Supabase — for the authoritative gate, also
    /// check `AppState.isPro` or call `is_user_subscribed()` on the server.
    var isPro: Bool {
        guard let info = customerInfo else { return false }
        return info.entitlements[Constants.RevenueCat.entitlementId]?.isActive == true
    }

    /// Whether `configure()` has been called. Calling it twice is a no-op.
    private var hasConfigured = false

    // MARK: - Init
    private init() {}

    // MARK: - Configuration

    /// Configure the RevenueCat SDK. Call once on app launch from `ArkLineApp`.
    /// Safe to call multiple times — subsequent calls are no-ops.
    func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true

        Purchases.logLevel = .info
        Purchases.configure(withAPIKey: Constants.RevenueCat.publicAPIKey)

        // Create the delegate bridge here (not as a lazy var, which is
        // incompatible with @Observable's macro-rewritten properties).
        let bridge = RevenueCatDelegateBridge { [weak self] info in
            guard let self else { return }
            Task { @MainActor in
                self.customerInfo = info
                self.postSubscriptionStatusChanged()
            }
        }
        self.delegate = bridge
        Purchases.shared.delegate = bridge

        // Kick off a customer info fetch so `isPro` is hot by the time the UI
        // asks for it. If the user is already signed in to Supabase, the
        // session restore path will also call `logIn(userId:)` shortly after.
        Task {
            await refreshCustomerInfo()
        }
    }

    // MARK: - User identity

    /// Link the current RevenueCat user to a Supabase user id. Call this right
    /// after Supabase authentication succeeds, so RevenueCat's `appUserID`
    /// matches the user_id that our webhook will write into `subscriptions`.
    func logIn(userId: UUID) async {
        guard hasConfigured else {
            logError("RevenueCat.logIn called before configure()", category: .auth)
            return
        }
        do {
            let (info, _) = try await Purchases.shared.logIn(userId.uuidString)
            self.customerInfo = info
            postSubscriptionStatusChanged()
        } catch {
            logError(error, context: "RevenueCat logIn", category: .auth)
        }
    }

    /// Sign out from RevenueCat. Call from `AppState.signOut()` so the next
    /// user on this device doesn't inherit the previous user's entitlements.
    func logOut() async {
        guard hasConfigured else { return }
        do {
            let info = try await Purchases.shared.logOut()
            self.customerInfo = info
            postSubscriptionStatusChanged()
        } catch {
            // RC throws if there's no user to log out (anonymous user) — that's fine.
            logError(error, context: "RevenueCat logOut", category: .auth)
        }
    }

    // MARK: - Customer info

    /// Force-refresh customer info from RevenueCat. Useful after a known event
    /// (e.g., user just completed a purchase elsewhere, or to verify after a
    /// successful in-app purchase callback).
    @discardableResult
    func refreshCustomerInfo() async -> CustomerInfo? {
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            postSubscriptionStatusChanged()
            return info
        } catch {
            logError(error, context: "RevenueCat customerInfo", category: .data)
            return nil
        }
    }

    // MARK: - Restore Purchases (required by App Review)

    /// Restore prior purchases for the signed-in Apple ID. Required to be
    /// discoverable from the paywall — Apple guideline 3.1.1 enforces this.
    func restorePurchases() async throws -> CustomerInfo {
        let info = try await Purchases.shared.restorePurchases()
        self.customerInfo = info
        postSubscriptionStatusChanged()
        return info
    }

    // MARK: - Delegate bridge

    /// We use a small wrapper to satisfy `PurchasesDelegate` (NSObject-bound)
    /// from our @Observable struct-flavored service. Initialized inside
    /// `configure()` — `lazy` would conflict with @Observable's macro rewrite.
    private var delegate: RevenueCatDelegateBridge?

    private func postSubscriptionStatusChanged() {
        NotificationCenter.default.post(
            name: Constants.Notifications.subscriptionStatusChanged,
            object: nil
        )
    }
}

// MARK: - Delegate Bridge
// PurchasesDelegate requires an NSObject conformance; our @Observable service
// can't easily inherit from NSObject without losing observation semantics, so
// we delegate the protocol to a private NSObject helper.
private final class RevenueCatDelegateBridge: NSObject, PurchasesDelegate {
    private let onUpdate: (CustomerInfo) -> Void

    init(onUpdate: @escaping (CustomerInfo) -> Void) {
        self.onUpdate = onUpdate
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onUpdate(customerInfo)
    }
}
