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

// MARK: - Trail Lesson Admin
//
// Admin-only editor for the guided trails (Foundations, Crypto). Lesson content
// lives in Supabase (`trail_lessons`) so it can be kept current without shipping
// an app update. The app ships a built-in copy of every lesson; editing here
// overrides the built-in copy for that (trail, position). Edit + publish only.

struct TrailAdminView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var kind: TrailKind = .foundations
    @State private var lessons: [TrailLesson] = []
    @State private var isLoading = true
    @State private var editing: TrailLessonDraft?

    var body: some View {
            List {
                Section {
                    Picker("Trail", selection: $kind) {
                        ForEach(TrailKind.allCases, id: \.self) { k in
                            Text(k.navTitle).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    ForEach(lessons) { lesson in
                        Button {
                            editing = TrailLessonDraft(from: lesson)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(lesson.position). \(lesson.title)")
                                        .font(AppFonts.body14Medium)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))
                                    Text(lesson.isPublished ? "Published" : "Draft")
                                        .font(AppFonts.caption12)
                                        .foregroundColor(lesson.isPublished ? AppColors.textSecondary : AppColors.warning)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
            .overlay { if isLoading { ProgressView() } }
            .navigationTitle("Manage Lessons")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onChange(of: kind) { _, _ in Task { await load() } }
            .sheet(item: $editing, onDismiss: { Task { await load() } }) { draft in
                TrailLessonEditorForm(draft: draft)
            }
            .task { await load() }
    }

    /// Merge DB rows over the built-in seed by position, so every lesson is
    /// listed even before it has ever been edited.
    private func load() async {
        isLoading = true
        let seed = kind.seed
        let rows = (try? await TrailLessonService.shared.fetchAll(trailKey: kind.rawValue)) ?? []
        let byPos = Dictionary(rows.map { ($0.position, $0) }, uniquingKeysWith: { a, _ in a })
        lessons = seed.map { byPos[$0.position] ?? $0 }
        isLoading = false
    }
}

// MARK: - Editable lesson draft

struct TrailLessonDraft: Identifiable {
    var id: String { "\(trailKey)-\(position)" }
    let trailKey: String
    let position: Int
    var title: String
    var idea: String
    var seeInApp: String
    var mindsetCheck: String
    var takeaway: String
    var oneMoreThing: String
    var preview: String
    var deepLinkRaw: String   // "" = none
    var isPublished: Bool

    init(from l: TrailLesson) {
        trailKey = l.trailKey
        position = l.position
        title = l.title
        idea = l.idea
        seeInApp = l.seeInApp ?? ""
        mindsetCheck = l.mindsetCheck ?? ""
        takeaway = l.takeaway
        oneMoreThing = l.oneMoreThing ?? ""
        preview = l.preview
        deepLinkRaw = l.deepLinkRaw ?? ""
        isPublished = l.isPublished
    }
}

// MARK: - Lesson editor form

struct TrailLessonEditorForm: View {
    @State var draft: TrailLessonDraft
    @Environment(\.dismiss) var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let deepLinkOptions: [String] = [""] + LessonDeepLink.allCases.map { $0.rawValue }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title & preview") {
                    TextField("Title", text: $draft.title, axis: .vertical).lineLimit(1...3)
                    TextField("Preview (one short line)", text: $draft.preview, axis: .vertical).lineLimit(1...2)
                }
                Section("The idea") {
                    TextEditor(text: $draft.idea)
                        .frame(minHeight: 160)
                        .font(.system(size: 14))
                }
                Section("See it in your app (optional)") {
                    TextEditor(text: $draft.seeInApp)
                        .frame(minHeight: 80)
                        .font(.system(size: 14))
                    Picker("Deep link", selection: $draft.deepLinkRaw) {
                        ForEach(deepLinkOptions, id: \.self) { opt in
                            Text(opt.isEmpty ? "None" : opt).tag(opt)
                        }
                    }
                }
                Section("Mindset check (optional)") {
                    TextEditor(text: $draft.mindsetCheck)
                        .frame(minHeight: 80)
                        .font(.system(size: 14))
                }
                Section("Takeaway") {
                    TextEditor(text: $draft.takeaway)
                        .frame(minHeight: 60)
                        .font(.system(size: 14))
                }
                Section("One more thing (optional)") {
                    TextField("One more thing", text: $draft.oneMoreThing, axis: .vertical).lineLimit(1...4)
                }
                Section {
                    Toggle("Published", isOn: $draft.isPublished)
                }
            }
            .navigationTitle("Lesson \(draft.position)")
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
                            .disabled(draft.title.isEmpty || draft.takeaway.isEmpty)
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
                let payload = TrailLessonUpsert(
                    trailKey: draft.trailKey,
                    position: draft.position,
                    title: draft.title,
                    idea: draft.idea,
                    seeInApp: draft.seeInApp.isEmpty ? nil : draft.seeInApp,
                    mindsetCheck: draft.mindsetCheck.isEmpty ? nil : draft.mindsetCheck,
                    takeaway: draft.takeaway,
                    oneMoreThing: draft.oneMoreThing.isEmpty ? nil : draft.oneMoreThing,
                    preview: draft.preview,
                    deepLink: draft.deepLinkRaw.isEmpty ? nil : draft.deepLinkRaw,
                    isPublished: draft.isPublished
                )
                try await TrailLessonService.shared.upsert(payload)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showError = true
                logError("Failed to save trail lesson: \(error)", category: .data)
            }
        }
    }
}
