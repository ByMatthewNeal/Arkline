import SwiftUI

struct ModelPortfolioUpdateCard: View {
    let trade: ModelPortfolioTrade
    let portfolioName: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var changes: [(asset: String, from: Double, to: Double, isIncrease: Bool)] {
        let allAssets = Set(trade.fromAllocation.keys).union(trade.toAllocation.keys)
        return allAssets.compactMap { asset in
            let from = trade.fromAllocation[asset] ?? 0
            let to = trade.toAllocation[asset] ?? 0
            guard abs(from - to) >= 1 else { return nil }
            return (asset: asset, from: from, to: to, isIncrease: to > from)
        }.sorted { $0.asset < $1.asset }
    }

    private var tradeAge: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: trade.tradeDate) else { return trade.tradeDate }

        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0

        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(AppColors.accent)
                Text("Model Portfolio Updates")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }

            // Card
            NavigationLink {
                // Navigate to model portfolio detail — use strategy from trade
                ModelPortfolioNavLink(portfolioName: portfolioName)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(portfolioName)
                            .font(AppFonts.body14Bold)
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text(tradeAge)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // Trigger
                    Text(trade.trigger)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    // Changes (max 4 shown)
                    VStack(spacing: 4) {
                        ForEach(Array(changes.prefix(4)), id: \.asset) { change in
                            HStack(spacing: 6) {
                                Image(systemName: change.isIncrease ? "plus.circle.fill" : "minus.circle.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(change.isIncrease ? AppColors.success : AppColors.error)

                                Text(change.asset)
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(textPrimary)

                                Text("\(change.from, specifier: "%.0f")% → \(change.to, specifier: "%.0f")%")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(change.isIncrease ? AppColors.success : AppColors.error)

                                Spacer()

                                Text("\(change.to, specifier: "%.0f")%")
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    if changes.count > 4 {
                        Text("+\(changes.count - 4) more")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.accent)
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
