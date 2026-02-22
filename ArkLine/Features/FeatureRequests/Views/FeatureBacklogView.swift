import SwiftUI

// MARK: - Feature Backlog View (Admin)

/// Admin dashboard for managing feature requests
struct FeatureBacklogView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = FeatureRequestViewModel()
    @State private var selectedRequest: FeatureRequest?
    @State private var showingDetail = false

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Stats Cards
                    statsSection

                    // Filter Tabs
                    filterTabs

                    // Request List
                    requestList
                }
                .padding(ArkSpacing.lg)
            }
        }
        .navigationTitle("Feature Backlog")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await viewModel.loadRequests()
        }
        .refreshable {
            await viewModel.loadRequests()
        }
        .sheet(item: $selectedRequest) { request in
            NavigationStack {
                FeatureRequestDetailView(
                    request: request,
                    viewModel: viewModel,
                    onDismiss: { selectedRequest = nil }
                )
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ArkSpacing.sm) {
            StatCard(
                title: "Total",
                value: "\(viewModel.totalCount)",
                icon: "tray.full.fill",
                color: AppColors.accent
            )

            StatCard(
                title: "Pending",
                value: "\(viewModel.pendingCount)",
                icon: "clock.fill",
                color: Color(hex: FeatureStatus.pending.color)
            )

            StatCard(
                title: "Approved",
                value: "\(viewModel.approvedCount)",
                icon: "checkmark.circle.fill",
                color: Color(hex: FeatureStatus.approved.color)
            )

            StatCard(
                title: "Implemented",
                value: "\(viewModel.implementedCount)",
                icon: "checkmark.seal.fill",
                color: Color(hex: FeatureStatus.implemented.color)
            )
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ArkSpacing.xs) {
                FilterChipButton(
                    title: "All",
                    isSelected: viewModel.selectedFilter == nil,
                    action: { viewModel.selectedFilter = nil }
                )

                ForEach(FeatureStatus.allCases, id: \.self) { status in
                    FilterChipButton(
                        title: status.displayName,
                        isSelected: viewModel.selectedFilter == status,
                        action: { viewModel.selectedFilter = status }
                    )
                }
            }
            .padding(.horizontal, ArkSpacing.xs)
        }
    }

    // MARK: - Request List

    private var requestList: some View {
        VStack(spacing: ArkSpacing.sm) {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 40)
            } else if viewModel.filteredRequests.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredRequests) { request in
                    FeatureRequestCard(request: request) {
                        selectedRequest = request
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)

            Text("No requests found")
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)

            if viewModel.selectedFilter != nil {
                Text("Try selecting a different filter")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.top, 40)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(title)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.md)
    }
}

// MARK: - Filter Chip Button

private struct FilterChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ArkFonts.caption)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.xs)
                .background(isSelected ? AppColors.accent : AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Request Card

struct FeatureRequestCard: View {
    let request: FeatureRequest
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                // Header
                HStack {
                    // Category Badge
                    HStack(spacing: 4) {
                        Image(systemName: request.category.icon)
                            .font(.system(size: 10))
                        Text(request.category.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(4)

                    Spacer()

                    // Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: request.status.icon)
                            .font(.system(size: 10))
                        Text(request.status.displayName)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color(hex: request.status.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: request.status.color).opacity(0.15))
                    .cornerRadius(4)
                }

                // Title
                Text(request.title)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description Preview
                Text(request.description)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Footer
                HStack {
                    // Priority
                    if let priority = request.priority {
                        HStack(spacing: 4) {
                            Image(systemName: priority.icon)
                                .font(.system(size: 10))
                            Text(priority.displayName)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(Color(hex: priority.color))
                    }

                    Spacer()

                    // Time ago
                    Text(request.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeatureBacklogView()
            .environmentObject(AppState())
    }
}
