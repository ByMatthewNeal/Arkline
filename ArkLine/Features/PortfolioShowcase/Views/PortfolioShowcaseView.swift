import SwiftUI

// MARK: - Portfolio Showcase View

/// Main entry point for creating portfolio comparisons with privacy controls
struct PortfolioShowcaseView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var viewModel = PortfolioShowcaseViewModel()
    @State private var showLeftPicker = false
    @State private var showRightPicker = false
    @State private var showExportPreview = false

    var body: some View {
        NavigationStack {
            if appState.isPro {
                showcaseContent
            } else {
                PremiumFeatureGate(feature: .portfolioShowcase) {}
            }
        }
    }

    private var showcaseContent: some View {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Privacy Level Selector
                    PrivacyFilterSelector(selectedLevel: $viewModel.configuration.privacyLevel)
                        .onChange(of: viewModel.configuration.privacyLevel) { _, _ in
                            // Privacy level change triggers snapshot regeneration in ViewModel
                        }

                    // Dual Portfolio Comparison
                    DualPortfolioComparisonView(
                        leftSnapshot: viewModel.leftSnapshot,
                        rightSnapshot: viewModel.rightSnapshot,
                        isLoadingLeft: viewModel.isLoadingLeft,
                        isLoadingRight: viewModel.isLoadingRight,
                        onSelectLeft: { showLeftPicker = true },
                        onSelectRight: { showRightPicker = true },
                        onClearLeft: { viewModel.clearLeftPortfolio() },
                        onClearRight: { viewModel.clearRightPortfolio() },
                        onSwap: { viewModel.swapPortfolios() }
                    )

                    // Comparison Summary (when both selected)
                    if viewModel.hasBothPortfolios {
                        ComparisonSummaryView(
                            left: viewModel.leftSnapshot!,
                            right: viewModel.rightSnapshot!
                        )
                    }

                    // Export hint
                    if viewModel.hasAnyPortfolio {
                        HStack(spacing: ArkSpacing.xs) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Tap the share button to export as image")
                                .font(ArkFonts.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, ArkSpacing.sm)
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Portfolio Showcase")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showExportPreview = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!viewModel.canExport)
                }
            }
            .sheet(isPresented: $showLeftPicker) {
                ShowcasePortfolioPicker(
                    title: "Select Left Portfolio",
                    portfolios: viewModel.availableForLeft,
                    onSelect: { portfolio in
                        Task {
                            await viewModel.selectLeftPortfolio(portfolio)
                        }
                    }
                )
            }
            .sheet(isPresented: $showRightPicker) {
                ShowcasePortfolioPicker(
                    title: "Select Right Portfolio",
                    portfolios: viewModel.availableForRight,
                    onSelect: { portfolio in
                        Task {
                            await viewModel.selectRightPortfolio(portfolio)
                        }
                    }
                )
            }
            .sheet(isPresented: $showExportPreview) {
                ShowcaseExportPreview(viewModel: viewModel)
            }
            .task {
                if let userId = appState.currentUser?.id {
                    await viewModel.loadPortfolios(userId: userId)
                }
            }
    }
}

// MARK: - Comparison Summary View

private struct ComparisonSummaryView: View {
    let left: PortfolioSnapshot
    let right: PortfolioSnapshot
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Comparison")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: ArkSpacing.xs) {
                // Performance comparison
                if let leftPerf = left.profitLossPercentage,
                   let rightPerf = right.profitLossPercentage {
                    ComparisonRow(
                        label: "Performance",
                        leftValue: String(format: "%+.2f%%", leftPerf),
                        rightValue: String(format: "%+.2f%%", rightPerf),
                        leftColor: leftPerf >= 0 ? AppColors.success : AppColors.error,
                        rightColor: rightPerf >= 0 ? AppColors.success : AppColors.error,
                        winner: leftPerf > rightPerf ? .left : (rightPerf > leftPerf ? .right : .tie)
                    )
                }

                // Asset count comparison
                ComparisonRow(
                    label: "Assets",
                    leftValue: "\(left.assetCount)",
                    rightValue: "\(right.assetCount)",
                    leftColor: AppColors.textPrimary(colorScheme),
                    rightColor: AppColors.textPrimary(colorScheme),
                    winner: left.assetCount > right.assetCount ? .left : (right.assetCount > left.assetCount ? .right : .tie)
                )

                // Day change comparison
                if let leftDay = left.dayChangePercentage,
                   let rightDay = right.dayChangePercentage {
                    ComparisonRow(
                        label: "Today",
                        leftValue: String(format: "%+.2f%%", leftDay),
                        rightValue: String(format: "%+.2f%%", rightDay),
                        leftColor: leftDay >= 0 ? AppColors.success : AppColors.error,
                        rightColor: rightDay >= 0 ? AppColors.success : AppColors.error,
                        winner: leftDay > rightDay ? .left : (rightDay > leftDay ? .right : .tie)
                    )
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
    }
}

private struct ComparisonRow: View {
    let label: String
    let leftValue: String
    let rightValue: String
    let leftColor: Color
    let rightColor: Color
    let winner: Winner

    enum Winner { case left, right, tie }

    var body: some View {
        HStack {
            // Left value
            HStack(spacing: ArkSpacing.xxs) {
                if winner == .left {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)
                }
                Text(leftValue)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(leftColor)
            }
            .frame(maxWidth: .infinity)

            // Label
            Text(label)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 80)

            // Right value
            HStack(spacing: ArkSpacing.xxs) {
                Text(rightValue)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(rightColor)
                if winner == .right {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    PortfolioShowcaseView()
        .environmentObject(AppState())
}
