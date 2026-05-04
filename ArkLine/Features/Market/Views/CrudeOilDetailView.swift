import SwiftUI
import Charts

// MARK: - Crude Oil Detail View
struct CrudeOilDetailView: View {
    let crudeOilData: CrudeOilData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var timeRange: MacroChartTimeRange = .oneMonth
    @State private var selectedDate: Date? = nil
    @State private var history: [CrudeOilData] = []
    @State private var isLoadingChart = false
    @State private var brentData: CrudeOilData?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var levelColor: Color {
        guard let oil = crudeOilData?.value else { return .gray }
        if oil < 80 { return AppColors.success }    // Bullish
        if oil < 95 { return AppColors.warning }    // Neutral
        return AppColors.error                      // Bearish
    }

    private var signalIcon: String {
        guard let oil = crudeOilData?.value else { return "questionmark" }
        if oil < 80 { return "arrow.up.right" }
        if oil < 95 { return "minus" }
        return "arrow.down.right"
    }

    private var chartData: [MacroChartPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        return history.reversed().compactMap { item -> MacroChartPoint? in
            guard let date = formatter.date(from: item.date), date >= cutoff else { return nil }
            return MacroChartPoint(date: date, value: item.value)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(crudeOilData.map { $0.value.asCurrency } ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .default))
                            .foregroundColor(textPrimary)

                        HStack(spacing: 8) {
                            Image(systemName: signalIcon)
                            Text(crudeOilData?.signalDescription ?? "Loading...")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(levelColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(levelColor.opacity(0.15))
                        .cornerRadius(12)

                        if let change = crudeOilData?.changePercent {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 12))
                                Text(String(format: "%+.2f%%", change))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                    .padding(.top, 20)

                    // Brent vs WTI comparison
                    if let wti = crudeOilData?.value, let brent = brentData?.value {
                        HStack(spacing: 16) {
                            oilPriceCard(label: "WTI", price: wti, change: crudeOilData?.changePercent)
                            oilPriceCard(label: "Brent", price: brent, change: brentData?.changePercent)

                            VStack(spacing: 4) {
                                Text("Spread")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                    .textCase(.uppercase)
                                Text(String(format: "$%.2f", brent - wti))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.06)
                                    : Color.black.opacity(0.04)
                            )
                            .cornerRadius(12)
                        }
                    } else if brentData == nil, crudeOilData != nil {
                        // Brent still loading — show just the label
                        HStack(spacing: 16) {
                            oilPriceCard(label: "WTI", price: crudeOilData?.value ?? 0, change: crudeOilData?.changePercent)

                            VStack(spacing: 4) {
                                Text("Brent")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                    .textCase(.uppercase)
                                ProgressView()
                                    .controlSize(.small)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.06)
                                    : Color.black.opacity(0.04)
                            )
                            .cornerRadius(12)
                        }
                    }

                    MacroIndicatorChart(
                        data: chartData,
                        lineColor: levelColor,
                        valueFormatter: { $0.asCurrency },
                        selectedTimeRange: $timeRange,
                        selectedDate: $selectedDate,
                        isLoading: isLoadingChart
                    )

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

                    MacroInfoSection(title: "WTI vs Brent Crude", content: """
WTI (West Texas Intermediate) is the US benchmark. Brent is the global benchmark, priced from North Sea oil. Brent typically trades at a premium to WTI. A widening spread signals tighter global supply relative to US supply, while a narrowing spread suggests US production constraints or strong domestic demand. Both are leading inflation indicators.
""")

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
            .navigationTitle("Crude Oil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard history.isEmpty else { return }
                isLoadingChart = true
                async let wtiHistory = ServiceContainer.shared.crudeOilService.fetchCrudeOilHistory(days: 365)
                async let brentFetch = YahooFinanceService.shared.fetchBrentOil()

                do { history = try await wtiHistory } catch {}
                do { brentData = try await brentFetch } catch {}
                isLoadingChart = false
            }
        }
    }

    // MARK: - Oil Price Card

    private func oilPriceCard(label: String, price: Double, change: Double?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .textCase(.uppercase)
            Text(price.asCurrency)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(textPrimary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9))
                    Text(String(format: "%+.2f%%", change))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.04)
        )
        .cornerRadius(12)
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
