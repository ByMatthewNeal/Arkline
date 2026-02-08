import SwiftUI

// MARK: - Portfolio Switcher Sheet
struct PortfolioSwitcherSheet: View {
    let portfolios: [Portfolio]
    @Binding var selectedPortfolio: Portfolio?
    @Bindable var viewModel: PortfolioViewModel
    var onCreatePortfolio: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var portfolioToEdit: Portfolio?
    @State private var portfolioToDelete: Portfolio?
    @State private var showDeleteConfirmation = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if portfolios.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textSecondary)
                        Text("No portfolios yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                        Text("Create your first portfolio to start tracking your assets")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                } else {
                    List {
                        ForEach(portfolios) { portfolio in
                            PortfolioSwitcherRow(
                                portfolio: portfolio,
                                isSelected: selectedPortfolio?.id == portfolio.id,
                                onSelect: {
                                    selectedPortfolio = portfolio
                                    dismiss()
                                },
                                onEdit: {
                                    portfolioToEdit = portfolio
                                },
                                onDelete: {
                                    portfolioToDelete = portfolio
                                    showDeleteConfirmation = true
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    portfolioToDelete = portfolio
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    portfolioToEdit = portfolio
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(AppColors.accent)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                Button(action: {
                    dismiss()
                    onCreatePortfolio?()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }

                        Text("Create New Portfolio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Select Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
            .sheet(item: $portfolioToEdit) { portfolio in
                EditPortfolioView(viewModel: viewModel, portfolio: portfolio)
            }
            .alert("Delete Portfolio", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    portfolioToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let portfolio = portfolioToDelete {
                        Task {
                            try? await viewModel.deletePortfolio(portfolio)
                        }
                        portfolioToDelete = nil
                    }
                }
            } message: {
                if let portfolio = portfolioToDelete {
                    Text("Are you sure you want to delete \"\(portfolio.name)\"? This will permanently remove all holdings and transactions.")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Portfolio Switcher Row
struct PortfolioSwitcherRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(portfolio.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(portfolio.isPublic ? "Public" : "Private")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppColors.accent)
            }

            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button { onEdit() } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
