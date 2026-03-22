import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showPortfolioPicker = false
    @State private var showCustomizeSheet = false
    @State private var showNotificationsSheet = false
    @State private var showTelegramExportSheet = false
    @State private var navigationPath = NavigationPath()
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    private var hasNotifications: Bool {
        viewModel.unreadNotificationCount > 0
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()
                    .allowsHitTesting(false)

                // Content
                ZStack(alignment: .top) {
                    // Scrollable content (goes under the header)
                    ScrollViewReader { scrollProxy in
                    ScrollView(.vertical) {
                        VStack(spacing: 20) {
                            // Spacer to push content below the header
                            Color.clear.frame(height: 80).id("scrollTop")

                        // Stale data warning (shown when fetches failed)
                        if viewModel.failedFetchCount > 0, !viewModel.isLoading {
                            StaleDataBanner(
                                failedCount: viewModel.failedFetchCount,
                                lastRefreshed: viewModel.lastRefreshed,
                                onRetry: { Task { await viewModel.refresh(forceRefresh: true) } }
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
                            hasLoadedPortfolios: viewModel.hasLoadedPortfolios,
                            hasPortfolios: !viewModel.portfolios.isEmpty
                        )
                        .padding(.horizontal, 20)

                        // AI Daily Briefing (fixed position under portfolio)
                        if appState.isWidgetEnabled(.aiMarketSummary) {
                            HomeAISummaryWidget(
                                summary: viewModel.marketSummary,
                                isLoading: viewModel.isLoadingSummary,
                                userName: appState.currentUser?.firstName ?? "there",
                                isAdmin: appState.currentUser?.isAdmin == true,
                                liveRegime: viewModel.currentRegimeResult,
                                onFeedback: appState.currentUser?.isAdmin == true ? { rating, note in
                                    guard let userId = appState.currentUser?.id else { return }
                                    Task { await viewModel.submitBriefingFeedback(rating: rating, note: note, userId: userId) }
                                } : nil,
                                forceExpand: Binding(
                                    get: { appState.shouldExpandBriefing },
                                    set: { appState.shouldExpandBriefing = $0 }
                                )
                            )
                            .padding(.horizontal, 20)
                        }

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
                    .containerRelativeFrame(.horizontal)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refresh(forceRefresh: true)
                }
                .onChange(of: appState.homeNavigationReset) { _, _ in
                    navigationPath = NavigationPath()
                    withAnimation(.arkSpring) {
                        scrollProxy.scrollTo("scrollTop", anchor: .top)
                    }
                }
                .onChange(of: appState.pendingQPSAsset) { _, newValue in
                    if newValue != nil {
                        withAnimation(.arkSpring) {
                            scrollProxy.scrollTo("widget_qpsSignals", anchor: .center)
                        }
                        appState.pendingQPSAsset = nil
                    }
                }
            } // ScrollViewReader

                    // Floating header with fading material background
                    GlassHeader(
                        greeting: viewModel.greeting,
                        userName: appState.currentUser?.firstName ?? "User",
                        avatarUrl: appState.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                        appState: appState,
                        hasNotification: hasNotifications,
                        unreadCount: viewModel.unreadNotificationCount,
                        onCustomizeTap: { showCustomizeSheet = true },
                        onExportTap: { showTelegramExportSheet = true },
                        onNotificationsTap: { showNotificationsSheet = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .background {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(.all, edges: .top)
                            .mask(
                                VStack(spacing: 0) {
                                    Rectangle()
                                    LinearGradient(
                                        colors: [.white, .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 24)
                                }
                                .ignoresSafeArea(.all, edges: .top)
                            )
                    }
                    .allowsHitTesting(true)
            } // ZStack (scroll + floating header)
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
                NotificationsSheet(
                    notifications: viewModel.inboxNotifications,
                    onNotificationTapped: { notification in
                        viewModel.markNotificationRead(notification.id)
                    },
                    onMarkAllRead: {
                        viewModel.markAllNotificationsRead()
                    },
                    onNavigate: { notification in
                        switch notification.type {
                        case .dailyBriefing:
                            appState.shouldExpandBriefing = true
                        case .signalGenerated, .signalT1Hit, .signalOutcome:
                            appState.selectedTab = .market
                        case .dcaReminder:
                            appState.selectedTab = .profile
                            appState.pendingDCAReminderId = "open"
                        case .extremeMacroMove, .marketRegimeChange:
                            // Stay on home, macro dashboard is visible
                            break
                        case .sentimentRegimeShift:
                            appState.selectedTab = .market
                        case .qpsSignalChange:
                            appState.pendingQPSAsset = "scroll"
                        }
                    }
                )
            }
            .sheet(isPresented: $showTelegramExportSheet) {
                DailyMarketUpdateShareSheet(briefingSummary: viewModel.marketSummary?.summary)
            }
            .task {
                viewModel.startAutoRefresh()
                async let portfolios: () = viewModel.loadPortfolios()
                async let refreshTask: () = viewModel.refresh()
                _ = await (portfolios, refreshTask)

            }
            .onReceive(NotificationCenter.default.publisher(for: Constants.Notifications.authStateChanged)) { _ in
                if !viewModel.hasLoadedPortfolios || (viewModel.portfolioValue == 0 && SupabaseAuthManager.shared.isAuthenticated) {
                    Task { await viewModel.loadPortfolios(forceRefresh: true) }
                }
            }
            .onAppear {
                viewModel.userName = appState.currentUser?.firstName ?? "User"
                Task { await AnalyticsService.shared.trackScreenView("home") }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, appState.selectedTab == .home else { return }
                // Check for a newer briefing when returning to foreground
                // (cron generates at 10am and 5pm ET, so clear local cache to pick up new one)
                if let generated = viewModel.marketSummary?.generatedAt,
                   Date().timeIntervalSince(generated) > 1800,
                   !viewModel.isLoading {
                    MarketSummaryService.shared.clearLocalCache()
                    Task { await viewModel.fetchMarketSummary() }
                }
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                if newTab == .home {
                    viewModel.startAutoRefresh()
                } else {
                    viewModel.stopAutoRefresh()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
}
