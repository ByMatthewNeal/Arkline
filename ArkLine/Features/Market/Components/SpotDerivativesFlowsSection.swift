import SwiftUI
import Charts

// MARK: - Shared helpers
private func fmtSignedM(_ v: Double) -> String {
    let sign = v > 0 ? "+" : (v < 0 ? "-" : "")
    let a = abs(v)
    if a >= 1000 { return String(format: "%@$%.1fB", sign, a / 1000) }
    return String(format: "%@$%.0fM", sign, a)
}

private func fmtSignedPct(_ v: Double) -> String {
    String(format: "%@%.1f%%", v > 0 ? "+" : "", v)
}

private func fmtK(_ v: Double) -> String {
    v >= 1000 ? String(format: "$%.1fk", v / 1000) : String(format: "$%.0f", v)
}

private func regimeColor(_ regime: String?) -> Color {
    switch regime {
    case "Spot-led bid", "Broad risk-on": return Color(red: 0.20, green: 0.70, blue: 0.42)
    case "Leverage-driven": return Color(red: 0.95, green: 0.62, blue: 0.20)
    case "Deleveraging": return Color(red: 0.90, green: 0.33, blue: 0.33)
    default: return Color(red: 0.40, green: 0.55, blue: 0.95)
    }
}

// MARK: - Market Section (compact card)
struct SpotDerivativesFlowsSection: View {
    var refreshId: UUID = UUID()
    var embedded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var data: SpotDerivativesFlowsData?
    @State private var isLoading = true

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spot vs Derivatives")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
                if let d = data, let r = d.regime {
                    Text(r)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(regimeColor(r))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(regimeColor(r).opacity(0.14)))
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: 10).fill(cardBackground.opacity(0.4))
                    .frame(height: 120).redacted(reason: .placeholder).shimmer(isLoading: true)
            } else if let d = data {
                NavigationLink {
                    SpotDerivativesFlowsDetailView()
                } label: {
                    VStack(spacing: 12) {
                        if let note = d.regimeNote {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(spacing: 10) {
                            statChip("Spot 7d", d.cvd7d.map(fmtSignedM) ?? "—",
                                     (d.cvd7d ?? 0) >= 0 ? .green : .red)
                            statChip("OI 7d", d.oi7dPct.map(fmtSignedPct) ?? "—",
                                     (d.oi7dPct ?? 0) >= 0 ? .green : .red)
                            statChip("Funding", d.fundingNow.map { String(format: "%.3f%%", $0) } ?? "—",
                                     (d.fundingNow ?? 0) >= 0 ? .green : .red)
                        }
                        HStack {
                            Text("Open details")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Text("Flow data unavailable right now.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
            }
        }
        .padding(.horizontal, embedded ? 0 : 16)
        .task(id: refreshId) { await load() }
    }

    private func statChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08)))
    }

    private func load() async {
        let d = try? await ServiceContainer.shared.spotDerivativesFlowsService.fetch()
        data = d
        isLoading = false
    }
}

// MARK: - Detail View
struct SpotDerivativesFlowsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var data: SpotDerivativesFlowsData?
    @State private var isLoading = true

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && data == nil {
                    HStack { Spacer(); ProgressView().padding(.vertical, 60); Spacer() }
                } else if let d = data {
                    regimeBanner(d)

                    chartCard(
                        title: "Spot CVD",
                        subtitle: "Cumulative spot buying minus selling across Binance, Coinbase and Kraken",
                        value: d.spotCvd.last.map { fmtSignedM($0) } ?? "—",
                        series: d.spotCvd, days: d.days,
                        color: Color(red: 0.20, green: 0.70, blue: 0.42), baseline: false)

                    chartCard(
                        title: "Open Interest",
                        subtitle: "Total perp positions open, in USD",
                        value: d.oiUsd.last.map { String(format: "$%.2fB", $0) } ?? "—",
                        series: d.oiUsd, days: d.days,
                        color: Color(red: 0.40, green: 0.55, blue: 0.95), baseline: false)

                    chartCard(
                        title: "Funding Rate",
                        subtitle: "Positive means longs pay shorts (crowded long)",
                        value: d.fundingNow.map { String(format: "%.3f%%", $0) } ?? "—",
                        series: d.fundingPct, days: d.days,
                        color: Color(red: 0.95, green: 0.62, blue: 0.20), baseline: true)
                } else {
                    Text("Flow data unavailable right now.")
                        .font(.subheadline).foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                }

                howItWorks
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .navigationTitle("Spot vs Derivatives")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.background(colorScheme))
        .task { await load() }
    }

    private func regimeBanner(_ d: SpotDerivativesFlowsData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(regimeColor(d.regime)).frame(width: 9, height: 9)
                Text(d.regime ?? "Mixed")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
                Spacer()
                Text("BTC \(fmtK(d.currentPrice))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
            }
            if let note = d.regimeNote {
                Text(note).font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(regimeColor(d.regime).opacity(0.10)))
        .padding(.horizontal)
    }

    private func chartCard(title: String, subtitle: String, value: String,
                           series: [Double], days: [Double], color: Color, baseline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(textPrimary)
                Spacer()
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(color)
            }
            Text(subtitle).font(.system(size: 11)).foregroundColor(AppColors.textTertiary)

            Chart {
                if baseline {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(AppColors.textTertiary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                }
                ForEach(Array(series.enumerated()), id: \.offset) { i, v in
                    if i < days.count {
                        LineMark(
                            x: .value("Day", Date(timeIntervalSince1970: days[i])),
                            y: .value(title, v)
                        )
                        .foregroundStyle(color)
                        .interpolationMethod(.monotone)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine().foregroundStyle(AppColors.textTertiary.opacity(0.12))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine().foregroundStyle(AppColors.textTertiary.opacity(0.12))
                    AxisValueLabel().foregroundStyle(AppColors.textTertiary)
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Read This")
                .font(.headline).foregroundColor(textPrimary)
            bullet("Spot CVD rising means buyers are lifting the offer on real spot exchanges. That is organic demand, not leverage.")
            bullet("Open interest is the size of leveraged positioning. Price rising on rising OI with flat spot is leverage driven and tends to be more fragile.")
            bullet("Funding is what longs and shorts pay each other. Persistently high positive funding means the long side is crowded.")
            bullet("The best setups usually have spot leading. Leverage led moves unwind faster. Guides, not guarantees. Source: Coinalyze.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundColor(AppColors.accent)
            Text(text).font(.subheadline).foregroundColor(AppColors.textSecondary)
        }
    }

    private func load() async {
        let d = try? await ServiceContainer.shared.spotDerivativesFlowsService.fetch()
        data = d
        isLoading = false
    }
}
