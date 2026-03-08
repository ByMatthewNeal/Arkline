import Foundation

enum StripePlan: String, CaseIterable, Identifiable {
    case foundingMonthly
    case foundingAnnual
    case standardMonthly
    case standardAnnual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundingMonthly: return "Founding Member \u{2014} Monthly"
        case .foundingAnnual: return "Founding Member \u{2014} Annual"
        case .standardMonthly: return "Standard \u{2014} Monthly"
        case .standardAnnual: return "Standard \u{2014} Annual"
        }
    }

    var shortName: String {
        switch self {
        case .foundingMonthly: return "Founding Mo."
        case .foundingAnnual: return "Founding Yr."
        case .standardMonthly: return "Standard Mo."
        case .standardAnnual: return "Standard Yr."
        }
    }

    var paymentURL: String {
        switch self {
        case .foundingMonthly: return "https://buy.stripe.com/test_14AfZhfXpbzx8Ho8gu6Ri0j"
        case .foundingAnnual: return "https://buy.stripe.com/test_14A28r26zfPN5vceES6Ri0i"
        case .standardMonthly: return "https://buy.stripe.com/test_5kQ3cvbH91YX4r8bsG6Ri0h"
        case .standardAnnual: return "https://buy.stripe.com/test_9B6cN5fXpeLJ9Ls54i6Ri0g"
        }
    }

    var price: String {
        switch self {
        case .foundingMonthly: return "$39.99/mo"
        case .foundingAnnual: return "$400/yr"
        case .standardMonthly: return "$59.99/mo"
        case .standardAnnual: return "$650/yr"
        }
    }

    var isFounder: Bool {
        self == .foundingMonthly || self == .foundingAnnual
    }

    var priceId: String {
        switch self {
        case .foundingMonthly: return "price_1T7fMpIkKaS0zcmXlgr4orwA"
        case .foundingAnnual: return "price_1T7fNgIkKaS0zcmXmhkZDBl0"
        case .standardMonthly: return "price_1T7fOAIkKaS0zcmX3ZwtcSZO"
        case .standardAnnual: return "price_1T7fOlIkKaS0zcmXop5vY67x"
        }
    }
}
