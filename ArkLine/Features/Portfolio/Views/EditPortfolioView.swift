import SwiftUI

struct EditPortfolioView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    let portfolio: Portfolio

    @State private var portfolioName: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(viewModel: PortfolioViewModel, portfolio: Portfolio) {
        self.viewModel = viewModel
        self.portfolio = portfolio
        _portfolioName = State(initialValue: portfolio.name)
        _isPublic = State(initialValue: portfolio.isPublic)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var cardBackground: Color {
        AppColors.cardBackground(colorScheme)
    }

    private var isValid: Bool {
        !portfolioName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        portfolioName.trimmingCharacters(in: .whitespaces) != portfolio.name ||
        isPublic != portfolio.isPublic
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Portfolio Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Portfolio Name")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(textSecondary)

                            TextField("e.g., Retirement Fund", text: $portfolioName)
                                .font(AppFonts.body16)
                                .foregroundColor(textPrimary)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(cardBackground)
                                )
                        }

                        // Visibility Toggle Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Visibility")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(textSecondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Public Portfolio")
                                        .font(AppFonts.body16Medium)
                                        .foregroundColor(textPrimary)

                                    Text("Allow others to view your portfolio")
                                        .font(AppFonts.caption13)
                                        .foregroundColor(textSecondary)
                                }

                                Spacer()

                                Toggle("", isOn: $isPublic)
                                    .tint(AppColors.accent)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(cardBackground)
                            )
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePortfolio()
                    }
                    .font(AppFonts.title16)
                    .foregroundColor(isValid && hasChanges ? AppColors.accent : textSecondary.opacity(0.5))
                    .disabled(!isValid || !hasChanges || isSaving)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
        }
    }

    private func savePortfolio() {
        guard isValid, hasChanges else { return }

        isSaving = true

        Task {
            do {
                try await viewModel.updatePortfolio(
                    portfolio,
                    name: portfolioName.trimmingCharacters(in: .whitespaces),
                    isPublic: isPublic
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = AppError.from(error).userMessage
                    showError = true
                }
            }
        }
    }
}
