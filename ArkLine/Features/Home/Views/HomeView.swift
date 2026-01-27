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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
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

                        // Portfolio Value Card (Hero) - Always visible
                        PortfolioHeroCard(
                            totalValue: viewModel.portfolioValue,
                            change: viewModel.portfolioChange,
                            changePercent: viewModel.portfolioChangePercent,
                            portfolioName: viewModel.selectedPortfolio?.name ?? "Main Portfolio",
                            chartData: viewModel.portfolioChartData,
                            onPortfolioTap: { showPortfolioPicker = true },
                            selectedTimePeriod: Binding(
                                get: { viewModel.selectedTimePeriod },
                                set: { viewModel.selectedTimePeriod = $0 }
                            )
                        )
                        .padding(.horizontal, 20)

                        // Dynamic Widget Section with Drag-and-Drop
                        ReorderableWidgetStack(
                            viewModel: viewModel,
                            appState: appState
                        )

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.refresh()
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
                NotificationsSheet()
            }
            .onChange(of: appState.homeNavigationReset) { _, _ in
                // Pop to root when home tab is tapped while already on home
                navigationPath = NavigationPath()
            }
            .task {
                await viewModel.loadPortfolios()
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Glass Header (Hedge Fund Style)
struct GlassHeader: View {
    let greeting: String
    let userName: String
    let avatarUrl: URL?
    @ObservedObject var appState: AppState
    var onCustomizeTap: (() -> Void)? = nil
    var onNotificationsTap: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            // Profile Avatar - refined style
            ProfessionalAvatar(imageUrl: avatarUrl, name: userName, size: 52)

            // Greeting and name with date
            VStack(alignment: .leading, spacing: 4) {
                // Date line - subtle, professional
                Text(currentDateFormatted.uppercased())
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(textPrimary.opacity(0.4))
                    .tracking(1.2)

                // Name - prominent, using Urbanist
                Text(userName.isEmpty ? "Welcome" : userName)
                    .font(AppFonts.title24)
                    .foregroundColor(textPrimary)
            }

            Spacer()

            // Action buttons - minimal, refined
            HStack(spacing: 8) {
                if let onCustomizeTap = onCustomizeTap {
                    HeaderIconButton(icon: "slider.horizontal.3", action: onCustomizeTap)
                }

                HeaderIconButton(icon: "bell", hasNotification: true, action: {
                    onNotificationsTap?()
                })
            }
        }
    }
}

// MARK: - Header Icon Button (Refined)
struct HeaderIconButton: View {
    let icon: String
    var hasNotification: Bool = false
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Subtle background
                Circle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.04))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .frame(width: 40, height: 40)

                // Notification indicator
                if hasNotification {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Professional Avatar (Hedge Fund Style)
struct ProfessionalAvatar: View {
    let imageUrl: URL?
    let name: String
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Use the selected avatar color theme from AppState
    private var avatarGradient: LinearGradient {
        let colors = appState.avatarColorTheme.gradientColors
        return LinearGradient(
            colors: [colors.light, colors.dark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            if let url = imageUrl {
                // Image avatar
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsView
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                // Initials avatar with gradient
                initialsView
            }
        }
        // Subtle shadow for depth
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }

    private var initialsView: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(avatarGradient)
                .frame(width: size, height: size)

            // Subtle inner border
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)

            // Initials - using Inter Bold
            Text(String(name.prefix(1)).uppercased())
                .font(AppFonts.interFont(size: size * 0.38, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Legacy Notification Indicator (for compatibility)
struct NotificationIndicator: View {
    var hasNotification: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HeaderIconButton(icon: "bell", hasNotification: hasNotification, action: {})
    }
}

// MARK: - Reorderable Widget Stack (Drag & Drop)
struct ReorderableWidgetStack: View {
    @Bindable var viewModel: HomeViewModel
    @ObservedObject var appState: AppState
    @State private var isEditMode: Bool = false
    @State private var draggingWidget: HomeWidgetType?
    @State private var draggedOverWidget: HomeWidgetType?
    @Environment(\.colorScheme) var colorScheme

    private var visibleWidgets: [HomeWidgetType] {
        appState.widgetConfiguration.orderedEnabledWidgets.filter { shouldShowWidget($0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Edit mode toggle
            HStack {
                Text("Widgets")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isEditMode.toggle()
                    }
                }) {
                    Text(isEditMode ? "Done" : "Edit")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 4)

            // Widget list
            ForEach(Array(visibleWidgets.enumerated()), id: \.element) { index, widgetType in
                WidgetRowContainer(
                    widgetType: widgetType,
                    isEditMode: isEditMode,
                    isFirst: index == 0,
                    isLast: index == visibleWidgets.count - 1,
                    isDragging: draggingWidget == widgetType,
                    isDraggedOver: draggedOverWidget == widgetType,
                    onMoveUp: {
                        moveWidget(widgetType, direction: -1)
                    },
                    onMoveDown: {
                        moveWidget(widgetType, direction: 1)
                    }
                ) {
                    widgetView(for: widgetType)
                }
                .onDrag {
                    self.draggingWidget = widgetType
                    return NSItemProvider(object: widgetType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: WidgetDropDelegate(
                    item: widgetType,
                    items: visibleWidgets,
                    draggingItem: $draggingWidget,
                    draggedOverItem: $draggedOverWidget,
                    onReorder: { newOrder in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            // Merge with full order (including disabled widgets)
                            var fullOrder = appState.widgetConfiguration.widgetOrder
                            let enabledSet = Set(newOrder)
                            fullOrder.removeAll { enabledSet.contains($0) }
                            // Insert enabled widgets in new order at their positions
                            for widget in newOrder.reversed() {
                                if let originalIndex = appState.widgetConfiguration.widgetOrder.firstIndex(of: widget) {
                                    fullOrder.insert(widget, at: min(originalIndex, fullOrder.count))
                                } else {
                                    fullOrder.insert(widget, at: 0)
                                }
                            }
                            appState.updateWidgetOrder(newOrder + fullOrder.filter { !enabledSet.contains($0) })
                        }
                    }
                ))
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.widgetConfiguration.orderedEnabledWidgets)
    }

    private func moveWidget(_ widget: HomeWidgetType, direction: Int) {
        var order = appState.widgetConfiguration.widgetOrder
        guard let currentIndex = order.firstIndex(of: widget) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < order.count else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            order.remove(at: currentIndex)
            order.insert(widget, at: newIndex)
            appState.updateWidgetOrder(order)
        }
    }

    // Check if widget has data to display
    private func shouldShowWidget(_ type: HomeWidgetType) -> Bool {
        switch type {
        case .upcomingEvents:
            // Always show - displays loading state if empty
            return true
        case .riskScore:
            return viewModel.compositeRiskScore != nil
        case .fearGreedIndex:
            return viewModel.fearGreedIndex != nil
        case .marketMovers:
            return true
        case .dcaReminders:
            return true
        case .favorites:
            return !viewModel.favoriteAssets.isEmpty
        case .fedWatch:
            return !viewModel.fedWatchMeetings.isEmpty
        case .dailyNews:
            return !viewModel.newsItems.isEmpty
        case .marketSentiment:
            return viewModel.sentimentViewModel != nil
        case .assetRiskLevel:
            return viewModel.selectedRiskLevel != nil
        case .vixIndicator:
            return true
        case .dxyIndicator:
            return true
        case .globalLiquidity:
            return true
        case .macroDashboard:
            // Show if we have at least 2 of the 3 indicators
            let hasVix = viewModel.vixData != nil
            let hasDxy = viewModel.dxyData != nil
            let hasM2 = viewModel.globalLiquidityChanges != nil
            return [hasVix, hasDxy, hasM2].filter { $0 }.count >= 2
        }
    }

    // Render the appropriate widget
    @ViewBuilder
    private func widgetView(for type: HomeWidgetType) -> some View {
        switch type {
        case .upcomingEvents:
            UpcomingEventsSection(
                events: viewModel.upcomingEvents,
                lastUpdated: viewModel.eventsLastUpdated,
                size: appState.widgetSize(.upcomingEvents)
            )

        case .riskScore:
            if let score = viewModel.compositeRiskScore {
                RiskScoreCard(
                    score: score,
                    riskScore: viewModel.arkLineRiskScore,
                    itcRiskLevel: viewModel.selectedRiskLevel,
                    size: appState.widgetSize(.riskScore),
                    selectedCoin: viewModel.selectedRiskCoin,
                    onCoinChanged: { coin in
                        viewModel.selectRiskCoin(coin)
                    }
                )
            }

        case .fearGreedIndex:
            if let fearGreed = viewModel.fearGreedIndex {
                GlassFearGreedCard(index: fearGreed, size: appState.widgetSize(.fearGreedIndex))
            }

        case .marketMovers:
            HomeMarketMoversWidget(
                btcPrice: viewModel.btcPrice,
                ethPrice: viewModel.ethPrice,
                btcChange: viewModel.btcChange24h,
                ethChange: viewModel.ethChange24h,
                size: appState.widgetSize(.marketMovers)
            )

        case .fedWatch:
            HomeFedWatchWidget(
                meetings: viewModel.fedWatchMeetings,
                size: appState.widgetSize(.fedWatch)
            )

        case .dailyNews:
            HomeDailyNewsWidget(
                news: viewModel.newsItems,
                size: appState.widgetSize(.dailyNews)
            )

        case .marketSentiment:
            if let sentimentVM = viewModel.sentimentViewModel {
                HomeMarketSentimentWidget(
                    viewModel: sentimentVM,
                    size: appState.widgetSize(.marketSentiment)
                )
            }

        case .dcaReminders:
            DCARemindersEntrySection(
                todayReminders: viewModel.todayReminders,
                onComplete: { reminder in Task { await viewModel.markReminderComplete(reminder) } },
                size: appState.widgetSize(.dcaReminders)
            )

        case .favorites:
            FavoritesSection(
                assets: viewModel.favoriteAssets,
                size: appState.widgetSize(.favorites)
            )

        case .assetRiskLevel:
            RiskLevelWidget(
                riskLevel: viewModel.selectedRiskLevel,
                coinSymbol: viewModel.selectedRiskCoin,
                size: appState.widgetSize(.assetRiskLevel)
            )

        case .vixIndicator:
            VIXWidget(
                vixData: viewModel.vixData,
                size: appState.widgetSize(.vixIndicator)
            )

        case .dxyIndicator:
            DXYWidget(
                dxyData: viewModel.dxyData,
                size: appState.widgetSize(.dxyIndicator)
            )

        case .globalLiquidity:
            GlobalLiquidityWidget(
                liquidityChanges: viewModel.globalLiquidityChanges,
                size: appState.widgetSize(.globalLiquidity)
            )

        case .macroDashboard:
            MacroDashboardWidget(
                vixData: viewModel.vixData,
                dxyData: viewModel.dxyData,
                liquidityData: viewModel.globalLiquidityChanges,
                size: appState.widgetSize(.macroDashboard)
            )
        }
    }
}

// MARK: - Widget Row Container (with Edit Controls)
struct WidgetRowContainer<Content: View>: View {
    let widgetType: HomeWidgetType
    let isEditMode: Bool
    let isFirst: Bool
    let isLast: Bool
    let isDragging: Bool
    let isDraggedOver: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Reorder controls (visible in edit mode)
            if isEditMode {
                VStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isFirst ? AppColors.textSecondary.opacity(0.3) : AppColors.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark
                                        ? Color.white.opacity(0.08)
                                        : Color.black.opacity(0.05))
                            )
                    }
                    .disabled(isFirst)

                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isLast ? AppColors.textSecondary.opacity(0.3) : AppColors.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark
                                        ? Color.white.opacity(0.08)
                                        : Color.black.opacity(0.05))
                            )
                    }
                    .disabled(isLast)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Main content
            content()
                .frame(maxWidth: .infinity)
        }
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .opacity(isDragging ? 0.8 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isDraggedOver ? AppColors.accent : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.15), value: isDraggedOver)
        )
        .shadow(
            color: isDragging ? Color.black.opacity(0.2) : Color.clear,
            radius: isDragging ? 12 : 0,
            y: isDragging ? 8 : 0
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
}

