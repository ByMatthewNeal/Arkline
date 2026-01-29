import SwiftUI

// MARK: - Template Picker View

/// View for selecting a broadcast template
struct TemplatePickerView: View {
    let onSelect: (BroadcastTemplate) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Info card
                    infoCard

                    // Built-in templates
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Templates")
                            .font(ArkFonts.subheadline)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, ArkSpacing.md)

                        ForEach(BuiltInTemplate.allCases, id: \.rawValue) { template in
                            TemplateCard(
                                template: template.template,
                                onSelect: {
                                    onSelect(template.template)
                                    dismiss()
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(AppColors.accent)
                Text("Quick Start with Templates")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Text("Templates provide a consistent structure for your broadcasts. Select one to get started quickly.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.1))
        .cornerRadius(ArkSpacing.sm)
        .padding(.horizontal, ArkSpacing.md)
    }
}

// MARK: - Template Card

private struct TemplateCard: View {
    let template: BroadcastTemplate
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: ArkSpacing.md) {
                    // Icon
                    Image(systemName: template.icon)
                        .font(.title2)
                        .foregroundColor(Color(hex: template.color))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: template.color).opacity(0.15))
                        .cornerRadius(ArkSpacing.sm)

                    // Title and description
                    VStack(alignment: .leading, spacing: 2) {
                        Text(template.name)
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text(template.description)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(ArkSpacing.md)
            }
            .buttonStyle(.plain)

            // Expanded content (preview)
            if isExpanded {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Divider()

                    // Title preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                        Text(template.titleTemplate)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(2)
                    }

                    // Content preview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content Structure")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                        Text(template.contentTemplate)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(6)
                    }

                    // Tags
                    if !template.defaultTags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tags")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)

                            HStack(spacing: ArkSpacing.xs) {
                                ForEach(template.defaultTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(hex: template.color))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: template.color).opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Use button
                    Button(action: onSelect) {
                        Text("Use This Template")
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ArkSpacing.sm)
                            .background(Color(hex: template.color))
                            .cornerRadius(ArkSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, ArkSpacing.md)
            }
        }
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .padding(.horizontal, ArkSpacing.md)
    }
}

// MARK: - Preview

#Preview {
    TemplatePickerView { template in
        print("Selected: \(template.name)")
    }
}
