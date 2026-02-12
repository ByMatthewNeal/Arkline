import SwiftUI
import Kingfisher

// MARK: - Broadcast Studio View

/// Admin-only view for creating, editing, and publishing broadcasts.
/// This is the main dashboard for the Broadcast Studio feature.
struct BroadcastStudioView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = BroadcastViewModel()

    @State private var showingEditor = false
    @State private var showingAnalytics = false
    @State private var selectedBroadcast: Broadcast?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Header
                    headerSection

                    // Quick Stats
                    statsSection

                    // Scheduled Section
                    if !scheduledBroadcasts.isEmpty {
                        broadcastSection(title: "Scheduled", broadcasts: scheduledBroadcasts, icon: "clock.fill", color: AppColors.warning)
                    }

                    // Drafts Section
                    if !viewModel.drafts.isEmpty {
                        broadcastSection(title: "Drafts", broadcasts: viewModel.drafts.filter { $0.status != .scheduled })
                    }

                    // Published Section
                    if !viewModel.published.isEmpty {
                        broadcastSection(title: "Published", broadcasts: viewModel.published)
                    }

                    // Empty State
                    if viewModel.drafts.isEmpty && viewModel.published.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Broadcast Studio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppColors.accent)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedBroadcast = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .refreshable {
                await viewModel.loadBroadcasts()
            }
            .sheet(isPresented: $showingEditor) {
                BroadcastEditorView(broadcast: selectedBroadcast, viewModel: viewModel)
            }
            .sheet(isPresented: $showingAnalytics) {
                BroadcastAnalyticsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadBroadcasts()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Welcome, \(appState.currentUser?.firstName ?? "Admin")")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Create and publish market insights to your users")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ArkSpacing.md)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: ArkSpacing.sm) {
            BroadcastStatCard(
                title: "Drafts",
                value: "\(viewModel.drafts.filter { $0.status != .scheduled }.count)",
                icon: "doc",
                color: AppColors.textSecondary
            )

            BroadcastStatCard(
                title: "Scheduled",
                value: "\(scheduledBroadcasts.count)",
                icon: "clock",
                color: AppColors.warning
            )

            BroadcastStatCard(
                title: "Published",
                value: "\(viewModel.published.count)",
                icon: "checkmark.circle",
                color: AppColors.success
            )
        }
    }

    // MARK: - Computed Properties

    private var scheduledBroadcasts: [Broadcast] {
        viewModel.drafts.filter { $0.status == .scheduled }
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
    }

    // MARK: - Broadcast Section

    private func broadcastSection(
        title: String,
        broadcasts: [Broadcast],
        icon: String? = nil,
        color: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color ?? AppColors.textSecondary)
                }
                Text(title)
                    .font(ArkFonts.subheadline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(broadcasts.count)")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            ForEach(broadcasts) { broadcast in
                BroadcastRowView(
                    broadcast: broadcast,
                    onTap: {
                        selectedBroadcast = broadcast
                        showingEditor = true
                    },
                    onPublish: broadcast.status == .draft || broadcast.status == .scheduled ? {
                        Task {
                            try? await viewModel.publishBroadcast(broadcast)
                        }
                    } : nil,
                    onDelete: {
                        Task {
                            try? await viewModel.deleteBroadcast(broadcast)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No Broadcasts Yet")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Tap the + button to create your first broadcast")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingEditor = true
            } label: {
                Text("Create Broadcast")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(ArkSpacing.sm)
            }
        }
        .padding(.vertical, ArkSpacing.xxl)
    }
}

// MARK: - Preview

#Preview {
    BroadcastStudioView()
        .environmentObject(AppState())
}
