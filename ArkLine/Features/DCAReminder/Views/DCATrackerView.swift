import SwiftUI

// MARK: - DCA Tracker Dashboard
struct DCATrackerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCATrackerViewModel
    @State private var showAllHistory = false
    @State private var showDeleteConfirmation = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { AppColors.cardBackground(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: ArkSpacing.md) {
                if let plan = viewModel.selectedPlan {
                    // A. Plan Header Card
                    planHeaderCard(plan)

                    // B. Allocation Progress Ring
                    allocationRingCard(plan)

                    // C. Live Portfolio Card
                    portfolioCard(plan)

                    // D. DCA Streak
                    if plan.streakCurrent > 0 || plan.streakBest > 0 {
                        streakCard(plan)
                    }

                    // E. P&L Card
                    if plan.totalCostBasis > 0 {
                        pnlCard(plan)
                    }

                    // F. Log Entry Button
                    logEntryButton(plan)

                    // G. Buy History
                    buyHistorySection

                    // H. Best/Worst Buy
                    bestWorstSection

                    // I. Risk Suggestion
                    riskSuggestionCard(plan)

                    // J. Capital Injection & Delete
                    bottomActionsSection(plan)

                    Spacer(minLength: 100)
                } else if viewModel.isLoading {
                    loadingState
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, ArkSpacing.lg)
            .padding(.top, ArkSpacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $viewModel.showLogEntry) {
            if let plan = viewModel.selectedPlan {
                LogDCAEntrySheet(viewModel: viewModel, plan: plan)
            }
        }
        .sheet(isPresented: $viewModel.showCreatePlan) {
            CreateDCAPlanSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddFunds) {
            addFundsSheet
        }
        .alert("Delete Plan", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let plan = viewModel.selectedPlan {
                    Task { await viewModel.deletePlan(id: plan.id) }
                }
            }
        } message: {
            Text("This will permanently delete this DCA plan and all its entries. This cannot be undone.")
        }
        .onAppear {
            Task { await viewModel.loadPlans() }
        }
    }

    // MARK: - A. Plan Header Card

    private func planHeaderCard(_ plan: DCAPlan) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                HStack(spacing: ArkSpacing.xs) {
                    DCACoinIconView(symbol: plan.assetSymbol, size: 32)

                    Text("\(plan.assetSymbol) Dynamic DCA")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                statusBadge(plan)
            }

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text("Target: \(Int(plan.targetAllocationPct))% \(plan.assetSymbol) / \(Int(plan.cashAllocationPct))% Cash")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.7))

                Text("\(plan.startingCapital.asCurrency) starting capital")
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.5))

                HStack(spacing: ArkSpacing.xxs) {
                    Text("Started \(formattedStartDate(plan.startDate))")
                    Text("--")
                    Text("\(plan.totalWeeks) weeks")
                }
                .font(AppFonts.caption12)
                .foregroundColor(textPrimary.opacity(0.4))
            }
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(cardBg)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    private func statusBadge(_ plan: DCAPlan) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(plan.isActive ? AppColors.success : (plan.isPaused ? AppColors.warning : AppColors.textSecondary))
                .frame(width: 6, height: 6)

            Text(plan.status.capitalized)
                .font(AppFonts.caption12Medium)
                .foregroundColor(plan.isActive ? AppColors.success : (plan.isPaused ? AppColors.warning : AppColors.textSecondary))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((plan.isActive ? AppColors.success : (plan.isPaused ? AppColors.warning : AppColors.textSecondary)).opacity(0.15))
        )
    }

    // MARK: - B. Allocation Progress Ring

    private func allocationRingCard(_ plan: DCAPlan) -> some View {
        let currentPct = viewModel.livePrice > 0 ? plan.currentAllocationPct(price: viewModel.livePrice) : 0
        let gap = abs(plan.targetAllocationPct - currentPct)
        let ringColor: Color = gap <= 5 ? AppColors.success : (gap <= 15 ? AppColors.warning : AppColors.error)

        return VStack(spacing: ArkSpacing.sm) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 10)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(currentPct / 100, 1.0))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Center text
                VStack(spacing: 2) {
                    Text("\(String(format: "%.1f", currentPct))%")
                        .font(AppFonts.number24)
                        .foregroundColor(textPrimary)

                    Text(plan.assetSymbol)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }

            HStack(spacing: ArkSpacing.md) {
                VStack(spacing: 2) {
                    Text("Target")
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.5))
                    Text("\(Int(plan.targetAllocationPct))%")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }

                Rectangle()
                    .fill(AppColors.divider(colorScheme))
                    .frame(width: 1, height: 28)

                VStack(spacing: 2) {
                    Text("Gap")
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.5))
                    Text("\(String(format: "%.1f", gap))%")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(ringColor)
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(cardBg)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    // MARK: - C. Live Portfolio Card

    private func portfolioCard(_ plan: DCAPlan) -> some View {
        let price = viewModel.livePrice
        let btcValue = plan.currentValue(price: price)
        let totalPortfolio = plan.totalPortfolioValue(price: price)
        let stillToBuy = plan.stillToBuy(price: price)
        let recWeekly = plan.recommendedWeeklyDCA(price: price)

        return VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("LIVE PORTFOLIO")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.accent)

            portfolioRow(label: "\(plan.assetSymbol) Held", value: formatQuantity(plan.currentQty, symbol: plan.assetSymbol))
            portfolioRow(label: "\(plan.assetSymbol) Value", value: btcValue.asCurrency)
            portfolioRow(label: "Cash Remaining", value: plan.cashRemaining.asCurrency)

            Divider()
                .background(AppColors.divider(colorScheme))

            portfolioRow(label: "Total Portfolio", value: totalPortfolio.asCurrency, bold: true)

            Divider()
                .background(AppColors.divider(colorScheme))

            portfolioRow(label: "Still to Buy", value: stillToBuy.asCurrency)
            portfolioRow(label: "Rec. Weekly DCA", value: recWeekly.asCurrency)

            if let remaining = plan.weeksRemaining {
                portfolioRow(label: "Weeks Remaining", value: "\(remaining) of \(plan.totalWeeks)")
            }
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(cardBg)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    private func portfolioRow(label: String, value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary.opacity(0.6))
            Spacer()
            Text(value)
                .font(bold ? AppFonts.body14Bold : AppFonts.body14Medium)
                .foregroundColor(textPrimary)
        }
    }

    // MARK: - D. Streak Card

    private func streakCard(_ plan: DCAPlan) -> some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.warning)

            Text("\(plan.streakCurrent) week streak")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            Spacer()

            if plan.streakCurrent < plan.streakBest {
                Text("Best: \(plan.streakBest)")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(textPrimary.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.fillSecondary(colorScheme))
                    )
            }
        }
        .padding(ArkSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                .fill(cardBg)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    // MARK: - E. P&L Card

    private func pnlCard(_ plan: DCAPlan) -> some View {
        let price = viewModel.livePrice
        let pnl = plan.unrealizedPnL(price: price)
        let pnlPct = plan.unrealizedPnLPct(price: price)
        let isPositive = pnl >= 0
        let pnlColor = isPositive ? AppColors.success : AppColors.error

        return VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("TRUE P&L")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.accent)

            portfolioRow(label: "Cost Basis", value: plan.totalCostBasis.asCurrency)
            portfolioRow(label: "Current Value", value: plan.currentValue(price: price).asCurrency)

            Divider()
                .background(AppColors.divider(colorScheme))

            HStack {
                Text("Unrealized P&L")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary.opacity(0.6))
                Spacer()
                Text("\(isPositive ? "+" : "")\(pnl.asCurrency) (\(isPositive ? "+" : "")\(String(format: "%.1f", pnlPct))%)")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(pnlColor)
            }

            portfolioRow(label: "Blended Avg Cost", value: "\(plan.blendedAvgCost.asCurrency)/\(plan.assetSymbol)")
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(cardBg)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    // MARK: - F. Log Entry Button

    private func logEntryButton(_ plan: DCAPlan) -> some View {
        Button {
            viewModel.showLogEntry = true
        } label: {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Log This Week's Buy")
                    .font(AppFonts.body14Bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                    .fill(AppColors.accent)
            )
        }
        .disabled(!plan.isActive)
        .opacity(plan.isActive ? 1 : 0.5)
    }

    // MARK: - G. Buy History

    @ViewBuilder
    private var buyHistorySection: some View {
        let buyEntries = viewModel.completedEntries.filter { !$0.isCapitalInjection }
        let displayEntries = showAllHistory ? buyEntries : Array(buyEntries.prefix(5))

        if !buyEntries.isEmpty {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                HStack {
                    Text("BUY HISTORY")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)

                    Spacer()

                    if buyEntries.count > 5 {
                        Button {
                            withAnimation(.arkSpring) { showAllHistory.toggle() }
                        } label: {
                            Text(showAllHistory ? "Show Less" : "Show All (\(buyEntries.count))")
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }

                ForEach(displayEntries) { entry in
                    buyHistoryRow(entry)
                }
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .fill(cardBg)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
    }

    private func buyHistoryRow(_ entry: DCAEntry) -> some View {
        HStack(spacing: ArkSpacing.xs) {
            Text("Wk \(entry.weekNumber)")
                .font(AppFonts.caption12Medium)
                .foregroundColor(textPrimary.opacity(0.5))
                .frame(width: 40, alignment: .leading)

            Text(formattedEntryDate(entry.entryDate))
                .font(AppFonts.caption12)
                .foregroundColor(textPrimary.opacity(0.5))
                .frame(width: 50, alignment: .leading)

            Text(entry.actualAmount?.asCurrency ?? "--")
                .font(AppFonts.caption12Medium)
                .foregroundColor(textPrimary)

            Spacer()

            if let price = entry.pricePaid {
                Text("@ \(formatPrice(price))")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            if let qty = entry.qtyBought {
                Text(formatSmallQty(qty))
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            // Variance indicator
            if let variance = entry.variance {
                Image(systemName: abs(variance) < 5 ? "checkmark.circle.fill" : (variance > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"))
                    .font(.system(size: 12))
                    .foregroundColor(abs(variance) < 5 ? AppColors.success : (variance > 0 ? AppColors.warning : AppColors.info))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.success)
            }
        }
    }

    // MARK: - H. Best/Worst Buy

    @ViewBuilder
    private var bestWorstSection: some View {
        if viewModel.bestEntry != nil || viewModel.worstEntry != nil {
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                if let best = viewModel.bestEntry, let price = best.pricePaid {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(AppColors.success)
                            .font(.system(size: 14))
                        Text("Best Entry: Wk \(best.weekNumber) -- \(formatPrice(price))/\(viewModel.selectedPlan?.assetSymbol ?? "") (lowest cost)")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(textPrimary.opacity(0.7))
                    }
                }

                if let worst = viewModel.worstEntry, let price = worst.pricePaid {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(AppColors.error)
                            .font(.system(size: 14))
                        Text("Worst Entry: Wk \(worst.weekNumber) -- \(formatPrice(price))/\(viewModel.selectedPlan?.assetSymbol ?? "") (highest cost)")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(textPrimary.opacity(0.7))
                    }
                }
            }
            .padding(ArkSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                    .fill(cardBg)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
    }

    // MARK: - I. Risk Suggestion

    @ViewBuilder
    private func riskSuggestionCard(_ plan: DCAPlan) -> some View {
        // Only show for crypto assets with risk data
        RiskSuggestionView(symbol: plan.assetSymbol)
    }

    // MARK: - J. Bottom Actions

    private func bottomActionsSection(_ plan: DCAPlan) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            // Add Funds button
            Button {
                viewModel.showAddFunds = true
            } label: {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "plus.square.fill")
                        .font(.system(size: 14))
                    Text("Add Funds")
                        .font(AppFonts.body14Medium)
                }
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                        .fill(AppColors.accent.opacity(0.1))
                )
            }

            // Delete plan button
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Delete Plan")
                        .font(AppFonts.caption12Medium)
                }
                .foregroundColor(AppColors.error.opacity(0.7))
            }
            .padding(.top, ArkSpacing.xs)
        }
    }

    // MARK: - Add Funds Sheet

    private var addFundsSheet: some View {
        AddFundsSheet(viewModel: viewModel)
    }

    // MARK: - Empty & Loading States

    private var loadingState: some View {
        VStack(spacing: ArkSpacing.sm) {
            ProgressView()
                .controlSize(.regular)
                .tint(AppColors.accent)
            Text("Loading DCA plans...")
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "chart.line.uptrend.xyaxis.circle",
            title: "No DCA Plans",
            message: "Create a structured DCA plan to start building your position systematically",
            actionTitle: "Create DCA Plan",
            action: { viewModel.showCreatePlan = true }
        )
    }

    // MARK: - Formatting Helpers

    private func formattedStartDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return dateString }
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        display.timeZone = TimeZone(identifier: "America/New_York")
        return display.string(from: date)
    }

    private func formattedEntryDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return dateString }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        display.timeZone = TimeZone(identifier: "America/New_York")
        return display.string(from: date)
    }

    private func formatQuantity(_ qty: Double, symbol: String) -> String {
        if qty >= 1 {
            return String(format: "%.4f %@", qty, symbol)
        } else {
            return String(format: "%.6f %@", qty, symbol)
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return "$\(String(format: "%.0f", price))"
        } else if price >= 1 {
            return "$\(String(format: "%.2f", price))"
        } else {
            return "$\(String(format: "%.4f", price))"
        }
    }

    private func formatSmallQty(_ qty: Double) -> String {
        if qty >= 1 {
            return String(format: "%.4f", qty)
        } else {
            return String(format: "%.5f", qty)
        }
    }
}

