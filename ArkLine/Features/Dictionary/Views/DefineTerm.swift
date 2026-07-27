import SwiftUI

// MARK: - DefineTerm

/// Inline "explain this term" trigger. Renders a small "?" (or decorates a label)
/// that opens a bottom-sheet explainer sourced from the `dictionary` table.
/// Renders nothing when the key has no dictionary entry — wire tap targets freely;
/// they light up the moment the term is loaded into the DB.
///
/// Usage:
///   Text("Risk Levels").defineTerm("risk-levels", screen: "risk")
///   Text("VIX").defineTerm("vix", screen: "macro", variant: .underline)
///   someCard.defineTerm("momentum-map", screen: "home", variant: .wrap)
enum DefineTermVariant {
    /// Small "?" glyph appended after the label (default).
    case icon
    /// Dotted underline; the whole label is the tap target.
    case underline
    /// Invisible; the wrapped view itself becomes the trigger.
    case wrap
}

/// Dotted baseline used by the `.underline` variant.
private struct DefineTermUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

struct DefineTermModifier: ViewModifier {
    let termKey: String
    let screen: String
    var variant: DefineTermVariant = .icon

    @State private var isPresented = false

    // Type erasure at each branch keeps the generic tree shallow — nested
    // ViewBuilder conditionals here made the Swift type checker explode.
    func body(content: Content) -> some View {
        let entry = DictionaryStore.shared.lookup(termKey)
        return erasedBody(content: content, entry: entry)
            .onAppear { DictionaryStore.shared.loadIfNeeded() }
    }

