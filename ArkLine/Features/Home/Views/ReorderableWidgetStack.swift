import SwiftUI

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

    // Avoid re-filtering inside shouldShowWidget — cache check results
    private var hasStockRiskData: Bool {
        !viewModel.stockRiskLevels.isEmpty
    }

    var body: some View {
        LazyVStack(spacing: 16) {
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
                .accessibilityLabel(isEditMode ? "Done editing widgets" : "Edit widget order")
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
                .cardAppearance(delay: index)
                .modifier(ConditionalDragModifier(
                    enabled: isEditMode,
                    widgetType: widgetType,
                    visibleWidgets: visibleWidgets,
                    draggingWidget: $draggingWidget,
                    draggedOverWidget: $draggedOverWidget,
                    widgetOrder: appState.widgetConfiguration.widgetOrder,
                    onUpdateOrder: { appState.updateWidgetOrder($0) }
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
            return viewModel.arkLineRiskScore != nil
        case .fearGreedIndex:
            return viewModel.fearGreedIndex != nil
        case .marketMovers:
            return true
        case .dcaReminders:
            return true
        case .fedWatch:
            return !viewModel.fedWatchMeetings.isEmpty
        case .dailyNews:
            return true
        case .assetRiskLevel:
            return !viewModel.riskLevels.isEmpty
        case .stockRiskLevel:
            return hasStockRiskData
        case .vixIndicator:
            // Hidden when Macro Dashboard is enabled (already shows VIX)
            return !appState.isWidgetEnabled(.macroDashboard)
        case .dxyIndicator:
            // Hidden when Macro Dashboard is enabled (already shows DXY)
            return !appState.isWidgetEnabled(.macroDashboard)
        case .globalLiquidity:
            // Hidden when Macro Dashboard is enabled (already shows M2)
            return !appState.isWidgetEnabled(.macroDashboard)
        case .supplyInProfit:
            return true
        case .macroDashboard:
            // Show if we have at least 2 of the 3 indicators
            let hasVix = viewModel.vixData != nil
            let hasDxy = viewModel.dxyData != nil
            let hasM2 = viewModel.globalLiquidityChanges != nil
            return [hasVix, hasDxy, hasM2].filter { $0 }.count >= 2
        case .favorites:
            return true
        case .aiMarketSummary:
            return false
        case .flashIntel:
            return true
        case .usFutures:
            return true
        case .qpsSignals:
            return true
        case .marketDeck:
            return viewModel.latestDeck != nil
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
            // Show ArkLine Score widget (same as Market Overview)
            if let arkLineScore = viewModel.arkLineRiskScore {
                HomeArkLineScoreWidget(
                    score: arkLineScore,
                    size: appState.widgetSize(.riskScore),
                    fearGreedIndex: viewModel.fearGreedIndex
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
                solPrice: viewModel.solPrice,
                btcChange: viewModel.btcChange24h,
                ethChange: viewModel.ethChange24h,
                solChange: viewModel.solChange24h,
                enabledAssets: appState.isPro ? appState.enabledCoreAssets : [.btc],
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

        case .dcaReminders:
            DCARemindersEntrySection(
                todayReminders: viewModel.todayReminders,
                onComplete: { reminder in Task { await viewModel.markReminderComplete(reminder) } },
                size: appState.widgetSize(.dcaReminders)
            )

        case .assetRiskLevel:
            MultiCoinRiskSection(
                riskLevels: appState.isPro ? viewModel.userSelectedRiskLevels : viewModel.userSelectedRiskLevels.filter { $0.coin == "BTC" },
                size: appState.widgetSize(.assetRiskLevel)
            )

        case .stockRiskLevel:
            StockRiskLevelSection(
                riskLevels: viewModel.stockSelectedRiskLevels,
                size: appState.widgetSize(.stockRiskLevel)
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

        case .supplyInProfit:
            SupplyInProfitWidget(
                supplyData: viewModel.supplyInProfitData,
                size: appState.widgetSize(.supplyInProfit)
            )

        case .macroDashboard:
            MacroDashboardWidget(
                vixData: viewModel.vixData,
                dxyData: viewModel.dxyData,
                liquidityData: viewModel.globalLiquidityChanges,
                netLiquidityData: viewModel.netLiquidityData,
                globalLiquidityIndex: viewModel.globalLiquidityIndex,
                vixHistory: viewModel.vixHistory,
                dxyHistory: viewModel.dxyHistory,
                macroZScores: viewModel.macroZScores,
                regime: viewModel.computedRegime,
                quadrant: viewModel.currentRegimeResult?.quadrant,
                size: appState.widgetSize(.macroDashboard)
            )

        case .favorites:
            FavoritesSection(
                assets: viewModel.favoriteAssets,
                size: appState.widgetSize(.favorites)
            )

        case .aiMarketSummary:
            HomeAISummaryWidget(
                summary: viewModel.marketSummary,
                isLoading: viewModel.isLoadingSummary,
                userName: "there",
                size: appState.widgetSize(.aiMarketSummary),
                isAdmin: appState.currentUser?.isAdmin == true,
                onFeedback: appState.currentUser?.isAdmin == true ? { rating, note in
                    guard let userId = appState.currentUser?.id else { return }
                    Task { await viewModel.submitBriefingFeedback(rating: rating, note: note, userId: userId) }
                } : nil
            )

        case .flashIntel:
            FlashIntelSection(
                signals: viewModel.flashIntelSignals,
                isPro: appState.isPro,
                size: appState.widgetSize(.flashIntel),
                stats: viewModel.signalStats,
                highImpactEvents: viewModel.todaysEvents.filter { $0.isHighImpact },
                marketConditions: viewModel.marketConditions
            )

        case .usFutures:
            USFuturesSection()

        case .qpsSignals:
            QPSSignalChangesCard(
                signals: viewModel.qpsSignals,
                isPro: appState.isPro,
                size: appState.widgetSize(.qpsSignals)
            )
            .id("widget_qpsSignals")

        case .marketDeck:
            if let deck = viewModel.latestDeck {
                MarketDeckCard(deck: deck)
            }
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
                    .accessibilityLabel("Move \(widgetType.displayName) up")

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
                    .accessibilityLabel("Move \(widgetType.displayName) down")
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

// MARK: - Conditional Drag Modifier
/// Only attaches onDrag/onDrop when enabled, preventing gesture conflicts with vertical scrolling.
struct ConditionalDragModifier: ViewModifier {
    let enabled: Bool
    let widgetType: HomeWidgetType
    let visibleWidgets: [HomeWidgetType]
    @Binding var draggingWidget: HomeWidgetType?
    @Binding var draggedOverWidget: HomeWidgetType?
    let widgetOrder: [HomeWidgetType]
    let onUpdateOrder: ([HomeWidgetType]) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingWidget = widgetType
                    return NSItemProvider(object: widgetType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: WidgetDropDelegate(
                    item: widgetType,
                    items: visibleWidgets,
                    draggingItem: $draggingWidget,
                    draggedOverItem: $draggedOverWidget,
                    onReorder: { newOrder in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var fullOrder = widgetOrder
                            let enabledSet = Set(newOrder)
                            fullOrder.removeAll { enabledSet.contains($0) }
                            for widget in newOrder.reversed() {
                                if let originalIndex = widgetOrder.firstIndex(of: widget) {
                                    fullOrder.insert(widget, at: min(originalIndex, fullOrder.count))
                                } else {
                                    fullOrder.insert(widget, at: 0)
                                }
                            }
                            onUpdateOrder(newOrder + fullOrder.filter { !enabledSet.contains($0) })
                        }
                    }
                ))
        } else {
            content
        }
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
