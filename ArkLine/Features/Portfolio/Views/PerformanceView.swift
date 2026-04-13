import SwiftUI

struct PerformanceView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: PortfolioViewModel
    @State private var showExportSheet = false
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var selectedPeriod: PerformancePeriod = .all

    enum PerformancePeriod: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"
        case year = "1Y"
        case all = "All"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return nil
            }
        }
    }

    private var hasData: Bool {
        !viewModel.holdings.isEmpty
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

    private var filteredHistoryPoints: [PortfolioHistoryPoint] {
        guard let days = selectedPeriod.days else { return viewModel.historyPoints }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return viewModel.historyPoints.filter { $0.date >= cutoff }
    }

    private var performanceContent: some View {
        VStack(spacing: 20) {
            // Time period picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(PerformancePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Return Summary
            ReturnSummaryCard(metrics: viewModel.performanceMetrics)
                .padding(.horizontal, 20)

            // Risk Metrics
            RiskMetricsCard(metrics: viewModel.performanceMetrics)
                .padding(.horizontal, 20)

            // Portfolio Value Chart
            if !filteredHistoryPoints.isEmpty {
                EquityCurveCard(historyPoints: filteredHistoryPoints)
                    .padding(.horizontal, 20)
                    .premiumRequired(.advancedPortfolio)
            }

            // Per-Asset Performance
            AssetPerformanceCard(
                holdings: viewModel.holdings,
                totalValue: viewModel.performanceMetrics.currentValue
            )
            .padding(.horizontal, 20)
            .premiumRequired(.advancedPortfolio)

            // Investment Activity
            InvestmentActivityCard(monthlyInvestments: viewModel.performanceMetrics.monthlyInvestments)
                .padding(.horizontal, 20)

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
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Unable to generate the export. Please try again.")
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
                        historyPoints: viewModel.historyPoints,
                        holdings: viewModel.holdings
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
            } else {
                await MainActor.run {
                    showExportError = true
                }
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
