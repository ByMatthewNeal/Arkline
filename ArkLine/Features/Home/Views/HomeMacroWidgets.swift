import SwiftUI

// MARK: - VIX Widget
struct VIXWidget: View {
    let vixData: VIXData?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var signalColor: Color {
        guard let vix = vixData?.value else { return .secondary }
        if vix < 18 { return AppColors.success }
        if vix > 25 { return AppColors.error }
        return AppColors.warning
    }

    private var levelDescription: String {
        guard let vix = vixData?.value else { return "--" }
        if vix < 15 { return "Low" }
        if vix < 20 { return "Normal" }
        if vix < 25 { return "Elevated" }
        return "High"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: size == .compact ? 6 : 10) {
                HStack(alignment: .center) {
                    Text("VIX")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                Text(vixData.map { String(format: "%.2f", $0.value) } ?? "--")
                    .font(.system(size: size == .compact ? 28 : 36, weight: .semibold, design: .default))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                HStack {
                    Text("Volatility Index")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(levelDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(signalColor)
                }
            }
            .padding(size == .compact ? 12 : 16)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            VIXDetailView(vixData: vixData)
        }
    }
}

// MARK: - DXY Widget
struct DXYWidget: View {
    let dxyData: DXYData?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var signalColor: Color {
        guard let change = dxyData?.changePercent else { return .secondary }
        if change > 0.3 { return AppColors.error }
        if change < -0.3 { return AppColors.success }
        return AppColors.warning
    }

    private var trendDescription: String {
        guard let change = dxyData?.changePercent else { return "--" }
        if change < -0.5 { return "Weakening" }
        if change > 0.5 { return "Strengthening" }
        return "Stable"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: size == .compact ? 6 : 10) {
                HStack(alignment: .center) {
                    Text("DXY")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(dxyData.map { String(format: "%.2f", $0.value) } ?? "--")
                        .font(.system(size: size == .compact ? 28 : 36, weight: .semibold, design: .default))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()

                    if let change = dxyData?.changePercent {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(change >= 0 ? AppColors.error : AppColors.success)
                    }
                }

                HStack {
                    Text("US Dollar Index")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(trendDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(signalColor)
                }
            }
            .padding(size == .compact ? 12 : 16)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            DXYDetailView(dxyData: dxyData)
        }
    }
}

// MARK: - Global Liquidity Widget
struct GlobalLiquidityWidget: View {
    let liquidityChanges: GlobalLiquidityChanges?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var signalColor: Color {
        guard let liquidity = liquidityChanges else { return .secondary }
        if liquidity.monthlyChange > 1.0 { return AppColors.success }
        if liquidity.monthlyChange < -1.0 { return AppColors.error }
        return AppColors.warning
    }

    private var trendDescription: String {
        guard let liquidity = liquidityChanges else { return "--" }
        if liquidity.monthlyChange > 2.0 { return "Expanding" }
        if liquidity.monthlyChange > 0 { return "Growing" }
        if liquidity.monthlyChange > -2.0 { return "Contracting" }
        return "Shrinking"
    }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1fT", value / 1_000_000_000_000)
        } else if value >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        }
        return String(format: "$%.0f", value)
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: size == .compact ? 6 : 10) {
                HStack(alignment: .center) {
                    Text("Global M2")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(liquidityChanges.map { formatLiquidity($0.current) } ?? "--")
                        .font(.system(size: size == .compact ? 28 : 36, weight: .semibold, design: .default))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()

                    if let change = liquidityChanges?.monthlyChange {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }

                HStack {
                    Text("Money Supply")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(trendDescription)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(signalColor)
                }
            }
            .padding(size == .compact ? 12 : 16)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            GlobalM2DetailView(liquidityChanges: liquidityChanges)
        }
    }
}

