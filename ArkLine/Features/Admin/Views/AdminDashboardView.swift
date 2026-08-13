import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var memberCount: Int?
    @State private var healthSummary: String?

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            List {
                // Quick Actions
                Section {
                    NavigationLink(destination: CompMemberView()) {
                        AdminDashboardRow(
                            icon: "gift.fill",
                            iconColor: AppColors.success,
                            title: "Comp a Member",
                            subtitle: "Grant free access by email"
                        )
                    }

                    NavigationLink(destination: AdminQuickShareView()) {
                        AdminDashboardRow(
                            icon: "qrcode",
                            iconColor: AppColors.accent,
                            title: "Quick Share",
                            subtitle: "Share payment link & QR code"
                        )
                    }
                } header: {
                    Text("Quick Actions")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Monitoring
                Section {
                    NavigationLink(destination: APIHealthView()) {
                        AdminDashboardRow(
                            icon: "antenna.radiowaves.left.and.right",
                            iconColor: AppColors.success,
                            title: "System Health",
                            subtitle: healthSummary ?? "APIs, data freshness & cron jobs"
                        )
                    }

                    NavigationLink(destination: OperatingCostsView()) {
                        AdminDashboardRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: AppColors.warning,
                            title: "Operating Costs",
                            subtitle: "Monthly & annual overhead"
                        )
                    }
                } header: {
                    Text("Monitoring")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Management
                Section {
                    NavigationLink(destination: FeatureBacklogView()) {
                        AdminDashboardRow(
                            icon: "lightbulb.fill",
                            iconColor: AppColors.warning,
                            title: "Feature Backlog",
                            subtitle: "Review feature requests"
                        )
                    }

                    NavigationLink(destination: MemberManagementView()) {
                        AdminDashboardRow(
                            icon: "person.2.fill",
                            iconColor: AppColors.info,
                            title: "Members",
                            subtitle: memberCount.map { "\($0) member\($0 == 1 ? "" : "s")" } ?? "View & manage members"
                        )
                    }

                    NavigationLink(destination: RevenueDashboardView()) {
                        AdminDashboardRow(
                            icon: "chart.bar.fill",
                            iconColor: AppColors.success,
                            title: "Revenue",
                            subtitle: "MRR, ARR & metrics"
                        )
                    }

                    NavigationLink(destination: PortfolioTargetsAdminView()) {
                        AdminDashboardRow(
                            icon: "chart.pie.fill",
                            iconColor: AppColors.success,
                            title: "Portfolio Positions",
                            subtitle: "Update equity model portfolio allocations"
                        )
                    }

                    NavigationLink(destination: ResearchNotesAdminView()) {
                        AdminDashboardRow(
                            icon: "doc.text.magnifyingglass",
                            iconColor: AppColors.info,
                            title: "Research Notes",
                            subtitle: "Generate, review & publish position research"
                        )
                    }

                    NavigationLink(destination: MarketDeckAdminView()) {
                        AdminDashboardRow(
                            icon: "doc.richtext",
                            iconColor: AppColors.accent,
                            title: "Weekly Market Deck",
                            subtitle: "Generate & publish weekly updates"
                        )
                    }

                    NavigationLink(destination: AdminDictionaryView()) {
                        AdminDashboardRow(
                            icon: "character.book.closed",
                            iconColor: .purple,
                            title: "Dictionary",
                            subtitle: "Manage glossary terms"
                        )
                    }

                    NavigationLink(destination: TrailAdminView()) {
                        AdminDashboardRow(
                            icon: "signpost.right.fill",
                            iconColor: AppColors.accent,
                            title: "Trail Lessons",
                            subtitle: "Edit Foundations & Crypto lessons"
                        )
                    }
                } header: {
                    Text("Management")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 60)
            }
        }
        .navigationTitle("Admin Panel")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await loadQuickStats()
        }
    }

    private func loadQuickStats() async {
        // Member count — use the same source as the Revenue screen so the two
        // agree: get-admin-metrics counts REAL external members (it excludes the
        // founder's own logins, test accounts and the Apple reviewer). Counting
        // raw profile rows here previously showed everyone.
        if let metrics = try? await AdminService().fetchMetrics() {
            await MainActor.run { memberCount = metrics.totalMembers }
        }

        // Health summary (quick check)
        let results = await APIHealthService.shared.runAllChecks()
        let healthy = results.filter { $0.status == .healthy }.count
        let total = results.count
        let down = results.filter { $0.status == .down }.count
        await MainActor.run {
            if down > 0 {
                healthSummary = "\(healthy)/\(total) healthy, \(down) down"
            } else {
                healthSummary = "\(healthy)/\(total) systems healthy"
            }
        }
    }
}

// MARK: - Dashboard Row

struct AdminDashboardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.vertical, ArkSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        AdminDashboardView()
            .environmentObject(AppState())
    }
}
