import Foundation
import SwiftUI

/// Comprehensive portfolio performance metrics
struct PerformanceMetrics: Equatable {
    // Core returns
    let totalReturn: Double
    let totalReturnPercentage: Double

    // Win/Loss metrics
    let winRate: Double                    // % of profitable trades (0-100)
    let averageWin: Double                 // Average profit on winning trades
    let averageLoss: Double                // Average loss on losing trades
    let profitFactor: Double               // averageWin / averageLoss ratio

    // Risk metrics
    let maxDrawdown: Double                // Maximum peak-to-trough decline (percentage)
    let maxDrawdownValue: Double           // Maximum drawdown in currency
    let sharpeRatio: Double                // Risk-adjusted return

    // Trade statistics
    let numberOfTrades: Int                // Total closed trades
    let winningTrades: Int                 // Number of profitable trades
    let losingTrades: Int                  // Number of losing trades
    let averageHoldingPeriodDays: Double   // Average time holding positions

    // Derived properties
    var riskRewardRatio: String {
        guard averageLoss != 0 else { return "N/A" }
        let ratio = abs(averageWin / averageLoss)
        return String(format: "1:%.1f", ratio)
    }

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

    var holdingPeriodDescription: String {
        switch averageHoldingPeriodDays {
        case ..<7: return "Day Trading"
        case 7..<30: return "Swing Trading"
        case 30..<90: return "Position Trading"
        default: return "Long-term Holding"
        }
    }

    // Empty state for when no data is available
    static let empty = PerformanceMetrics(
        totalReturn: 0,
        totalReturnPercentage: 0,
        winRate: 0,
        averageWin: 0,
        averageLoss: 0,
        profitFactor: 0,
        maxDrawdown: 0,
        maxDrawdownValue: 0,
        sharpeRatio: 0,
        numberOfTrades: 0,
        winningTrades: 0,
        losingTrades: 0,
        averageHoldingPeriodDays: 0
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
