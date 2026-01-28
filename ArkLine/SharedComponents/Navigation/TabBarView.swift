import SwiftUI

// MARK: - Tab Item (5 Tabs as per Design)
enum AppTab: String, CaseIterable {
    case home = "Home"
    case market = "Market"
    case portfolio = "Portfolio"
    case insights = "Insights"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .market: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "wallet.pass.fill"
        case .insights: return "antenna.radiowaves.left.and.right"
        case .profile: return "person.fill"
        }
    }

    var unselectedIcon: String {
        switch self {
        case .home: return "house"
        case .market: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "wallet.pass"
        case .insights: return "antenna.radiowaves.left.and.right"
        case .profile: return "person"
        }
    }
}

// MARK: - Custom Tab Bar (Floating Design - Slim)
struct CustomTabBar: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: AppTab
    var badges: [AppTab: Int] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    badge: badges[tab]
                ) {
                    if selectedTab == tab {
                        // Already on this tab - trigger pop to root
                        triggerNavigationReset(for: tab)
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    colorScheme == .dark
                        ? Color(hex: "1A1A1A").opacity(0.95)
                        : Color.white.opacity(0.95)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.05),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.12),
            radius: 12,
            x: 0,
            y: 4
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 0)
    }

    private func triggerNavigationReset(for tab: AppTab) {
        switch tab {
        case .home:
            appState.homeNavigationReset = UUID()
        case .market:
            appState.marketNavigationReset = UUID()
        case .portfolio:
            appState.portfolioNavigationReset = UUID()
        case .insights:
            appState.insightsNavigationReset = UUID()
        case .profile:
            appState.profileNavigationReset = UUID()
        }
    }
}

// MARK: - Tab Bar Item (Icon Only - With Floating Pill)
struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private let activeColor = Color.white  // White icon when selected
    private let inactiveColor = AppColors.textSecondary  // Gray when not selected
    private let pillColor = AppColors.accent  // Blue pill background

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    // Blue pill background for selected tab
                    if isSelected {
                        Capsule()
                            .fill(pillColor)
                            .frame(width: 56, height: 36)
                    }

                    Image(systemName: isSelected ? tab.icon : tab.unselectedIcon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? activeColor : inactiveColor)
                }

                // Badge dot
                if let badge = badge, badge > 0 {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                        .offset(x: 8, y: -2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content based on selected tab
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .market:
                    MarketOverviewView()
                case .portfolio:
                    PortfolioView()
                case .insights:
                    BroadcastTabView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating Tab Bar
            CustomTabBar(selectedTab: $appState.selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .background(AppColors.background(colorScheme))
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(AppState())
}
