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
        case .foundingMonthly: return "https://buy.stripe.com/14A3cxeeE3063rP5341Fe03"
        case .foundingAnnual: return "https://buy.stripe.com/00weVf1rSesKbYl8fg1Fe02"
        case .standardMonthly: return "https://buy.stripe.com/aFa9AV0nOgAS9Qd7bc1Fe01"
        case .standardAnnual: return "https://buy.stripe.com/3cI6oJ7QgbgyaUh2UW1Fe00"
        }
    }

    var price: String {
        switch self {
        case .foundingMonthly: return "$39.99/mo"
        case .foundingAnnual: return "$400/yr"
        case .standardMonthly: return "$69.99/mo"
        case .standardAnnual: return "$700/yr"
        }
    }

    var isFounder: Bool {
        self == .foundingMonthly || self == .foundingAnnual
    }

    var priceId: String {
        switch self {
        case .foundingMonthly: return "price_1TXCJyPHuageZ7zbIGTJCHPl"
        case .foundingAnnual: return "price_1TXCOPPHuageZ7zb7d2HyeHc"
        case .standardMonthly: return "price_1TXCPTPHuageZ7zbCrDoFlRO"
        case .standardAnnual: return "price_1TXCQVPHuageZ7zbPW34YDHU"
        }
    }
}
