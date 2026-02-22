import Foundation
import SwiftUI

/// Monthly investment amount for DCA tracking
struct MonthlyInvestment: Identifiable, Equatable {
    var id: String { monthKey }
    let monthKey: String  // "2026-02"
    let label: String     // "Feb '26"
    let amount: Double
}

/// Comprehensive portfolio performance metrics (hold/DCA focused)
struct PerformanceMetrics: Equatable {
    // Core returns
    let totalReturn: Double
    let totalReturnPercentage: Double

    // Portfolio summary
    let totalInvested: Double
    let currentValue: Double
    let numberOfAssets: Int

    // Risk metrics
    let maxDrawdown: Double                // Maximum peak-to-trough decline (percentage)
    let maxDrawdownValue: Double           // Maximum drawdown in currency
    let sharpeRatio: Double                // Risk-adjusted return

    // DCA activity
    let monthlyInvestments: [MonthlyInvestment]

    // Derived properties
    var sharpeRating: String {
        switch sharpeRatio {
        case ..<0: return "Poor"
        case 0..<1: return "Below Average"
        case 1..<2: return "Good"
        case 2..<3: return "Very Good"
        default: return "Excellent"
        }
    }

    var sharpeColor: Color {
        switch sharpeRatio {
        case ..<0: return AppColors.error
        case 0..<1: return AppColors.warning
        default: return AppColors.success
        }
    }

    // Empty state for when no data is available
    static let empty = PerformanceMetrics(
        totalReturn: 0,
        totalReturnPercentage: 0,
        totalInvested: 0,
        currentValue: 0,
        numberOfAssets: 0,
        maxDrawdown: 0,
        maxDrawdownValue: 0,
        sharpeRatio: 0,
        monthlyInvestments: []
    )
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable, Identifiable {
    case screenshot = "Screenshot"
    case pdf = "PDF Report"
    case csv = "CSV Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .screenshot: return "camera"
        case .pdf: return "doc.richtext"
        case .csv: return "tablecells"
        }
    }

    var fileExtension: String {
        switch self {
        case .screenshot: return "png"
        case .pdf: return "pdf"
        case .csv: return "csv"
        }
    }

    var mimeType: String {
        switch self {
        case .screenshot: return "image/png"
        case .pdf: return "application/pdf"
        case .csv: return "text/csv"
        }
    }
}
