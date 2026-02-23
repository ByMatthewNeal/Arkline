import SwiftUI

// MARK: - Crude Oil Detail View
struct CrudeOilDetailView: View {
    let crudeOilData: CrudeOilData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var levelColor: Color {
        guard let oil = crudeOilData?.value else { return .gray }
        if oil < 65 { return .green }
        if oil < 75 { return Color(hex: "3B82F6") }
        if oil < 85 { return .orange }
        return .red
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(crudeOilData.map { String(format: "$%.2f", $0.value) } ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        if let change = crudeOilData?.changePercent {
                            HStack(spacing: 8) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%+.2f%%", change))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(levelColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(levelColor.opacity(0.15))
                            .cornerRadius(12)
                        }

                        Text(crudeOilData?.signalDescription ?? "Loading...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(levelColor)
                    }
                    .padding(.top, 20)

                    MacroInfoSection(title: "What is WTI Crude Oil?", content: """
WTI (West Texas Intermediate) is the benchmark for US crude oil prices. It's one of the most-watched commodity prices globally and a leading indicator of inflation expectations. Oil prices directly affect transportation, manufacturing, and energy costs across the economy.
""")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Price Level Interpretation")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        OilLevelRow(range: "Below $55", description: "Very low - Deflationary signal", color: .green)
                        OilLevelRow(range: "$55-65", description: "Low - Easing inflation pressure", color: .green)
                        OilLevelRow(range: "$65-75", description: "Normal range", color: .blue)
                        OilLevelRow(range: "$75-85", description: "Elevated - Rising inflation risk", color: .orange)
                        OilLevelRow(range: "$85-95", description: "High - Inflationary pressure", color: .red)
                        OilLevelRow(range: "Above $95", description: "Very high - Stagflation risk", color: .purple)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    MacroInfoSection(title: "Impact on Crypto", content: """
\u{2022} Rising oil prices drive inflation expectations, making the Fed more hawkish. Higher rates are bearish for risk assets like crypto.
\u{2022} Falling oil prices ease inflation fears, giving the Fed room to cut rates. This is bullish for crypto.
\u{2022} Oil price spikes (geopolitical events) often trigger risk-off moves that hit crypto.
\u{2022} Sustained low oil can signal weak demand (recession risk), which is also bearish.
""")

                    MacroInfoSection(title: "Historical Context", content: """
\u{2022} 2022 Peak: WTI hit $130 after Russia-Ukraine conflict
\u{2022} 2020 COVID Crash: WTI briefly went negative (-$37)
\u{2022} 2014 Shale Boom: Prices fell from $107 to $26
\u{2022} Normal range (2015-2019): $45-75
\u{2022} Current OPEC+ production cuts support prices above $60
""")
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("WTI - Crude Oil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct OilLevelRow: View {
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
                .frame(width: 80, alignment: .leading)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