// MARK: - Widget Drop Delegate
struct WidgetDropDelegate: DropDelegate {
    let item: HomeWidgetType
    let items: [HomeWidgetType]
    @Binding var draggingItem: HomeWidgetType?
    @Binding var draggedOverItem: HomeWidgetType?
    let onReorder: ([HomeWidgetType]) -> Void

    func dropEntered(info: DropInfo) {
        draggedOverItem = item
    }

    func dropExited(info: DropInfo) {
        draggedOverItem = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingItem = draggingItem,
              draggingItem != item else {
            self.draggingItem = nil
            self.draggedOverItem = nil
            return false
        }

        var newItems = items

        // Find indices
        guard let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: item) else {
            self.draggingItem = nil
            self.draggedOverItem = nil
            return false
        }

        // Reorder
        newItems.remove(at: fromIndex)
        newItems.insert(draggingItem, at: toIndex)

        onReorder(newItems)

        self.draggingItem = nil
        self.draggedOverItem = nil
        return true
    }
}

// MARK: - Glass Theme Toggle Button
struct GlassThemeToggleButton: View {
    @ObservedObject var appState: AppState
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if appState.darkModePreference == .dark {
                    appState.setDarkModePreference(.light)
                } else {
                    appState.setDarkModePreference(.dark)
                }
            }
        }) {
            Circle()
                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F5"))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.accent)
                )
        }
    }
}

// MARK: - Glass Icon Button
struct GlassIconButton: View {
    let icon: String
    var hasNotification: Bool = false
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { }) {
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F5"))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textPrimary)

                // Notification dot
                if hasNotification {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 8, height: 8)
                        .offset(x: 12, y: -12)
                }
            }
        }
    }
}

// MARK: - Glass Avatar (Legacy - wraps ProfessionalAvatar)
struct GlassAvatar: View {
    let imageUrl: URL?
    let name: String
    let size: CGFloat

    var body: some View {
        ProfessionalAvatar(imageUrl: imageUrl, name: name, size: size)
    }
}

// MARK: - Portfolio Hero Card
struct PortfolioHeroCard: View {
    let totalValue: Double
    let change: Double
    let changePercent: Double
    let portfolioName: String
    let chartData: [CGFloat]
    let onPortfolioTap: () -> Void
    @Binding var selectedTimePeriod: TimePeriod
    @Environment(\.colorScheme) var colorScheme

    // Track time period changes to re-trigger animation
    @State private var chartAnimationId = UUID()

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Portfolio Selector (Delta-style centered dropdown)
            Button(action: onPortfolioTap) {
                HStack(spacing: 6) {
                    Text(portfolioName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                )
            }
            .buttonStyle(.plain)

            // Time Period Selector
            TimePeriodSelector(selectedPeriod: $selectedTimePeriod)

            // Total Value
            VStack(spacing: 8) {
                Text("FUNDS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .tracking(1)

                Text(totalValue.asCurrency)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(textPrimary)

                // Change indicator
                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(isPositive ? "+" : "")\(change.asCurrency)")
                        .font(.system(size: 16, weight: .semibold))

                    Text("(\(isPositive ? "+" : "")\(changePercent, specifier: "%.2f")%)")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((isPositive ? AppColors.success : AppColors.error).opacity(0.15))
                )
            }

            // Portfolio sparkline chart - re-animates on time period change
            PortfolioSparkline(
                dataPoints: chartData,
                isPositive: isPositive,
                showGlow: true,
                showEndDot: true,
                animated: true
            )
            .id(chartAnimationId)  // Forces view recreation for animation
            .frame(height: 80)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .onChange(of: selectedTimePeriod) { _, _ in
            // Trigger chart re-animation when time period changes
            chartAnimationId = UUID()
        }
    }
}

