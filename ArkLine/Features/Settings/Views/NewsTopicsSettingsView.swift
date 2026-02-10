import SwiftUI

struct NewsTopicsSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SettingsViewModel

    @State private var newCustomTopic: String = ""
    @FocusState private var isTextFieldFocused: Bool

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Pre-defined Topics Section
                    predefinedTopicsSection

                    // Custom Topics Section
                    customTopicsSection
                        .premiumRequired(.customNews)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.top, ArkSpacing.md)
            }
        }
        .navigationTitle("News Topics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Pre-defined Topics
    private var predefinedTopicsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Categories")
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Select topics to include in your news feed")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: ArkSpacing.sm
            ) {
                ForEach(Constants.NewsTopic.allCases, id: \.self) { topic in
                    NewsTopicChip(
                        topic: topic,
                        isSelected: viewModel.selectedNewsTopics.contains(topic),
                        colorScheme: colorScheme
                    ) {
                        viewModel.toggleNewsTopic(topic)
                    }
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.card)
    }

    // MARK: - Custom Topics
    private var customTopicsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Custom Keywords")
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Add specific tickers, companies, or topics")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            // Input field
            HStack(spacing: ArkSpacing.xs) {
                TextField("e.g., Tesla, Solana, China", text: $newCustomTopic)
                    .font(AppFonts.body14)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.fillSecondary(colorScheme))
                    .cornerRadius(ArkSpacing.Radius.input)
                    .focused($isTextFieldFocused)
                    .onSubmit { addCustomTopic() }

                Button(action: addCustomTopic) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.accent)
                }
                .disabled(newCustomTopic.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Custom topics chips
            if !viewModel.customNewsTopics.isEmpty {
                NewsFlowLayout(spacing: ArkSpacing.xs) {
                    ForEach(viewModel.customNewsTopics, id: \.self) { keyword in
                        CustomTopicChip(
                            keyword: keyword,
                            colorScheme: colorScheme,
                            onRemove: {
                                viewModel.removeCustomTopic(keyword)
                            }
                        )
                    }
                }
                .padding(.top, ArkSpacing.xs)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.card)
    }

    private func addCustomTopic() {
        viewModel.addCustomTopic(newCustomTopic)
        newCustomTopic = ""
    }
}

// MARK: - News Topic Chip (Pre-defined)
struct NewsTopicChip: View {
    let topic: Constants.NewsTopic
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: topic.icon)
                    .font(.system(size: 14))
                Text(topic.displayName)
                    .font(AppFonts.body14Medium)
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ArkSpacing.sm)
            .background(isSelected ? AppColors.accent : AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.Radius.input)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                    .stroke(
                        isSelected ? Color.clear : AppColors.divider(colorScheme),
                        lineWidth: ArkSpacing.Border.thin
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Topic Chip (Removable)
struct CustomTopicChip: View {
    let keyword: String
    let colorScheme: ColorScheme
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: ArkSpacing.xxs) {
            Text(keyword)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xs)
        .background(AppColors.fillSecondary(colorScheme))
        .cornerRadius(ArkSpacing.Radius.full)
    }
}

// MARK: - Flow Layout (for wrapping chips)
private struct NewsFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

#Preview {
    NavigationStack {
        NewsTopicsSettingsView(viewModel: SettingsViewModel())
            .environmentObject(AppState())
    }
}
