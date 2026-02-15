import SwiftUI

// MARK: - Risk Level Widget (Home Screen)
/// Compact widget for displaying Asset Risk Level on the Home screen
struct RiskLevelWidget: View {
    let riskLevel: ITCRiskLevel?
    var coinSymbol: String = "BTC"
    var daysAtLevel: Int? = nil
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    // MARK: - Sizing
    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 50
        case .standard: return 70
        case .expanded: return 90
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 5
        case .standard: return 8
        case .expanded: return 10
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            Group {
                if let risk = riskLevel {
                    contentView(risk: risk)
                } else {
                    placeholderView
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coinSymbol) risk level: \(riskLevel.map { String(format: "%.0f", $0.riskLevel * 100) } ?? "loading") percent")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView(initialCoin: RiskCoin(rawValue: coinSymbol) ?? .btc)
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private func contentView(risk: ITCRiskLevel) -> some View {
        HStack(spacing: size == .compact ? 12 : 16) {
            // Latest Value Display
            VStack(alignment: .leading, spacing: size == .compact ? 4 : 8) {
                HStack(spacing: 6) {
                    Text("\(coinSymbol) Risk Level")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                }

                // Large colored risk value
                Text(String(format: "%.3f", risk.riskLevel))
                    .font(.system(size: size == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(RiskColors.color(for: risk.riskLevel))

                // Risk category badge with colored dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(RiskColors.color(for: risk.riskLevel))
                        .frame(width: 8, height: 8)

                    Text(RiskColors.category(for: risk.riskLevel))
                        .font(size == .compact ? .caption : .subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))
                }

                if let days = daysAtLevel {
                    Text("\(days) day\(days == 1 ? "" : "s") at this level")
                        .font(.system(size: size == .compact ? 9 : 11))
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                if size == .expanded {
                    Text("intothecryptoverse.com")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))
                }
            }

            Spacer()

            // Mini gauge
            RiskGauge(
                riskLevel: risk.riskLevel,
                size: gaugeSize,
                strokeWidth: strokeWidth,
                colorScheme: colorScheme
            )
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Placeholder View
    private var placeholderView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(coinSymbol) Risk Level")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Text("--")
                    .font(.system(size: size == .compact ? 24 : 32, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary.opacity(0.3))

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            Spacer()

            // Skeleton gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: strokeWidth
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Legacy Alias for backward compatibility
typealias ITCRiskWidget = RiskLevelWidget

// MARK: - Previews
#Preview("ITC Risk Widget - Standard") {
    VStack(spacing: 20) {
        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.409
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.15
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.85
            ),
            size: .standard
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Widget - Compact") {
    ITCRiskWidget(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.409
        ),
        size: .compact
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Card") {
    ITCRiskCard(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.409
        ),
        coinSymbol: "BTC"
    )
    .frame(width: 180)
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Chart View") {
    ITCRiskChartView()
        .environmentObject(AppState())
}
