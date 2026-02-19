import SwiftUI

struct PortfolioView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = PortfolioViewModel()
    @State private var showAddTransaction = false
    @State private var showCreatePortfolio = false
    @State private var showPortfolioPicker = false
    @State private var showShowcase = false
    @State private var navigationPath = NavigationPath()

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
                    Button(action: { showPortfolioPicker = true }) {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedPortfolio?.name ?? "Portfolio")
                                .font(.system(size: 17, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: ArkSpacing.sm) {
                        // Showcase button
                        Button(action: { showShowcase = true }) {
                            Image(systemName: "square.split.2x1")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Portfolio showcase")

                        // Add transaction button
                        Button(action: { showAddTransaction = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel("Add transaction")
                    }
                }
            }
            #endif
            .sheet(isPresented: $showPortfolioPicker) {
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
                        showCreatePortfolio = true
                    }
                )
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView(viewModel: viewModel)
            }
            .sheet(isPresented: $showCreatePortfolio) {
                CreatePortfolioView(viewModel: viewModel)
            }
            .sheet(isPresented: $showShowcase) {
                PortfolioShowcaseView()
            }
            .onChange(of: appState.shouldShowPortfolioCreation) { _, shouldShow in
                if shouldShow {
                    // Small delay to allow view transition to complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreatePortfolio = true
                        appState.shouldShowPortfolioCreation = false
                    }
                }
            }
            .onAppear {
                // Also check on appear in case onChange missed it
                if appState.shouldShowPortfolioCreation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCreatePortfolio = true
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
