import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Showcase Export Preview

/// Preview and export the portfolio showcase as an image
struct ShowcaseExportPreview: View {
    @Bindable var viewModel: PortfolioShowcaseViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Preview Section
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Preview")
                            .font(ArkFonts.subheadline)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        // Exportable view preview
                        ExportableShowcaseView(
                            leftSnapshot: viewModel.leftSnapshot,
                            rightSnapshot: viewModel.rightSnapshot,
                            showBranding: viewModel.configuration.showBranding,
                            showTimestamp: viewModel.configuration.showTimestamp
                        )
                        .frame(maxWidth: .infinity)
                        .cornerRadius(ArkSpacing.md)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }

                    // Options Section
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Options")
                            .font(ArkFonts.subheadline)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        VStack(spacing: 0) {
                            Toggle(isOn: $viewModel.configuration.showBranding) {
                                HStack {
                                    Image(systemName: "star.circle")
                                        .foregroundColor(AppColors.accent)
                                    Text("Show ArkLine Branding")
                                        .font(ArkFonts.body)
                                }
                            }
                            .tint(AppColors.accent)
                            .padding(ArkSpacing.md)

                            Divider()

                            Toggle(isOn: $viewModel.configuration.showTimestamp) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(AppColors.accent)
                                    Text("Show Timestamp")
                                        .font(ArkFonts.body)
                                }
                            }
                            .tint(AppColors.accent)
                            .padding(ArkSpacing.md)
                        }
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                    }

                    // Privacy reminder
                    HStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "lock.shield")
                            .foregroundColor(AppColors.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy: \(viewModel.configuration.privacyLevel.displayName)")
                                .font(ArkFonts.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text("Go back to change privacy level before exporting")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(ArkSpacing.sm)
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await exportImage()
                        }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .alert("Export Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Export Image

    @MainActor
    private func exportImage() async {
        isExporting = true
        defer { isExporting = false }

        do {
            // Create the exportable view
            let exportView = ExportableShowcaseView(
                leftSnapshot: viewModel.leftSnapshot,
                rightSnapshot: viewModel.rightSnapshot,
                showBranding: viewModel.configuration.showBranding,
                showTimestamp: viewModel.configuration.showTimestamp
            )
            .environment(\.colorScheme, .dark) // Force dark mode for export

            // Determine size based on content
            let width: CGFloat = 390
            let height: CGFloat = viewModel.hasBothPortfolios ? 480 : 380

            // Render to image
            let renderer = ImageRenderer(content: exportView.frame(width: width, height: height))
            renderer.scale = 3.0 // High resolution

            guard let uiImage = renderer.uiImage else {
                throw ExportError.renderFailed
            }

            // Present share sheet
            shareImage(uiImage)

        } catch {
            errorMessage = error.localizedDescription
            showError = true
            logError("Export failed: \(error)", category: .ui)
        }
    }

    private func shareImage(_ image: UIImage) {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        // iPad presentation
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
        #endif
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render image"
        }
    }
}

// MARK: - Exportable Showcase View

/// The actual view that gets rendered to an image
struct ExportableShowcaseView: View {
    let leftSnapshot: PortfolioSnapshot?
    let rightSnapshot: PortfolioSnapshot?
    let showBranding: Bool
    let showTimestamp: Bool

    var body: some View {
        VStack(spacing: ArkSpacing.md) {
            // Header with branding
            if showBranding {
                HStack {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)

                        Text("ArkLine")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if showTimestamp {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.top, ArkSpacing.md)
            }

            // Portfolio cards
            HStack(alignment: .top, spacing: ArkSpacing.sm) {
                if let left = leftSnapshot {
                    ExportablePortfolioCard(snapshot: left)
                }

                if leftSnapshot != nil && rightSnapshot != nil {
                    // VS divider
                    VStack {
                        Spacer()
                        Text("VS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(hex: "2A2A2A"))
                            .cornerRadius(4)
                        Spacer()
                    }
                    .frame(width: 30)
                }

                if let right = rightSnapshot {
                    ExportablePortfolioCard(snapshot: right)
                }
            }
            .padding(.horizontal, ArkSpacing.md)

            // Footer
            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.bottom, ArkSpacing.sm)
            }
        }
        .padding(.vertical, ArkSpacing.sm)
        .background(Color(hex: "121212"))
    }
}

// MARK: - Exportable Portfolio Card

/// Simplified card for image export
private struct ExportablePortfolioCard: View {
    let snapshot: PortfolioSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack {
                Text(snapshot.portfolioName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text(snapshot.primaryAssetType.capitalized)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.2))
                    .cornerRadius(4)
            }

            // Value
            if let value = snapshot.totalValue {
                Text(value.asCurrency)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
            }

            // Performance
            HStack {
                if let perf = snapshot.profitLossPercentage {
                    HStack(spacing: 2) {
                        Image(systemName: perf >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text(String(format: "%+.2f%%", perf))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(perf >= 0 ? AppColors.success : AppColors.error)
                }

                Spacer()

                Text("\(snapshot.assetCount) assets")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Allocation bar
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(snapshot.allocations) { allocation in
                        Rectangle()
                            .fill(allocation.swiftUIColor)
                            .frame(width: max(2, geometry.size.width * (allocation.percentage / 100)))
                    }
                }
            }
            .frame(height: 6)
            .cornerRadius(3)

            // Top 3 holdings
            ForEach(snapshot.holdings.prefix(3)) { holding in
                HStack(spacing: ArkSpacing.xs) {
                    Circle()
                        .fill(holdingColor(holding.assetType).opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String(holding.symbol.prefix(1)))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(holdingColor(holding.assetType))
                        )

                    Text(holding.symbol.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Text(String(format: "%.1f%%", holding.allocationPercentage))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(ArkSpacing.sm)
        .background(Color(hex: "1E1E1E"))
        .cornerRadius(ArkSpacing.sm)
    }

    private var badgeColor: Color {
        switch snapshot.primaryAssetType.lowercased() {
        case "crypto": return Color(hex: "6366F1")
        case "stock": return Color(hex: "22C55E")
        case "metal": return Color(hex: "F59E0B")
        default: return AppColors.accent
        }
    }

    private func holdingColor(_ assetType: String) -> Color {
        switch assetType.lowercased() {
        case "crypto": return Color(hex: "6366F1")
        case "stock": return Color(hex: "22C55E")
        case "metal": return Color(hex: "F59E0B")
        default: return AppColors.accent
        }
    }
}

// MARK: - Preview

#Preview {
    ShowcaseExportPreview(
        viewModel: PortfolioShowcaseViewModel()
    )
}
