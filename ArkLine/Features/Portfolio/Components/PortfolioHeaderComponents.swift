import SwiftUI

// MARK: - Portfolio Header
struct PortfolioHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    /// Same privacy toggle as the Home hero — hiding your balance in one place
    /// must hide it everywhere.
    @AppStorage(Constants.UserDefaults.portfolioHidden) private var isHidden = false
    /// Presentation Mode: hide money, keep growth percentages — for showing others.
    @AppStorage(PresentationDefaults.enabled) private var presentationMode = false
    @AppStorage(PresentationDefaults.hideQuantities) private var presentationHideQuantities = false
    let totalValue: Double
    let dayChange: Double
    let dayChangePercentage: Double
    let profitLoss: Double
    let profitLossPercentage: Double

    private var currency: String {
        appState.preferredCurrency
    }

    private var privacy: PrivacyState {
        PrivacyState(fullyHidden: isHidden, presentation: presentationMode, hideQuantities: presentationHideQuantities)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Total Value")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isHidden.toggle() }
                }) {
                    Image(systemName: isHidden ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityLabel(isHidden ? "Show balance" : "Hide balance")

                // Presentation Mode: masks money, keeps growth percentages — for
                // handing your phone to someone without revealing account size.
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { presentationMode.toggle() }
                }) {
                    Image(systemName: "percent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(presentationMode ? AppColors.accent : AppColors.textSecondary)
                }
                .accessibilityLabel(presentationMode ? "Turn off presentation mode" : "Presentation mode: show growth, hide amounts")
            }

            Text(privacy.currency(totalValue, code: currency))
                .font(AppFonts.number44)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .contentTransition(.numericText())

            HStack(spacing: 16) {
                // Day Change
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text(privacy.signedCurrency(dayChange, code: currency))
                            .font(AppFonts.body14Medium)
                            .contentTransition(.numericText())
                        if !privacy.maskPercent {
                            Text("(\(dayChangePercentage >= 0 ? "+" : "")\(dayChangePercentage, specifier: "%.2f")%)")
                                .font(AppFonts.caption12)
                                .contentTransition(.numericText())
                        }
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
                        Text(privacy.signedCurrency(profitLoss, code: currency))
                            .font(AppFonts.body14Medium)
                            .contentTransition(.numericText())
                        if !privacy.maskPercent {
                            Text("(\(profitLossPercentage >= 0 ? "+" : "")\(profitLossPercentage, specifier: "%.2f")%)")
                                .font(AppFonts.caption12)
                                .contentTransition(.numericText())
                        }
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
