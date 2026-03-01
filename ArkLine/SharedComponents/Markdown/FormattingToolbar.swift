import SwiftUI

// MARK: - Formatting Toolbar

/// Horizontal row of markdown formatting buttons for the broadcast editor.
struct FormattingToolbar: View {
    let onFormat: (MarkdownFormat) -> Void

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            // Text style menu
            Menu {
                Button { onFormat(.title) } label: {
                    Label("Title", systemImage: "textformat.size.larger")
                }
                Button { onFormat(.heading) } label: {
                    Label("Heading", systemImage: "textformat.size")
                }
                Button { onFormat(.subheading) } label: {
                    Label("Subheading", systemImage: "textformat.size.smaller")
                }
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }

            // Indent / blockquote
            toolbarButton(icon: "increase.indent", format: .indent)

            // Divider
            Rectangle()
                .fill(AppColors.textTertiary.opacity(0.3))
                .frame(width: 1, height: 20)
                .padding(.horizontal, ArkSpacing.xxs)

            // Text formatting group
            toolbarButton(icon: "bold", format: .bold)
            toolbarButton(icon: "italic", format: .italic)
            toolbarButton(icon: "underline", format: .underline)
            toolbarButton(icon: "strikethrough", format: .strikethrough)

            // Divider
            Rectangle()
                .fill(AppColors.textTertiary.opacity(0.3))
                .frame(width: 1, height: 20)
                .padding(.horizontal, ArkSpacing.xxs)

            // Structural formatting group
            toolbarButton(icon: "link", format: .link)
            toolbarButton(icon: "list.number", format: .orderedList)
            toolbarButton(icon: "list.bullet", format: .unorderedList)

            Spacer()
        }
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xs)
    }

    private func toolbarButton(icon: String, format: MarkdownFormat) -> some View {
        Button {
            onFormat(format)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
