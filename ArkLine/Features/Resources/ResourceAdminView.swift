import SwiftUI

// MARK: - Resource Admin
//
// Admin-only editor for the Resources hub. Lets you add or edit articles (markdown
// body, section, ordering, publish state) without shipping an app update — the
// content lives in Supabase. Link rows (Dictionary/Referral) are managed in the DB.

struct ResourceAdminView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var articles: [ResourceArticle] = []
    @State private var isLoading = true
    @State private var editing: ResourceDraft?

    var body: some View {
        NavigationStack {
            List {
                ForEach(articles) { article in
                    Button {
                        editing = ResourceDraft(from: article)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(article.title)
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Text("\(article.section.title) · \(article.isPublished ? "Published" : "Draft")\(article.isLink ? " · link" : "")")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .disabled(article.isLink) // link rows are DB-managed
                }
            }
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle("Manage Resources")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editing = ResourceDraft.new()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing, onDismiss: { Task { await load() } }) { draft in
                ResourceEditorForm(draft: draft)
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            articles = try await ResourceService.shared.fetchAll()
        } catch {
            logError("Failed to load resources (admin): \(error)", category: .data)
        }
        isLoading = false
    }
}

// MARK: - Editable draft

struct ResourceDraft: Identifiable {
    let id: String            // slug (stable), or a temp id for new
    var slug: String
    var title: String
    var summary: String
    var body: String
    var category: String
    var icon: String
    var sortOrder: Int
    var isPublished: Bool
    let isNew: Bool

    init(from a: ResourceArticle) {
        id = a.slug
        slug = a.slug
        title = a.title
        summary = a.summary ?? ""
        body = a.body ?? ""
        category = a.category
        icon = a.icon ?? "doc.text"
        sortOrder = a.sortOrder
        isPublished = a.isPublished
        isNew = false
    }

    private init() {
        id = UUID().uuidString
        slug = ""
        title = ""
        summary = ""
        body = ""
        category = ResourceSection.learn.rawValue
        icon = "doc.text"
        sortOrder = 0
        isPublished = false
        isNew = true
    }

    static func new() -> ResourceDraft { ResourceDraft() }
}

// MARK: - Editor form

struct ResourceEditorForm: View {
    @State var draft: ResourceDraft
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let sections = ResourceSection.allCases

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title", text: $draft.title)
                        .onChange(of: draft.title) { _, new in
                            if draft.isNew { draft.slug = slugify(new) }
                        }
                    TextField("Slug (stable id)", text: $draft.slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Summary (one line)", text: $draft.summary, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Placement") {
                    Picker("Section", selection: $draft.category) {
                        ForEach(sections, id: \.rawValue) { s in
                            Text(s.title).tag(s.rawValue)
                        }
                    }
                    Stepper("Order: \(draft.sortOrder)", value: $draft.sortOrder, in: 0...99)
                    TextField("SF Symbol (icon)", text: $draft.icon)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Published", isOn: $draft.isPublished)
                }

                Section("Body (Markdown)") {
                    TextEditor(text: $draft.body)
                        .frame(minHeight: 240)
                        .font(.system(size: 14, design: .monospaced))
                }
            }
            .navigationTitle(draft.isNew ? "New Resource" : "Edit Resource")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(draft.title.isEmpty || draft.slug.isEmpty)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                let payload = ResourceArticleUpsert(
                    slug: draft.slug,
                    title: draft.title,
                    summary: draft.summary.isEmpty ? nil : draft.summary,
                    body: draft.body.isEmpty ? nil : draft.body,
                    category: draft.category,
                    icon: draft.icon.isEmpty ? nil : draft.icon,
                    sortOrder: draft.sortOrder,
                    isPublished: draft.isPublished
                )
                try await ResourceService.shared.upsert(payload)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
                logError("Failed to save resource: \(error)", category: .data)
            }
        }
    }

    /// Lowercase, hyphenated slug from a title.
    private func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        let allowed = lowered.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : "-"
        }
        var slug = String(allowed)
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