// MARK: - Risk Suggestion Sub-View
private struct RiskSuggestionView: View {
    let symbol: String
    @Environment(\.colorScheme) var colorScheme
    @State private var riskLevel: ITCRiskLevel?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        Group {
            if let risk = riskLevel {
                let score = risk.riskLevel
                let isFavorable = score < 0.40
                let isModerate = score >= 0.40 && score < 0.55
                let color: Color = isFavorable ? AppColors.success : (isModerate ? AppColors.warning : AppColors.error)
                let icon = isFavorable ? "lightbulb.fill" : "exclamationmark.triangle.fill"
                let message = isFavorable
                    ? "\(symbol) risk is \(risk.riskCategory) (\(String(format: "%.2f", score))) -- favorable DCA conditions"
                    : "\(symbol) risk is \(risk.riskCategory) (\(String(format: "%.2f", score))) -- consider a smaller buy this week"

                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)

                    Text(message)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(textPrimary.opacity(0.7))
                        .lineLimit(2)
                }
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                        .fill(color.opacity(0.08))
                )
            }
        }
        .task {
            await loadRisk()
        }
    }

    private func loadRisk() async {
        do {
            let riskService = ServiceContainer.shared.itcRiskService
            riskLevel = try await riskService.fetchLatestRiskLevel(coin: symbol)
        } catch {
            // Silently fail - risk suggestion is optional
        }
    }
}

