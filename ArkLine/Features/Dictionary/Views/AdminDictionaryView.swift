import SwiftUI

// MARK: - Admin Dictionary View

struct AdminDictionaryView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var terms: [DictionaryTerm] = []
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var editingTerm: DictionaryTerm? = nil
    @State private var showDeleteConfirmation = false
    @State private var termToDelete: DictionaryTerm? = nil

    private let service = ServiceContainer.shared.dictionaryService

    private let categories = ["Crypto", "Macro", "Technical", "Trading", "Risk", "General"]

    // MARK: - Filtered Terms

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
                } else if filteredTerms.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label("No Terms", systemImage: "character.book.closed")
                    } description: {
                        Text(searchText.isEmpty ? "Tap + to add the first term" : "No results for \"\(searchText)\"")
                    }
                    Spacer()
                } else {
                    termsList
                }
            }
        }
        .navigationTitle("Dictionary Manager")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .searchable(text: $searchText, prompt: "Search terms...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.selection()
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Text("\(terms.count) terms")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            DictionaryTermFormSheet(mode: .add) { request in
                await addTerm(request)
            }
        }
        .sheet(item: $editingTerm) { term in
            DictionaryTermFormSheet(mode: .edit(term)) { request in
                await updateTerm(id: term.id, request: request)
            }
        }
        .alert("Delete Term", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { termToDelete = nil }
            Button("Delete", role: .destructive) {
                if let term = termToDelete {
                    Task { await deleteTerm(term) }
                }
            }
        } message: {
            if let term = termToDelete {
                Text("Are you sure you want to delete \"\(term.term)\"?")
            }
        }
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
        List {
            ForEach(filteredTerms) { term in
                Button {
                    Haptics.selection()
                    editingTerm = term
                } label: {
                    HStack(spacing: ArkSpacing.sm) {
                        Image(systemName: term.categoryIcon)
                            .font(.system(size: 16))
                            .foregroundColor(term.categoryColor)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: ArkSpacing.xxxs) {
                            Text(term.term)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text(term.definition)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                    .padding(.vertical, ArkSpacing.xxs)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        termToDelete = term
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 80, for: .scrollContent)
    }

    // MARK: - Actions

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

    private func addTerm(_ request: CreateTermRequest) async {
        do {
            let newTerm = try await service.create(term: request)
            terms.append(newTerm)
            terms.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        } catch {
            logError("Failed to create dictionary term: \(error)", category: .network)
        }
    }

    private func updateTerm(id: UUID, request: UpdateTermRequest) async {
        do {
            try await service.update(id: id, term: request)
            if let index = terms.firstIndex(where: { $0.id == id }) {
                terms[index] = DictionaryTerm(
                    id: id,
                    term: request.term,
                    definition: request.definition,
                    category: request.category,
                    example: request.example,
                    relatedTerms: request.relatedTerms,
                    createdAt: terms[index].createdAt
                )
            }
        } catch {
            logError("Failed to update dictionary term: \(error)", category: .network)
        }
    }

    private func deleteTerm(_ term: DictionaryTerm) async {
        do {
            try await service.delete(id: term.id)
            terms.removeAll { $0.id == term.id }
        } catch {
            logError("Failed to delete dictionary term: \(error)", category: .network)
        }
        termToDelete = nil
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
}

// MARK: - Form Sheet

struct DictionaryTermFormSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(DictionaryTerm)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let term): return term.id.uuidString
            }
        }
    }

    let mode: Mode
    let onSave: (CreateTermRequest) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var term = ""
    @State private var definition = ""
    @State private var selectedCategory = "General"
    @State private var example = ""
    @State private var relatedTermsText = ""
    @State private var isSaving = false

    private let categories = ["Crypto", "Macro", "Technical", "Trading", "Risk", "General"]

    private var isValid: Bool {
        !term.trimmingCharacters(in: .whitespaces).isEmpty &&
        !definition.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var title: String {
        switch mode {
        case .add: return "Add Term"
        case .edit: return "Edit Term"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                Form {
                    Section {
                        TextField("Term", text: $term)
                            .font(AppFonts.body14)

                        Picker("Category", selection: $selectedCategory) {
                            ForEach(categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .font(AppFonts.body14)
                    } header: {
                        Text("Term")
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))

                    Section {
                        TextEditor(text: $definition)
                            .font(AppFonts.body14)
                            .frame(minHeight: 100)
                    } header: {
                        Text("Definition")
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))

                    Section {
                        TextEditor(text: $example)
                            .font(AppFonts.body14)
                            .frame(minHeight: 60)
                    } header: {
                        Text("Example (optional)")
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))

                    Section {
                        TextField("e.g. Bitcoin, Blockchain, DeFi", text: $relatedTermsText)
                            .font(AppFonts.body14)
                    } header: {
                        Text("Related Terms (comma-separated)")
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        if case .edit(let existing) = mode {
            term = existing.term
            definition = existing.definition
            selectedCategory = existing.category?.capitalized ?? "General"
            example = existing.example ?? ""
            relatedTermsText = existing.relatedTerms?.joined(separator: ", ") ?? ""
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let relatedTerms = relatedTermsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let request = CreateTermRequest(
            term: term.trimmingCharacters(in: .whitespaces),
            definition: definition.trimmingCharacters(in: .whitespaces),
            category: selectedCategory.lowercased(),
            example: example.trimmingCharacters(in: .whitespaces).isEmpty ? nil : example.trimmingCharacters(in: .whitespaces),
            relatedTerms: relatedTerms.isEmpty ? nil : relatedTerms
        )

        await onSave(request)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AdminDictionaryView()
    }
}
