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
            return viewModel.arkLineRiskScore != nil
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
            return true
        case .assetRiskLevel:
            // Show if any user-selected coin has risk data
            return !viewModel.userSelectedRiskLevels.filter { $0.riskLevel != nil }.isEmpty
        case .vixIndicator:
            return true
        case .dxyIndicator:
            return true
        case .globalLiquidity:
            return true
        case .supplyInProfit:
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
            // Show ArkLine Score widget (same as Market Overview)
            if let arkLineScore = viewModel.arkLineRiskScore {
                HomeArkLineScoreWidget(score: arkLineScore, size: appState.widgetSize(.riskScore))
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

        case .favorites:
            FavoritesSection(
                assets: viewModel.favoriteAssets,
                size: appState.widgetSize(.favorites)
            )

        case .assetRiskLevel:
            MultiCoinRiskSection(
                riskLevels: appState.isPro ? viewModel.userSelectedRiskLevels : viewModel.userSelectedRiskLevels.filter { $0.coin == "BTC" },
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
                macroZScores: viewModel.macroZScores,
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
