import SwiftUI

// MARK: - Stat Card

struct BroadcastStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(ArkFonts.title2)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Broadcast Row View

struct BroadcastRowView: View {
    let broadcast: Broadcast
    let onTap: () -> Void
    var onPublish: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ArkSpacing.md) {
                // Status indicator
                Circle()
                    .fill(broadcast.status.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(broadcast.title.isEmpty ? "Untitled" : broadcast.title)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1)

                    HStack(spacing: ArkSpacing.xs) {
                        if broadcast.status == .published, let publishedAt = broadcast.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\u{2022}")
                                .foregroundColor(AppColors.textTertiary)
                            Text("Published")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.success)
                        } else if broadcast.status == .scheduled, let scheduledAt = broadcast.scheduledAt {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.warning)
                            Text(scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.warning)
                        } else {
                            Text(broadcast.timeAgo)
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            if broadcast.status == .draft {
                                Text("\u{2022}")
                                    .foregroundColor(AppColors.textTertiary)
                                Text("Draft")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                        }
                    }

                    // Tags
                    if !broadcast.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(broadcast.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppColors.cardBackground(colorScheme).opacity(0.5))
                                    .cornerRadius(3)
                            }
                            if broadcast.tags.count > 2 {
                                Text("+\(broadcast.tags.count - 2)")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }

                Spacer()

                // Media indicators
                HStack(spacing: ArkSpacing.xs) {
                    if broadcast.audioURL != nil {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !broadcast.images.isEmpty {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if broadcast.portfolioAttachment != nil {
                        Image(systemName: "square.split.2x1")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !broadcast.appReferences.isEmpty {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onPublish = onPublish {
                Button {
                    onPublish()
                } label: {
                    Label("Publish", systemImage: "paperplane.fill")
                }
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
