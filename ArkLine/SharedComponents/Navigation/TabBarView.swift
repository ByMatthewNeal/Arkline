import SwiftUI

// MARK: - Tab Item (4 Tabs as per Design Spec)
enum AppTab: String, CaseIterable {
    case home = "Home"
    case market = "Market"
    case portfolio = "Portfolio"
    case community = "Community"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .market: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "wallet.pass.fill"
        case .community: return "person.2.fill"
        }
    }

    var unselectedIcon: String {
        switch self {
        case .home: return "house"
        case .market: return "chart.line.uptrend.xyaxis"
        case .portfolio: return "wallet.pass"
        case .community: return "person.2"
        }
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Environment(\.colorScheme) var colorScheme
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            AppColors.surface(colorScheme)
                .overlay(
                    Rectangle()
                        .fill(AppColors.divider(colorScheme))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    var badge: Int? = nil
    let action: () -> Void

    private let activeColor = AppColors.accent      // #3B69FF
    private let inactiveColor = AppColors.textSecondary  // #888888

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.icon : tab.unselectedIcon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? activeColor : inactiveColor)

                    if let badge = badge, badge > 0 {
                        Circle()
                            .fill(AppColors.error)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }

                Text(tab.rawValue)
                    .font(AppFonts.footnote10)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? activeColor : inactiveColor)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Home Tab
                HomeView()
                    .tag(AppTab.home)

                // Market Tab
                MarketOverviewView()
                    .tag(AppTab.market)

                // Portfolio Tab
                PortfolioView()
                    .tag(AppTab.portfolio)

                // Community Tab
                CommunityView()
                    .tag(AppTab.community)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            CustomTabBar(selectedTab: $selectedTab)
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
