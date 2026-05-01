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

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count <= maxTitleLength &&
        description.count <= maxDescriptionLength
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Header
                    headerSection

                    // Form Fields
                    VStack(spacing: ArkSpacing.lg) {
                        categoryChips
                        titleField
                        tipsSection
                        descriptionField
                    }
                    .padding(.horizontal, ArkSpacing.lg)

                    // Submit Button
                    submitButton
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

            Text("Help us improve Arkline by suggesting new features")
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, ArkSpacing.xl)
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Category")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 10))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                }
                .foregroundColor(AppColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeatureCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: FeatureCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category } }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))

                Text(category.displayName)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AppColors.accent : AppColors.cardBackground(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : AppColors.textSecondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Title Field

    private var titleField: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Title")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if title.count > Int(Double(maxTitleLength) * 0.8) {
                    Text("\(title.count)/\(maxTitleLength)")
                        .font(ArkFonts.caption)
                        .foregroundColor(title.count > maxTitleLength ? AppColors.error : AppColors.textTertiary)
                }
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

    // MARK: - Tips Section

    private var tipsSection: some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            Image(systemName: "lightbulb.min")
                .font(.system(size: 12))
                .foregroundColor(AppColors.warning.opacity(0.7))
                .padding(.top, 2)

            Text("Be specific about the problem, describe how it would work, and why it's valuable.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Description")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if description.count > Int(Double(maxDescriptionLength) * 0.8) {
                    Text("\(description.count)/\(maxDescriptionLength)")
                        .font(ArkFonts.caption)
                        .foregroundColor(description.count > maxDescriptionLength ? AppColors.error : AppColors.textTertiary)
                }
            }

            TextEditor(text: $description)
                .font(ArkFonts.body)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(ArkSpacing.sm)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.md)
                .overlay(
                    Group {
                        if description.isEmpty {
                            Text("What would this feature do?")
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

    // MARK: - Submit Action

    private func submitRequest() {
        guard isFormValid else { return }

        isSubmitting = true

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        #endif

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
                    #if canImport(UIKit)
                    generator.notificationOccurred(.success)
                    #endif
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    #if canImport(UIKit)
                    generator.notificationOccurred(.error)
                    #endif
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
