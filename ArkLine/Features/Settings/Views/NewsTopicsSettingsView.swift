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

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Quick Presets
                    presetsSection

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

    // MARK: - Quick Presets
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Quick Setup")
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Not sure where to start? Pick a preset.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: ArkSpacing.xs) {
                ForEach(NewsPreset.allCases, id: \.self) { preset in
                    Button {
                        viewModel.applyPreset(preset)
                    } label: {
                        HStack(spacing: ArkSpacing.sm) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 16))
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(AppFonts.body14Medium)
                                Text(preset.subtitle)
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if viewModel.selectedNewsTopics == preset.topics {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .padding(ArkSpacing.sm)
                        .background(
                            viewModel.selectedNewsTopics == preset.topics
                                ? AppColors.accent.opacity(0.1)
                                : AppColors.fillSecondary(colorScheme)
                        )
                        .cornerRadius(ArkSpacing.Radius.input)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.card)
    }

    // MARK: - Pre-defined Topics
    private var predefinedTopicsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Categories")
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Or pick your own topics")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: ArkSpacing.sm
            ) {
                ForEach(Constants.NewsTopic.allCases.filter { $0 != .nfts }, id: \.self) { topic in
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

// MARK: - News Presets
enum NewsPreset: String, CaseIterable {
    case recommended
    case cryptoFocused
    case macroTrader

    var title: String {
        switch self {
        case .recommended: return "Recommended"
        case .cryptoFocused: return "Crypto Focused"
        case .macroTrader: return "Macro Trader"
        }
    }

    var subtitle: String {
        switch self {
        case .recommended: return "Best for most investors — broad market coverage"
        case .cryptoFocused: return "Crypto, DeFi, and regulation news"
        case .macroTrader: return "Economy, geopolitics, and stocks"
        }
    }

    var icon: String {
        switch self {
        case .recommended: return "star.fill"
        case .cryptoFocused: return "bitcoinsign.circle"
        case .macroTrader: return "globe"
        }
    }

    var topics: Set<Constants.NewsTopic> {
        switch self {
        case .recommended:
            return [.crypto, .macroEconomy, .geopolitics, .stocks]
        case .cryptoFocused:
            return [.crypto, .defi, .regulation]
        case .macroTrader:
            return [.macroEconomy, .geopolitics, .stocks, .techAI]
        }
    }
}

#Preview {
    NavigationStack {
        NewsTopicsSettingsView(viewModel: SettingsViewModel())
            .environmentObject(AppState())
    }
}
