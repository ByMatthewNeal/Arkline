import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showPortfolioPicker = false
    @State private var showCustomizeSheet = false
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
                            onCustomizeTap: { showCustomizeSheet = true }
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
                    )
                )
            }
            .sheet(isPresented: $showCustomizeSheet) {
                CustomizeHomeView()
            }
            .onChange(of: appState.homeNavigationReset) { _, _ in
                // Pop to root when home tab is tapped while already on home
                navigationPath = NavigationPath()
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

                HeaderIconButton(icon: "bell", hasNotification: true, action: {})
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

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Generate a subtle gradient based on name
    private var avatarGradient: LinearGradient {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash + 40) % 360) / 360.0

        return LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.6, brightness: colorScheme == .dark ? 0.5 : 0.85),
                Color(hue: hue2, saturation: 0.5, brightness: colorScheme == .dark ? 0.4 : 0.75)
            ],
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
    var viewModel: HomeViewModel
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
            return !viewModel.upcomingEvents.isEmpty
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
            if let riskScore = viewModel.compositeRiskScore {
                RiskScoreCard(score: riskScore, size: appState.widgetSize(.riskScore))
            }

        case .fearGreedIndex:
            if let fearGreed = viewModel.fearGreedIndex {
                GlassFearGreedCard(index: fearGreed, size: appState.widgetSize(.fearGreedIndex))
            }

        case .marketMovers:
            MarketMoversSection(
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
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var riskLabel: String {
        switch score {
        case 0..<30: return "High Risk"
        case 30..<70: return "Moderate"
        default: return "Low Risk"
        }
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

    var body: some View {
        HStack(spacing: size == .compact ? 12 : 16) {
            // Score circle - blue accent theme
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

                // Progress ring - blue gradient
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.6), AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))

                // Subtle glow
                Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .blur(radius: size == .compact ? 8 : 12)
                    .frame(width: circleSize * 0.6, height: circleSize * 0.6)

                // Score text
                Text("\(score)")
                    .font(.system(size: size == .compact ? 18 : (size == .expanded ? 30 : 24), weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }

            VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                Text("ArkLine Risk Score")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                // Neutral badge for risk level
                Text(riskLabel)
                    .font(size == .compact ? .caption : .subheadline)
                    .foregroundColor(AppColors.textSecondary)

                if size != .compact {
                    Text("Based on 10 indicators")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                if size == .expanded {
                    Text("Market conditions favor cautious positioning")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.6))
                        .padding(.top, 4)
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

// MARK: - Market Movers Section
struct MarketMoversSection: View {
    let btcPrice: Double
    let ethPrice: Double
    let btcChange: Double
    let ethChange: Double
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            Text("Market Movers")
                .font(size == .compact ? .subheadline : .headline)
                .foregroundColor(textPrimary)

            if size == .compact {
                // Compact: horizontal row
                HStack(spacing: 8) {
                    CompactCoinCard(symbol: "BTC", price: btcPrice, change: btcChange, accentColor: AppColors.accent)
                    CompactCoinCard(symbol: "ETH", price: ethPrice, change: ethChange, accentColor: AppColors.accent)
                }
            } else {
                HStack(spacing: 12) {
                    GlassCoinCard(
                        symbol: "BTC",
                        name: "Bitcoin",
                        price: btcPrice,
                        change: btcChange,
                        icon: "bitcoinsign.circle.fill",
                        accentColor: AppColors.accent,
                        isExpanded: size == .expanded
                    )

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
            }
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

                Button(action: {}) {
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
                    ForEach(groupedEvents.prefix(maxGroups), id: \.key) { group in
                        EventDateGroup(
                            dateKey: group.key,
                            events: Array(group.events.prefix(maxEventsPerGroup)),
                            isCompact: size == .compact
                        )
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

    private var impactIcon: String {
        switch event.impact {
        case .high, .medium:
            return "bolt.fill"
        case .low:
            return "circle.fill"
        }
    }

    private var hasDataValues: Bool {
        event.actual != nil || event.forecast != nil || event.previous != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            HStack(spacing: isCompact ? 6 : 10) {
                Image(systemName: impactIcon)
                    .font(.system(size: isCompact ? 10 : 12, weight: .semibold))
                    .foregroundColor(event.impact.color)
                    .frame(width: isCompact ? 14 : 18)

                Text(event.timeDisplayFormatted)
                    .font(.system(size: isCompact ? 10 : 12, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .frame(width: isCompact ? 45 : 55, alignment: .leading)

                if let flag = event.countryFlag {
                    Text(flag)
                        .font(.system(size: isCompact ? 11 : 13))
                }

                Text(event.title)
                    .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)

                Spacer()

                if !isCompact {
                    Button(action: { showEventInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }

            if hasDataValues && !isCompact {
                HStack(spacing: 12) {
                    Spacer()
                        .frame(width: 83)

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
                        HStack(spacing: 10) {
                            if let flag = event.countryFlag {
                                Text(flag)
                                    .font(.system(size: 32))
                            }
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
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
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

    private var timeString: String {
        guard let time = event.time else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: time).lowercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Impact indicator
            if event.impact == .high {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 20)
            } else {
                Circle()
                    .fill(AppColors.textSecondary.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .frame(width: 20)
            }

            // Time
            if !timeString.isEmpty {
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 60, alignment: .leading)
            }

            // Country flag
            Text(event.countryFlag ?? "🌐")
                .font(.system(size: 16))

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
                        .foregroundColor(AppColors.textSecondary)
                    Text(forecast)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
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
                        HStack {
                            Text(event.countryFlag ?? "🌐")
                                .font(.system(size: 32))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.country ?? "Global")
                                    .font(.headline)
                                    .foregroundColor(textPrimary)

                                HStack(spacing: 8) {
                                    // Impact badge
                                    HStack(spacing: 4) {
                                        if event.impact == .high {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 10))
                                        }
                                        Text(event.impact.rawValue.capitalized)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(event.impact == .high ? AppColors.accent : AppColors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        (event.impact == .high ? AppColors.accent : AppColors.textSecondary).opacity(0.15)
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

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
}
