import SwiftUI

// MARK: - Reorderable Market Widget Stack
struct ReorderableMarketWidgetStack: View {
    @Bindable var viewModel: MarketViewModel
    @Bindable var sentimentViewModel: SentimentViewModel
    var allocationViewModel: AllocationViewModel?
    @ObservedObject var appState: AppState
    var widgetRefreshId: UUID = UUID()
    var selectedZone: MarketZone = .all
    @State private var isEditMode: Bool = false
    @State private var showCustomizeSheet: Bool = false
    @State private var draggingWidget: MarketWidgetType?
    @State private var draggedOverWidget: MarketWidgetType?
    @Environment(\.colorScheme) var colorScheme

    private var visibleWidgets: [MarketWidgetType] {
        let enabled = appState.marketWidgetConfiguration.orderedEnabledWidgets
        guard selectedZone != .all else { return enabled }
        return enabled.filter { $0.zone == selectedZone }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Edit mode toggle
            HStack {
                Spacer()

                Button(action: {
                    showCustomizeSheet = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Customize Market sections")

                // Reordering applies to the full list, so Edit is only offered in "All"
                if selectedZone == .all {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            isEditMode.toggle()
                        }
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                    }
                    .padding(.leading, 12)
                    .accessibilityLabel(isEditMode ? "Done editing widgets" : "Edit widget order")
                }
            }
            .padding(.horizontal, 24)

            // Empty state: no visible sections (all hidden, or none in this zone)
            if visibleWidgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)

                    Text(selectedZone == .all
                        ? "All sections are hidden"
                        : "No \(selectedZone.displayName) sections enabled")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)

                    Button(action: { showCustomizeSheet = true }) {
                        Text("Customize Market")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            }

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
        .onChange(of: selectedZone) { _, _ in
            // Leaving "All" exits edit mode — reordering a filtered view would be ambiguous
            isEditMode = false
        }
        .sheet(isPresented: $showCustomizeSheet) {
            CustomizeMarketView()
                .environmentObject(appState)
        }
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
        case .usFutures:
            USFuturesSection(refreshId: widgetRefreshId)
                .padding(.horizontal)

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
            TraditionalMarketsSection(qpsSignals: viewModel.qpsSignals)

        case .topCoins:
            TopCoinsSection(viewModel: viewModel)

        case .sentiment:
            SentimentSummarySection(
                viewModel: sentimentViewModel,
                isPro: appState.isPro
            )

        case .altcoinScreener:
            AltcoinScreenerSection(refreshId: widgetRefreshId)

        case .swingSetups:
            SwingSetupsSummarySection(isPro: appState.isPro, refreshId: widgetRefreshId)

        case .globalLiquidity:
            GlobalLiquiditySection(refreshId: widgetRefreshId)

        case .liquidityCycle:
            LiquidityCycleSection(refreshId: widgetRefreshId)

        case .cycleScorecard:
            CycleScorecardSection(refreshId: widgetRefreshId)

        case .qpsGrid:
            QPSGridSection(
                signals: viewModel.qpsSignals,
                isPro: appState.isPro
            )

        case .marketBreadth:
            MarketBreadthSection(refreshId: widgetRefreshId)

        case .mindset:
            MindsetMarketSection()

        case .metalsSupportResistance:
            MetalsSupportResistanceSection(refreshId: widgetRefreshId)

        case .liquidationHeatmap:
            LiquidationHeatmapSection(refreshId: widgetRefreshId)

        case .spotDerivativesFlows:
            SpotDerivativesFlowsSection(refreshId: widgetRefreshId)

        case .derivativesPositioning:
            DerivativesPositioningSection(viewModel: sentimentViewModel)
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

