import SwiftUI

struct ModelPortfolioCard: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = ModelPortfolioViewModel()
    @State private var showInfo = false
    @State private var pendingPortfolio: ModelPortfolio?
    @State private var isExpanded = false

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
                    // Core
                    if let core = viewModel.corePortfolio {
                        NavigationLink(destination: ModelPortfolioDetailView(
                            portfolio: core,
                            viewModel: viewModel
                        )) {
                            portfolioRow(
                                name: core.name,
                                returnPct: viewModel.coreReturn,
                                nav: viewModel.latestCoreNav?.nav,
                                signal: viewModel.latestCoreNav?.btcSignal,
                                regime: viewModel.latestCoreNav?.macroRegime,
                                isFollowed: viewModel.isFollowing(core)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .background(AppColors.divider(colorScheme))

                    // Edge
                    if let edge = viewModel.edgePortfolio {
                        NavigationLink(destination: ModelPortfolioDetailView(
                            portfolio: edge,
                            viewModel: viewModel
                        )) {
                            portfolioRow(
                                name: edge.name,
                                returnPct: viewModel.edgeReturn,
                                nav: viewModel.latestEdgeNav?.nav,
                                signal: viewModel.latestEdgeNav?.btcSignal,
                                regime: viewModel.latestEdgeNav?.macroRegime,
                                isFollowed: viewModel.isFollowing(edge)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .background(AppColors.divider(colorScheme))

                    // Alpha
                    if let alpha = viewModel.alphaPortfolio {
                        NavigationLink(destination: ModelPortfolioDetailView(
                            portfolio: alpha,
                            viewModel: viewModel
                        )) {
                            portfolioRow(
                                name: alpha.name,
                                returnPct: viewModel.alphaReturn,
                                nav: viewModel.latestAlphaNav?.nav,
                                signal: viewModel.latestAlphaNav?.btcSignal,
                                regime: viewModel.latestAlphaNav?.macroRegime,
                                isFollowed: viewModel.isFollowing(alpha)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .background(AppColors.divider(colorScheme))

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
        let portfolio: ModelPortfolio?
        switch strategy {
        case "core": portfolio = viewModel.corePortfolio
        case "edge": portfolio = viewModel.edgePortfolio
        case "alpha": portfolio = viewModel.alphaPortfolio
        default: portfolio = viewModel.corePortfolio
        }
        if let portfolio {
            pendingPortfolio = portfolio
            appState.pendingModelPortfolioStrategy = nil
        }
    }

    // Portfolio accent colors
    private static let coreColor = Color(hex: "3369FF")   // Blue
    private static let edgeColor = Color(hex: "8B5CF6")   // Purple
    private static let alphaColor = Color(hex: "F97316")  // Orange
    private static let spyColor = Color(hex: "FF9500")    // Amber

    private func portfolioColor(for name: String) -> Color {
        if name.contains("Core") { return Self.coreColor }
        if name.contains("Edge") { return Self.edgeColor }
        if name.contains("Alpha") { return Self.alphaColor }
        return AppColors.accent
    }

    @ViewBuilder
    private func portfolioRow(
        name: String,
        returnPct: Double,
        nav: Double?,
        signal: String?,
        regime: String?,
        isFollowed: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(portfolioColor(for: name))
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
                    Text("Arkline Model Portfolios are AI-generated systematic strategies that use daily positioning signals, macro regime data, and trend analysis to dynamically allocate across crypto assets.")
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
                        name: "S&P 500 Benchmark",
                        color: Color(hex: "FF9500"),
                        description: "Buy & hold S&P 500 benchmark for performance comparison. All portfolios start at the same NAV to provide a fair reference point."
                    )

                    // How it works
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("How It Works")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Text("All positions are spot only — no leverage, futures, or short selling. Portfolios rebalance once daily at 8:30 PM ET based on positioning signals and macro regime conditions. Allocations shift between crypto exposure and defensive assets (stablecoins, gold) depending on market conditions.")
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
                        Text("These model portfolios are generated entirely by AI and are for educational and informational purposes only. They do not constitute financial advice, investment recommendations, or an offer to buy or sell any securities. Past performance does not guarantee future results. Always do your own research (DYOR) and consult a qualified financial advisor before making any investment decisions.")
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
