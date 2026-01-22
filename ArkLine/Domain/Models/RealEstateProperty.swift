import Foundation

// MARK: - Property Type Enum
enum PropertyType: String, Codable, CaseIterable {
    case house = "house"
    case condo = "condo"
    case land = "land"
    case apartment = "apartment"
    case commercial = "commercial"

    var displayName: String {
        switch self {
        case .house: return "House"
        case .condo: return "Condo"
        case .land: return "Land"
        case .apartment: return "Apartment"
        case .commercial: return "Commercial"
        }
    }

    var icon: String {
        switch self {
        case .house: return "house.fill"
        case .condo: return "building.fill"
        case .land: return "leaf.fill"
        case .apartment: return "building.2.fill"
        case .commercial: return "storefront.fill"
        }
    }
}

// MARK: - Real Estate Property Model
struct RealEstateProperty: Codable, Identifiable, Equatable {
    let id: UUID
    let holdingId: UUID  // Links to PortfolioHolding

    // Property Details
    var propertyName: String
    var address: String
    var propertyType: PropertyType
    var squareFootage: Double?

    // Financial Details
    var purchasePrice: Double
    var purchaseDate: Date
    var currentEstimatedValue: Double
    var lastValuationDate: Date

    // Income & Expenses
    var monthlyRentalIncome: Double?
    var monthlyExpenses: Double?  // Property tax, HOA, insurance, maintenance

    // Metadata
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case holdingId = "holding_id"
        case propertyName = "property_name"
        case address
        case propertyType = "property_type"
        case squareFootage = "square_footage"
        case purchasePrice = "purchase_price"
        case purchaseDate = "purchase_date"
        case currentEstimatedValue = "current_estimated_value"
        case lastValuationDate = "last_valuation_date"
        case monthlyRentalIncome = "monthly_rental_income"
        case monthlyExpenses = "monthly_expenses"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: UUID = UUID(),
        holdingId: UUID,
        propertyName: String,
        address: String,
        propertyType: PropertyType,
        squareFootage: Double? = nil,
        purchasePrice: Double,
        purchaseDate: Date,
        currentEstimatedValue: Double,
        lastValuationDate: Date = Date(),
        monthlyRentalIncome: Double? = nil,
        monthlyExpenses: Double? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.holdingId = holdingId
        self.propertyName = propertyName
        self.address = address
        self.propertyType = propertyType
        self.squareFootage = squareFootage
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.currentEstimatedValue = currentEstimatedValue
        self.lastValuationDate = lastValuationDate
        self.monthlyRentalIncome = monthlyRentalIncome
        self.monthlyExpenses = monthlyExpenses
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties
extension RealEstateProperty {
    var appreciation: Double {
        currentEstimatedValue - purchasePrice
    }

    var appreciationPercentage: Double {
        guard purchasePrice > 0 else { return 0 }
        return ((currentEstimatedValue - purchasePrice) / purchasePrice) * 100
    }

    var annualRentalIncome: Double {
        (monthlyRentalIncome ?? 0) * 12
    }

    var annualExpenses: Double {
        (monthlyExpenses ?? 0) * 12
    }

    var netAnnualIncome: Double {
        annualRentalIncome - annualExpenses
    }

    var capRate: Double {
        guard currentEstimatedValue > 0 else { return 0 }
        return (netAnnualIncome / currentEstimatedValue) * 100
    }

    var pricePerSquareFoot: Double? {
        guard let sqft = squareFootage, sqft > 0 else { return nil }
        return currentEstimatedValue / sqft
    }

    var isAppreciating: Bool {
        appreciation >= 0
    }
}
