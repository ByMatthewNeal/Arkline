import SwiftUI

// MARK: - Broadcast Portfolio Picker

/// View for selecting portfolios to attach to a broadcast
struct BroadcastPortfolioPicker: View {
    @Binding var attachment: BroadcastPortfolioAttachment?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var portfolios: [Portfolio] = []
    @State private var holdings: [UUID: [PortfolioHolding]] = [:]
    @State private var leftPortfolio: Portfolio?
    @State private var rightPortfolio: Portfolio?
    @State private var privacyLevel: PrivacyLevel = .percentageOnly
    @State private var caption: String = ""
    @State private var isLoading = true
    @State private var showLeftPicker = false
    @State private var showRightPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Instructions
                    instructionsCard

                    // Portfolio Selection
                    portfolioSelectionSection

                    // Privacy Level
                    privacyLevelSection

                    // Caption
                    captionSection

                    // Preview
                    if leftPortfolio != nil || rightPortfolio != nil {
                        previewSection
                    }
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Attach Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Attach") {
                        saveAttachment()
                        dismiss()
                    }
                    .disabled(leftPortfolio == nil && rightPortfolio == nil)
                }
            }
            .sheet(isPresented: $showLeftPicker) {
                PortfolioSelectorSheet(
                    title: "Select First Portfolio",
                    portfolios: portfolios,
                    selectedPortfolio: $leftPortfolio,
                    excludePortfolioId: rightPortfolio?.id
                )
            }
            .sheet(isPresented: $showRightPicker) {
                PortfolioSelectorSheet(
                    title: "Select Second Portfolio",
                    portfolios: portfolios,
                    selectedPortfolio: $rightPortfolio,
                    excludePortfolioId: leftPortfolio?.id
                )
            }
            .task {
                await loadPortfolios()
            }
            .onAppear {
                // Load existing attachment if editing
                if let existing = attachment {
                    privacyLevel = existing.privacyLevel
                    caption = existing.caption ?? ""
                }
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.accent)
                Text("Share Your Portfolio")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Text("Select one or two portfolios to share with your broadcast. Users will see a visual showcase with your chosen privacy settings.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.1))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Portfolio Selection Section

    private var portfolioSelectionSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Portfolios")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(ArkSpacing.xl)
            } else if portfolios.isEmpty {
                emptyPortfoliosView
            } else {
                // First portfolio slot
                portfolioSlot(
                    label: "First Portfolio",
                    portfolio: leftPortfolio,
                    onSelect: { showLeftPicker = true },
                    onClear: { leftPortfolio = nil }
                )

                // Second portfolio slot (optional)
                portfolioSlot(
                    label: "Second Portfolio (optional)",
                    portfolio: rightPortfolio,
                    onSelect: { showRightPicker = true },
                    onClear: { rightPortfolio = nil }
                )

                if leftPortfolio != nil && rightPortfolio != nil {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                        Text("Both portfolios will be shown side-by-side for comparison")
                            .font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }

    private func portfolioSlot(
        label: String,
        portfolio: Portfolio?,
        onSelect: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)

            Button(action: onSelect) {
                HStack(spacing: ArkSpacing.md) {
                    if let portfolio = portfolio {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "wallet.pass.fill")
                                    .font(.body)
                                    .foregroundColor(AppColors.accent)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(portfolio.name)
                                .font(ArkFonts.body)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            if let holdingsList = holdings[portfolio.id] {
                                Text("\(holdingsList.count) assets")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundColor(AppColors.accent)

                        Text("Select Portfolio")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyPortfoliosView: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "wallet.pass")
                .font(.largeTitle)
                .foregroundColor(AppColors.textTertiary)

            Text("No portfolios available")
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)

            Text("Create a portfolio first to share it in broadcasts")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(ArkSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Privacy Level Section

    private var privacyLevelSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Privacy Level")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: ArkSpacing.xs) {
                ForEach(PrivacyLevel.allCases) { level in
                    Button {
                        privacyLevel = level
                    } label: {
                        HStack(spacing: ArkSpacing.md) {
                            Image(systemName: level.icon)
                                .font(.body)
                                .foregroundColor(privacyLevel == level ? AppColors.accent : AppColors.textSecondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName)
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))

                                Text(level.description)
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if privacyLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(ArkSpacing.md)
                        .background(
                            privacyLevel == level
                                ? AppColors.accent.opacity(0.1)
                                : AppColors.cardBackground(colorScheme)
                        )
                        .cornerRadius(ArkSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Caption (optional)")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            TextField("Add a caption for your portfolio showcase...", text: $caption, axis: .vertical)
                .font(ArkFonts.body)
                .lineLimit(2...4)
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Preview")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: ArkSpacing.sm) {
                HStack(spacing: ArkSpacing.sm) {
                    if let left = leftPortfolio, let leftHoldings = holdings[left.id] {
                        miniPortfolioPreview(portfolio: left, holdings: leftHoldings)
                    }

                    if leftPortfolio != nil && rightPortfolio != nil {
                        Text("vs")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }

                    if let right = rightPortfolio, let rightHoldings = holdings[right.id] {
                        miniPortfolioPreview(portfolio: right, holdings: rightHoldings)
                    }
                }

                if !caption.isEmpty {
                    Text(caption)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
    }

    private func miniPortfolioPreview(portfolio: Portfolio, holdings: [PortfolioHolding]) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text(portfolio.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(1)

            // Calculate performance
            let totalValue = holdings.reduce(0) { $0 + $1.currentValue }
            let totalCost = holdings.reduce(0) { $0 + $1.totalCost }
            let performance = totalCost > 0 ? ((totalValue - totalCost) / totalCost) * 100 : 0

            if privacyLevel != .anonymous {
                HStack(spacing: 2) {
                    Image(systemName: performance >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10))
                    Text(String(format: "%+.1f%%", performance))
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(performance >= 0 ? AppColors.success : AppColors.error)
            }

            Text("\(holdings.count) assets")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ArkSpacing.sm)
        .background(Color.black.opacity(0.05))
        .cornerRadius(ArkSpacing.xs)
    }

    // MARK: - Actions

    private func loadPortfolios() async {
        guard let userId = appState.currentUser?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let service = ServiceContainer.shared.portfolioService
            portfolios = try await service.fetchPortfolios(userId: userId)

            // Load holdings for each portfolio
            for portfolio in portfolios {
                let portfolioHoldings = try await service.fetchHoldings(portfolioId: portfolio.id)
                holdings[portfolio.id] = portfolioHoldings
            }
        } catch {
            logError("Failed to load portfolios: \(error)", category: .data)
        }
    }

    private func saveAttachment() {
        var leftSnapshot: PortfolioSnapshot?
        var rightSnapshot: PortfolioSnapshot?

        if let left = leftPortfolio, let leftHoldings = holdings[left.id] {
            leftSnapshot = PortfolioSnapshot(from: left, holdings: leftHoldings, privacyLevel: privacyLevel)
        }

        if let right = rightPortfolio, let rightHoldings = holdings[right.id] {
            rightSnapshot = PortfolioSnapshot(from: right, holdings: rightHoldings, privacyLevel: privacyLevel)
        }

        attachment = BroadcastPortfolioAttachment(
            leftSnapshot: leftSnapshot,
            rightSnapshot: rightSnapshot,
            privacyLevel: privacyLevel,
            caption: caption.isEmpty ? nil : caption
        )
    }
}

// MARK: - Portfolio Selector Sheet

private struct PortfolioSelectorSheet: View {
    let title: String
    let portfolios: [Portfolio]
    @Binding var selectedPortfolio: Portfolio?
    let excludePortfolioId: UUID?

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var availablePortfolios: [Portfolio] {
        if let excludeId = excludePortfolioId {
            return portfolios.filter { $0.id != excludeId }
        }
        return portfolios
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availablePortfolios) { portfolio in
                    Button {
                        selectedPortfolio = portfolio
                        dismiss()
                    } label: {
                        HStack(spacing: ArkSpacing.md) {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "wallet.pass.fill")
                                        .foregroundColor(AppColors.accent)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(portfolio.name)
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))

                                HStack(spacing: ArkSpacing.xs) {
                                    if portfolio.isPublic {
                                        Label("Public", systemImage: "globe")
                                            .font(ArkFonts.caption)
                                            .foregroundColor(AppColors.success)
                                    } else {
                                        Label("Private", systemImage: "lock")
                                            .font(ArkFonts.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }

                            Spacer()

                            if selectedPortfolio?.id == portfolio.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BroadcastPortfolioPicker(attachment: .constant(nil))
        .environmentObject(AppState())
}
