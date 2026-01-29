import SwiftUI

// MARK: - App Reference Picker View

/// View for selecting app sections to reference in a broadcast.
/// Allows admins to link to specific parts of the app with optional notes.
struct AppReferencePickerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @Binding var selectedReferences: [AppReference]

    @State private var searchText = ""
    @State private var editingReference: AppReference?
    @State private var showingNoteEditor = false

    var body: some View {
        NavigationStack {
            List {
                // Selected references section
                if !selectedReferences.isEmpty {
                    Section {
                        ForEach(selectedReferences) { reference in
                            selectedReferenceRow(reference)
                        }
                        .onDelete(perform: deleteReferences)
                    } header: {
                        Text("Selected (\(selectedReferences.count))")
                    }
                }

                // Available sections
                Section {
                    ForEach(filteredSections, id: \.self) { section in
                        availableSectionRow(section)
                    }
                } header: {
                    Text("App Sections")
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search sections")
            .navigationTitle("App References")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNoteEditor) {
                if let reference = editingReference {
                    NoteEditorSheet(
                        reference: reference,
                        onSave: { updatedReference in
                            if let index = selectedReferences.firstIndex(where: { $0.id == updatedReference.id }) {
                                selectedReferences[index] = updatedReference
                            }
                            editingReference = nil
                        }
                    )
                }
            }
        }
    }

    // MARK: - Filtered Sections

    private var filteredSections: [AppSection] {
        let availableSections = AppSection.allCases.filter { section in
            !selectedReferences.contains { $0.section == section }
        }

        if searchText.isEmpty {
            return availableSections
        }

        return availableSections.filter { section in
            section.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Selected Reference Row

    private func selectedReferenceRow(_ reference: AppReference) -> some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: reference.section.iconName)
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text(reference.section.displayName)
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let note = reference.note, !note.isEmpty {
                    Text(note)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Edit note button
            Button {
                editingReference = reference
                showingNoteEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
            }
            .buttonStyle(.plain)

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.success)
        }
        .padding(.vertical, ArkSpacing.xxs)
    }

    // MARK: - Available Section Row

    private func availableSectionRow(_ section: AppSection) -> some View {
        Button {
            addReference(for: section)
        } label: {
            HStack(spacing: ArkSpacing.md) {
                Image(systemName: section.iconName)
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(section.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(sectionDescription(section))
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(AppColors.accent)
            }
            .padding(.vertical, ArkSpacing.xxs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func addReference(for section: AppSection) {
        let reference = AppReference(section: section)
        selectedReferences.append(reference)
    }

    private func deleteReferences(at offsets: IndexSet) {
        selectedReferences.remove(atOffsets: offsets)
    }

    // MARK: - Section Descriptions

    private func sectionDescription(_ section: AppSection) -> String {
        switch section {
        case .vix:
            return "Market volatility indicator"
        case .dxy:
            return "US Dollar strength index"
        case .m2:
            return "Money supply & liquidity"
        case .bitcoinRisk:
            return "Risk level analysis for BTC"
        case .upcomingEvents:
            return "Economic calendar & events"
        case .fearGreed:
            return "Market sentiment gauge"
        case .sentiment:
            return "Overall market mood"
        case .rainbowChart:
            return "Long-term BTC price bands"
        case .technicalAnalysis:
            return "Charts & technical indicators"
        case .portfolioShowcase:
            return "Portfolio comparison showcase"
        }
    }
}

// MARK: - Note Editor Sheet

private struct NoteEditorSheet: View {
    let reference: AppReference
    let onSave: (AppReference) -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: ArkSpacing.lg) {
                // Section info
                HStack(spacing: ArkSpacing.md) {
                    Image(systemName: reference.section.iconName)
                        .font(.title2)
                        .foregroundColor(AppColors.accent)

                    Text(reference.section.displayName)
                        .font(ArkFonts.headline)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)

                // Note field
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    Text("Note (optional)")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Add context about this reference...", text: $noteText, axis: .vertical)
                        .font(ArkFonts.body)
                        .lineLimit(3...6)
                        .padding(ArkSpacing.md)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                }

                Spacer()
            }
            .padding(ArkSpacing.md)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = reference
                        updated.note = noteText.isEmpty ? nil : noteText
                        onSave(updated)
                        dismiss()
                    }
                }
            }
            .onAppear {
                noteText = reference.note ?? ""
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AppReferencePickerView(selectedReferences: .constant([]))
}
