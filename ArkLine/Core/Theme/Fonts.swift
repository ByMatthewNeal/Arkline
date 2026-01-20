import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - ArkLine Typography System
// Uses Inter for numbers and body text, Urbanist for titles

/// Font configuration namespace
struct AppFonts {
    // MARK: - Font Family Names
    static let interFamily = "Inter"
    static let urbanistFamily = "Urbanist"

    // MARK: - Number Styles (Inter - Bold/Medium)
    static let number64 = interFont(size: 64, weight: .bold)
    static let number44 = interFont(size: 44, weight: .bold)
    static let number36 = interFont(size: 36, weight: .bold)
    static let number24 = interFont(size: 24, weight: .bold)
    static let number20 = interFont(size: 20, weight: .bold)
    static let number20Medium = interFont(size: 20, weight: .medium)

    // MARK: - Title Styles (Urbanist - Medium)
    static let title32 = urbanistFont(size: 32, weight: .medium)
    static let title30 = urbanistFont(size: 30, weight: .medium)
    static let title24 = urbanistFont(size: 24, weight: .medium)
    static let title20 = urbanistFont(size: 20, weight: .medium)

    // MARK: - Text Styles (Inter)
    static let title18Bold = interFont(size: 18, weight: .bold)
    static let title18SemiBold = interFont(size: 18, weight: .semibold)
    static let title16 = interFont(size: 16, weight: .semibold)
    static let body14Bold = interFont(size: 14, weight: .bold)
    static let body14Medium = interFont(size: 14, weight: .medium)
    static let body14 = interFont(size: 14, weight: .regular)
    static let caption12Medium = interFont(size: 12, weight: .medium)
    static let caption12 = interFont(size: 12, weight: .regular)
    static let footnote10Bold = interFont(size: 10, weight: .bold)
    static let footnote10 = interFont(size: 10, weight: .regular)

    // MARK: - Font Factory Methods

    /// Creates an Inter font with given size and weight
    static func interFont(size: CGFloat, weight: Font.Weight) -> Font {
        // Try custom font first, fall back to system
        if fontExists(name: interFontName(for: weight), size: size) {
            return .custom(interFontName(for: weight), size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// Creates an Urbanist font with given size and weight
    static func urbanistFont(size: CGFloat, weight: Font.Weight) -> Font {
        // Try custom font first, fall back to system rounded
        if fontExists(name: urbanistFontName(for: weight), size: size) {
            return .custom(urbanistFontName(for: weight), size: size)
        }
        return .system(size: size, weight: weight, design: .rounded)
    }

    /// Check if a font exists on the current platform
    private static func fontExists(name: String, size: CGFloat) -> Bool {
        #if canImport(UIKit)
        return UIFont(name: name, size: size) != nil
        #elseif canImport(AppKit)
        return NSFont(name: name, size: size) != nil
        #else
        return false
        #endif
    }

    /// Maps Font.Weight to Inter font file name
    private static func interFontName(for weight: Font.Weight) -> String {
        switch weight {
        case .regular: return "Inter-Regular"
        case .medium: return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold: return "Inter-Bold"
        default: return "Inter-Regular"
        }
    }

    /// Maps Font.Weight to Urbanist font file name
    private static func urbanistFontName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "Urbanist-Medium"
        case .semibold: return "Urbanist-SemiBold"
        case .bold: return "Urbanist-Bold"
        default: return "Urbanist-Medium"
        }
    }
}

// MARK: - Font Style Enum for Convenience
enum ArkFontStyle {
    // Numbers
    case number64, number44, number36, number24, number20, number20Medium
    // Titles (Urbanist)
    case title32, title30, title24, title20
    // Text (Inter)
    case title18Bold, title18SemiBold, title16
    case body14Bold, body14Medium, body14
    case caption12Medium, caption12
    case footnote10Bold, footnote10

    var font: Font {
        switch self {
        case .number64: return AppFonts.number64
        case .number44: return AppFonts.number44
        case .number36: return AppFonts.number36
        case .number24: return AppFonts.number24
        case .number20: return AppFonts.number20
        case .number20Medium: return AppFonts.number20Medium
        case .title32: return AppFonts.title32
        case .title30: return AppFonts.title30
        case .title24: return AppFonts.title24
        case .title20: return AppFonts.title20
        case .title18Bold: return AppFonts.title18Bold
        case .title18SemiBold: return AppFonts.title18SemiBold
        case .title16: return AppFonts.title16
        case .body14Bold: return AppFonts.body14Bold
        case .body14Medium: return AppFonts.body14Medium
        case .body14: return AppFonts.body14
        case .caption12Medium: return AppFonts.caption12Medium
        case .caption12: return AppFonts.caption12
        case .footnote10Bold: return AppFonts.footnote10Bold
        case .footnote10: return AppFonts.footnote10
        }
    }
}

// MARK: - View Modifiers for Typography

struct ArkTypography: ViewModifier {
    let style: ArkFontStyle
    let color: Color?

