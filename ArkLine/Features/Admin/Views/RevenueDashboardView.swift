import SwiftUI

struct RevenueDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = MemberManagementViewModel()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    if viewModel.isLoadingMetrics {
                        ProgressView()
                            .padding(.top, ArkSpacing.xxl)
                    } else if let metrics = viewModel.metrics {
                        metricsGrid(metrics)
                    } else if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.error)
                            .padding(.top, ArkSpacing.xxl)
                    }
                }
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.loadMetrics()
            }
        }
        .navigationTitle("Revenue")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await viewModel.loadMetrics()
        }
    }

    private func metricsGrid(_ metrics: AdminMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ArkSpacing.sm) {
            MetricCard(
                title: "MRR",
                value: formatCurrency(metrics.mrr),
                icon: "dollarsign.circle.fill",
                color: AppColors.success
            )
            MetricCard(
                title: "ARR",
                value: formatCurrency(metrics.arr),
                icon: "chart.line.uptrend.xyaxis",
                color: AppColors.accent
            )
            MetricCard(
                title: "Active Members",
                value: "\(metrics.activeMembers)",
                icon: "person.fill.checkmark",
                color: AppColors.success
            )
            MetricCard(
                title: "Churn Rate",
                value: String(format: "%.1f%%", metrics.churnRate),
                icon: "arrow.down.right",
                color: metrics.churnRate > 5 ? AppColors.error : AppColors.warning
            )
            MetricCard(
                title: "Founding Members",
                value: "\(metrics.foundingMembers)",
                icon: "crown.fill",
                color: AppColors.warning
            )
            MetricCard(
                title: "Trialing",
                value: "\(metrics.trialingMembers)",
                icon: "clock.fill",
                color: AppColors.info
            )
            MetricCard(
                title: "Past Due",
                value: "\(metrics.pastDueMembers)",
                icon: "exclamationmark.triangle.fill",
                color: AppColors.warning
            )
            MetricCard(
                title: "Total Members",
                value: "\(metrics.totalMembers)",
                icon: "person.2.fill",
                color: AppColors.accent
            )
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.1fk", value / 1000)
        }
        return String(format: "$%.0f", value)
    }
}

#Preview {
    NavigationStack {
        RevenueDashboardView()
            .environmentObject(AppState())
    }
}