// MARK: - VIX Detail View
struct VIXDetailView: View {
    let vixData: VIXData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(vixData.map { String(format: "%.2f", $0.value) } ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        Text(vixData?.signalDescription ?? "Loading...")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(signalColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(signalColor.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)

                    MacroInfoSection(title: "What is VIX?", content: """
The CBOE Volatility Index (VIX) measures the market's expectation of 30-day volatility implied by S&P 500 index options. Often called the "fear gauge," it reflects investor sentiment and uncertainty in the market.
""")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Level Interpretation")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        VIXLevelRow(range: "Below 15", description: "Low volatility - Complacency", color: .green)
                        VIXLevelRow(range: "15-20", description: "Normal market conditions", color: .blue)
                        VIXLevelRow(range: "20-25", description: "Elevated uncertainty", color: .orange)
                        VIXLevelRow(range: "25-30", description: "High fear - Market stress", color: .red)
                        VIXLevelRow(range: "Above 30", description: "Extreme fear - Potential panic", color: .purple)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    MacroInfoSection(title: "Impact on Crypto", content: """
• High VIX (>25): Risk-off environment. Investors flee to safety, often selling crypto.
• Low VIX (<18): Risk-on sentiment. Investors seek higher returns in assets like crypto.
• VIX spikes often coincide with Bitcoin drawdowns as correlations increase during market stress.
""")

                    MacroInfoSection(title: "Historical Context", content: """
• Average VIX: ~19-20
• COVID crash (Mar 2020): VIX hit 82.69
• 2008 Financial Crisis: VIX peaked at 89.53
• Calm markets: VIX can stay below 15 for extended periods
""")
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("VIX - Volatility Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var signalColor: Color {
        guard let vix = vixData?.value else { return .gray }
        if vix < 18 { return .green }
        if vix < 25 { return .orange }
        return .red
    }
}

struct VIXLevelRow: View {
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

// MARK: - DXY Detail View
struct DXYDetailView: View {
    let dxyData: DXYData?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(dxyData.map { String(format: "%.2f", $0.value) } ?? "--")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        if let change = dxyData?.changePercent {
                            HStack(spacing: 8) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%+.2f%%", change))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(change >= 0 ? .red : .green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background((change >= 0 ? Color.red : Color.green).opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 20)

                    MacroInfoSection(title: "What is DXY?", content: """
The US Dollar Index (DXY) measures the value of the US dollar relative to a basket of foreign currencies: Euro (57.6%), Japanese Yen (13.6%), British Pound (11.9%), Canadian Dollar (9.1%), Swedish Krona (4.2%), and Swiss Franc (3.6%).
""")

                    MacroInfoSection(title: "Impact on Crypto", content: """
• Rising DXY: Bearish for crypto. A stronger dollar reduces appetite for risk assets.
• Falling DXY: Bullish for crypto. Dollar weakness often drives investors to alternatives.
• BTC and DXY typically show inverse correlation, especially during macro-driven markets.
""")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Historical Ranges")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        DXYLevelRow(range: "Below 90", description: "Weak dollar - Risk-on", color: .green)
                        DXYLevelRow(range: "90-100", description: "Normal range", color: .blue)
                        DXYLevelRow(range: "100-105", description: "Strong dollar", color: .orange)
                        DXYLevelRow(range: "Above 105", description: "Very strong - Risk-off", color: .red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    MacroInfoSection(title: "Historical Context", content: """
• 2022 Peak: DXY reached ~114, highest in 20 years
• Pre-COVID: Typically ranged 95-100
• 2008 Low: Around 71
• Current Fed policy significantly impacts DXY movements
""")
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("DXY - Dollar Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DXYLevelRow: View {
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

// MARK: - Global M2 Detail View
struct GlobalM2DetailView: View {
    let liquidityChanges: GlobalLiquidityChanges?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000_000)
        }
        return String(format: "$%.2fB", value / 1_000_000_000)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Text(liquidityChanges.map { formatLiquidity($0.current) } ?? "--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(textPrimary)

                        if let change = liquidityChanges?.monthlyChange {
                            HStack(spacing: 8) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text(String(format: "%+.2f%% MoM", change))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(change >= 0 ? .green : .red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background((change >= 0 ? Color.green : Color.red).opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 20)

                    MacroInfoSection(title: "What is Global M2?", content: """
Global M2 represents the total money supply across major economies, including cash, checking deposits, and easily convertible near-money. It's a key indicator of global liquidity and monetary conditions.
""")

                    if let liquidity = liquidityChanges {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Change Overview")
                                .font(.headline)
                                .foregroundColor(textPrimary)

                            if let daily = liquidity.dailyChange {
                                M2ChangeRow(
                                    period: "Daily",
                                    change: daily,
                                    dollarChange: liquidity.formatDollars(liquidity.dailyChangeDollars ?? 0)
                                )
                            }
                            M2ChangeRow(
                                period: "Weekly",
                                change: liquidity.weeklyChange,
                                dollarChange: liquidity.formatDollars(liquidity.weeklyChangeDollars)
                            )
                            M2ChangeRow(
                                period: "Monthly",
                                change: liquidity.monthlyChange,
                                dollarChange: liquidity.formatDollars(liquidity.monthlyChangeDollars)
                            )
                            M2ChangeRow(
                                period: "Yearly",
                                change: liquidity.yearlyChange,
                                dollarChange: liquidity.formatDollars(liquidity.yearlyChangeDollars)
                            )
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }

                    MacroInfoSection(title: "Impact on Crypto", content: """
• Expanding M2: Bullish for crypto. More liquidity seeks higher-yielding assets.
• Contracting M2: Bearish for crypto. Quantitative tightening reduces risk appetite.
• Bitcoin often moves with global M2 with a ~10-week lag.
• M2 expansion was a key driver of 2020-2021 crypto bull run.
""")

                    MacroInfoSection(title: "Historical Context", content: """
• 2020-2021: Unprecedented M2 expansion (~40% growth)
• 2022-2023: First M2 contraction in decades
• Correlation with BTC: ~0.8 over long timeframes
• Central bank balance sheets directly impact global M2
""")

                    Text("This product uses the FRED® API but is not endorsed or certified by the Federal Reserve Bank of St. Louis.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Global M2 - Money Supply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct M2ChangeRow: View {
    let period: String
    let change: Double
    var dollarChange: String? = nil

    var body: some View {
        HStack {
            Text(period)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%+.2f%%", change))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(change >= 0 ? .green : .red)
                if let dollar = dollarChange {
                    Text(dollar)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct MacroInfoSection: View {
    let title: String
    let content: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
