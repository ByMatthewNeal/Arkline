import SwiftUI

// MARK: - Reorderable Market Widget Stack
struct ReorderableMarketWidgetStack: View {
    @Bindable var viewModel: MarketViewModel
    @Bindable var sentimentViewModel: SentimentViewModel
    var allocationViewModel: AllocationViewModel?
    @ObservedObject var appState: AppState
    @State private var isEditMode: Bool = false
    @State private var draggingWidget: MarketWidgetType?
    @State private var draggedOverWidget: MarketWidgetType?
    @Environment(\.colorScheme) var colorScheme

    private var visibleWidgets: [MarketWidgetType] {
        appState.marketWidgetConfiguration.orderedEnabledWidgets
    }

    var body: some View {
        VStack(spacing: 24) {
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
            .padding(.horizontal, 24)

            // Widget list
            ForEach(Array(visibleWidgets.enumerated()), id: \.element) { index, widgetType in
                MarketWidgetRowContainer(
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
                .modifier(MarketConditionalDragModifier(
                    enabled: isEditMode,
                    widgetType: widgetType,
                    visibleWidgets: visibleWidgets,
                    draggingWidget: $draggingWidget,
                    draggedOverWidget: $draggedOverWidget,
                    widgetOrder: appState.marketWidgetConfiguration.widgetOrder,
                    onUpdateOrder: { appState.updateMarketWidgetOrder($0) }
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.marketWidgetConfiguration.orderedEnabledWidgets)
    }

    private func moveWidget(_ widget: MarketWidgetType, direction: Int) {
        var order = appState.marketWidgetConfiguration.widgetOrder
        guard let currentIndex = order.firstIndex(of: widget) else { return }

        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < order.count else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            order.remove(at: currentIndex)
            order.insert(widget, at: newIndex)
            appState.updateMarketWidgetOrder(order)
        }
    }

    @ViewBuilder
    private func widgetView(for type: MarketWidgetType) -> some View {
        switch type {
        case .dailyNews:
            DailyNewsSection(news: viewModel.newsItems)

        case .fedWatch:
            FedWatchSection(meetings: viewModel.fedWatchMeetings)

        case .allocation:
            AllocationSummarySection(
                allocationSummary: allocationViewModel?.allocationSummary,
                isLoading: allocationViewModel?.isLoading ?? false,
                hasExtremeMove: sentimentViewModel.hasExtremeMacroMove,
                sentimentViewModel: sentimentViewModel
            )

        case .traditionalMarkets:
            TraditionalMarketsSection()

        case .topCoins:
            TopCoinsSection(viewModel: viewModel)

        case .sentiment:
            SentimentSummarySection(
                viewModel: sentimentViewModel,
                isPro: appState.isPro
            )

        case .altcoinScreener:
            AltcoinScreenerSection()
        }
    }
}

// MARK: - Market Widget Row Container
private struct MarketWidgetRowContainer<Content: View>: View {
    let widgetType: MarketWidgetType
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

// MARK: - Market Conditional Drag Modifier
private struct MarketConditionalDragModifier: ViewModifier {
    let enabled: Bool
    let widgetType: MarketWidgetType
    let visibleWidgets: [MarketWidgetType]
    @Binding var draggingWidget: MarketWidgetType?
    @Binding var draggedOverWidget: MarketWidgetType?
    let widgetOrder: [MarketWidgetType]
    let onUpdateOrder: ([MarketWidgetType]) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingWidget = widgetType
                    return NSItemProvider(object: widgetType.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: MarketWidgetDropDelegate(
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

// MARK: - Market Widget Drop Delegate
private struct MarketWidgetDropDelegate: DropDelegate {
    let item: MarketWidgetType
    let items: [MarketWidgetType]
    @Binding var draggingItem: MarketWidgetType?
    @Binding var draggedOverItem: MarketWidgetType?
    let onReorder: ([MarketWidgetType]) -> Void

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

        guard let fromIndex = items.firstIndex(of: draggingItem),
              let toIndex = items.firstIndex(of: item) else {
            self.draggingItem = nil
            self.draggedOverItem = nil
            return false
        }

        newItems.remove(at: fromIndex)
        newItems.insert(draggingItem, at: toIndex)

        onReorder(newItems)

        self.draggingItem = nil
        self.draggedOverItem = nil
        return true
    }
}
