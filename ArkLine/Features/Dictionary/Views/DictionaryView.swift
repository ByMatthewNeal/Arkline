import SwiftUI

// MARK: - Dictionary View

struct DictionaryView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var terms: [DictionaryTerm] = []
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var expandedTermId: UUID? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?

    private let service = ServiceContainer.shared.dictionaryService

    private let categories = ["Crypto", "Macro", "Technical", "Trading", "Risk", "General"]

    // MARK: - Filtered & Grouped Terms

    private var filteredTerms: [DictionaryTerm] {
        var result = terms

        if let category = selectedCategory {
            result = result.filter { $0.category?.lowercased() == category.lowercased() }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.term.lowercased().contains(query) ||
                $0.definition.lowercased().contains(query)
            }
        }

        return result.sorted { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
    }

    private var groupedTerms: [(String, [DictionaryTerm])] {
        let grouped = Dictionary(grouping: filteredTerms) { term in
            String(term.term.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 0) {
                // Category filter chips
                categoryChips
                    .padding(.top, ArkSpacing.xs)

                if isLoading && terms.isEmpty {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Spacer()
                } else if let error = errorMessage, terms.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await loadTerms() } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                } else if filteredTerms.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label("No Terms Found", systemImage: "magnifyingglass")
                    } description: {
                        if !searchText.isEmpty {
                            Text("No results for \"\(searchText)\"")
                        } else if selectedCategory != nil {
                            Text("No terms in this category yet")
                        } else {
                            Text("The dictionary is empty")
                        }
                    }
                    Spacer()
                } else {
                    termsList
                }
            }
        }
        .navigationTitle("Dictionary")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: $searchText, prompt: "Search terms...")
        .task { await loadTerms() }
        .refreshable { await loadTerms() }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ArkSpacing.xs) {
                chipButton(title: "All", isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }

                ForEach(categories, id: \.self) { category in
                    chipButton(
                        title: category,
                        isSelected: selectedCategory == category,
                        color: categoryColor(for: category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, ArkSpacing.md)
            .padding(.vertical, ArkSpacing.xs)
        }
    }

    private func chipButton(title: String, isSelected: Bool, color: Color = AppColors.accent, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Text(title)
                .font(AppFonts.caption13)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, ArkSpacing.sm)
                .padding(.vertical, ArkSpacing.xxs + 2)
                .background(isSelected ? color : AppColors.fillSecondary(colorScheme))
                .cornerRadius(ArkSpacing.Radius.full)
        }
    }

    // MARK: - Terms List

    private var termsList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(groupedTerms, id: \.0) { letter, termsInGroup in
                    Section {
                        ForEach(termsInGroup) { term in
                            termRow(term)
                                .id(term.id)
                        }
                    } header: {
                        Text(letter)
                            .font(AppFonts.title18Bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 80, for: .scrollContent)
            .onAppear { scrollProxy = proxy }
        }
    }

    // MARK: - Term Row

    private func termRow(_ term: DictionaryTerm) -> some View {
        let isExpanded = expandedTermId == term.id

        return VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            // Header row (always visible)
            Button {
                Haptics.selection()
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedTermId = isExpanded ? nil : term.id
                }
            } label: {
                HStack(alignment: .top, spacing: ArkSpacing.sm) {
                    VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                        Text(term.term)
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        if !isExpanded {
                            Text(term.definition)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    // Category badge
                    HStack(spacing: ArkSpacing.xxxs) {
                        Image(systemName: term.categoryIcon)
                            .font(.system(size: 10))
                        Text(term.displayCategory)
                            .font(AppFonts.caption12)
                    }
                    .foregroundColor(term.categoryColor)
                    .padding(.horizontal, ArkSpacing.xs)
                    .padding(.vertical, ArkSpacing.xxxs)
                    .background(term.categoryColor.opacity(0.12))
                    .cornerRadius(ArkSpacing.Radius.full)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    // Full definition
                    Text(term.definition)
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    // Example
                    if let example = term.example, !example.isEmpty {
                        VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                            Text("Example")
                                .font(AppFonts.caption12)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)

                            Text(example)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                                .italic()
                                .padding(ArkSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.fillSecondary(colorScheme))
                                .cornerRadius(ArkSpacing.Radius.sm)
                        }
                    }

                    // Related terms
                    if let related = term.relatedTerms, !related.isEmpty {
                        VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                            Text("Related Terms")
                                .font(AppFonts.caption12)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)

                            DictionaryFlowLayout(spacing: ArkSpacing.xxs) {
                                ForEach(related, id: \.self) { relatedTerm in
                                    Button {
                                        scrollToTerm(relatedTerm)
                                    } label: {
                                        Text(relatedTerm)
                                            .font(AppFonts.caption12)
                                            .foregroundColor(AppColors.accent)
                                            .padding(.horizontal, ArkSpacing.xs)
                                            .padding(.vertical, ArkSpacing.xxxs)
                                            .background(AppColors.accent.opacity(0.1))
                                            .cornerRadius(ArkSpacing.Radius.full)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, ArkSpacing.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, ArkSpacing.xxs)
    }

    // MARK: - Helpers

    private func scrollToTerm(_ termName: String) {
        if let match = terms.first(where: { $0.term.lowercased() == termName.lowercased() }) {
            searchText = ""
            selectedCategory = nil
            withAnimation {
                expandedTermId = match.id
                scrollProxy?.scrollTo(match.id, anchor: .top)
            }
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "crypto": return AppColors.accent
        case "macro": return .purple
        case "technical": return .orange
        case "trading": return AppColors.success
        case "risk": return AppColors.error
        case "general": return .gray
        default: return .gray
        }
    }

    private func loadTerms() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            terms = try await service.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
            logError("Failed to load dictionary terms: \(error)", category: .network)
        }
    }
}

// MARK: - Flow Layout

/// Simple flow layout for wrapping related term chips.
private struct DictionaryFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                let position = result.positions[index]
                subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX)
            totalHeight = currentY + rowHeight
        }

        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

#Preview {
    NavigationStack {
        DictionaryView()
    }
}
