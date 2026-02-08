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
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
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
                (colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Portfolio Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Portfolio Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textSecondary)

                            TextField("e.g., Retirement Fund", text: $portfolioName)
                                .font(.system(size: 16))
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
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textSecondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Public Portfolio")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(textPrimary)

                                    Text("Allow others to view your portfolio")
                                        .font(.system(size: 13))
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
                    .font(.system(size: 16, weight: .semibold))
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
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
