import SwiftUI

// MARK: - Feature Request Form View

/// User form for submitting feature requests
struct FeatureRequestFormView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: FeatureCategory = .other
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let service = FeatureRequestService()
    private let maxTitleLength = 100
    private let maxDescriptionLength = 500

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count <= maxTitleLength &&
        description.count <= maxDescriptionLength
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Header
                    headerSection

                    // Form Fields
                    VStack(spacing: ArkSpacing.lg) {
                        titleField
                        categoryPicker
                        descriptionField
                    }
                    .padding(.horizontal, ArkSpacing.lg)

                    // Submit Button
                    submitButton
                        .padding(.horizontal, ArkSpacing.lg)

                    // Tips
                    tipsSection
                        .padding(.horizontal, ArkSpacing.lg)

                    Spacer(minLength: 100)
                }
                .padding(.top, ArkSpacing.lg)
            }
        }
        .navigationTitle("Request a Feature")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Success!", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Thank you for your feedback! We'll review your request and consider it for future updates.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.warning)

            Text("Have an idea?")
                .font(ArkFonts.title2)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Help us improve ArkLine by suggesting new features")
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, ArkSpacing.xl)
    }

    // MARK: - Title Field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Title")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(title.count)/\(maxTitleLength)")
                    .font(ArkFonts.caption)
                    .foregroundColor(title.count > maxTitleLength ? AppColors.error : AppColors.textTertiary)
            }

            TextField("Brief summary of your idea", text: $title)
                .font(ArkFonts.body)
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.md)
                .onChange(of: title) { _, newValue in
                    if newValue.count > maxTitleLength + 10 {
                        title = String(newValue.prefix(maxTitleLength + 10))
                    }
                }
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Category")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            Menu {
                ForEach(FeatureCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        Label(category.displayName, systemImage: category.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)

                    Text(selectedCategory.displayName)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.md)
            }
        }
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Description")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(description.count)/\(maxDescriptionLength)")
                    .font(ArkFonts.caption)
                    .foregroundColor(description.count > maxDescriptionLength ? AppColors.error : AppColors.textTertiary)
            }

            TextEditor(text: $description)
                .font(ArkFonts.body)
                .frame(minHeight: 150)
                .padding(ArkSpacing.sm)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.md)
                .overlay(
                    Group {
                        if description.isEmpty {
                            Text("Describe your feature idea in detail. What problem does it solve? How would it work?")
                                .font(ArkFonts.body)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(ArkSpacing.md)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: description) { _, newValue in
                    if newValue.count > maxDescriptionLength + 20 {
                        description = String(newValue.prefix(maxDescriptionLength + 20))
                    }
                }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: submitRequest) {
            HStack(spacing: ArkSpacing.sm) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Submit Request")
                }
            }
            .font(ArkFonts.bodySemibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(ArkSpacing.md)
            .background(isFormValid ? AppColors.accent : AppColors.accent.opacity(0.5))
            .cornerRadius(ArkSpacing.Radius.md)
        }
        .disabled(!isFormValid || isSubmitting)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Tips for a great request:")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                tipRow(icon: "checkmark.circle", text: "Be specific about the problem you're facing")
                tipRow(icon: "checkmark.circle", text: "Describe how the feature would work")
                tipRow(icon: "checkmark.circle", text: "Explain why this would be valuable")
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme).opacity(0.5))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.success)

            Text(text)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Submit Action

    private func submitRequest() {
        guard isFormValid else { return }

        isSubmitting = true

        Task {
            do {
                guard let userId = SupabaseAuthManager.shared.currentUserId else {
                    throw AppError.authError("Not logged in")
                }

                let request = FeatureRequest(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: selectedCategory,
                    authorId: userId,
                    authorEmail: appState.currentUser?.email
                )

                _ = try await service.createRequest(request)

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = AppError.from(error).userMessage
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeatureRequestFormView()
            .environmentObject(AppState())
    }
}
