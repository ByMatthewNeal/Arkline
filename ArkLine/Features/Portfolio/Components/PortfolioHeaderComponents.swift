import SwiftUI

// MARK: - Portfolio Header
struct PortfolioHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    let totalValue: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let profitLoss: Double
    let profitLossPercentage: Double

    private var currency: String {
        appState.preferredCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Value")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Text(totalValue.asCurrency(code: currency))
                .font(AppFonts.number44)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: 16) {
                // Day Change
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text("\(dayChange >= 0 ? "+" : "")\(dayChange.asCurrency(code: currency))")
                            .font(AppFonts.body14Medium)
                        Text("(\(dayChangePercentage >= 0 ? "+" : "")\(dayChangePercentage, specifier: "%.2f")%)")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(dayChange >= 0 ? AppColors.success : AppColors.error)
                }

                Divider().frame(height: 30)

                // Total P/L
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Time")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: profitLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text("\(profitLoss >= 0 ? "+" : "")\(profitLoss.asCurrency(code: currency))")
                            .font(AppFonts.body14Medium)
                        Text("(\(profitLossPercentage >= 0 ? "+" : "")\(profitLossPercentage, specifier: "%.2f")%)")
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(profitLoss >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tab Selector
struct PortfolioTabSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTab: PortfolioTab

    var body: some View {
        HStack(spacing: 0) {
            // Left chevron hint
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                .padding(.leading, 8)
                .padding(.trailing, 2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(PortfolioTab.allCases, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                withAnimation {
                                    proxy.scrollTo(tab, anchor: .center)
                                }
                            }) {
                                Text(tab.rawValue)
                                    .font(AppFonts.caption12Medium)
                                    .foregroundColor(selectedTab == tab ? .white : AppColors.textSecondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? AppColors.accent : Color.clear)
                                    .cornerRadius(20)
                            }
                            .id(tab)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Right chevron hint
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                .padding(.leading, 2)
                .padding(.trailing, 8)
        }
        .glassCard(cornerRadius: 24)
    }
}
