import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = ProfileViewModel()
    @State private var showReferral = false
    @State private var showPortfolio = false

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
                ScrollView {
                    VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeader(viewModel: viewModel, onEditTap: { showEditProfile = true })

                    // Quick Actions
                    ProfileQuickActions(
                        onReferral: { showReferral = true },
                        onPortfolio: { showPortfolio = true }
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
                    ProfileStats(stats: viewModel.stats)
                        .padding(.horizontal, 20)

                    // Recent Activity
                    ProfileRecentActivity(activities: viewModel.recentActivity)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
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
            .sheet(isPresented: $showPortfolio) {
                PortfolioSheetView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(user: viewModel.user) { updatedUser in
                    viewModel.user = updatedUser
                    appState.setAuthenticated(true, user: updatedUser)
                }
            }
            .onChange(of: appState.profileNavigationReset) { _, _ in
                navigationPath = NavigationPath()
            }
            .onAppear {
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
