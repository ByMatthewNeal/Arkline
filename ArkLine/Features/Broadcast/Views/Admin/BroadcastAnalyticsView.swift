import SwiftUI

// MARK: - Broadcast Analytics View

/// Analytics dashboard for broadcast performance
struct BroadcastAnalyticsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: BroadcastViewModel
    @State private var selectedPeriod: AnalyticsPeriod = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Period selector
                    periodSelector

                    // Summary cards
                    summarySection

                    // Top performing broadcasts
                    topBroadcastsSection

                    // Reaction breakdown
                    reactionBreakdownSection

                    // Recent activity
                    recentActivitySection
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: ArkSpacing.xs) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation { selectedPeriod = period }
                } label: {
                    Text(period.displayName)
                        .font(ArkFonts.caption)
                        .foregroundColor(selectedPeriod == period ? .white : AppColors.textSecondary)
                        .padding(.horizontal, ArkSpacing.md)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(selectedPeriod == period ? AppColors.accent : AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Overview")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ArkSpacing.sm) {
                AnalyticsStatCard(
                    title: "Total Broadcasts",
                    value: "\(viewModel.published.count + viewModel.drafts.count)",
                    icon: "antenna.radiowaves.left.and.right",
                    color: AppColors.accent
                )

                AnalyticsStatCard(
                    title: "Published",
                    value: "\(viewModel.published.count)",
                    icon: "checkmark.circle",
                    color: AppColors.success
                )

                AnalyticsStatCard(
                    title: "Total Reactions",
                    value: "\(totalReactions)",
                    icon: "heart.fill",
                    color: AppColors.error
                )

                AnalyticsStatCard(
                    title: "Avg Reactions",
                    value: String(format: "%.1f", avgReactionsPerBroadcast),
                    icon: "chart.bar.fill",
                    color: AppColors.warning
                )
            }
        }
    }

    // MARK: - Top Broadcasts Section

    private var topBroadcastsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Top Performing")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if topBroadcasts.isEmpty {
                emptyStateCard(message: "No published broadcasts yet")
            } else {
                VStack(spacing: ArkSpacing.xs) {
                    ForEach(Array(topBroadcasts.enumerated()), id: \.element.id) { index, broadcast in
                        TopBroadcastRow(
                            rank: index + 1,
                            broadcast: broadcast
                        )
                    }
                }
                .padding(ArkSpacing.sm)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            }
        }
    }

    // MARK: - Reaction Breakdown Section

    private var reactionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Reaction Breakdown")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: ArkSpacing.sm) {
                ForEach(ReactionEmoji.allCases, id: \.rawValue) { emoji in
                    VStack(spacing: 4) {
                        Text(emoji.rawValue)
                            .font(.title2)

                        Text("\(reactionCount(for: emoji))")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
            }
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Recent Activity")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: ArkSpacing.xs) {
                ForEach(recentActivities, id: \.id) { activity in
                    BroadcastActivityRow(activity: activity)
                }
            }
            .padding(ArkSpacing.sm)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
    }

    // MARK: - Empty State

    private func emptyStateCard(message: String) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)
            Text(message)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.xl)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Computed Properties

    private var totalReactions: Int {
        viewModel.published.compactMap { $0.reactionCount }.reduce(0, +)
    }

    private var avgReactionsPerBroadcast: Double {
        guard !viewModel.published.isEmpty else { return 0 }
        return Double(totalReactions) / Double(viewModel.published.count)
    }

    private var topBroadcasts: [Broadcast] {
        viewModel.published
            .sorted { ($0.reactionCount ?? 0) > ($1.reactionCount ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    private func reactionCount(for emoji: ReactionEmoji) -> Int {
        // This would normally come from aggregated analytics
        // For now, return placeholder
        Int.random(in: 0...50)
    }

    private var recentActivities: [BroadcastActivityItem] {
        // Generate recent activities from broadcasts
        viewModel.published.prefix(5).map { broadcast in
            BroadcastActivityItem(
                id: broadcast.id,
                type: .published,
                title: broadcast.title,
                date: broadcast.publishedAt ?? broadcast.createdAt
            )
        }
    }
}

// MARK: - Analytics Period

enum AnalyticsPeriod: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"
    case allTime = "All"

    var displayName: String { rawValue }
}

// MARK: - Analytics Stat Card

private struct AnalyticsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
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
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Top Broadcast Row

private struct TopBroadcastRow: View {
    let rank: Int
    let broadcast: Broadcast
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 30)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(broadcast.title)
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Text(broadcast.timeAgo)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            // Reaction count
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(AppColors.error)
                Text("\(broadcast.reactionCount ?? 0)")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.vertical, ArkSpacing.xs)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700") // Gold
        case 2: return Color(hex: "C0C0C0") // Silver
        case 3: return Color(hex: "CD7F32") // Bronze
        default: return AppColors.textSecondary
        }
    }
}

// MARK: - Broadcast Activity Item

struct BroadcastActivityItem: Identifiable {
    let id: UUID
    let type: BroadcastActivityType
    let title: String
    let date: Date
}

enum BroadcastActivityType {
    case published
    case reaction
    case view

    var icon: String {
        switch self {
        case .published: return "paperplane.fill"
        case .reaction: return "heart.fill"
        case .view: return "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .published: return AppColors.accent
        case .reaction: return AppColors.error
        case .view: return AppColors.success
        }
    }
}

// MARK: - Broadcast Activity Row

private struct BroadcastActivityRow: View {
    let activity: BroadcastActivityItem
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: activity.type.icon)
                .font(.caption)
                .foregroundColor(activity.type.color)
                .frame(width: 24, height: 24)
                .background(activity.type.color.opacity(0.15))
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Text(activity.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(.vertical, ArkSpacing.xxs)
    }
}

// MARK: - Preview

#Preview {
    BroadcastAnalyticsView(viewModel: BroadcastViewModel())
}
