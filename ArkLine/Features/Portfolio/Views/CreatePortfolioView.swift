import SwiftUI

struct CreatePortfolioView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel

    @State private var portfolioName = ""
    @State private var isPublic = false
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""

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

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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

                        // Info Section
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.accent.opacity(0.7))

                            Text("After creating your portfolio, you can add assets like stocks, crypto, metals, and real estate properties.")
                                .font(.system(size: 13))
                                .foregroundColor(textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent.opacity(0.08))
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createPortfolio()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isValid ? AppColors.accent : textSecondary.opacity(0.5))
                    .disabled(!isValid || isCreating)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
            }
        }
    }

    private func createPortfolio() {
        guard isValid else { return }

        isCreating = true

        Task {
            do {
                try await viewModel.createPortfolio(
                    name: portfolioName.trimmingCharacters(in: .whitespaces),
                    isPublic: isPublic
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = AppError.from(error).userMessage
                    showError = true
                }
            }
        }
    }
}

#Preview {
    CreatePortfolioView(viewModel: PortfolioViewModel())
}
