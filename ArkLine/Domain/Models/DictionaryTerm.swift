import SwiftUI

// MARK: - Dictionary Term Model

struct DictionaryTerm: Codable, Identifiable, Hashable {
    let id: UUID
    var term: String
    var definition: String
    var category: String?
    var example: String?
    var relatedTerms: [String]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, term, definition, category, example
        case relatedTerms = "related_terms"
        case createdAt = "created_at"
    }

    // MARK: - Category Helpers

    var categoryIcon: String {
        switch category?.lowercased() {
        case "crypto": return "bitcoinsign.circle.fill"
        case "macro": return "globe.americas.fill"
        case "technical": return "chart.xyaxis.line"
        case "trading": return "arrow.left.arrow.right.circle.fill"
        case "risk": return "exclamationmark.shield.fill"
        case "general": return "book.fill"
        default: return "book.fill"
        }
    }

    var categoryColor: Color {
        switch category?.lowercased() {
        case "crypto": return AppColors.accent
        case "macro": return .purple
        case "technical": return .orange
        case "trading": return AppColors.success
        case "risk": return AppColors.error
        case "general": return .gray
        default: return .gray
        }
    }

    var displayCategory: String {
        category?.capitalized ?? "General"
    }
}

// MARK: - Request Models

struct CreateTermRequest: Codable {
    let term: String
    let definition: String
    let category: String?
    let example: String?
    let relatedTerms: [String]?

    enum CodingKeys: String, CodingKey {
        case term, definition, category, example
        case relatedTerms = "related_terms"
    }
}

struct UpdateTermRequest: Codable {
    let term: String
    let definition: String
    let category: String?
    let example: String?
    let relatedTerms: [String]?

    enum CodingKeys: String, CodingKey {
        case term, definition, category, example
        case relatedTerms = "related_terms"
    }
}