// MARK: - Mindset Section (Psychology zone)
/// The mental game, gathered on the Market tab under the Psychology chip: the
/// day's beat, the full psychology trail, a browsable set of principles, and a
/// pointer to the live tools that read the crowd's emotion. The state-matched
/// reminders live on the Cycle Scorecard and Sentiment Regime.
private struct MindsetMarketSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var expanded: Set<Int> = []
    @State private var selectedCategory: PrincipleCategory? = nil
    @State private var selectedRhythm: Int? = nil

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    enum PrincipleCategory: String, CaseIterable, Identifiable {
        case master = "Master Yourself"
        case crowd = "Read the Crowd"
        case downside = "Protect the Downside"
        case simple = "Keep It Simple"
        var id: String { rawValue }
        var subtitle: String {
            switch self {
            case .master: return "The real work"
            case .crowd: return "Don't be a follower"
            case .downside: return "Survive first"
            case .simple: return "Cut the noise"
            }
        }
    }

    private struct Principle: Identifiable { let id: Int; let category: PrincipleCategory; let title: String; let body: String }

    private struct Book: Identifiable { let id: Int; let title: String; let author: String; let note: String }

    private struct Rhythm: Identifiable { let id: Int; let name: String; let guide: String }

    private static let rhythms: [Rhythm] = [
        .init(id: 0, name: "Set and forget", guide: "You've got a plan and it's on autopilot. A few minutes a week is plenty. That's most people, and there's no shame in it. Boring is a strategy."),
        .init(id: 1, name: "Check in", guide: "You like staying in the loop. A couple of short check-ins a week keeps you informed without letting the noise run you."),
        .init(id: 2, name: "Hands on", guide: "You're active and you enjoy it. Fine, but set a start and a stop time and protect the rest of your day. More screen time is not more returns."),
    ]

    private static let overdoingSigns: [String] = [
        "It's the first thing you check in the morning and the last thing at night.",
        "A green day or a red day decides your whole mood.",
        "You're refreshing prices on your day off, at dinner, around the people you love.",
        "Sleep, work, or relationships are slipping so you can watch a screen.",
    ]

    private static let books: [Book] = [
        .init(id: 0, title: "Best Loser Wins", author: "Tom Hougaard", note: "The one who learns to lose well is the one who ends up winning. It's about controlling your own reactions, not calling the chart right."),
        .init(id: 1, title: "The Psychology of Money", author: "Morgan Housel", note: "Doing well with money has almost nothing to do with how smart you are. It's about how you behave when it's on the line."),
        .init(id: 2, title: "The 10X Rule", author: "Grant Cardone", note: "Aim way higher than feels reasonable, then put in the work to match. Most people aim too low and move too slow."),
        .init(id: 3, title: "Who Not How", author: "Dan Sullivan & Dr. Benjamin Hardy", note: "Stop trying to do everything yourself. Growth comes faster from finding the right people than from grinding alone."),
        .init(id: 4, title: "Mastery", author: "Robert Greene", note: "Mastery isn't talent, it's time and reps. A look at how the greats actually got there, one patient day at a time."),
        .init(id: 5, title: "Thinking in Bets", author: "Annie Duke", note: "Treat every choice like a bet with the odds unknown. Judge yourself on the decision, not just how it turned out, because good calls can still lose."),
        .init(id: 6, title: "The Lords of Easy Money", author: "Christopher Leonard", note: "How years of cheap money reshaped the markets and the risks. It's the backstory to why liquidity drives so much of what we watch."),
        .init(id: 7, title: "Atomic Habits", author: "James Clear", note: "Small habits stacked over time beat big bursts of motivation. Build the system and the results follow."),
        .init(id: 8, title: "Thinking, Fast and Slow", author: "Daniel Kahneman", note: "The two ways your brain makes decisions, and the blind spots hiding in both. A map of the traps your own mind sets for you."),
        .init(id: 9, title: "Ego Is the Enemy", author: "Ryan Holiday", note: "Ego trips you up on the way up, at the top, and after a fall. Humility and self-awareness are what keep you growing."),
        .init(id: 10, title: "Richer, Wiser, Happier", author: "William Green", note: "Fifty of the greatest investors alive on how they win, in markets and in life. The lesson underneath it all: keep it simple, stay steady, don't beat yourself."),
        .init(id: 11, title: "The Psychology of Investing", author: "John R. Nofsinger", note: "A plain-English look at the biases quietly costing you money, overconfidence, loss aversion, mental accounting, and how to build around them."),
    ]

    private static let principles: [Principle] = [
        // Master Yourself — the real work
        .init(id: 0, category: .master, title: "Master yourself, not the market", body: "You can't delete fear, greed, or the itch to chase what everybody else is chasing. That's just being human. But you can catch it, name it, and choose not to move on it. Being able to sit with the feeling and not obey it is worth more than any chart."),
        .init(id: 1, category: .master, title: "Decide before the emotion arrives", body: "Make the plan while your head is clear, then let it run. Because in the moment, when everything is green or everything is red, you are not thinking, you are reacting. And the crowd's fear or greed will make the call for you if you didn't make it first."),
        .init(id: 2, category: .master, title: "Pain is a poor estimator of probability", body: "Nothing goes up forever and nothing goes down forever. A drop that feels like the end of the world is usually just a number you have lived through before and came out the other side of. The pain is loud, but it is not accurate."),
        .init(id: 3, category: .master, title: "It's a human problem, not a technical one", body: "Most people who lose aren't losing because they missed some indicator. They lose because of how they act when it gets hard. You don't need another tool. You need to get right with yourself first."),
        .init(id: 4, category: .master, title: "Your mind invents patterns that aren't there", body: "Your brain is built to find shapes in the noise, even when there's nothing there. Sometimes that clean setup you swear you see is just your own head telling you what you want to hear. Slow down and make sure it's real."),
        .init(id: 5, category: .master, title: "Make money, not right", body: "Your ego wants to be right. Your account only cares that you made money. Those two are not the same thing. Let go of needing to prove you were correct and it gets a lot easier to walk away from a bad position."),
        .init(id: 6, category: .master, title: "Know your own worst habits", body: "The edge isn't knowing more, it's knowing yourself. Get honest about where you slip up, the revenge trade, the panic sell, the FOMO buy, and put something in place that stops you before you get there."),

        // Read the Crowd — don't move with the mob
        .init(id: 7, category: .crowd, title: "The crowd is loudest before it is wrong", body: "FOMO is just the herd dressed up in a suit. When everybody's sure, when the whole feed is celebrating, that noise is the warning sign, not the green light."),
        .init(id: 8, category: .crowd, title: "Bottoms are courage, tops are discipline", body: "The best buys feel terrible and the best sells feel amazing. Safety and opportunity rarely sit in the same seat, so the moves that actually matter almost never feel good while you're making them."),
        .init(id: 9, category: .crowd, title: "Familiar is not the same as safe", body: "We pile into what we know, our own country's market, the coin our friends talk about, the names we recognize. Familiar feels safe, but a lot of the time it's just all your eggs in one basket wearing a comfortable face."),
        .init(id: 10, category: .crowd, title: "A great company isn't always a great investment", body: "A great company and a great investment are not the same thing. When everybody already knows a company is winning, that news is baked into the price. Pay too much for a good story and the math still has to work. The price you pay is what protects you."),

        // Protect the Downside — survive first
        .init(id: 11, category: .downside, title: "Protect first, profit second", body: "Size everything so one bad day can't take you out and no single loss can make you want revenge. Staying in the game long enough to let it compound beats swinging for the fences and striking out."),
        .init(id: 12, category: .downside, title: "A paper loss is not a real loss", body: "A red day is just ink on a screen. It doesn't become real until you sell it, or until the thing you own is actually broken. In a spread-out portfolio with no borrowed money, the dip isn't what hurts you. Panicking into it is."),
        .init(id: 13, category: .downside, title: "Don't chase a loss", body: "After you take a hit, everything in you wants to bet bigger and win it back fast. That's the exact move that turns a small hole into a deep one. The way out is slow and boring, never a desperate swing."),
        .init(id: 14, category: .downside, title: "Only play games you can win", body: "Some of the worst losses come from playing a game you had no business in. If you can't explain what you own or roughly what it's worth, you're not investing, you're hoping. Stay in your lane. It doesn't have to be a big lane, it just has to be honest."),

        // Keep It Simple — cut the noise
        .init(id: 15, category: .simple, title: "Patience is a position", body: "The market moves money from people in a hurry to people who can wait. Most days the strongest thing you can do, and the hardest, is nothing at all."),
        .init(id: 16, category: .simple, title: "Activity is not progress", body: "Doing more feels like working harder, but the people who trade the most usually end up with the least. Fees and bad timing quietly eat it all. Sitting still and letting it compound is the move nobody posts about."),
        .init(id: 17, category: .simple, title: "Subtract to see clearly", body: "Most of the edge comes from taking things away, not piling more on. Cut the noise, the fifty tabs, the loud voices, and focus on the few things that actually move the needle."),
        .init(id: 18, category: .simple, title: "Simple is not the same as easy", body: "A rule can fit in one sentence and still take you years to actually live by. The hard part was never understanding it. The hard part is doing it when it counts."),
        .init(id: 19, category: .simple, title: "Invert: dodge the obvious mistakes", body: "You don't have to be a genius. It's a lot easier to just avoid being a fool. Before you ask how to win, ask how you'd blow it, then don't do those things. That alone keeps you ahead of most people."),
        .init(id: 20, category: .simple, title: "You can't predict, you can only prepare", body: "Nobody knows what happens next. Anybody telling you they do is usually just talking their own book. You can't control the move, but you can control how ready you are for it."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card 1 — orientation: masthead, today's beat, the trail.
            VStack(alignment: .leading, spacing: 14) {
                header
                beatCard
                trailCard
                liveToolsNote
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))

            // Card 2 — principles: its own section.
            VStack(alignment: .leading, spacing: 14) {
                principlesBlock
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))

            // Card 3 — balance: keeping investing in its place.
            VStack(alignment: .leading, spacing: 14) {
                balanceBlock
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))

            // Card 4 — reading list: its own section.
            VStack(alignment: .leading, spacing: 14) {
                readingListBlock
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.75))
                .frame(width: 28, height: 3)
                .padding(.bottom, 2)
            Text("MINDSET")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("The last market you'll master is the one in your own head. Get that right and fear and greed stop running your money. Nobody sat most of us down and taught this, so we're teaching it here.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var beatCard: some View {
        let beat = MindsetBeats.today
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MINDSET TODAY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(AppColors.accent)
                Spacer()
                Text(beat.tag.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.8)
                    .foregroundColor(AppColors.textTertiary)
            }
            Text(beat.line)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.accent.opacity(0.055))
                Image(systemName: "quote.closing")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundColor(AppColors.accent.opacity(0.07))
                    .padding(.trailing, 10)
                    .padding(.top, 6)
            }
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.accent.opacity(0.55))
                .frame(width: 3)
                .padding(.vertical, 6)
        }
    }

    private var trailCard: some View {
        NavigationLink { TrailOverviewView(kind: .behavioral) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Brain vs Your Money")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("The full trail. \(TrailKind.behavioral.seed.count) lessons on the mental traps and how to beat them.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.textTertiary.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.textTertiary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var principlesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.75))
                .frame(width: 28, height: 3)
                .padding(.bottom, 2)
            Text("PRINCIPLES")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Tap a theme to dig in.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PrincipleCategory.allCases) { cat in
                    categorySquare(cat)
                }
            }

            if let sel = selectedCategory {
                let items = Self.principles.filter { $0.category == sel }
                VStack(alignment: .leading, spacing: 8) {
                    Text(sel.rawValue.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(AppColors.accent)
                        .padding(.top, 4)
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                        principleRow(p, number: idx + 1, isLast: idx == items.count - 1)
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func categorySquare(_ cat: PrincipleCategory) -> some View {
        let selected = selectedCategory == cat
        let count = Self.principles.filter { $0.category == cat }.count
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = selected ? nil : cat
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(cat.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                Spacer(minLength: 6)
                Text("\(count) principles")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(selected ? AppColors.accent : AppColors.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? AppColors.accent.opacity(0.10) : AppColors.textTertiary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? AppColors.accent.opacity(0.5) : AppColors.textTertiary.opacity(0.15),
                            lineWidth: selected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func principleRow(_ p: Principle, number: Int, isLast: Bool) -> some View {
        let isOpen = expanded.contains(p.id)
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isOpen { expanded.remove(p.id) } else { expanded.insert(p.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(String(format: "%02d", number))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.accent.opacity(0.7))
                        .frame(width: 22, alignment: .leading)
                    Text(p.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isOpen {
                Text(p.body)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppColors.textTertiary.opacity(0.12)).frame(height: 0.5)
            }
        }
    }

    private var balanceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.75))
                .frame(width: 28, height: 3)
                .padding(.bottom, 2)
            Text("BALANCE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Investing is supposed to buy you a life, not become your life. It's an avenue to where you're trying to go, not who you are. Here's how to keep it in its place.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // How much time is enough
            Text("HOW MUCH TIME IS ENOUGH?")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, 4)
            HStack(spacing: 8) {
                ForEach(Self.rhythms) { r in
                    rhythmPill(r)
                }
            }
            if let sel = selectedRhythm, let r = Self.rhythms.first(where: { $0.id == sel }) {
                Text(r.guide)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .transition(.opacity)
            } else {
                Text("More time staring at charts doesn't make you more money. Past a point, it just makes you more anxious.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            // Signs you're overdoing it
            Text("SIGNS YOU'RE OVERDOING IT")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Self.overdoingSigns, id: \.self) { s in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(AppColors.accent.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(s)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Text("If a few of these hit home, that's not a failure. It's a signal to step back.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Text("Build the wealth so you can live the life. Don't trade the life to watch the wealth.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
    }

    private func rhythmPill(_ r: Rhythm) -> some View {
        let selected = selectedRhythm == r.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedRhythm = selected ? nil : r.id
            }
        } label: {
            Text(r.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected ? .white : AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    Capsule().fill(selected ? AppColors.accent : AppColors.textTertiary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    private var readingListBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.75))
                .frame(width: 28, height: 3)
                .padding(.bottom, 2)
            Text("READING LIST")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("The books that shaped how I think about markets, money, and myself. If all you've got right now is the will to learn, start here.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
            ForEach(Self.books) { b in
                bookRow(b)
            }
        }
    }

    private func bookRow(_ b: Book) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(format: "%02d", b.id + 1))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.accent.opacity(0.7))
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(b.author)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
                Text(b.note)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            if b.id != Self.books.last?.id {
                Rectangle().fill(AppColors.textTertiary.opacity(0.12)).frame(height: 0.5)
            }
        }
    }

    private var liveToolsNote: some View {
        Text("You can watch the crowd's mood move in real time, right here: the Cycle Scorecard, Sentiment Regime, and Fear & Greed.")
            .font(.system(size: 11))
            .foregroundColor(AppColors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }
}

// MARK: - Metals Support & Resistance (Market Tab)
/// Dedicated gold + silver support/resistance, built on the same calculator and
/// card as the crypto S/R. Levels come from Yahoo daily futures (GC=F, SI=F) via
/// MetalsKeyLevelsService, since metals have no Coinbase pair.
struct MetalsSupportResistanceSection: View {
    var refreshId: UUID = UUID()
    @Environment(\.colorScheme) private var colorScheme

    @State private var gold: KeyLevels?
    @State private var silver: KeyLevels?
    @State private var isLoading = true
    @State private var lastLoaded: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Metals: Support & Resistance")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text("Where gold and silver have reacted before")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            if isLoading && gold == nil && silver == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if (gold?.hasLevels != true) && (silver?.hasLevels != true) {
                Text("Levels unavailable right now.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                if let g = gold, g.hasLevels {
                    SupportResistanceCard(
                        levels: g,
                        colorScheme: colorScheme,
                        title: "Gold",
                        subtitle: "XAU · where price has reacted before"
                    )
                }
                if let s = silver, s.hasLevels {
                    SupportResistanceCard(
                        levels: s,
                        colorScheme: colorScheme,
                        title: "Silver",
                        subtitle: "XAG · where price has reacted before"
                    )
                }
            }
        }
        .task(id: refreshId) { await load() }
    }

    private func load() async {
        if lastLoaded == refreshId, gold != nil || silver != nil { return }
        isLoading = true
        let g = await MetalsKeyLevelsService.fetch(.gold)
        await MainActor.run { gold = g }
        let s = await MetalsKeyLevelsService.fetch(.silver)
        await MainActor.run {
            silver = s
            lastLoaded = refreshId
            isLoading = false
        }
    }
}
