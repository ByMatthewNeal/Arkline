import Foundation

/// UserDefaults keys for Presentation Mode — the "show a friend" display mode that
/// masks money but keeps growth percentages visible. The full-hide eye toggle lives
/// separately at `Constants.UserDefaults.portfolioHidden`.
enum PresentationDefaults {
    /// Presentation Mode on/off. Masks currency amounts, keeps percentages and ratios.
    static let enabled = "arkline_presentation_mode"
    /// When Presentation Mode is on, also mask asset quantities and share counts.
    static let hideQuantities = "arkline_presentation_hide_quantities"
}

/// Resolves how portfolio figures should be rendered given the two privacy modes:
///
/// - The full-hide eye toggle (`portfolioHidden`): hides everything — money,
///   percentages, and quantities — for shoulder-surfing privacy.
/// - Presentation Mode: hides money and (optionally) quantities, but deliberately
///   keeps growth percentages and ratios visible so you can show someone your
///   performance without revealing account size.
///
/// Views declare the three `@AppStorage` flags and build a `PrivacyState` from them,
/// then route every figure through these helpers so masking stays consistent and no
/// currency amount ever leaks while a mode is active.
struct PrivacyState {
    let fullyHidden: Bool
    let presentation: Bool
    let hideQuantities: Bool

    init(fullyHidden: Bool, presentation: Bool, hideQuantities: Bool) {
        self.fullyHidden = fullyHidden
        self.presentation = presentation
        self.hideQuantities = hideQuantities
    }

    /// Mask money amounts when either mode is on.
    var maskCurrency: Bool { fullyHidden || presentation }
    /// Only the full-hide toggle masks percentages; Presentation Mode keeps them.
    var maskPercent: Bool { fullyHidden }
    /// Quantities hide under full-hide, or under Presentation Mode when the user opted in.
    var maskQuantity: Bool { fullyHidden || (presentation && hideQuantities) }
    /// Any masking currently active.
    var isActive: Bool { fullyHidden || presentation }

    static let dotsLong = "••••••"
    static let dotsShort = "••••"

    /// Currency figure, masked to dots when money is hidden.
    func currency(_ value: Double, code: String) -> String {
        maskCurrency ? Self.dotsLong : value.asCurrency(code: code)
    }

    /// Signed short currency (e.g. "+$1,234.00") for change / profit-loss rows.
    func signedCurrency(_ value: Double, code: String) -> String {
        maskCurrency ? Self.dotsShort : "\(value >= 0 ? "+" : "")\(value.asCurrency(code: code))"
    }

    /// A pre-formatted quantity string, masked to dots only when quantities are hidden.
    func quantity(_ text: @autoclosure () -> String) -> String {
        maskQuantity ? Self.dotsShort : text()
    }
}