    private func erasedBody(content: Content, entry: DictionaryTerm?) -> AnyView {
        guard let entry else { return AnyView(content) }
        let sheet = trigger(content: content, entry: entry)
            .sheet(isPresented: $isPresented) {
                TermExplainerSheet(initialTerm: entry, screen: screen)
                    // Spec: sheet stays ≤60% of screen height and scrolls
                    // internally. A .large detent leaves most of the sheet
                    // empty for short definitions.
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        return AnyView(sheet)
    }

    private func trigger(content: Content, entry: DictionaryTerm) -> AnyView {
        let label = "Define \(entry.term)"
        switch variant {
        case .icon:
            return AnyView(iconTrigger(content: content, label: label))
        case .underline:
            return AnyView(underlineTrigger(content: content, label: label))
        case .wrap:
            return AnyView(wrapTrigger(content: content, label: label))
        }
    }

    private func iconTrigger(content: Content, label: String) -> some View {
        HStack(spacing: 4) {
            content
            Button {
                isPresented = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }

    private func underlineTrigger(content: Content, label: String) -> some View {
        Button {
            isPresented = true
        } label: {
            content
                .overlay(alignment: .bottom) { underline }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var underline: some View {
        DefineTermUnderline()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .foregroundColor(AppColors.textSecondary.opacity(0.5))
            .frame(height: 1)
            .offset(y: 2)
    }

    private func wrapTrigger(content: Content, label: String) -> some View {
        Button {
            isPresented = true
        } label: {
            content.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

extension View {
    /// Makes this label explainable: on a dictionary hit, adds a tap target that
    /// opens the term's definition sheet. On a miss, renders unchanged.
    func defineTerm(_ termKey: String, screen: String, variant: DefineTermVariant = .icon) -> some View {
        modifier(DefineTermModifier(termKey: termKey, screen: screen, variant: variant))
    }
}

// MARK: - Explainer Sheet

/// Bottom-sheet definition view: term + category chip, definition, example block,
/// related-term chips that swap content in place (with a back stack), and a
/// footer link to the full glossary.
struct TermExplainerSheet: View {
    let initialTerm: DictionaryTerm
    let screen: String

    @State private var current: DictionaryTerm?
    @State private var backStack: [DictionaryTerm] = []
    @State private var showGlossary = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var term: DictionaryTerm { current ?? initialTerm }

    var body: some View {
        // A NavigationStack here would reserve a full nav bar just to hold
        // "Done", leaving a dead band above the title — so the header is a
        // plain row instead.
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            ScrollView {
                content
            }
        }
        .background(AppColors.background(colorScheme))
        .sheet(isPresented: $showGlossary) { glossarySheet }
        .onAppear { trackView(of: initialTerm, source: "inline") }
    }

    private var headerBar: some View {
        HStack {
            backButton
            Spacer()
            doneButton
        }
        .padding(.horizontal, ArkSpacing.lg)
        .padding(.top, ArkSpacing.sm)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            header
            definitionText
            exampleBlock
            relatedSection
            glossaryLink
        }
        .padding(.horizontal, ArkSpacing.lg)
        .padding(.top, ArkSpacing.sm)
        // Keeps the glossary link clear of the detent edge.
        .padding(.bottom, ArkSpacing.xxl)
    }

    // MARK: - Header controls

    @ViewBuilder
    private var backButton: some View {
        if let previous = backStack.last {
            Button {
                backStack.removeLast()
                current = previous
            } label: {
                Label(previous.term, systemImage: "chevron.left")
                    .font(AppFonts.body14)
                    .lineLimit(1)
            }
            .foregroundColor(AppColors.accent)
        }
    }

    private var doneButton: some View {
        Button("Done") { dismiss() }
            .foregroundColor(AppColors.accent)
    }

    private var glossarySheet: some View {
        NavigationStack {
            DictionaryView(initialSearch: term.term)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showGlossary = false }
                    }
                }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text(term.term)
                .font(AppFonts.title18Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            categoryChip
        }
    }

    private var categoryChip: some View {
        HStack(spacing: 5) {
            Image(systemName: term.categoryIcon)
                .font(.system(size: 10))
            Text(term.displayCategory)
                .font(AppFonts.caption12Medium)
        }
        .foregroundColor(term.categoryColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(term.categoryColor.opacity(0.12)))
    }

    private var definitionText: some View {
        Text(term.definition)
            .font(AppFonts.body16)
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var exampleBlock: some View {
        if let example = term.example, !example.isEmpty {
            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text("For example")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.accent)
                Text(example)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ArkSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(exampleBackground)
        }
    }

    private var exampleBackground: some View {
        RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
            .fill(AppColors.accent.opacity(0.08))
    }

    @ViewBuilder
    private var relatedSection: some View {
        let related = term.relatedTerms ?? []
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Related")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                DictionaryFlowLayout(spacing: 8) {
                    ForEach(related, id: \.self) { name in
                        relatedChip(name)
                    }
                }
            }
        }
    }

    private func relatedChip(_ name: String) -> AnyView {
        // Related terms with no dictionary entry render muted — never a dead tap.
        guard let entry = DictionaryStore.shared.lookup(name), entry.id != term.id else {
            return AnyView(chipLabel(name, active: false))
        }
        let button = Button {
            open(entry)
        } label: {
            chipLabel(name, active: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Define \(entry.term)")
        return AnyView(button)
    }

    private func chipLabel(_ name: String, active: Bool) -> some View {
        Text(name)
            .font(AppFonts.caption12Medium)
            .foregroundColor(active ? AppColors.accent : AppColors.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(chipFill(active: active)))
    }

    private func chipFill(active: Bool) -> Color {
        active ? AppColors.accent.opacity(0.1) : AppColors.fillSecondary(colorScheme)
    }

    private var glossaryLink: some View {
        Button {
            showGlossary = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                Text("Open full glossary")
            }
            .font(AppFonts.body14Medium)
        }
        .foregroundColor(AppColors.accent)
        .padding(.top, ArkSpacing.xs)
    }

    // MARK: - Navigation

    private func open(_ entry: DictionaryTerm) {
        backStack.append(term)
        if backStack.count > 5 { backStack.removeFirst() }
        current = entry
        trackView(of: entry, source: "related-chip")
        Haptics.selection()
    }

    // MARK: - Analytics

    private func trackView(of entry: DictionaryTerm, source: String) {
        let slug = entry.slug ?? DictionaryStore.slugify(entry.term)
        let props: [String: AnyCodableValue] = [
            "slug": AnyCodableValue.string(slug),
            "screen": AnyCodableValue.string(screen),
            "source": AnyCodableValue.string(source)
        ]
        Task {
            await AnalyticsService.shared.track("glossary_term_viewed", properties: props)
        }
    }
}
