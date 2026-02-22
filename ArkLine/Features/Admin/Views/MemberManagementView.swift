import SwiftUI

struct MemberManagementView: View {
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
                    // Stats header
                    if let metrics = viewModel.metrics {
                        statsSection(metrics)
                    }

                    // Search
                    SearchBar(text: $viewModel.searchText, placeholder: "Search members...")
                        .padding(.horizontal, ArkSpacing.lg)

                    // Filter pills
                    filterPills

                    // Member list
                    memberList
                }
                .padding(.vertical, ArkSpacing.lg)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.loadMembers()
                await viewModel.loadMetrics()
            }
        }
        .navigationTitle("Members")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await viewModel.loadMembers()
            await viewModel.loadMetrics()
        }
        .onChange(of: viewModel.statusFilter) { _, _ in
            Task { await viewModel.loadMembers() }
        }
        .overlay {
            if let success = viewModel.successMessage {
                VStack {
                    Spacer()
                    Text(success)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ArkSpacing.lg)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(AppColors.success)
                        .cornerRadius(ArkSpacing.Radius.sm)
                        .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        viewModel.clearSuccess()
                    }
                }
            }
        }
    }

    // MARK: - Stats Section

    private func statsSection(_ metrics: AdminMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ArkSpacing.sm) {
            MetricCard(title: "Total", value: "\(metrics.totalMembers)", icon: "person.2.fill", color: AppColors.accent)
            MetricCard(title: "Active", value: "\(metrics.activeMembers)", icon: "checkmark.circle.fill", color: AppColors.success)
            MetricCard(title: "Trialing", value: "\(metrics.trialingMembers)", icon: "clock.fill", color: AppColors.info)
            MetricCard(title: "Churned", value: "\(metrics.canceledMembers)", icon: "xmark.circle.fill", color: AppColors.error)
        }
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ArkSpacing.xs) {
                ForEach(MemberManagementViewModel.MemberStatusFilter.allCases, id: \.self) { filter in
                    Button {
                        viewModel.statusFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(
                                viewModel.statusFilter == filter
                                ? .white
                                : AppColors.textSecondary
                            )
                            .padding(.horizontal, ArkSpacing.md)
                            .padding(.vertical, ArkSpacing.xs)
                            .background(
                                viewModel.statusFilter == filter
                                ? AppColors.accent
                                : AppColors.cardBackground(colorScheme)
                            )
                            .cornerRadius(ArkSpacing.Radius.full)
                    }
                }
            }
            .padding(.horizontal, ArkSpacing.lg)
        }
    }

    // MARK: - Member List

    private var memberList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView()
                    .padding(.top, ArkSpacing.xxl)
            } else if viewModel.filteredMembers.isEmpty {
                VStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No members found")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, ArkSpacing.xxl)
            } else {
                ForEach(viewModel.filteredMembers) { member in
                    NavigationLink(destination: MemberDetailView(member: member, viewModel: viewModel)) {
                        MemberRow(member: member)
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.xs)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MemberManagementView()
            .environmentObject(AppState())
    }
}
