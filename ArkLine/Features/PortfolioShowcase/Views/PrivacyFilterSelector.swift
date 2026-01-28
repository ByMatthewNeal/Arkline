import SwiftUI

// MARK: - Privacy Filter Selector

/// Horizontal chip-style selector for privacy levels
struct PrivacyFilterSelector: View {
    @Binding var selectedLevel: PrivacyLevel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack {
                Image(systemName: "eye.slash")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)

                Text("Privacy Level")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Info button
                Button {
                    // Could show a tooltip/popover explaining privacy levels
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            // Privacy level chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(PrivacyLevel.allCases) { level in
                        PrivacyLevelChip(
                            level: level,
                            isSelected: selectedLevel == level,
                            onTap: { selectedLevel = level }
                        )
                    }
                }
            }

            // Description of selected level
            Text(selectedLevel.description)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
                .animation(.easeInOut(duration: 0.2), value: selectedLevel)
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Privacy Level Chip

private struct PrivacyLevelChip: View {
    let level: PrivacyLevel
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: level.icon)
                    .font(.caption)

                Text(level.displayName)
                    .font(ArkFonts.caption)
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary(colorScheme))
            .padding(.horizontal, ArkSpacing.sm)
            .padding(.vertical, ArkSpacing.xs)
            .background(
                isSelected
                    ? AppColors.accent
                    : AppColors.cardBackground(colorScheme)
            )
            .cornerRadius(ArkSpacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.xs)
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.textTertiary.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PrivacyFilterSelector(selectedLevel: .constant(.percentageOnly))
    }
    .padding()
    .background(Color.black)
}