    init(_ style: ArkFontStyle, color: Color? = nil) {
        self.style = style
        self.color = color
    }

    func body(content: Content) -> some View {
        if let color = color {
            content
                .font(style.font)
                .foregroundStyle(color)
        } else {
            content
                .font(style.font)
        }
    }
}

extension View {
    /// Apply ArkLine typography style
    func arkFont(_ style: ArkFontStyle, color: Color? = nil) -> some View {
        modifier(ArkTypography(style, color: color))
    }

    // MARK: - Convenience Modifiers for Numbers

    func arkNumber64(color: Color? = nil) -> some View {
        arkFont(.number64, color: color)
    }

    func arkNumber44(color: Color? = nil) -> some View {
        arkFont(.number44, color: color)
    }

    func arkNumber36(color: Color? = nil) -> some View {
        arkFont(.number36, color: color)
    }

    func arkNumber24(color: Color? = nil) -> some View {
        arkFont(.number24, color: color)
    }

    func arkNumber20(color: Color? = nil) -> some View {
        arkFont(.number20, color: color)
    }

    // MARK: - Convenience Modifiers for Titles

    func arkTitle32(color: Color? = nil) -> some View {
        arkFont(.title32, color: color)
    }

    func arkTitle30(color: Color? = nil) -> some View {
        arkFont(.title30, color: color)
    }

    func arkTitle24(color: Color? = nil) -> some View {
        arkFont(.title24, color: color)
    }

    func arkTitle20(color: Color? = nil) -> some View {
        arkFont(.title20, color: color)
    }

    // MARK: - Convenience Modifiers for Body Text

    func arkTitle18(color: Color? = nil) -> some View {
        arkFont(.title18SemiBold, color: color)
    }

    func arkTitle16(color: Color? = nil) -> some View {
        arkFont(.title16, color: color)
    }

    func arkBody(color: Color? = nil) -> some View {
        arkFont(.body14, color: color)
    }

    func arkBodyMedium(color: Color? = nil) -> some View {
        arkFont(.body14Medium, color: color)
    }

    func arkCaption(color: Color? = nil) -> some View {
        arkFont(.caption12, color: color)
    }

    func arkFootnote(color: Color? = nil) -> some View {
        arkFont(.footnote10, color: color)
    }
}

// MARK: - Legacy Support (for existing code compatibility)

struct ArkFonts {
    // Map old names to new system
    static let largeTitle = AppFonts.title32
    static let title = AppFonts.title30
    static let title2 = AppFonts.title24
    static let title3 = AppFonts.title20
    static let headline = AppFonts.title18SemiBold
    static let body = AppFonts.body14
    static let bodyMedium = AppFonts.body14Medium
    static let bodySemibold = AppFonts.body14Bold
    static let subheadline = AppFonts.body14Medium
    static let subheadlineMedium = AppFonts.body14Medium
    static let footnote = AppFonts.caption12
    static let footnoteMedium = AppFonts.caption12Medium
    static let caption = AppFonts.caption12
    static let captionMedium = AppFonts.caption12Medium
    static let caption2 = AppFonts.footnote10
    static let display = AppFonts.number44

    // Numeric fonts
    static let numericLarge = AppFonts.number44
    static let numericTitle = AppFonts.number36
    static let numericBody = AppFonts.number20Medium
    static let numericCaption = AppFonts.caption12Medium
}

// MARK: - Legacy View Modifiers (for backward compatibility)

extension View {
    func arkLargeTitle(color: Color = .white) -> some View {
        arkFont(.title32, color: color)
    }

    func arkTitle(color: Color = .white) -> some View {
        arkFont(.title30, color: color)
    }

    func arkTitle2(color: Color = .white) -> some View {
        arkFont(.title24, color: color)
    }

    func arkTitle3(color: Color = .white) -> some View {
        arkFont(.title20, color: color)
    }

    func arkHeadline(color: Color = .white) -> some View {
        arkFont(.title18SemiBold, color: color)
    }

    func arkSubheadline(color: Color = .gray) -> some View {
        arkFont(.body14Medium, color: color)
    }
}
