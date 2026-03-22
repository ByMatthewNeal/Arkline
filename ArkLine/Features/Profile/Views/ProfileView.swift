import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = ProfileViewModel()
    @State private var showReferral = false

    @State private var showEditProfile = false
    @State private var navigationPath = NavigationPath()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()

                // Content
                ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 0).id("scrollTop")
                    // Profile Header
                    ProfileHeader(viewModel: viewModel, onEditTap: { showEditProfile = true })

                    // Quick Actions
                    ProfileQuickActions(
                        onReferral: { showReferral = true },
                        onPortfolio: { appState.selectedTab = .portfolio }
                    )
                    .padding(.horizontal, 20)

                    // Admin Section (only for admins)
                    if appState.currentUser?.isAdmin == true {
                        NavigationLink(destination: AdminDashboardView()) {
                            AdminPanelCard()
                        }
                        .padding(.horizontal, 20)
                    }

                    // Stats
                    ProfileStats(
                        stats: viewModel.stats,
                        onDCATap: { navigationPath.append("dcaList") },
                        onPortfoliosTap: { appState.selectedTab = .portfolio }
                    )
                        .padding(.horizontal, 20)

                    // Portfolio Allocation
                    ProfileAllocationSection(allocations: viewModel.allocations)
                        .padding(.horizontal, 20)

                    // Recent Activity
                    ProfileRecentActivity(activities: viewModel.recentActivity)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
                .onChange(of: appState.profileNavigationReset) { _, _ in
                    navigationPath = NavigationPath()
                    withAnimation(.arkSpring) {
                        scrollProxy.scrollTo("scrollTop", anchor: .top)
                    }
                }
            } // ScrollViewReader
            }
            .navigationDestination(for: String.self) { route in
                if route == "dcaList" {
                    DCAListView()
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
            .sheet(isPresented: $showReferral) {
                ReferFriendView(viewModel: viewModel)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(user: viewModel.user) { updatedUser in
                    viewModel.user = updatedUser
                    appState.setAuthenticated(true, user: updatedUser)
                }
            }
            .onChange(of: appState.pendingDCAReminderId) { _, newId in
                if newId != nil {
                    navigationPath.append("dcaList")
                    appState.pendingDCAReminderId = nil
                }
            }
            .onAppear {
                // Handle pending DCA deep link
                if appState.pendingDCAReminderId != nil {
                    navigationPath.append("dcaList")
                    appState.pendingDCAReminderId = nil
                }
                // Use the actual user from AppState if available
                if let currentUser = appState.currentUser {
                    viewModel.user = currentUser
                }
                Task {
                    await appState.refreshUserProfile()
                    // Update viewModel after refresh
                    if let updatedUser = appState.currentUser {
                        viewModel.user = updatedUser
                    }
                    await viewModel.refresh()
                }
                Task { await AnalyticsService.shared.trackScreenView("profile") }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
