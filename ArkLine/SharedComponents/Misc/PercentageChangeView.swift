import SwiftUI

// MARK: - Percentage Change View
struct PercentageChangeView: View {
    let value: Double
    var showIcon: Bool = true
    var size: ChangeSize = .medium

    var body: some View {
        HStack(spacing: 2) {
            if showIcon {
                Image(systemName: value >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: size.iconSize, weight: .semibold))
            }

            Text(formattedValue)
                .font(size.font)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value >= 0 ? "Up" : "Down") \(formattedValue)")
    }

    private var formattedValue: String {
        let absValue = abs(value)
        if absValue >= 100 {
            return String(format: "%.0f%%", absValue)
        } else if absValue >= 10 {
            return String(format: "%.1f%%", absValue)
        } else {
            return String(format: "%.2f%%", absValue)
        }
    }

    private var color: Color {
        if value > 0 {
            return Color(hex: "22C55E")
        } else if value < 0 {
            return Color(hex: "EF4444")
        } else {
            return Color(hex: "71717A")
        }
    }
}

// MARK: - Change Size
enum ChangeSize {
    case small
    case medium
    case large

    var font: Font {
        switch self {
        case .small: return .caption
        case .medium: return .subheadline
        case .large: return .body
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
}

// MARK: - Price Change View (with absolute value)
struct PriceChangeView: View {
    let absoluteChange: Double
    let percentageChange: Double
    var currencySymbol: String = "$"
    var size: ChangeSize = .medium

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 2) {
                Text(absoluteChangeFormatted)
                    .font(size.font)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)

            PercentageChangeView(value: percentageChange, showIcon: true, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(absoluteChangeFormatted), \(percentageChange >= 0 ? "up" : "down") \(String(format: "%.2f", abs(percentageChange))) percent")
    }

    private var absoluteChangeFormatted: String {
        let sign = absoluteChange >= 0 ? "+" : ""
        return "\(sign)\(currencySymbol)\(String(format: "%.2f", abs(absoluteChange)))"
    }

    private var color: Color {
        if absoluteChange > 0 {
            return Color(hex: "22C55E")
        } else if absoluteChange < 0 {
            return Color(hex: "EF4444")
        } else {
            return Color(hex: "71717A")
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            PercentageChangeView(value: 5.67)
            PercentageChangeView(value: -3.21)
            PercentageChangeView(value: 0)
        }

        HStack(spacing: 20) {
            PercentageChangeView(value: 12.5, size: .small)
            PercentageChangeView(value: 12.5, size: .medium)
            PercentageChangeView(value: 12.5, size: .large)
        }

        PriceChangeView(absoluteChange: 1234.56, percentageChange: 2.34)
        PriceChangeView(absoluteChange: -567.89, percentageChange: -1.23)
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
