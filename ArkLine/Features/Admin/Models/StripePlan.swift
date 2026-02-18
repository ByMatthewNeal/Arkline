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
        case .foundingMonthly: return "https://buy.stripe.com/test_4gMdR926zfPNg9QaoC6Ri0c"
        case .foundingAnnual: return "https://buy.stripe.com/test_4gM9ATcLd5b92j08gu6Ri0d"
        case .standardMonthly: return "https://buy.stripe.com/test_00w00jdPh331bTAdAO6Ri0e"
        case .standardAnnual: return "https://buy.stripe.com/test_28E8wP9z1avtcXE40e6Ri0f"
        }
    }

    var price: String {
        switch self {
        case .foundingMonthly: return "$19.99/mo"
        case .foundingAnnual: return "$149.99/yr"
        case .standardMonthly: return "$29.99/mo"
        case .standardAnnual: return "$249.99/yr"
        }
    }

    var isFounder: Bool {
        self == .foundingMonthly || self == .foundingAnnual
    }
}
