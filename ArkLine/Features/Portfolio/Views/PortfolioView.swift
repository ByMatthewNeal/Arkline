import SwiftUI

struct PortfolioView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = PortfolioViewModel()
    @State private var activeSheet: PortfolioSheet?
    @State private var navigationPath = NavigationPath()

    private enum PortfolioSheet: Identifiable {
        case addTransaction
        case createPortfolio
        case portfolioPicker
        case showcase

        var id: Int { hashValue }
    }

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()

                // Content
                VStack(spacing: 0) {
                // Error Banner
                if let error = viewModel.error {
                    ErrorBanner(error: error) {
                        viewModel.dismissError()
                    } onRetry: {
                        Task { await viewModel.refresh() }
                    }
                }

                // Stale Price Warning
                if viewModel.priceRefreshFailed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("Prices may be outdated")
                            .font(AppFonts.caption12)
                        Spacer()
                        Button("Retry") {
                            Task { await viewModel.refreshPrices() }
                        }
                        .font(AppFonts.caption12Medium)
                    }
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                // Portfolio Value Header
                PortfolioHeader(
                    totalValue: viewModel.totalValue,
                    dayChange: viewModel.dayChange,
                    dayChangePercentage: viewModel.dayChangePercentage,
                    profitLoss: viewModel.totalProfitLoss,
                    profitLossPercentage: viewModel.totalProfitLossPercentage
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Tab Selector
                PortfolioTabSelector(selectedTab: $viewModel.selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Content
                ZStack {
                    ScrollViewReader { scrollProxy in
                    ScrollView {
                        Color.clear.frame(height: 0).id("scrollTop")
                        switch viewModel.selectedTab {
                        case .overview:
                            PortfolioOverviewContent(viewModel: viewModel)
                        case .holdings:
                            PortfolioHoldingsContent(viewModel: viewModel)
                        case .allocation:
                            PortfolioAllocationContent(viewModel: viewModel)
                        case .dcaCalculator:
                            DCACalculatorView(viewModel: viewModel)
                        case .performance:
                            PerformanceView(viewModel: viewModel)
                        case .transactions:
                            PortfolioTransactionsContent(viewModel: viewModel)
                        }

                        // Disclaimer
                        FinancialDisclaimer()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Spacer(minLength: 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                    .task {
                        await viewModel.refresh()
                    }
                    .onAppear {
                        Task { await AnalyticsService.shared.trackScreenView("portfolio") }
                    }
                    .onChange(of: appState.portfolioNavigationReset) { _, _ in
                        navigationPath = NavigationPath()
                        withAnimation(.arkSpring) {
                            scrollProxy.scrollTo("scrollTop", anchor: .top)
                        }
                    }
                    } // ScrollViewReader

                    // Loading Overlay
                    if viewModel.isLoading {
                        LoadingOverlay()
                    }
                }
                }
            }
            .navigationTitle(viewModel.selectedPortfolio?.name ?? "Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { activeSheet = .portfolioPicker }) {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedPortfolio?.name ?? "Portfolio")
                                .font(AppFonts.title18SemiBold)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                    .accessibilityLabel("Switch portfolio, current: \(viewModel.selectedPortfolio?.name ?? "Portfolio")")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: ArkSpacing.sm) {
                        // Showcase button
                        Button(action: { activeSheet = .showcase }) {
                            Image(systemName: "square.split.2x1")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Portfolio showcase")

                        // Add transaction button
                        Button(action: { activeSheet = .addTransaction }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Add transaction")
                    }
                }
            }
            #endif
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .portfolioPicker:
                    PortfolioSwitcherSheet(
                        portfolios: viewModel.portfolios,
                        selectedPortfolio: Binding(
                            get: { viewModel.selectedPortfolio },
                            set: { portfolio in
                                if let portfolio = portfolio {
                                    viewModel.selectPortfolio(portfolio)
                                }
                            }
                        ),
                        viewModel: viewModel,
                        onCreatePortfolio: {
                            activeSheet = .createPortfolio
                        }
                    )
                case .addTransaction:
                    AddTransactionView(viewModel: viewModel)
                case .createPortfolio:
                    CreatePortfolioView(viewModel: viewModel)
                case .showcase:
                    PortfolioShowcaseView()
                }
            }
            .onChange(of: appState.shouldShowPortfolioCreation) { _, shouldShow in
                if shouldShow {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        activeSheet = .createPortfolio
                        appState.shouldShowPortfolioCreation = false
                    }
                }
            }
            .onAppear {
                if appState.shouldShowPortfolioCreation {
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        activeSheet = .createPortfolio
                        appState.shouldShowPortfolioCreation = false
                    }
                }
            }
        }
    }
}

#Preview {
    PortfolioView()
        .environmentObject(AppState())
}
