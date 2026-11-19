import SwiftUI
import RevenueCat
import RevenueCatUI

/// Wraps RevenueCatUI's `PaywallView` for presenting the IAP purchase flow.
/// The actual paywall design is configured remotely in the RevenueCat dashboard
/// (Paywalls → default offering paywall). Code-side, we just listen for
/// purchase / restore completion and let the caller decide where to navigate.
///
/// IMPORTANT: Anti-steering compliance — do NOT add any UI here that points
/// users to arkline.io for a cheaper subscription, references the website
/// price, or otherwise tries to circumvent IAP. Apple's review will reject
/// the app for guideline 3.1.3 (anti-steering) if we do.
struct ArkPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    /// Result of the paywall interaction passed back to the caller.
    enum Outcome {
        /// User completed a purchase (initial or upgrade). CustomerInfo
        /// reflects post-purchase state; the "Arkline Pro" entitlement should
        /// be active.
        case purchased(CustomerInfo)
        /// User restored prior purchases. CustomerInfo reflects whatever
        /// active entitlements were found (may or may not include "Arkline Pro").
        case restored(CustomerInfo)
        /// User dismissed without buying or restoring.
        case dismissed
    }

    /// When true, present the discounted "founding" offering (existing users
    /// from before the paid relaunch) instead of the standard "default" offering
    /// (new users). The appropriate offering is resolved asynchronously on
    /// appear; defaults to standard pricing.
    var isFoundingMember: Bool = false

    /// Called when the paywall flow ends — purchase, restore, or dismissal.
    let onCompletion: (Outcome) -> Void

    /// Resolved offering to present. nil while loading, then either the founding
    /// or default offering (or stays nil if the fetch failed, in which case we
    /// fall back to RevenueCatUI's default PaywallView).
    @State private var offering: Offering?
    @State private var didResolveOffering = false

    var body: some View {
        Group {
            if let offering {
                configured(PaywallView(offering: offering))
            } else if didResolveOffering {
                // Offering fetch failed — fall back to the SDK's current offering
                // so the paywall still works rather than showing nothing.
                configured(PaywallView())
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            offering = await RevenueCatService.shared.paywallOffering(foundingMember: isFoundingMember)
            didResolveOffering = true
        }
    }

    /// Attach the purchase/restore completion handlers shared by both the
    /// offering-specific and fallback paywalls.
    private func configured(_ paywall: PaywallView) -> some View {
        paywall
            .onPurchaseCompleted { customerInfo in
                onCompletion(.purchased(customerInfo))
            }
            .onRestoreCompleted { customerInfo in
                onCompletion(.restored(customerInfo))
            }
            .interactiveDismissDisabled(false)
    }
}

#Preview {
    ArkPaywallSheet { outcome in
        print("Paywall outcome:", outcome)
    }
}
