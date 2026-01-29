import SwiftUI

// MARK: - Feature Request Detail View (Admin)

/// Detailed view for reviewing and managing a feature request
struct FeatureRequestDetailView: View {
    let request: FeatureRequest
    @Bindable var viewModel: FeatureRequestViewModel
    let onDismiss: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var editedRequest: FeatureRequest
    @State private var adminNotes: String
    @State private var isAnalyzing = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var hasChanges: Bool {
        editedRequest.status != request.status ||
        editedRequest.priority != request.priority ||
        adminNotes != (request.adminNotes ?? "")
    }

    init(request: FeatureRequest, viewModel: FeatureRequestViewModel, onDismiss: @escaping () -> Void) {
        self.request = request
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self._editedRequest = State(initialValue: request)
        self._adminNotes = State(initialValue: request.adminNotes ?? "")
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Request Info
                    requestInfoSection

                    // Status & Priority
                    statusPrioritySection

                    // Admin Notes
                    adminNotesSection

                    // AI Analysis
                    aiAnalysisSection

                    // Actions
                    actionsSection

                    Spacer(minLength: 100)
                }
                .padding(ArkSpacing.lg)
            }
        }
        .navigationTitle("Review Request")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onDismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .alert("Delete Request?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteRequest()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Request Info Section

    private var requestInfoSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            // Category & Date
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: request.category.icon)
                        .font(.system(size: 14))
                    Text(request.category.displayName)
                        .font(ArkFonts.caption)
                }
                .foregroundColor(AppColors.accent)

                Spacer()

                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            // Title
            Text(request.title)
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Description
            Text(request.description)
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Author Info
            if let email = request.authorEmail {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 12))
                    Text(email)
                        .font(ArkFonts.caption)
                }
                .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    // MARK: - Status & Priority Section

    private var statusPrioritySection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Status & Priority")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            // Status Picker
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Status")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ArkSpacing.xs) {
                        ForEach(FeatureStatus.allCases, id: \.self) { status in
                            StatusChip(
                                status: status,
                                isSelected: editedRequest.status == status,
                                action: { editedRequest.status = status }
                            )
                        }
                    }
                }
            }

            // Priority Picker
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("Priority")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)

                HStack(spacing: ArkSpacing.xs) {
                    ForEach(FeaturePriority.allCases, id: \.self) { priority in
                        PriorityChip(
                            priority: priority,
                            isSelected: editedRequest.priority == priority,
                            action: { editedRequest.priority = priority }
                        )
                    }
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    // MARK: - Admin Notes Section

    private var adminNotesSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Admin Notes")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            TextEditor(text: $adminNotes)
                .font(ArkFonts.body)
                .frame(minHeight: 100)
                .padding(ArkSpacing.sm)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.md)
                .overlay(
                    Group {
                        if adminNotes.isEmpty {
                            Text("Add notes about this request (internal only)")
                                .font(ArkFonts.body)
                                .foregroundColor(AppColors.textTertiary)
                                .padding(ArkSpacing.md)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }

    // MARK: - AI Analysis Section

    private var aiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("AI Analysis")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Button(action: runAIAnalysis) {
                    HStack(spacing: 4) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                        }
                        Text(isAnalyzing ? "Analyzing..." : "Analyze")
                            .font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.accent)
                }
                .disabled(isAnalyzing)
            }

            if let analysis = editedRequest.aiAnalysis {
                Text(analysis)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme).opacity(0.5))
                    .cornerRadius(ArkSpacing.Radius.sm)
            } else {
                Text("Tap 'Analyze' to get AI-powered insights about this request")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(ArkSpacing.sm)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Quick Actions
            HStack(spacing: ArkSpacing.sm) {
                Button(action: { quickApprove() }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Approve")
                    }
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ArkSpacing.md)
                    .background(Color(hex: FeatureStatus.approved.color))
                    .cornerRadius(ArkSpacing.Radius.md)
                }

                Button(action: { quickReject() }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Reject")
                    }
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ArkSpacing.md)
                    .background(Color(hex: FeatureStatus.rejected.color))
                    .cornerRadius(ArkSpacing.Radius.md)
                }
            }

            // Delete Button
            Button(action: { showDeleteConfirm = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Request")
                }
                .font(ArkFonts.body)
                .foregroundColor(AppColors.error)
            }
            .padding(.top, ArkSpacing.sm)
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        isSaving = true

        var updatedRequest = editedRequest
        updatedRequest.adminNotes = adminNotes.isEmpty ? nil : adminNotes
        updatedRequest.reviewedAt = Date()
        updatedRequest.reviewedBy = SupabaseAuthManager.shared.currentUserId

        Task {
            await viewModel.saveRequest(updatedRequest)
            await MainActor.run {
                isSaving = false
                onDismiss()
            }
        }
    }

    private func quickApprove() {
        editedRequest.status = .approved
        saveChanges()
    }

    private func quickReject() {
        editedRequest.status = .rejected
        saveChanges()
    }

    private func deleteRequest() {
        Task {
            await viewModel.deleteRequest(request)
            await MainActor.run {
                onDismiss()
            }
        }
    }

    private func runAIAnalysis() {
        isAnalyzing = true

        Task {
            let analysis = await viewModel.analyzeImportance(for: request)
            await MainActor.run {
                editedRequest.aiAnalysis = analysis
                isAnalyzing = false
            }
        }
    }
}

// MARK: - Status Chip

private struct StatusChip: View {
    let status: FeatureStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.system(size: 10))
                Text(status.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Color(hex: status.color))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: status.color) : Color(hex: status.color).opacity(0.15))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Priority Chip

private struct PriorityChip: View {
    let priority: FeaturePriority
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: priority.icon)
                    .font(.system(size: 10))
                Text(priority.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : Color(hex: priority.color))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(hex: priority.color) : Color(hex: priority.color).opacity(0.15))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeatureRequestDetailView(
            request: FeatureRequest(
                title: "Add dark mode toggle in quick settings",
                description: "It would be great to have a quick toggle for dark mode without going into full settings. Maybe in the header or as a floating button.",
                category: .ui,
                authorId: UUID(),
                authorEmail: "user@example.com"
            ),
            viewModel: FeatureRequestViewModel(),
            onDismiss: {}
        )
        .environmentObject(AppState())
    }
}
