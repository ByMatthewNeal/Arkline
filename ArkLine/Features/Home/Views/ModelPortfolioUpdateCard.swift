import SwiftUI

/// Home widget for the model portfolios — the user's window into "what is the
/// strategy doing right now."
///
/// Two modes, chosen automatically:
/// - **Change alert** (a rebalance happened in the last 3 days): leads with the
///   trigger ("BTC neutral → bullish") and the weight deltas, like the alert a
///   member would see in a trading desk channel.
/// - **Current positioning** (no recent trade): a stacked allocation bar with
///   per-asset weights plus the strategy's signal chips, so the card always
///   answers "where does the strategy stand" instead of disappearing.
///
/// The header menu picks which strategy to display — it IS the app's single
/// "Track" preference (same one the detail view's Track button sets), so
/// rebalance push notifications follow the choice automatically.
struct ModelPortfolioUpdateCard: View {
    let trade: ModelPortfolioTrade?
    let nav: ModelPortfolioNav?
    let portfolioName: String
    let portfolios: [ModelPortfolio]
    let followedStrategy: String?
    let onSelectStrategy: (String) -> Void

    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    // MARK: - Trade helpers

    private var changes: [(asset: String, from: Double, to: Double, isIncrease: Bool)] {
        guard let trade else { return [] }
        let allAssets = Set(trade.fromAllocation.keys).union(trade.toAllocation.keys)
        return allAssets.compactMap { asset in
            let from = trade.fromAllocation[asset] ?? 0
            let to = trade.toAllocation[asset] ?? 0
            guard abs(from - to) >= 1 else { return nil }
            return (asset: asset, from: from, to: to, isIncrease: to > from)
        }.sorted { $0.asset < $1.asset }
    }

    private func tradeDateParsed(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    private var tradeAgeDays: Int? {
        guard let trade, let date = tradeDateParsed(trade.tradeDate) else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day
    }

    /// A rebalance in the last 3 days leads the card; older ones become a footnote
    private var isRecentTrade: Bool {
        guard let days = tradeAgeDays else { return false }
        return days <= 3
    }

    private var tradeAge: String {
        guard let days = tradeAgeDays else { return trade?.tradeDate ?? "" }
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    // MARK: - Allocation helpers

    /// Current allocation sorted by weight, stables/gold labeled like a human would
    private var currentAllocations: [(asset: String, pct: Double)] {
        guard let nav else { return [] }
        return nav.allocations
            .map { (asset: displayName(for: $0.key), pct: $0.value.pct) }
            .filter { $0.pct >= 0.5 }
            .sorted { $0.pct > $1.pct }
    }

    private func displayName(for asset: String) -> String {
        switch asset.uppercased() {
        case "USDC", "USDT": return "Cash"
        case "PAXG": return "Gold"
        default: return asset.uppercased()
        }
    }

    private func allocationColor(for asset: String) -> Color {
        switch asset.uppercased() {
        case "BTC": return Color(hex: "F7931A")
        case "ETH": return Color(hex: "8A92B2")
        case "SOL": return Color(hex: "9945FF")
        case "CASH": return Color(hex: "4CAF50").opacity(0.7)
        case "GOLD": return Color(hex: "FFD700").opacity(0.85)
        default: return AppColors.accent
        }
    }

    private func signalColor(_ signal: String?) -> Color {
        switch signal?.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        default: return AppColors.warning
        }
    }

    private var menuLabel: String {
        portfolioName.replacingOccurrences(of: "Arkline ", with: "")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with strategy picker
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(AppColors.accent)
                Text("Model Portfolio")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                if portfolios.count > 1 {
                    Menu {
                        Section("Track a strategy") {
                            ForEach(portfolios) { portfolio in
                                Button {
                                    onSelectStrategy(portfolio.strategy)
                                } label: {
                                    if portfolio.strategy == followedStrategy {
                                        Label(portfolio.name, systemImage: "checkmark")
                                    } else {
                                        Text(portfolio.name)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(menuLabel)
                                .font(AppFonts.caption12Medium)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }

            // Card body
            NavigationLink {
                ModelPortfolioNavLink(portfolioName: portfolioName)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(portfolioName)
                            .font(AppFonts.body14Bold)
                            .foregroundColor(textPrimary)
                        Spacer()
                        if isRecentTrade {
                            Text("Rebalanced \(tradeAge.lowercased())")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.accent)
                        } else if let nav {
                            Text("As of \(nav.navDate)")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    if isRecentTrade, let trade {
                        changeAlertContent(trade)
                    }

                    // Current positioning — always shown when available
                    if !currentAllocations.isEmpty {
                        allocationBar
                        allocationLegend
                    }

                    // Signal chips
                    if let nav {
                        signalChips(nav)
                    }

                    // Older rebalance becomes a footnote instead of vanishing
                    if !isRecentTrade, let trade {
                        Text("Last rebalance \(tradeAge.lowercased()): \(trade.trigger)")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }

                    // View details hint
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("View strategy")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Change Alert Mode

    @ViewBuilder
    private func changeAlertContent(_ trade: ModelPortfolioTrade) -> some View {
        Text(trade.trigger)
            .font(AppFonts.caption12Medium)
            .foregroundColor(textPrimary.opacity(0.85))

        VStack(spacing: 4) {
            ForEach(Array(changes.prefix(4)), id: \.asset) { change in
                HStack(spacing: 6) {
                    Image(systemName: change.isIncrease ? "plus.circle.fill" : "minus.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(change.isIncrease ? AppColors.success : AppColors.error)

                    Text(displayName(for: change.asset))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(textPrimary)

                    Text("\(change.from, specifier: "%.0f")% → \(change.to, specifier: "%.0f")%")
                        .font(AppFonts.caption12)
                        .foregroundColor(change.isIncrease ? AppColors.success : AppColors.error)

                    Spacer()
                }
            }
        }

        if changes.count > 4 {
            Text("+\(changes.count - 4) more")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - Current Positioning Mode

    private var allocationBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(currentAllocations, id: \.asset) { item in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(allocationColor(for: item.asset))
                        .frame(width: max(4, geo.size.width * item.pct / 100))
                }
            }
        }
        .frame(height: 8)
    }

    private var allocationLegend: some View {
        HStack(spacing: 10) {
            ForEach(currentAllocations.prefix(5), id: \.asset) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(allocationColor(for: item.asset))
                        .frame(width: 6, height: 6)
                    Text("\(item.asset) \(item.pct, specifier: "%.0f")%")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func signalChips(_ nav: ModelPortfolioNav) -> some View {
        HStack(spacing: 6) {
            if let btcSignal = nav.btcSignal {
                signalChip(label: "BTC", value: btcSignal.capitalized, color: signalColor(btcSignal))
            }
            if let regime = nav.macroRegime {
                signalChip(label: nil, value: regime, color: regime.lowercased().contains("risk-on") ? AppColors.success : AppColors.error)
            }
            Spacer(minLength: 0)
        }
    }

    private func signalChip(label: String?, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

/// Navigation helper — resolves model portfolio by name and navigates to its detail view
private struct ModelPortfolioNavLink: View {
    let portfolioName: String
    @State private var portfolio: ModelPortfolio?
    @State private var viewModel = ModelPortfolioViewModel()

    var body: some View {
        Group {
            if let portfolio {
                ModelPortfolioDetailView(portfolio: portfolio, viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        do {
                            let portfolios = try await ServiceContainer.shared.modelPortfolioService.fetchPortfolios()
                            portfolio = portfolios.first { $0.name == portfolioName }
                        } catch {}
                    }
            }
        }
    }
}
