import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showPortfolioPicker = false
    @State private var showCustomizeSheet = false
    @State private var showNotificationsSheet = false
    @State private var showTelegramExportSheet = false
    @State private var showAddPositionSheet = false
    @State private var addPositionViewModel = PortfolioViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var showDeckFromNotification = false
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
                    ScrollViewReader { scrollProxy in
                    ScrollView(.vertical) {
                        VStack(spacing: 20) {
                            Color.clear.frame(height: 0).id("scrollTop")

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
                            onAddPosition: !viewModel.portfolios.isEmpty ? {
                                if let portfolio = viewModel.selectedPortfolio {
                                    addPositionViewModel.selectPortfolio(portfolio)
                                }
                                showAddPositionSheet = true
                            } : nil,
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
                .safeAreaInset(edge: .top) {
                    GlassHeader(
                        greeting: viewModel.greeting,
                        userName: appState.currentUser?.firstName ?? "User",
                        avatarUrl: appState.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                        appState: appState,
                        hasNotification: hasNotifications,
                        unreadCount: viewModel.unreadNotificationCount,
                        onCustomizeTap: { showCustomizeSheet = true },
                        onExportTap: appState.currentUser?.isAdmin == true ? { showTelegramExportSheet = true } : nil,
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
                }
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
                            // Extract signal UUID from notification ID (e.g. "signal_new_{uuid}")
                            let parts = notification.id.components(separatedBy: "_")
                            if let uuidString = parts.last, let _ = UUID(uuidString: uuidString) {
                                NotificationCenter.default.post(
                                    name: Notification.Name("SwingSignalNotificationTapped"),
                                    object: nil,
                                    userInfo: ["id": uuidString]
                                )
                            } else {
                                appState.selectedTab = .market
                            }
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
            .sheet(isPresented: $showAddPositionSheet, onDismiss: {
                Task { await viewModel.loadPortfolios(forceRefresh: true) }
            }) {
                NavigationStack {
                    AddTransactionView(viewModel: addPositionViewModel)
                }
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
            .onReceive(NotificationCenter.default.publisher(for: Constants.Notifications.portfolioUpdated)) { _ in
                Task { await viewModel.loadPortfolios(forceRefresh: true) }
            }
            .onReceive(NotificationCenter.default.publisher(for: Constants.Notifications.marketDeckPublished)) { notification in
                if let deck = notification.object as? MarketUpdateDeck {
                    viewModel.latestDeck = deck
                } else {
                    Task {
                        let deck = try? await ServiceContainer.shared.marketDeckService.fetchLatestPublished()
                        viewModel.latestDeck = deck
                    }
                }
            }
            .onChange(of: appState.pendingMarketDeckId) { _, newValue in
                if newValue != nil {
                    showDeckFromNotification = true
                    appState.pendingMarketDeckId = nil
                }
            }
            .fullScreenCover(isPresented: $showDeckFromNotification) {
                if let deck = viewModel.latestDeck {
                    MarketDeckViewer(
                        viewModel: MarketDeckViewModel(deck: deck),
                        isAdmin: false
                    )
                }
            }
            .onAppear {
                viewModel.userName = appState.currentUser?.firstName ?? "User"
                Task { await AnalyticsService.shared.trackScreenView("home") }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, appState.selectedTab == .home else { return }

                let staleness = viewModel.lastRefreshed.map { Date().timeIntervalSince($0) }

                if let staleness, staleness > 300, !viewModel.isLoading {
                    // Clear briefing cache if data is more than 30 min old
                    // so we fetch the latest briefing (cron generates at 10am and 5pm ET)
                    if staleness > 1800 {
                        MarketSummaryService.shared.clearLocalCache()
                    }
                    Task {
                        await viewModel.refresh(forceRefresh: true)
                        await viewModel.loadPortfolios(forceRefresh: true)
                    }
                } else if viewModel.lastRefreshed == nil {
                    Task {
                        await viewModel.refresh(forceRefresh: true)
                        await viewModel.loadPortfolios(forceRefresh: true)
                    }
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
