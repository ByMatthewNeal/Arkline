import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showPortfolioPicker = false
    @State private var showCustomizeSheet = false
    @State private var showNotificationsSheet = false
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

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
                ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Color.clear.frame(height: 0).id("scrollTop")
                        // Header
                        GlassHeader(
                            greeting: viewModel.greeting,
                            userName: appState.currentUser?.firstName ?? "User",
                            avatarUrl: appState.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                            appState: appState,
                            onCustomizeTap: { showCustomizeSheet = true },
                            onNotificationsTap: { showNotificationsSheet = true }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Stale data warning (shown when fetches failed)
                        if viewModel.failedFetchCount > 0, !viewModel.isLoading {
                            StaleDataBanner(
                                failedCount: viewModel.failedFetchCount,
                                lastRefreshed: viewModel.lastRefreshed,
                                onRetry: { Task { await viewModel.refresh() } }
                            )
                            .padding(.horizontal, 20)
                        }

                        // Subscription status banner
                        if let status = appState.currentUser?.subscriptionStatus,
                           status != .active && status != .none {
                            SubscriptionBannerView(
                                status: status,
                                trialDaysRemaining: appState.currentUser?.trialDaysRemaining
                            )
                            .padding(.horizontal, 20)
                        }

                        // Portfolio Value Card (Hero) - Always visible
                        PortfolioHeroCard(
                            totalValue: viewModel.portfolioValue,
                            change: viewModel.portfolioChange,
                            changePercent: viewModel.portfolioChangePercent,
                            portfolioName: viewModel.selectedPortfolio?.name ?? "Main Portfolio",
                            chartData: viewModel.portfolioChartData,
                            onPortfolioTap: { showPortfolioPicker = true },
                            onSetupTap: {
                                appState.selectedTab = .portfolio
                                appState.shouldShowPortfolioCreation = true
                            },
                            selectedTimePeriod: Binding(
                                get: { viewModel.selectedTimePeriod },
                                set: { viewModel.selectedTimePeriod = $0 }
                            ),
                            hasLoadedPortfolios: viewModel.hasLoadedPortfolios
                        )
                        .padding(.horizontal, 20)

                        // Dynamic Widget Section with Drag-and-Drop
                        ReorderableWidgetStack(
                            viewModel: viewModel,
                            appState: appState
                        )

                        // Disclaimer
                        FinancialDisclaimer()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.refresh()
                }
                .onChange(of: appState.homeNavigationReset) { _, _ in
                    navigationPath = NavigationPath()
                    withAnimation(.arkSpring) {
                        scrollProxy.scrollTo("scrollTop", anchor: .top)
                    }
                }
            } // ScrollViewReader
            }
            .sheet(isPresented: $showPortfolioPicker) {
                PortfolioPickerSheet(
                    portfolios: viewModel.portfolios,
                    selectedPortfolio: Binding(
                        get: { viewModel.selectedPortfolio },
                        set: { portfolio in
                            if let portfolio = portfolio {
                                viewModel.selectPortfolio(portfolio)
                            }
                        }
                    ),
                    onCreatePortfolio: {
                        appState.selectedTab = .portfolio
                        appState.shouldShowPortfolioCreation = true
                    }
                )
            }
            .sheet(isPresented: $showCustomizeSheet) {
                CustomizeHomeView()
            }
            .sheet(isPresented: $showNotificationsSheet) {
                NotificationsSheet()
            }
            .task {
                async let portfolios: () = viewModel.loadPortfolios()
                async let refresh: () = viewModel.refresh()
                _ = await (portfolios, refresh)
            }
            .onAppear {
                viewModel.userName = appState.currentUser?.firstName ?? "User"
                Task { await AnalyticsService.shared.trackScreenView("home") }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
}
