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
                    NavigationLink(destination: SendInviteView()) {
                        AdminDashboardRow(
                            icon: "paperplane.fill",
                            iconColor: AppColors.success,
                            title: "Send Invite",
                            subtitle: "Payment or comped invite"
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
                } header: {
                    Text("Monitoring")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Management
                Section {
                    NavigationLink(destination: InviteCodeManagementView()) {
                        AdminDashboardRow(
                            icon: "ticket.fill",
                            iconColor: AppColors.accent,
                            title: "Invite Codes",
                            subtitle: "Generate & manage codes"
                        )
                    }

                    NavigationLink(destination: FeatureBacklogView()) {
                        AdminDashboardRow(
                            icon: "lightbulb.fill",
                            iconColor: AppColors.warning,
                            title: "Feature Backlog",
                            subtitle: "Review feature requests"
                        )
                    }

                    NavigationLink(destination: EarlyAccessSignupsView()) {
                        AdminDashboardRow(
                            icon: "envelope.fill",
                            iconColor: AppColors.accent,
                            title: "Early Access",
                            subtitle: "Website signups"
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
        // Member count
        if SupabaseManager.shared.isConfigured {
            let count: [[String: Int]]? = try? await SupabaseManager.shared.client
                .from("profiles")
                .select("id", head: false, count: .exact)
                .limit(0)
                .execute()
                .value
            // Use the count header instead
            if let rows: [[String: String]] = try? await SupabaseManager.shared.client
                .from("profiles")
                .select("id")
                .execute()
                .value {
                await MainActor.run { memberCount = rows.count }
            }
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