// MARK: - Add Funds Sheet
struct AddFundsSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: DCATrackerViewModel
    @State private var amountString = ""
    @State private var notes = ""

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var amount: Double { Double(amountString.replacingOccurrences(of: ",", with: "")) ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.lg) {
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Injection Amount")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    HStack {
                        Text("$")
                            .font(AppFonts.number24)
                            .foregroundColor(textPrimary.opacity(0.5))

                        TextField("0", text: $amountString)
                            .font(AppFonts.number24)
                            .foregroundColor(textPrimary)
                            .keyboardType(.decimalPad)
                    }
                    .padding(ArkSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                            .fill(AppColors.fillSecondary(colorScheme))
                    )
                }

                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Notes (optional)")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary.opacity(0.7))

                    TextField("e.g. Bonus deposit", text: $notes)
                        .font(AppFonts.body14)
                        .foregroundColor(textPrimary)
                        .padding(ArkSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                                .fill(AppColors.fillSecondary(colorScheme))
                        )
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.addInjection(
                            amount: amount,
                            notes: notes.isEmpty ? nil : notes
                        )
                        dismiss()
                    }
                } label: {
                    Text("Add Funds")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ArkSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                .fill(amount > 0 ? AppColors.accent : AppColors.accent.opacity(0.5))
                        )
                }
                .disabled(amount <= 0)
            }
            .padding(ArkSpacing.lg)
            .navigationTitle("Add Funds")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        DCATrackerView(viewModel: DCATrackerViewModel())
    }
}
