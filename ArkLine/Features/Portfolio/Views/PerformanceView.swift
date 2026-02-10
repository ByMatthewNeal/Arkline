import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var showExportSheet = false
    @State private var isExporting = false

    private var hasData: Bool {
        viewModel.performanceMetrics.numberOfTrades > 0 || !viewModel.historyPoints.isEmpty
    }

    var body: some View {
        Group {
            if hasData {
                performanceContent
            } else {
                EmptyPerformanceState()
                    .padding(.top, 40)
            }
        }
    }

    private var performanceContent: some View {
        VStack(spacing: 20) {
            // Summary Header Card
            PerformanceSummaryCard(metrics: viewModel.performanceMetrics)
                .padding(.horizontal, 20)

            // Win/Loss Stats
            if viewModel.performanceMetrics.numberOfTrades > 0 {
                WinLossStatsCard(metrics: viewModel.performanceMetrics)
                    .padding(.horizontal, 20)
            }

            // Risk Metrics
            RiskMetricsCard(metrics: viewModel.performanceMetrics)
                .padding(.horizontal, 20)
                .premiumRequired(.advancedPortfolio)

            // Equity Curve
            if !viewModel.historyPoints.isEmpty {
                EquityCurveCard(historyPoints: viewModel.historyPoints)
                    .padding(.horizontal, 20)
                    .premiumRequired(.advancedPortfolio)
            }

            // Export Button
            Button(action: { showExportSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                    Text("Export Report")
                        .font(AppFonts.body14Bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.accent)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .premiumRequired(.exportData)

            Spacer(minLength: 100)
        }
        .padding(.top, 20)
        .confirmationDialog("Export Format", isPresented: $showExportSheet, titleVisibility: .visible) {
            ForEach(ExportFormat.allCases) { format in
                Button {
                    exportData(format: format)
                } label: {
                    Label(format.rawValue, systemImage: format.icon)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .overlay {
            if isExporting {
                exportingOverlay
            }
        }
    }

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    .scaleEffect(1.2)

                Text("Generating export...")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }

    private func exportData(format: ExportFormat) {
        isExporting = true

        Task {
            defer {
                Task { @MainActor in
                    isExporting = false
                }
            }

            var fileData: Data?
            let portfolioName = viewModel.selectedPortfolio?.name ?? "Portfolio"
            let fileName = "\(portfolioName)_Performance_\(formatDateForFileName())"

            switch format {
            case .screenshot:
                fileData = ExportService.captureScreenshot(
                    of: PerformanceExportView(
                        portfolioName: portfolioName,
                        metrics: viewModel.performanceMetrics,
                        historyPoints: viewModel.historyPoints
                    ),
                    size: CGSize(width: 390, height: 844)
                )

            case .pdf:
                fileData = ExportService.generatePDF(
                    portfolioName: portfolioName,
                    metrics: viewModel.performanceMetrics,
                    holdings: viewModel.holdings,
                    transactions: viewModel.transactions,
                    historyPoints: viewModel.historyPoints
                )

            case .csv:
                fileData = ExportService.generateCSV(
                    portfolioName: portfolioName,
                    metrics: viewModel.performanceMetrics,
                    holdings: viewModel.holdings,
                    transactions: viewModel.transactions
                )
            }

            if let data = fileData {
                ExportService.shareFile(data: data, fileName: fileName, format: format)
            }
        }
    }

    private func formatDateForFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    PerformanceView(viewModel: PortfolioViewModel())
}
