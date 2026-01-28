import SwiftUI

// MARK: - Portfolio Snapshot Card View

/// Displays a single portfolio snapshot with privacy-aware rendering
struct PortfolioSnapshotCardView: View {
    let snapshot: PortfolioSnapshot
    var onClear: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            headerSection

            // Total Value
            valueSection

            // Performance
            performanceSection

            Divider()
                .background(AppColors.textTertiary.opacity(0.3))

            // Mini Allocation Chart
            MiniAllocationChart(allocations: snapshot.allocations)

            // Top Holdings
            topHoldingsSection
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.md)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.portfolioName)
                    .font(ArkFonts.subheadline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                AssetTypeBadge(type: snapshot.primaryAssetType)
            }

            Spacer()

            if let onClear = onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Value Section

    private var valueSection: some View {
        Group {
            if let totalValue = snapshot.totalValue {
                Text(totalValue.asCurrency)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            } else {
                PrivacyMaskedValue(size: .large)
            }
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        HStack(spacing: ArkSpacing.md) {
            // All-time P/L
            VStack(alignment: .leading, spacing: 2) {
                Text("All Time")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let percentage = snapshot.profitLossPercentage {
                    HStack(spacing: 2) {
                        Image(systemName: percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(String(format: "%+.2f%%", percentage))
                            .font(ArkFonts.bodySemibold)
                    }
                    .foregroundColor(percentage >= 0 ? AppColors.success : AppColors.error)
                } else {
                    PrivacyMaskedValue(size: .small)
                }
            }

            Spacer()

            // Today's change
            VStack(alignment: .trailing, spacing: 2) {
                Text("Today")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let dayChange = snapshot.dayChangePercentage {
                    HStack(spacing: 2) {
                        Image(systemName: dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(String(format: "%+.2f%%", dayChange))
                            .font(ArkFonts.bodySemibold)
                    }
                    .foregroundColor(dayChange >= 0 ? AppColors.success : AppColors.error)
                } else {
                    PrivacyMaskedValue(size: .small)
                }
            }
        }
    }

    // MARK: - Top Holdings Section

    private var topHoldingsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            ForEach(snapshot.holdings.prefix(3)) { holding in
                CompactHoldingRow(holding: holding)
            }

            if snapshot.holdings.count > 3 {
                Text("+\(snapshot.holdings.count - 3) more")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Asset Type Badge

struct AssetTypeBadge: View {
    let type: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(badgeColor)
            .padding(.horizontal, ArkSpacing.xs)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var displayName: String {
        switch type.lowercased() {
        case "crypto": return "Crypto"
        case "stock": return "Stocks"
        case "metal": return "Metals"
        case "real_estate": return "Real Estate"
        case "mixed": return "Mixed"
        default: return type.capitalized
        }
    }

    private var badgeColor: Color {
        switch type.lowercased() {
        case "crypto": return Color(hex: "6366F1")
        case "stock": return Color(hex: "22C55E")
        case "metal": return Color(hex: "F59E0B")
        case "real_estate": return Color(hex: "3B82F6")
        default: return AppColors.textSecondary
        }
    }
}

// MARK: - Privacy Masked Value

struct PrivacyMaskedValue: View {
    enum Size { case small, medium, large }
    var size: Size = .medium

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { _ in
                Circle()
                    .fill(AppColors.textSecondary.opacity(0.4))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }

    private var dotCount: Int {
        switch size {
        case .small: return 3
        case .medium: return 4
        case .large: return 5
        }
    }

    private var dotSize: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }

    private var dotSpacing: CGFloat {
        switch size {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
}

// MARK: - Compact Holding Row

struct CompactHoldingRow: View {
    let holding: HoldingSnapshot
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            // Icon placeholder
            Circle()
                .fill(assetColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(holding.symbol.prefix(1)))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(assetColor)
                )

            // Symbol and name
            VStack(alignment: .leading, spacing: 0) {
                Text(holding.symbol.uppercased())
                    .font(ArkFonts.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(holding.name)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Value or allocation
            VStack(alignment: .trailing, spacing: 0) {
                if let value = holding.currentValue {
                    Text(value.asCurrency)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                } else {
                    Text(String(format: "%.1f%%", holding.allocationPercentage))
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                if let perf = holding.profitLossPercentage {
                    Text(String(format: "%+.1f%%", perf))
                        .font(.system(size: 10))
                        .foregroundColor(perf >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
    }

    private var assetColor: Color {
        switch holding.assetType.lowercased() {
        case "crypto": return Color(hex: "6366F1")
        case "stock": return Color(hex: "22C55E")
        case "metal": return Color(hex: "F59E0B")
        default: return AppColors.accent
        }
    }
}

// MARK: - Mini Allocation Chart

struct MiniAllocationChart: View {
    let allocations: [AllocationSnapshot]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            // Bar chart
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(allocations) { allocation in
                        Rectangle()
                            .fill(allocation.swiftUIColor)
                            .frame(width: max(4, geometry.size.width * (allocation.percentage / 100)))
                    }
                }
            }
            .frame(height: 8)
            .cornerRadius(4)

            // Legend
            HStack(spacing: ArkSpacing.sm) {
                ForEach(allocations.prefix(3)) { allocation in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(allocation.swiftUIColor)
                            .frame(width: 6, height: 6)

                        Text(allocation.category)
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)

                        Text(String(format: "%.0f%%", allocation.percentage))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }

                if allocations.count > 3 {
                    Text("+\(allocations.count - 3)")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
    }
}

// MARK: - Currency Formatting Extension

extension Double {
    var asCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"

        if self >= 1_000_000 {
            formatter.maximumFractionDigits = 1
            return (formatter.string(from: NSNumber(value: self / 1_000_000)) ?? "$0") + "M"
        } else if self >= 10_000 {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "$0"
        } else {
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: self)) ?? "$0"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PortfolioSnapshotCardView(
            snapshot: PortfolioSnapshot(
                id: UUID(),
                portfolioId: UUID(),
                portfolioName: "Crypto Portfolio",
                snapshotDate: Date(),
                privacyLevel: .full,
                totalValue: 45230.50,
                totalCost: 35000,
                totalProfitLoss: 10230.50,
                profitLossPercentage: 29.23,
                dayChange: 523.20,
                dayChangePercentage: 1.17,
                holdings: [
                    HoldingSnapshot(id: UUID(), symbol: "BTC", name: "Bitcoin", assetType: "crypto", iconUrl: nil, quantity: 0.5, currentValue: 25000, profitLoss: 5000, profitLossPercentage: 25, allocationPercentage: 55),
                    HoldingSnapshot(id: UUID(), symbol: "ETH", name: "Ethereum", assetType: "crypto", iconUrl: nil, quantity: 5, currentValue: 15000, profitLoss: 3000, profitLossPercentage: 25, allocationPercentage: 33),
                    HoldingSnapshot(id: UUID(), symbol: "SOL", name: "Solana", assetType: "crypto", iconUrl: nil, quantity: 50, currentValue: 5230, profitLoss: 2230, profitLossPercentage: 74, allocationPercentage: 12)
                ],
                allocations: [
                    AllocationSnapshot(category: "Crypto", percentage: 100, value: 45230.50, color: "#6366F1")
                ],
                assetCount: 3,
                primaryAssetType: "crypto"
            ),
            onClear: {}
        )
        .frame(width: 180)
    }
    .padding()
    .background(Color.black)
}