// MARK: - Glass Quick Actions
struct GlassQuickActions: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Simplified: All buttons use the same accent color for cohesion
            GlassQuickActionButton(icon: "plus", label: "Buy")
            GlassQuickActionButton(icon: "arrow.up.right", label: "Send")
            GlassQuickActionButton(icon: "arrow.down.left", label: "Receive")
            GlassQuickActionButton(icon: "chart.bar.fill", label: "Trade")
        }
    }
}

struct GlassQuickActionButton: View {
    let icon: String
    let label: String
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { }) {
            VStack(spacing: 8) {
                // Icon container - subtle background, monochrome
                Circle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.04))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(textPrimary.opacity(0.8))
                    )

                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Risk Score Card
struct RiskScoreCard: View {
    let score: Int
    var riskScore: ArkLineRiskScore? = nil
    var itcRiskLevel: ITCRiskLevel? = nil
    var size: WidgetSize = .standard
    var selectedCoin: String = "BTC"
    var onCoinChanged: ((String) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Use ITC risk level if available, otherwise fall back to computed label
    var riskLabel: String {
        if let itc = itcRiskLevel {
            return itc.riskCategory
        }
        switch score {
        case 0..<30: return "Low Risk"
        case 30..<50: return "Moderate"
        case 50..<70: return "Elevated"
        default: return "High Risk"
        }
    }

    // Use ITC-based coloring if available
    private var riskColor: Color {
        if let itc = itcRiskLevel {
            return ITCRiskColors.color(for: itc.riskLevel, colorScheme: colorScheme)
        }
        // Fallback: Dynamic blue color based on risk level
        let normalizedScore = Double(score) / 100.0
        let saturation = 0.4 + (normalizedScore * 0.5)
        let brightness = 0.9 - (normalizedScore * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var riskColorLight: Color {
        riskColor.opacity(0.6)
    }

    private var circleSize: CGFloat {
        switch size {
        case .compact: return 50
        case .standard: return 70
        case .expanded: return 90
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 5
        case .standard: return 8
        case .expanded: return 10
        }
    }

    private var indicatorCount: Int {
        riskScore?.components.count ?? 10
    }

    // Display score: prefer ITC percentage, fallback to ArkLine score
    private var displayScore: Int {
        if let itc = itcRiskLevel {
            return Int(itc.riskPercentage)
        }
        return score
    }

    // Title changes based on data source
    private var cardTitle: String {
        if itcRiskLevel != nil {
            return "\(selectedCoin.rawValue) Risk Level"
        }
        return "ArkLine Risk Score"
    }

    // Subtitle/attribution
    private var cardSubtitle: String {
        if itcRiskLevel != nil {
            return "Into The Cryptoverse"
        }
        return "Based on \(indicatorCount) indicators"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: size == .compact ? 12 : 16) {
                // Score circle - colored based on risk
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08),
                            lineWidth: strokeWidth
                        )
                        .frame(width: circleSize, height: circleSize)

                    // Progress ring - dynamic gradient
                    Circle()
                        .trim(from: 0, to: CGFloat(displayScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [riskColorLight, riskColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))

                    // Subtle glow
                    Circle()
                        .fill(riskColor.opacity(0.2))
                        .blur(radius: size == .compact ? 8 : 12)
                        .frame(width: circleSize * 0.6, height: circleSize * 0.6)

                    // Score text
                    Text("\(displayScore)")
                        .font(.system(size: size == .compact ? 18 : (size == .expanded ? 30 : 24), weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                }

                VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                    // Title with coin selector
                    HStack(spacing: 8) {
                        Text(cardTitle)
                            .font(size == .compact ? .subheadline : .headline)
                            .foregroundColor(textPrimary)

                        if itcRiskLevel != nil && onCoinChanged != nil {
                            // Coin selector toggle (BTC/ETH for now)
                            HStack(spacing: 0) {
                                ForEach(["BTC", "ETH"], id: \.self) { coin in
                                    Button(action: {
                                        onCoinChanged?(coin)
                                    }) {
                                        Text(coin)
                                            .font(.system(size: size == .compact ? 9 : 10, weight: .semibold))
                                            .foregroundColor(
                                                selectedCoin == coin
                                                    ? .white
                                                    : textPrimary.opacity(0.6)
                                            )
                                            .padding(.horizontal, size == .compact ? 6 : 8)
                                            .padding(.vertical, size == .compact ? 3 : 4)
                                            .background(
                                                selectedCoin == coin
                                                    ? AppColors.accent
                                                    : Color.clear
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.05)
                            )
                            .cornerRadius(6)
                        }
                    }

                    // Risk level badge with color indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(riskColor)
                            .frame(width: 8, height: 8)

                        Text(riskLabel)
                            .font(size == .compact ? .caption : .subheadline)
                            .foregroundColor(riskColor)
                    }

                    if size != .compact {
                        Text(cardSubtitle)
                            .font(.caption)
                            .foregroundColor(textPrimary.opacity(0.5))
                    }

                    if size == .expanded {
                        if let recommendation = riskScore?.recommendation {
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(textPrimary.opacity(0.6))
                                .lineLimit(2)
                                .padding(.top, 4)
                        } else if let itc = itcRiskLevel {
                            Text("Updated: \(itc.date)")
                                .font(.caption)
                                .foregroundColor(textPrimary.opacity(0.5))
                                .padding(.top, 4)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.4))
            }
            .padding(size == .compact ? 14 : 20)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            if let itc = itcRiskLevel {
                ITCRiskDetailView(riskLevel: itc)
            } else {
                RiskScoreDetailView(riskScore: riskScore, score: score)
            }
        }
    }
}

// MARK: - Risk Score Detail View
struct RiskScoreDetailView: View {
    let riskScore: ArkLineRiskScore?
    let score: Int
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    /// Dynamic blue color based on risk level
    private func colorForScore(_ value: Double) -> Color {
        let saturation = 0.4 + (value * 0.5)
        let brightness = 0.9 - (value * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var mainRiskColor: Color {
        colorForScore(Double(score) / 100.0)
    }

    var riskLabel: String {
        switch score {
        case 0..<30: return "Low Risk"
        case 30..<50: return "Moderate"
        case 50..<70: return "Elevated"
        default: return "High Risk"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Main score display
                    VStack(spacing: ArkSpacing.md) {
                        ZStack {
                            // Background ring
                            Circle()
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.1)
                                        : Color.black.opacity(0.08),
                                    lineWidth: 12
                                )
                                .frame(width: 140, height: 140)

                            // Progress ring
                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [mainRiskColor.opacity(0.6), mainRiskColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            // Glow
                            Circle()
                                .fill(mainRiskColor.opacity(0.2))
                                .blur(radius: 20)
                                .frame(width: 80, height: 80)

                            // Score
                            VStack(spacing: 2) {
                                Text("\(score)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(textPrimary)
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundColor(textPrimary.opacity(0.5))
                            }
                        }

                        Text(riskLabel)
                            .font(.title3.bold())
                            .foregroundColor(mainRiskColor)

                        if let recommendation = riskScore?.recommendation {
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, ArkSpacing.xl)

                    // Indicators section
                    VStack(alignment: .leading, spacing: ArkSpacing.md) {
                        Text("Risk Indicators")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                            .padding(.horizontal)

                        if let components = riskScore?.components {
                            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                                RiskIndicatorRow(component: component, colorScheme: colorScheme)
                            }
                        } else {
                            // Placeholder when no data
                            ForEach(0..<7, id: \.self) { index in
                                RiskIndicatorPlaceholderRow(index: index, colorScheme: colorScheme)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Legend
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("How to Read")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("The ArkLine Risk Score combines multiple market indicators to assess current market conditions. A lower score (0-30) suggests favorable buying conditions, while a higher score (70-100) indicates elevated risk and potential for correction.")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                    .padding(.horizontal)

                    Spacer(minLength: ArkSpacing.xxl)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Risk Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Risk Indicator Row
struct RiskIndicatorRow: View {
    let component: RiskScoreComponent
    let colorScheme: ColorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var indicatorColor: Color {
        let saturation = 0.4 + (component.value * 0.5)
        let brightness = 0.9 - (component.value * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var signalIcon: String {
        component.signal.icon
    }

    private var signalColor: Color {
        Color(hex: component.signal.color)
    }

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            // Signal icon
            Image(systemName: signalIcon)
                .font(.system(size: 16))
                .foregroundColor(signalColor)
                .frame(width: 28, height: 28)
                .background(signalColor.opacity(0.15))
                .clipShape(Circle())

            // Name and weight
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(textPrimary)

                Text("\(Int(component.weight * 100))% weight")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Value bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(indicatorColor)
                        .frame(width: geo.size.width * component.value)
                }
            }
            .frame(width: 80, height: 8)

            // Score
            Text("\(Int(component.value * 100))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(indicatorColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, ArkSpacing.sm)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Risk Indicator Placeholder Row
struct RiskIndicatorPlaceholderRow: View {
    let index: Int
    let colorScheme: ColorScheme

    private let placeholderNames = [
        "Fear & Greed",
        "App Store Sentiment",
        "Funding Rates",
        "ETF Flows",
        "Liquidation Ratio",
        "BTC Dominance",
        "Google Trends"
    ]

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(placeholderNames[safe: index] ?? "Indicator \(index + 1)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("--% weight")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 8)

            Text("--")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(Color.gray)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, ArkSpacing.sm)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Glass Fear & Greed Card
struct GlassFearGreedCard: View {
    let index: FearGreedIndex
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 100
        case .standard: return 160
        case .expanded: return 200
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 8
        case .standard: return 12
        case .expanded: return 16
        }
    }

    var body: some View {
        VStack(spacing: size == .compact ? 10 : 16) {
            HStack {
                Text("Fear & Greed Index")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Spacer()

                // Simplified: text only, no colored badge
                Text(index.level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            // Gauge - Simplified monochromatic
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06),
                        lineWidth: strokeWidth
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
                    .rotationEffect(.degrees(0))

                // Value arc - simple blue gradient
                Circle()
                    .trim(from: 0.25, to: 0.25 + (0.5 * Double(index.value) / 100))
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.6), AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: gaugeSize, height: gaugeSize)
                    .rotationEffect(.degrees(0))

                // Center value
                VStack(spacing: size == .compact ? 2 : 4) {
                    Text("\(index.value)")
                        .font(.system(size: size == .compact ? 28 : (size == .expanded ? 56 : 48), weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)

                    Text("/ 100")
                        .font(size == .compact ? .system(size: 10) : .caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
            .padding(.vertical, size == .compact ? 4 : 8)

            if size == .expanded {
                Text("Yesterday: \(max(0, index.value - 3)) • Last week: \(max(0, index.value - 8))")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Home Market Movers Widget
struct HomeMarketMoversWidget: View {
    let btcPrice: Double
    let ethPrice: Double
    let btcChange: Double
    let ethChange: Double
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedAsset: CryptoAsset?

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Create CryptoAsset objects from available data for technical analysis
    private var btcAsset: CryptoAsset {
        CryptoAsset(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            currentPrice: btcPrice,
            priceChange24h: btcPrice * (btcChange / 100),
            priceChangePercentage24h: btcChange,
            iconUrl: nil,
            marketCap: 1_320_000_000_000,
            marketCapRank: 1
        )
    }

    private var ethAsset: CryptoAsset {
        CryptoAsset(
            id: "ethereum",
            symbol: "ETH",
            name: "Ethereum",
            currentPrice: ethPrice,
            priceChange24h: ethPrice * (ethChange / 100),
            priceChangePercentage24h: ethChange,
            iconUrl: nil,
            marketCap: 400_000_000_000,
            marketCapRank: 2
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            Text("Core")
                .font(size == .compact ? .subheadline : .headline)
                .foregroundColor(textPrimary)

            if size == .compact {
                // Compact: horizontal row
                HStack(spacing: 8) {
                    Button {
                        selectedAsset = btcAsset
                    } label: {
                        CompactCoinCard(symbol: "BTC", price: btcPrice, change: btcChange, accentColor: AppColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedAsset = ethAsset
                    } label: {
                        CompactCoinCard(symbol: "ETH", price: ethPrice, change: ethChange, accentColor: AppColors.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                HStack(spacing: 12) {
                    Button {
                        selectedAsset = btcAsset
                    } label: {
                        GlassCoinCard(
                            symbol: "BTC",
                            name: "Bitcoin",
                            price: btcPrice,
                            change: btcChange,
                            icon: "bitcoinsign.circle.fill",
                            accentColor: AppColors.accent,
                            isExpanded: size == .expanded
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button {
                        selectedAsset = ethAsset
                    } label: {
                        GlassCoinCard(
                            symbol: "ETH",
                            name: "Ethereum",
                            price: ethPrice,
                            change: ethChange,
                            icon: "diamond.fill",
                            accentColor: AppColors.accent,
                            isExpanded: size == .expanded
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .sheet(item: $selectedAsset) { asset in
            AssetTechnicalDetailSheet(asset: asset)
        }
    }
}

struct CompactCoinCard: View {
    let symbol: String
    let price: Double
    let change: Double
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accentColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(symbol.prefix(1))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(textPrimary)

                HStack(spacing: 2) {
                    Text(price.asCurrency)
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.7))

                    Text("\(isPositive ? "+" : "")\(change, specifier: "%.1f")%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

struct GlassCoinCard: View {
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let icon: String
    let accentColor: Color
    var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 16 : 12) {
            HStack {
                // Coin icon with glow
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.3))
                        .blur(radius: isExpanded ? 10 : 8)
                        .frame(width: isExpanded ? 44 : 36, height: isExpanded ? 44 : 36)

                    Image(systemName: icon)
                        .font(.system(size: isExpanded ? 24 : 20))
                        .foregroundColor(accentColor)
                }

                Spacer()

                // Change badge
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: isExpanded ? 12 : 10, weight: .bold))
                    Text("\(abs(change), specifier: "%.1f")%")
                        .font(.system(size: isExpanded ? 14 : 12, weight: .semibold))
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.system(size: isExpanded ? 22 : 18, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(price.asCurrency)
                    .font(.system(size: isExpanded ? 16 : 14))
                    .foregroundColor(textPrimary.opacity(0.7))

                if isExpanded {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
        }
        .padding(isExpanded ? 20 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 20 : 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - DCA Reminders Section
struct DCARemindersSection: View {
    let reminders: [DCAReminder]
    let onComplete: (DCAReminder) -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's DCA")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            ForEach(reminders) { reminder in
                GlassDCACard(reminder: reminder, onComplete: { onComplete(reminder) })
            }
        }
    }
}

struct GlassDCACard: View {
    let reminder: DCAReminder
    let onComplete: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Coin icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.3))
                    .blur(radius: 8)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)

                Text(reminder.symbol.prefix(1))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(reminder.amount.asCurrency)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            // Complete button with glow
            Button(action: onComplete) {
                Text("Invest")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(AppColors.success)
                                .blur(radius: 8)
                                .opacity(0.5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.success, AppColors.success.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Favorites Section
struct FavoritesSection: View {
    let assets: [CryptoAsset]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardWidth: CGFloat {
        switch size {
        case .compact: return 90
        case .standard: return 120
        case .expanded: return 150
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                Text("Favorites")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Button(action: { }) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: size == .compact ? 8 : 12) {
                    ForEach(assets) { asset in
                        GlassFavoriteCard(asset: asset, size: size)
                            .frame(width: cardWidth)
                    }
                }
            }
        }
    }
}

struct GlassFavoriteCard: View {
    let asset: CryptoAsset
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var symbolFontSize: CGFloat {
        switch size {
        case .compact: return 11
        case .standard: return 14
        case .expanded: return 16
        }
    }

    private var priceFontSize: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 16
        case .expanded: return 18
        }
    }

    private var changeFontSize: CGFloat {
        switch size {
        case .compact: return 10
        case .standard: return 12
        case .expanded: return 13
        }
    }

    private var cardPadding: CGFloat {
        switch size {
        case .compact: return 10
        case .standard: return 14
        case .expanded: return 16
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 6 : 12) {
            if size == .compact {
                // Compact: stacked layout
                Text(asset.symbol.uppercased())
                    .font(.system(size: symbolFontSize, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(asset.currentPrice.asCurrency)
                    .font(.system(size: priceFontSize, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.8))

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.1f")%")
                    .font(.system(size: changeFontSize, weight: .semibold))
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            } else {
                // Standard/Expanded: original layout
                HStack {
                    Text(asset.symbol.uppercased())
                        .font(.system(size: symbolFontSize, weight: .bold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.1f")%")
                        .font(.system(size: changeFontSize, weight: .semibold))
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }

                Text(asset.currentPrice.asCurrency)
                    .font(.system(size: priceFontSize, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.8))

                if size == .expanded {
                    // Add asset name for expanded view
                    Text(asset.name)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - DCA Reminders Entry Section (Always Visible)
struct DCARemindersEntrySection: View {
    let todayReminders: [DCAReminder]
    let onComplete: (DCAReminder) -> Void
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var maxReminders: Int {
        switch size {
        case .compact: return 1
        case .standard: return 3
        case .expanded: return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header with bell icon
            HStack {
                HStack(spacing: size == .compact ? 6 : 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(AppColors.accent)

                    Text("DCA Reminders")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                NavigationLink(destination: DCAListView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }
            }

            // Show today's reminders if any, otherwise show entry card
            if todayReminders.isEmpty {
                // Entry card when no reminders today
                NavigationLink(destination: DCAListView()) {
                    HStack(spacing: size == .compact ? 12 : 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: size == .compact ? 36 : 48, height: size == .compact ? 36 : 48)

                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: size == .compact ? 16 : 20))
                                .foregroundColor(AppColors.accent)
                        }

                        VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                            Text("Manage DCA Strategies")
                                .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                                .foregroundColor(textPrimary)

                            if size != .compact {
                                Text("Time-based & Risk-based reminders")
                                    .font(.caption)
                                    .foregroundColor(textPrimary.opacity(0.6))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                    .padding(size == .compact ? 12 : 16)
                    .background(
                        RoundedRectangle(cornerRadius: size == .compact ? 12 : 16)
                            .fill(cardBackground)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            } else {
                if size != .compact {
                    // Today's Reminders header
                    Text("Today's Reminders")
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary.opacity(0.6))
                        .padding(.top, 4)
                }

                // Show today's reminders with new design
                ForEach(Array(todayReminders.prefix(maxReminders))) { reminder in
                    HomeDCACard(reminder: reminder, onInvest: { onComplete(reminder) }, isCompact: size == .compact)
                }
            }
        }
    }
}

// MARK: - Home DCA Card (Today's reminder with actions)
struct HomeDCACard: View {
    let reminder: DCAReminder
    let onInvest: () -> Void
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showHistory = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            // Header row
            HStack(spacing: isCompact ? 10 : 12) {
                // Coin icon
                HomeCoinIcon(symbol: reminder.symbol, size: isCompact ? 36 : 44)

                // Info
                VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                    HStack(spacing: 8) {
                        Text(reminder.name)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundColor(textPrimary)

                        if !isCompact {
                            // Today badge
                            Text(todayDateBadge)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColors.accent.opacity(0.15))
                                )
                        }
                    }

                    Text(isCompact ? reminder.amount.asCurrency : "Purchase Amount: \(reminder.amount.asCurrency)")
                        .font(.system(size: isCompact ? 11 : 13))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Spacer()

                if isCompact {
                    // Simple invest button for compact
                    Button(action: onInvest) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            // Action buttons (only for non-compact)
            if !isCompact {
                HStack(spacing: 10) {
                    // History button
                    Button(action: { showHistory = true }) {
                        Text("History")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                            )
                    }

                    // Mark as Invested button
                    Button(action: onInvest) {
                        Text("Mark as Invested")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                    }
                }
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var todayDateBadge: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Home Coin Icon
struct HomeCoinIcon: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(coinColor.opacity(0.15))
                .frame(width: size, height: size)

            if let iconName = coinSystemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(coinColor)
            } else {
                Text(String(symbol.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(coinColor)
            }
        }
    }

    private var coinColor: Color {
        // Simplified: use accent color for all coins
        AppColors.accent
    }

    private var coinSystemIcon: String? {
        switch symbol.uppercased() {
        case "BTC": return "bitcoinsign"
        case "ETH": return "diamond.fill"
        default: return nil
        }
    }
}

// MARK: - Time Period Selector
/// Delta-style time period selector with capsule pills
struct TimePeriodSelector: View {
    @Binding var selectedPeriod: TimePeriod
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases) { period in
                TimePeriodPill(
                    period: period,
                    isSelected: selectedPeriod == period,
                    onTap: { selectedPeriod = period }
                )
            }
        }
    }
}

struct TimePeriodPill: View {
    let period: TimePeriod
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            Text(period.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : textPrimary.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : textPrimary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Portfolio Picker Sheet
struct PortfolioPickerSheet: View {
    let portfolios: [Portfolio]
    @Binding var selectedPortfolio: Portfolio?
    var onCreatePortfolio: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(portfolios) { portfolio in
                            PortfolioPickerRow(
                                portfolio: portfolio,
                                isSelected: selectedPortfolio?.id == portfolio.id,
                                onSelect: {
                                    selectedPortfolio = portfolio
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Button(action: {
                    dismiss()
                    onCreatePortfolio?()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }

                        Text("Create New Portfolio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Select Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct PortfolioPickerRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(portfolioColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: portfolioIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(portfolioColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(portfolio.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.accent)
                } else {
                    Circle()
                        .stroke(textPrimary.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var portfolioIcon: String {
        switch portfolio.name.lowercased() {
        case let name where name.contains("crypto"):
            return "bitcoinsign.circle"
        case let name where name.contains("long"):
            return "chart.line.uptrend.xyaxis"
        case let name where name.contains("main"):
            return "briefcase"
        default:
            return "folder"
        }
    }

    private var portfolioColor: Color {
        // Simplified: use accent color for all portfolios
        AppColors.accent
    }
}

// MARK: - Upcoming Events Section
struct UpcomingEventsSection: View {
    let events: [EconomicEvent]
    var lastUpdated: Date?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var groupedEvents: [(key: String, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: events) { $0.dateGroupKey }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
        }.map { (key: $0.key, events: $0.value.sorted { ($0.time ?? Date()) < ($1.time ?? Date()) }) }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = lastUpdated else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }

    private var maxGroups: Int {
        switch size {
        case .compact: return 1
        case .standard: return 3
        case .expanded: return 5
        }
    }

    private var maxEventsPerGroup: Int {
        switch size {
        case .compact: return 2
        case .standard: return 4
        case .expanded: return 6
        }
    }

    var body: some View {
        NavigationLink(destination: AllEventsView(events: events)) {
            VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
                HStack {
                    Text("Upcoming Events")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)

                    Spacer()

                    if lastUpdated != nil && size != .compact {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.success)
                                .frame(width: 6, height: 6)
                            Text(lastUpdatedText)
                                .font(.system(size: 10))
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                    }

                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: size == .compact ? 8 : 16) {
                    if events.isEmpty {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading events...")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    } else {
                        ForEach(groupedEvents.prefix(maxGroups), id: \.key) { group in
                            EventDateGroup(
                                dateKey: group.key,
                                events: Array(group.events.prefix(maxEventsPerGroup)),
                                isCompact: size == .compact
                            )
                        }
                    }
                }
                .padding(size == .compact ? 12 : 16)
                .background(
                    RoundedRectangle(cornerRadius: size == .compact ? 12 : 16)
                        .fill(cardBackground)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Event Date Group
struct EventDateGroup: View {
    let dateKey: String
    let events: [EconomicEvent]
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var isToday: Bool {
        guard let firstEvent = events.first else { return false }
        return Calendar.current.isDateInToday(firstEvent.date)
    }

    private var isTomorrow: Bool {
        guard let firstEvent = events.first else { return false }
        return Calendar.current.isDateInTomorrow(firstEvent.date)
    }

    private var displayDateKey: String {
        if isToday { return "Today" }
        else if isTomorrow { return "Tomorrow" }
        return dateKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
            HStack(spacing: 8) {
                Text(displayDateKey)
                    .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .textCase(.uppercase)

                if isToday {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, isCompact ? 2 : 4)

            VStack(spacing: 0) {
                ForEach(events) { event in
                    UpcomingEventRow(event: event, isCompact: isCompact)

                    if event.id != events.last?.id {
                        Divider()
                            .background(textPrimary.opacity(0.1))
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Event Row
struct UpcomingEventRow: View {
    let event: EconomicEvent
    var isCompact: Bool = false
    @State private var showEventInfo = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        textPrimary.opacity(0.5)
    }

    private var hasDataValues: Bool {
        event.actual != nil || event.forecast != nil || event.previous != nil
    }

    /// Country code extracted from country string (e.g., "US", "JP", "EU")
    private var countryCode: String {
        event.country.uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Vertical impact indicator bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.impact.color)
                .frame(width: 3, height: isCompact ? 32 : 44)
                .padding(.trailing, isCompact ? 8 : 12)

            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                HStack(spacing: isCompact ? 6 : 10) {
                    // Time
                    Text(event.timeDisplayFormatted)
                        .font(.system(size: isCompact ? 10 : 12, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                        .frame(width: isCompact ? 48 : 58, alignment: .leading)

                    // Country code badge
                    Text(countryCode)
                        .font(.system(size: isCompact ? 9 : 10, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(textPrimary.opacity(0.08))
                        )

                    // Event title
                    Text(event.title)
                        .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if !isCompact {
                        Button(action: { showEventInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Data values row
                if hasDataValues && !isCompact {
                    HStack(spacing: 12) {
                        Spacer()
                            .frame(width: 58)

                        if let actual = event.actual, !actual.isEmpty {
                            EventDataPill(label: "Act", value: actual, isActual: true)
                        }
                        if let forecast = event.forecast, !forecast.isEmpty {
                            EventDataPill(label: "Fcst", value: forecast, isActual: false)
                        }
                        if let previous = event.previous, !previous.isEmpty {
                            EventDataPill(label: "Prev", value: previous, isActual: false)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, isCompact ? 4 : 8)
        .sheet(isPresented: $showEventInfo) {
            EventInfoSheet(event: event)
        }
    }
}

// MARK: - Event Data Pill
struct EventDataPill: View {
    let label: String
    let value: String
    let isActual: Bool
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActual ? AppColors.accent : textPrimary.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
        )
    }
}

// MARK: - Event Info Sheet
struct EventInfoSheet: View {
    let event: EconomicEvent
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            // Country code badge
                            Text(event.country.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(textPrimary.opacity(0.08))
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(textPrimary)
                                Text(event.dateGroupKey + " \u{2022} " + event.timeDisplayFormatted)
                                    .font(.system(size: 14))
                                    .foregroundColor(textPrimary.opacity(0.6))
                            }
                        }

                        HStack(spacing: 8) {
                            EventImpactTag(impact: event.impact)
                            Text(event.currency ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(textPrimary.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E5E5E5"))
                                )
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )

                    if event.actual != nil || event.forecast != nil || event.previous != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DATA")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .tracking(1)

                            HStack(spacing: 0) {
                                EventDataColumn(label: "Actual", value: event.actual, highlight: true)
                                EventDataColumn(label: "Forecast", value: event.forecast, highlight: false)
                                EventDataColumn(label: "Previous", value: event.previous, highlight: false)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackground)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("WHY IT MATTERS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1)

                        Text(eventExplanation)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(textPrimary.opacity(0.85))
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackground)
                            )
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MARKET IMPACT")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .tracking(1)

                        Text(marketImpact)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(textPrimary.opacity(0.85))
                            .lineSpacing(4)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackground)
                            )
                    }
                }
                .padding(16)
            }
            .background(sheetBackground)
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isMarketHoliday: Bool {
        let title = event.title.lowercased()
        return title.contains("markets closed") || title.contains("early close")
    }

    private var eventExplanation: String {
        let title = event.title.lowercased()

        // Market Holidays
        if title.contains("markets closed") {
            if title.contains("new year") {
                return "New Year's Day marks the beginning of a new calendar and fiscal year. US stock markets (NYSE, NASDAQ) and bond markets are closed. Futures markets may have limited hours."
            } else if title.contains("martin luther king") || title.contains("mlk") {
                return "Martin Luther King Jr. Day honors the civil rights leader. US stock markets are closed, though bond markets may operate on limited schedules."
            } else if title.contains("presidents") {
                return "Presidents' Day (Washington's Birthday) is a federal holiday. US stock and bond markets are closed."
            } else if title.contains("good friday") {
                return "Good Friday is observed by US stock markets although it's not a federal holiday. NYSE and NASDAQ are closed, while some bond markets may operate."
            } else if title.contains("memorial") {
                return "Memorial Day honors military personnel who died in service. US stock and bond markets are closed. It also marks the unofficial start of summer."
            } else if title.contains("juneteenth") {
                return "Juneteenth (June 19) commemorates the end of slavery in the US. Stock markets have observed this holiday since 2022."
            } else if title.contains("independence") {
                return "Independence Day (July 4th) celebrates the Declaration of Independence. US stock and bond markets are closed."
            } else if title.contains("labor day") {
                return "Labor Day honors the American labor movement. US stock and bond markets are closed. It marks the unofficial end of summer."
            } else if title.contains("thanksgiving") {
                return "Thanksgiving Day is a major US holiday. Stock and bond markets are closed. Trading volume is typically light the entire week."
            } else if title.contains("christmas") {
                return "Christmas Day is a federal holiday. US stock and bond markets are closed. Trading is often light in the days leading up to the holiday."
            }
            return "This is a US market holiday. Stock exchanges (NYSE, NASDAQ) and bond markets are closed. Plan your trades accordingly."
        }

        // Early Close Days
        if title.contains("early close") {
            return "US markets close early at 1:00 PM ET on this day. This typically occurs before major holidays. Trading volume is usually light, and liquidity may be reduced."
        }

        // Regular economic events
        if title.contains("interest rate") || title.contains("policy rate") || title.contains("fed") && title.contains("decision") {
            return "Central bank interest rate decisions directly influence borrowing costs for consumers and businesses. Higher rates typically strengthen the currency but can slow economic growth, while lower rates do the opposite."
        } else if title.contains("cpi") || title.contains("inflation") {
            return "The Consumer Price Index measures the average change in prices paid by consumers for goods and services. It's a key indicator of inflation and influences central bank policy decisions."
        } else if title.contains("gdp") {
            return "Gross Domestic Product measures the total economic output of a country. It's the broadest measure of economic activity and health, affecting investor sentiment and currency valuations."
        } else if title.contains("pce") {
            return "Personal Consumption Expenditures is the Federal Reserve's preferred inflation gauge. Core PCE excludes volatile food and energy prices, providing a cleaner view of underlying inflation trends."
        } else if title.contains("non-farm") || title.contains("payroll") || title.contains("nfp") {
            return "Non-Farm Payrolls measures the number of jobs added or lost in the US economy. It's one of the most important economic indicators, directly impacting market expectations for Fed policy."
        } else if title.contains("jobless") || title.contains("unemployment") {
            return "Unemployment data shows the health of the labor market. Rising claims may signal economic weakness, while falling claims suggest a strong job market and potential wage pressures."
        } else if title.contains("trade balance") {
            return "The trade balance measures the difference between a country's exports and imports. A deficit can pressure the currency, while a surplus typically supports it."
        } else if title.contains("speaks") || title.contains("speech") {
            return "Central bank officials' speeches can provide hints about future monetary policy direction. Markets closely watch for any changes in tone or forward guidance."
        } else if title.contains("boj") {
            return "Bank of Japan decisions on monetary policy affect the yen and global markets. Japan's unique ultra-loose policy stance makes any policy shifts highly market-moving."
        }

        return "This economic indicator provides insights into the health of the \(event.country) economy. Markets may react to any deviation from expectations, affecting currency valuations and asset prices."
    }

    private var marketImpact: String {
        let title = event.title.lowercased()

        // Market Holidays
        if title.contains("markets closed") {
            return "NO TRADING available on US stock exchanges. If you have open positions, be aware they cannot be adjusted until markets reopen. Futures and forex markets may still operate with limited hours."
        }

        // Early Close Days
        if title.contains("early close") {
            return "REDUCED TRADING HOURS - markets close at 1:00 PM ET. Liquidity decreases significantly after noon. Consider closing or adjusting positions before the early close if needed."
        }

        let currency = event.currency ?? "currency"

        switch event.impact {
        case .high:
            return "This is a HIGH IMPACT event. Expect significant market volatility around the release time. The \(currency) and related assets may experience sharp moves. Consider reducing position sizes or avoiding new entries shortly before the announcement."
        case .medium:
            return "This is a MEDIUM IMPACT event. May cause moderate market movement, especially if the data significantly differs from expectations. Stay aware but normal trading can continue."
        case .low:
            return "This is a LOW IMPACT event. Typically causes minimal market reaction unless combined with other factors. Normal trading conditions expected."
        }
    }
}

// MARK: - Event Impact Tag
struct EventImpactTag: View {
    let impact: EventImpact

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(impact.color)
                .frame(width: 3, height: 14)
            Text(impact.displayName + " Impact")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(impact.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(impact.color.opacity(0.15))
        )
    }
}

// MARK: - Event Data Column
struct EventDataColumn: View {
    let label: String
    let value: String?
    let highlight: Bool
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(value ?? "-")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(highlight && value != nil ? AppColors.accent : textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - All Events View
struct AllEventsView: View {
    let events: [EconomicEvent]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var groupedEvents: [(key: String, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: events) { $0.dateGroupKey }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
        }.map { (key: $0.key, events: $0.value.sorted { ($0.time ?? Date()) < ($1.time ?? Date()) }) }
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isDarkMode {
                BrushEffectOverlay()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedEvents, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Date header
                            Text(group.key.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 20)

                            // Events for this date
                            VStack(spacing: 0) {
                                ForEach(group.events) { event in
                                    NavigationLink(destination: EventInfoView(event: event)) {
                                        EventDetailRow(event: event)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if event.id != group.events.last?.id {
                                        Divider()
                                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Upcoming Events")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Event Detail Row
struct EventDetailRow: View {
    let event: EconomicEvent
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var timeString: String {
        guard let time = event.time else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: time).lowercased()
    }

    /// Country code extracted from country string
    private var countryCode: String {
        event.country.uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Vertical impact indicator bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.impact.color)
                .frame(width: 3, height: 44)
                .padding(.trailing, 12)

            // Time
            if !timeString.isEmpty {
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(textSecondary)
                    .frame(width: 60, alignment: .leading)
            }

            // Country code badge
            Text(countryCode)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(textPrimary.opacity(0.08))
                )
                .padding(.trailing, 10)

            // Event name
            Text(event.title)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .lineLimit(2)

            Spacer()

            // Previous/Forecast/Actual values if available
            if let forecast = event.forecast {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Forecast")
                        .font(.system(size: 9))
                        .foregroundColor(textSecondary)
                    Text(forecast)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Event Info View (Detail)
struct EventInfoView: View {
    let event: EconomicEvent
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var timeString: String {
        guard let time = event.time else { return "TBD" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: event.date)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isDarkMode {
                BrushEffectOverlay()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Country and Impact
                        HStack(spacing: 16) {
                            // Country code in a professional badge
                            Text(event.country.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(textPrimary.opacity(0.08))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.country)
                                    .font(.headline)
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    // Impact badge with colored indicator
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(event.impact.color)
                                            .frame(width: 3, height: 14)
                                        Text(event.impact.rawValue.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(event.impact.color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        event.impact.color.opacity(0.12)
                                    )
                                    .cornerRadius(6)

                                    Text("Impact")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            Spacer()
                        }

                        // Event Title
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(textPrimary)

                        // Date & Time
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(dateString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(textPrimary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Time")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(timeString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(textPrimary)
                            }
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // Data Card (Forecast, Previous, Actual)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Economic Data")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        HStack(spacing: 0) {
                            EventDataColumn(
                                label: "Previous",
                                value: event.previous,
                                highlight: false
                            )

                            Divider()
                                .frame(height: 50)

                            EventDataColumn(
                                label: "Forecast",
                                value: event.forecast,
                                highlight: true
                            )

                            Divider()
                                .frame(height: 50)

                            EventDataColumn(
                                label: "Actual",
                                value: event.actual,
                                highlight: false
                            )
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // Description Card
                    if let description = event.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About This Event")
                                .font(.headline)
                                .foregroundColor(textPrimary)

                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }

                    // Why It Matters Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why It Matters")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text(whyItMatters)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Event Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var whyItMatters: String {
        let title = event.title.lowercased()

        if title.contains("cpi") || title.contains("inflation") {
            return "Consumer Price Index (CPI) measures inflation by tracking changes in prices paid by consumers. Higher than expected readings can signal rising inflation, potentially leading to interest rate hikes and impacting risk assets like crypto negatively in the short term."
        } else if title.contains("gdp") {
            return "Gross Domestic Product (GDP) measures the total value of goods and services produced. Strong GDP growth typically signals a healthy economy, which can be positive for risk assets. However, very strong growth may lead to inflation concerns."
        } else if title.contains("unemployment") || title.contains("employment") || title.contains("payroll") || title.contains("nfp") {
            return "Employment data is a key indicator of economic health. Strong job numbers suggest economic growth but may also signal potential inflation, which could lead to tighter monetary policy. Weak numbers may indicate economic slowdown."
        } else if title.contains("interest rate") || title.contains("policy rate") || title.contains("fed") || title.contains("fomc") {
            return "Central bank interest rate decisions directly impact liquidity and borrowing costs across the economy. Rate hikes typically strengthen the local currency and can pressure risk assets, while rate cuts often boost risk appetite."
        } else if title.contains("pce") {
            return "Personal Consumption Expenditures (PCE) is the Federal Reserve's preferred inflation measure. It influences monetary policy decisions and can significantly impact market expectations for interest rates."
        } else if title.contains("trade balance") {
            return "Trade balance measures the difference between a country's exports and imports. A surplus can strengthen the currency, while a deficit may weaken it. Large imbalances can affect currency valuations and international capital flows."
        } else if title.contains("pmi") || title.contains("manufacturing") {
            return "Purchasing Managers' Index (PMI) is a leading indicator of economic health. Readings above 50 indicate expansion, while below 50 signals contraction. It often moves markets as it provides early insight into economic trends."
        } else {
            return "Economic events can significantly impact financial markets by influencing investor sentiment, currency valuations, and monetary policy expectations. High-impact events often lead to increased volatility."
        }
    }
}

// MARK: - Notifications Sheet
struct NotificationsSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    // Mock notifications data
    private let mockNotifications: [MockNotification] = [
        MockNotification(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: AppColors.success,
            title: "BTC up 5.2% today",
            subtitle: "Bitcoin is showing strong momentum",
            time: "2m ago",
            isRead: false
        ),
        MockNotification(
            icon: "exclamationmark.triangle.fill",
            iconColor: AppColors.warning,
            title: "High volatility alert",
            subtitle: "Market volatility index above 70",
            time: "15m ago",
            isRead: false
        ),
        MockNotification(
            icon: "bell.badge.fill",
            iconColor: AppColors.accent,
            title: "DCA reminder",
            subtitle: "Weekly Bitcoin purchase scheduled",
            time: "1h ago",
            isRead: true
        ),
        MockNotification(
            icon: "calendar.badge.exclamationmark",
            iconColor: AppColors.error,
            title: "FOMC meeting tomorrow",
            subtitle: "High impact event at 2:00 PM EST",
            time: "3h ago",
            isRead: true
        ),
        MockNotification(
            icon: "arrow.up.circle.fill",
            iconColor: AppColors.success,
            title: "Fear & Greed at 72",
            subtitle: "Market sentiment shifted to Greed",
            time: "5h ago",
            isRead: true
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Unread section
                    let unreadNotifications = mockNotifications.filter { !$0.isRead }
                    if !unreadNotifications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, 4)

                            ForEach(unreadNotifications) { notification in
                                HomeNotificationRow(notification: notification)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Read section
                    let readNotifications = mockNotifications.filter { $0.isRead }
                    if !readNotifications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Earlier")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .padding(.horizontal, 4)

                            ForEach(readNotifications) { notification in
                                HomeNotificationRow(notification: notification)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Mark all as read
                    }) {
                        Text("Clear All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Mock Notification Model
struct MockNotification: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: String
    let isRead: Bool
}

// MARK: - Home Notification Row
struct HomeNotificationRow: View {
    let notification: MockNotification
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(notification.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: notification.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(notification.iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Text(notification.time)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.4))
                }

                Text(notification.subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .lineLimit(1)
            }

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(notification.isRead ? Color.clear : AppColors.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Trend Signal (shared)
enum MacroTrendSignal: String {
    case bullish = "Bullish"
    case bearish = "Bearish"
    case neutral = "Neutral"

    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .bearish: return AppColors.error
        case .neutral: return AppColors.warning
        }
    }

    var icon: String {
        switch self {
        case .bullish: return "arrow.up.right.circle.fill"
        case .bearish: return "arrow.down.right.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

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
                // Header
                HStack(alignment: .center) {
                    Text("VIX")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    // Subtle signal indicator
                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                // Value
                Text(vixData.map { String(format: "%.2f", $0.value) } ?? "--")
                    .font(.system(size: size == .compact ? 28 : 36, weight: .semibold, design: .default))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()

                // Footer
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
        // Rising DXY = bearish for risk assets, Falling = bullish
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
                // Header
                HStack(alignment: .center) {
                    Text("DXY")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    // Subtle signal indicator
                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                // Value with change
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

                // Footer
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
                // Header
                HStack(alignment: .center) {
                    Text("Global M2")
                        .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    // Subtle signal indicator
                    Circle()
                        .fill(signalColor)
                        .frame(width: 8, height: 8)
                }

                // Value with change
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

                // Footer
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
                    // Current Value Card
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

                    // What is VIX
                    MacroInfoSection(title: "What is VIX?", content: """
The CBOE Volatility Index (VIX) measures the market's expectation of 30-day volatility implied by S&P 500 index options. Often called the "fear gauge," it reflects investor sentiment and uncertainty in the market.
""")

                    // Level Interpretation
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

                    // Crypto Correlation
                    MacroInfoSection(title: "Impact on Crypto", content: """
• High VIX (>25): Risk-off environment. Investors flee to safety, often selling crypto.
• Low VIX (<18): Risk-on sentiment. Investors seek higher returns in assets like crypto.
• VIX spikes often coincide with Bitcoin drawdowns as correlations increase during market stress.
""")

                    // Historical Context
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
                    // Current Value Card
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

                    // What is DXY
                    MacroInfoSection(title: "What is DXY?", content: """
The US Dollar Index (DXY) measures the value of the US dollar relative to a basket of foreign currencies: Euro (57.6%), Japanese Yen (13.6%), British Pound (11.9%), Canadian Dollar (9.1%), Swedish Krona (4.2%), and Swiss Franc (3.6%).
""")

                    // Crypto Correlation
                    MacroInfoSection(title: "Impact on Crypto", content: """
• Rising DXY: Bearish for crypto. A stronger dollar reduces appetite for risk assets.
• Falling DXY: Bullish for crypto. Dollar weakness often drives investors to alternatives.
• BTC and DXY typically show inverse correlation, especially during macro-driven markets.
""")

                    // Level Interpretation
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

                    // Historical Context
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
                    // Current Value Card
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

                    // What is Global M2
                    MacroInfoSection(title: "What is Global M2?", content: """
Global M2 represents the total money supply across major economies, including cash, checking deposits, and easily convertible near-money. It's a key indicator of global liquidity and monetary conditions.
""")

                    // Change Breakdown
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

                    // Crypto Correlation
                    MacroInfoSection(title: "Impact on Crypto", content: """
• Expanding M2: Bullish for crypto. More liquidity seeks higher-yielding assets.
• Contracting M2: Bearish for crypto. Quantitative tightening reduces risk appetite.
• Bitcoin often moves with global M2 with a ~10-week lag.
• M2 expansion was a key driver of 2020-2021 crypto bull run.
""")

                    // Historical Context
                    MacroInfoSection(title: "Historical Context", content: """
• 2020-2021: Unprecedented M2 expansion (~40% growth)
• 2022-2023: First M2 contraction in decades
• Correlation with BTC: ~0.8 over long timeframes
• Central bank balance sheets directly impact global M2
""")

                    // FRED API Attribution
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

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
}
