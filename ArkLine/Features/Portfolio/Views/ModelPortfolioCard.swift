import SwiftUI

struct ModelPortfolioCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = ModelPortfolioViewModel()
    @State private var showInfo = false
    @State private var pendingPortfolio: ModelPortfolio?
    @State private var isExpanded = false
    @State private var rotation: MarketRotation?
    @State private var showRotationDetail = false
    private let rotationService = MarketRotationService()

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            // Header
            HStack {
                // Tappable area to expand/collapse
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.accent)
                        Text("Model Portfolios")
                            .font(AppFonts.title18SemiBold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
            if viewModel.isLoading && viewModel.portfolios.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if viewModel.portfolios.isEmpty {
                Text("No model portfolios available")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(spacing: ArkSpacing.sm) {
                    // Cross-market rotation strip: which market conditions favor, and why
                    if let rotation {
                        rotationStrip(rotation)
                    }

                    // Crypto portfolios
                    if !viewModel.cryptoPortfolios.isEmpty {
                        sectionLabel("Crypto")
                        ForEach(viewModel.cryptoPortfolios) { portfolio in
                            NavigationLink(destination: ModelPortfolioDetailView(
                                portfolio: portfolio,
                                viewModel: viewModel
                            )) {
                                portfolioRow(
                                    name: portfolio.name,
                                    strategy: portfolio.strategy,
                                    returnPct: viewModel.returnPct(for: portfolio),
                                    nav: viewModel.latestNav(for: portfolio)?.nav,
                                    signal: viewModel.latestNav(for: portfolio)?.btcSignal,
                                    regime: viewModel.latestNav(for: portfolio)?.macroRegime,
                                    isFollowed: viewModel.isFollowing(portfolio)
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppColors.divider(colorScheme))
                        }
                    }

                    // Stock portfolios
                    if !viewModel.stockPortfolios.isEmpty {
                        sectionLabel("Stocks")
                        ForEach(viewModel.stockPortfolios) { portfolio in
                            NavigationLink(destination: ModelPortfolioDetailView(
                                portfolio: portfolio,
                                viewModel: viewModel
                            )) {
                                portfolioRow(
                                    name: portfolio.name,
                                    strategy: portfolio.strategy,
                                    returnPct: viewModel.returnPct(for: portfolio),
                                    nav: viewModel.latestNav(for: portfolio)?.nav,
                                    signal: nil,
                                    regime: viewModel.latestNav(for: portfolio)?.macroRegime,
                                    isFollowed: viewModel.isFollowing(portfolio)
                                )
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .background(AppColors.divider(colorScheme))
                        }
                    }

                    // SPY Benchmark
                    if let spy = viewModel.latestBenchmark {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Self.spyColor)
                                .frame(width: 4, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("S&P 500 Benchmark")
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Buy & Hold")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("$\(spy.nav, specifier: "%.0f")")
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Text("\(spy.returnPct >= 0 ? "+" : "")\(spy.returnPct, specifier: "%.1f")%")
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(spy.returnPct >= 0 ? AppColors.success : AppColors.error)
                            }
                        }
                    }
                }
            }
            } // isExpanded
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
        .task {
            await viewModel.loadOverview()
            rotation = try? await rotationService.fetchLatest()
        }
        .sheet(isPresented: $showInfo) {
            ModelPortfolioInfoSheet()
        }
        .navigationDestination(item: $pendingPortfolio) { portfolio in
            ModelPortfolioDetailView(portfolio: portfolio, viewModel: viewModel)
        }
        .onChange(of: appState.pendingModelPortfolioStrategy) { _, strategy in
            guard let strategy, !viewModel.portfolios.isEmpty else { return }
            navigateToStrategy(strategy)
        }
        .onChange(of: viewModel.portfolios) { _, portfolios in
            guard !portfolios.isEmpty,
                  let strategy = appState.pendingModelPortfolioStrategy else { return }
            navigateToStrategy(strategy)
        }
    }

    private func navigateToStrategy(_ strategy: String) {
        let portfolio = viewModel.portfolio(forStrategy: strategy) ?? viewModel.corePortfolio
        if let portfolio {
            pendingPortfolio = portfolio
            appState.pendingModelPortfolioStrategy = nil
        }
    }

    // Portfolio accent colors (keyed by strategy)
    private static let strategyColors: [String: Color] = [
        "core": Color(hex: "3369FF"),        // Blue
        "edge": Color(hex: "8B5CF6"),        // Purple
        "alpha": Color(hex: "F97316"),       // Orange
        "stock_core": Color(hex: "10B981"),  // Green
        "stock_edge": Color(hex: "14B8A6"),  // Teal
    ]
    private static let spyColor = Color(hex: "FF9500")    // Amber

    private func portfolioColor(forStrategy strategy: String) -> Color {
        Self.strategyColors[strategy] ?? AppColors.accent
    }

    // MARK: - Rotation Strip

    /// 30-day return for a market, using the best-known series per asset class
    private func thirtyDayReturn(for portfolios: [ModelPortfolio]) -> Double? {
        let cutoff = Self.dateString(daysAgo: 30)
        var best: Double?
        for p in portfolios {
            let nav = viewModel.navHistory(for: p)
            guard let last = nav.last,
                  let start = nav.first(where: { $0.navDate >= cutoff }), start.nav > 0 else { continue }
            let ret = ((last.nav / start.nav) - 1) * 100
            if best == nil || ret > best! { best = ret }
        }
        return best
    }

    private var spyThirtyDayReturn: Double? {
        let cutoff = Self.dateString(daysAgo: 30)
        guard let last = viewModel.benchmarkNav.last,
              let start = viewModel.benchmarkNav.first(where: { $0.navDate >= cutoff }),
              start.nav > 0 else { return nil }
        return ((last.nav / start.nav) - 1) * 100
    }

    private static func dateString(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date().addingTimeInterval(-Double(daysAgo) * 86400))
    }

    private func rotationColor(_ vote: String) -> Color {
        switch vote {
        case "crypto": return Color(hex: "F7931A")   // BTC orange
        case "stocks": return Color(hex: "10B981")   // equity green
        default: return AppColors.textSecondary
        }
    }

    @ViewBuilder
    private func rotationStrip(_ rotation: MarketRotation) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showRotationDetail.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(rotationColor(rotation.favored))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Conditions favoring: \(rotation.favoredDisplay)")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        HStack(spacing: 6) {
                            if let cryptoRet = thirtyDayReturn(for: viewModel.cryptoPortfolios) {
                                Text("Crypto 30D \(cryptoRet >= 0 ? "+" : "")\(cryptoRet, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(cryptoRet >= 0 ? AppColors.success : AppColors.error)
                            }
                            if let stockRet = thirtyDayReturn(for: viewModel.stockPortfolios) {
                                Text("Stocks 30D \(stockRet >= 0 ? "+" : "")\(stockRet, specifier: "%.1f")%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(stockRet >= 0 ? AppColors.success : AppColors.error)
                            }
                            if let spyRet = spyThirtyDayReturn {
                                Text("SPY \(spyRet >= 0 ? "+" : "")\(spyRet, specifier: "%.1f")%")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: showRotationDetail ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showRotationDetail {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rotation.factors, id: \.factor) { f in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(rotationColor(f.vote))
                                .frame(width: 6, height: 6)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.factor)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                Text(f.detail)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("Descriptive market context, not a recommendation. Where conditions are favorable is where Arkline's coverage leans — you decide where your money goes.")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.top, 2)
                }
                .padding(.top, 4)
            }
        }
        .padding(ArkSpacing.sm)
        .background(rotationColor(rotation.favored).opacity(0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(rotationColor(rotation.favored).opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(AppColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func portfolioRow(
        name: String,
        strategy: String,
        returnPct: Double,
        nav: Double?,
        signal: String?,
        regime: String?,
        isFollowed: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(portfolioColor(forStrategy: strategy))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    if isFollowed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.success)
                    }
                }
                HStack(spacing: 6) {
                    if let signal {
                        signalBadge(signal)
                    }
                    if let regime {
                        Text(regime)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let nav {
                    Text("$\(nav, specifier: "%.0f")")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
                Text("\(returnPct >= 0 ? "+" : "")\(returnPct, specifier: "%.1f")%")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(returnPct >= 0 ? AppColors.success : AppColors.error)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textTertiary)
        }
    }

    @ViewBuilder
    private func signalBadge(_ signal: String) -> some View {
        let color: Color = switch signal.lowercased() {
        case "bullish": AppColors.success
        case "bearish": AppColors.error
        default: AppColors.warning
        }
        Text(signal.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Info Sheet

private struct ModelPortfolioInfoSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Intro
                    Text("Arkline Model Portfolios come in two flavors. Crypto portfolios are AI-generated systematic strategies driven by daily positioning signals, macro regime data, and trend analysis. Equity portfolios are curated investment portfolios — positions held for months to years, updated only when the thesis or risk picture changes.")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    // Portfolio descriptions
                    portfolioSection(
                        name: "Arkline Core",
                        color: Color(hex: "3369FF"),
                        description: "Conservative BTC + ETH strategy. Prioritizes capital preservation with heavier defensive positioning in bearish regimes. Designed for long-term accumulation."
                    )

                    portfolioSection(
                        name: "Arkline Edge",
                        color: Color(hex: "8B5CF6"),
                        description: "Balanced strategy with selective altcoin exposure. Deploys into the top-performing altcoins when conditions are bullish while maintaining a BTC/ETH core."
                    )

                    portfolioSection(
                        name: "Arkline Alpha",
                        color: Color(hex: "F97316"),
                        description: "Alt-heavy aggressive strategy. Allocates 40-50% into top-performing altcoins during bullish conditions. Higher volatility with greater upside potential in alt seasons."
                    )

                    portfolioSection(
                        name: "Arkline Equity Core",
                        color: Color(hex: "10B981"),
                        description: "Conservative equity portfolio. Eight quality AI-era compounders held for years, plus a cash reserve that scales with the macro regime. Low turnover by design."
                    )

                    portfolioSection(
                        name: "Arkline Equity Edge",
                        color: Color(hex: "14B8A6"),
                        description: "Aggressive equity portfolio. Core compounders plus a thematic sleeve of 6–12 month catalyst positions across power, rare earths, AI software, and compute."
                    )

                    portfolioSection(
                        name: "S&P 500 Benchmark",
                        color: Color(hex: "FF9500"),
                        description: "Buy & hold S&P 500 benchmark for performance comparison. All portfolios start at the same NAV to provide a fair reference point."
                    )

                    // How it works
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("How It Works")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Text("All positions are spot only — no leverage, futures, or short selling. Crypto portfolios rebalance once daily at 8:30 PM ET based on positioning signals and macro regime conditions, shifting between crypto exposure and defensive assets (stablecoins, gold). Equity portfolios are investment portfolios, not trading strategies: NAV is marked to market each trading day, and positions change only when the underlying thesis, valuation, or risk picture changes. Equity history before launch is simulated (backtested).")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Disclaimer
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.warning)
                            Text("Important Disclaimer")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }
                        Text("These are hypothetical model portfolios for educational and informational purposes only. They do not constitute financial advice, investment recommendations, or an offer to buy or sell any securities. Past performance does not guarantee future results. Always do your own research (DYOR) and consult a qualified financial advisor before making any investment decisions.")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.warning.opacity(0.08))
                    .cornerRadius(10)
                }
                .padding(ArkSpacing.lg)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("About Model Portfolios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func portfolioSection(name: String, color: Color, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(description)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
