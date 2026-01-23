import SwiftUI

// MARK: - Risk Tooltip View
/// Floating tooltip showing risk level details at a selected chart point.
struct RiskTooltipView: View {
    let date: Date
    let riskLevel: Double
    let price: Double?
    let fairValue: Double?
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var formattedPrice: String {
        guard let price = price else { return "--" }
        if price >= 1000 {
            return "$\(Int(price).formatted())"
        } else if price >= 1 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.4f", price)
        }
    }

    private var formattedFairValue: String {
        guard let fairValue = fairValue else { return "--" }
        if fairValue >= 1000 {
            return "$\(Int(fairValue).formatted())"
        } else if fairValue >= 1 {
            return String(format: "$%.2f", fairValue)
        } else {
            return String(format: "$%.4f", fairValue)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date
            Text(formattedDate)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(textSecondary)

            // Risk Level
            HStack(spacing: 6) {
                Circle()
                    .fill(riskColor)
                    .frame(width: 10, height: 10)

                Text(String(format: "%.3f", riskLevel))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(riskColor)
            }

            // Risk Category
            Text(RiskColors.category(for: riskLevel))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(riskColor)

            // Price info (if available)
            if price != nil {
                Divider()
                    .background(textSecondary.opacity(0.2))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Price:")
                            .font(.caption2)
                            .foregroundColor(textSecondary)
                        Spacer()
                        Text(formattedPrice)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(textPrimary)
                    }

                    if fairValue != nil {
                        HStack {
                            Text("Fair Value:")
                                .font(.caption2)
                                .foregroundColor(textSecondary)
                            Spacer()
                            Text(formattedFairValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(textSecondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(riskColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Selection Indicator
/// Visual indicator for chart selection point
struct ChartSelectionIndicator: View {
    let riskLevel: Double

    private var riskColor: Color {
        RiskColors.color(for: riskLevel)
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(riskColor.opacity(0.3))
                .frame(width: 20, height: 20)

            // Inner circle
            Circle()
                .fill(riskColor)
                .frame(width: 10, height: 10)

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Previews
#Preview("Risk Tooltip - Low Risk") {
    VStack {
        RiskTooltipView(
            date: Date(),
            riskLevel: 0.25,
            price: 45000,
            fairValue: 42000
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("Risk Tooltip - High Risk") {
    VStack {
        RiskTooltipView(
            date: Date(),
            riskLevel: 0.78,
            price: 95000,
            fairValue: 55000
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("Risk Tooltip - No Price") {
    VStack {
        RiskTooltipView(
            date: Date(),
            riskLevel: 0.45,
            price: nil,
            fairValue: nil
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
