import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Service for exporting portfolio data in various formats
final class ExportService {

    // MARK: - Screenshot Export

    @MainActor
    static func captureScreenshot<V: View>(of view: V, size: CGSize) -> Data? {
        #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = UIColor(Color(hex: "0F0F0F"))

        // Force layout
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        return image.pngData()
        #else
        return nil
        #endif
    }

    // MARK: - PDF Export

    static func generatePDF(
        portfolioName: String,
        metrics: PerformanceMetrics,
        holdings: [PortfolioHolding],
        transactions: [Transaction],
        historyPoints: [PortfolioHistoryPoint]
    ) -> Data? {
        #if canImport(UIKit)
        let pageWidth: CGFloat = 612  // Letter size
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfData = NSMutableData()

        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), nil)
        UIGraphicsBeginPDFPage()

        var yPosition: CGFloat = margin

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let title = "\(portfolioName) Performance Report"
        title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 40

        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        let dateString = "Generated: \(dateFormatter.string(from: Date()))"
        dateString.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
        yPosition += 35

        // Metrics Section Header
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        "Performance Metrics".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
        yPosition += 25

        // Metrics
        let metricAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]

        let metricsText = [
            "Total Return: \(formatCurrency(metrics.totalReturn)) (\(formatPercent(metrics.totalReturnPercentage)))",
            "Total Invested: \(formatCurrency(metrics.totalInvested))",
            "Current Value: \(formatCurrency(metrics.currentValue))",
            "Number of Assets: \(metrics.numberOfAssets)",
            "Max Drawdown: \(String(format: "%.2f", metrics.maxDrawdown))% (\(formatCurrency(metrics.maxDrawdownValue)))",
            "Sharpe Ratio: \(String(format: "%.2f", metrics.sharpeRatio)) (\(metrics.sharpeRating))"
        ]

        for metric in metricsText {
            metric.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: metricAttributes)
            yPosition += 18
        }

        yPosition += 20

        // Holdings Section
        if !holdings.isEmpty {
            "Current Holdings".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 25

            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            "Symbol          Value               P/L".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            yPosition += 15

            let holdingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]

            for holding in holdings.prefix(10) {
                let pnlSign = holding.profitLoss >= 0 ? "+" : ""
                let line = "\(holding.symbol.padding(toLength: 16, withPad: " ", startingAt: 0))\(formatCurrency(holding.currentValue).padding(toLength: 20, withPad: " ", startingAt: 0))\(pnlSign)\(formatCurrency(holding.profitLoss))"
                line.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: holdingAttributes)
                yPosition += 14

                if yPosition > pageHeight - margin {
                    UIGraphicsBeginPDFPage()
                    yPosition = margin
                }
            }

            if holdings.count > 10 {
                "... and \(holdings.count - 10) more holdings".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: holdingAttributes)
                yPosition += 14
            }
        }

        // Footer
        yPosition = pageHeight - margin
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.lightGray
        ]
        "Generated by ArkLine".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)

        UIGraphicsEndPDFContext()

        return pdfData as Data
        #else
        return nil
        #endif
    }

    // MARK: - CSV Export

    static func generateCSV(
        portfolioName: String,
        metrics: PerformanceMetrics,
        holdings: [PortfolioHolding],
        transactions: [Transaction]
    ) -> Data? {
        var csv = "ArkLine Portfolio Export\n"
        csv += "Portfolio: \(portfolioName)\n"
        csv += "Generated: \(ISO8601DateFormatter().string(from: Date()))\n\n"

        // Metrics section
        csv += "PERFORMANCE METRICS\n"
        csv += "Metric,Value\n"
        csv += "Total Return,$\(String(format: "%.2f", metrics.totalReturn))\n"
        csv += "Total Return %,\(String(format: "%.2f", metrics.totalReturnPercentage))%\n"
        csv += "Total Invested,$\(String(format: "%.2f", metrics.totalInvested))\n"
        csv += "Current Value,$\(String(format: "%.2f", metrics.currentValue))\n"
        csv += "Number of Assets,\(metrics.numberOfAssets)\n"
        csv += "Max Drawdown %,\(String(format: "%.2f", metrics.maxDrawdown))%\n"
        csv += "Max Drawdown Value,$\(String(format: "%.2f", metrics.maxDrawdownValue))\n"
        csv += "Sharpe Ratio,\(String(format: "%.2f", metrics.sharpeRatio))\n\n"

        // Holdings section
        csv += "HOLDINGS\n"
        csv += "Symbol,Name,Quantity,Avg Buy Price,Current Price,Current Value,P/L,P/L %\n"
        for holding in holdings {
            let name = holding.name.replacingOccurrences(of: ",", with: " ")
            csv += "\(holding.symbol),"
            csv += "\"\(name)\","
            csv += "\(String(format: "%.8f", holding.quantity)),"
            csv += "\(String(format: "%.2f", holding.averageBuyPrice ?? 0)),"
            csv += "\(String(format: "%.2f", holding.currentPrice ?? 0)),"
            csv += "\(String(format: "%.2f", holding.currentValue)),"
            csv += "\(String(format: "%.2f", holding.profitLoss)),"
            csv += "\(String(format: "%.2f", holding.profitLossPercentage))%\n"
        }

        csv += "\nTRANSACTIONS\n"
        csv += "Date,Type,Symbol,Quantity,Price,Total Value,Realized P/L,Notes\n"
        let dateFormatter = ISO8601DateFormatter()
        for tx in transactions.sorted(by: { $0.transactionDate > $1.transactionDate }) {
            let notes = (tx.notes ?? "").replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
            csv += "\(dateFormatter.string(from: tx.transactionDate)),"
            csv += "\(tx.type.displayName),"
            csv += "\(tx.symbol),"
            csv += "\(String(format: "%.8f", tx.quantity)),"
            csv += "\(String(format: "%.2f", tx.pricePerUnit)),"
            csv += "\(String(format: "%.2f", tx.totalValue)),"
            csv += "\(String(format: "%.2f", tx.realizedProfitLoss ?? 0)),"
            csv += "\"\(notes)\"\n"
        }

        return csv.data(using: .utf8)
    }

    // MARK: - Share File

    @MainActor
    static func shareFile(data: Data, fileName: String, format: ExportFormat) {
        #if canImport(UIKit)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).\(format.fileExtension)")

        do {
            try data.write(to: tempURL)

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
                activityItems: [tempURL],
                applicationActivities: nil
            )

            // iPad popover support
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
        } catch {
            logError("Export error: \(error)", category: .general)
        }
        #endif
    }

    // MARK: - Helpers

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private static func formatPercent(_ value: Double) -> String {
        return "\(value >= 0 ? "+" : "")\(String(format: "%.2f", value))%"
    }
}
