import SwiftUI

// MARK: - GEI Detail View
struct GEIDetailView: View {
    let geiData: GEIData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Score Display
                    scoreHeader

                    // Component Breakdown
                    if let gei = geiData, !gei.components.isEmpty {
                        componentBreakdown(components: gei.components)
                    }

                    // What is the GEI?
                    MacroInfoSection(title: "What is the GEI?", content: """
The Global Economy Index (GEI) is a composite leading indicator that combines 6 economic data points spanning bonds, credit, labor, commodities, and consumer behavior into a single number. A positive GEI signals economic expansion, while a negative GEI signals contraction. It provides a quick "is the economy growing or shrinking?" reading without needing to interpret each indicator individually.
""")

                    // Interpretation Guide
                    interpretationGuide

                    // Impact on Crypto
                    MacroInfoSection(title: "Impact on Crypto", content: """
\u{2022} Expansion (GEI > 0): Risk assets like crypto tend to perform well. Loose financial conditions, strong labor markets, and rising consumer confidence encourage speculative positioning.
\u{2022} Contraction (GEI < 0): Headwinds for crypto. Tightening credit, rising unemployment, and falling sentiment typically lead to risk-off positioning and lower crypto prices.
\u{2022} Extreme expansion (GEI > 1.5): The economy may be overheating. Watch for central bank tightening, which can trigger sharp corrections in risk assets.
\u{2022} Extreme contraction (GEI < -1.5): Historically marks accumulation zones for long-term investors. Maximum fear often precedes policy responses (rate cuts, QE) that fuel the next rally.
\u{2022} Use GEI alongside individual indicators — if GEI is positive but credit spreads are widening, the expansion may be fragile.
""")

                    // Data Sources
                    dataSourcesSection
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Global Economy Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 16) {
            Text(geiData?.formattedScore ?? "--")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(geiData?.scoreColor ?? .gray)

            if let gei = geiData {
                HStack(spacing: 8) {
                    Image(systemName: gei.signal.icon)
                    Text(gei.signalDescription)
                }
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(gei.signal.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(gei.signal.color.opacity(0.15))
                .cornerRadius(12)

                if gei.isExtreme {
                    Text(gei.score > 0 ? "Extreme reading — potential top risk" : "Extreme reading — potential accumulation zone")
                        .font(.caption)
                        .foregroundColor(gei.scoreColor)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Component Breakdown

    private func componentBreakdown(components: [GEIComponent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Component Breakdown")
                .font(.headline)
                .foregroundColor(textPrimary)

            // Header row
            HStack {
                Text("Indicator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Text("Z-Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }

            ForEach(components) { component in
                componentRow(component)
                if component.id != components.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func componentRow(_ component: GEIComponent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary)

                if component.isInverted {
                    Text("Inverted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(component.formattedValue)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(textPrimary)
                .frame(width: 70, alignment: .trailing)

            Text(component.formattedZScore)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(component.contributionColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Interpretation Guide

    private var interpretationGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Interpret")
                .font(.headline)
                .foregroundColor(textPrimary)

            GEILevelRow(range: "Above +1.5", description: "Overheated — watch for policy tightening", color: Color(hex: "22C55E"))
            GEILevelRow(range: "+0.25 to +1.5", description: "Expansion — favorable for risk assets", color: Color(hex: "84CC16"))
            GEILevelRow(range: "-0.25 to +0.25", description: "Neutral — mixed signals, no clear trend", color: Color(hex: "EAB308"))
            GEILevelRow(range: "-1.5 to -0.25", description: "Contraction — headwinds for crypto", color: Color(hex: "F97316"))
            GEILevelRow(range: "Below -1.5", description: "Deep contraction — potential accumulation zone", color: Color(hex: "EF4444"))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Data Sources

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Sources")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                dataSourceRow(name: "Copper Futures (HG=F)", source: "Yahoo Finance", frequency: "Daily")
                dataSourceRow(name: "10Y Treasury Yield (^TNX)", source: "Yahoo Finance", frequency: "Daily")
                dataSourceRow(name: "Yield Curve 10Y-2Y", source: "FRED", frequency: "Daily")
                dataSourceRow(name: "HY Credit Spread", source: "FRED", frequency: "Daily")
                dataSourceRow(name: "Initial Jobless Claims", source: "FRED", frequency: "Weekly")
                dataSourceRow(name: "Consumer Sentiment", source: "FRED", frequency: "Monthly")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func dataSourceRow(name: String, source: String, frequency: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(textPrimary)
            Spacer()
            Text("\(source) · \(frequency)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - GEI Level Row

struct GEILevelRow: View {
    let range: String
    let description: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(range)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 110, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
