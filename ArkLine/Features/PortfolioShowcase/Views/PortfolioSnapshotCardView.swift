import SwiftUI

// MARK: - Portfolio Snapshot Card View

/// Displays a single portfolio snapshot with privacy-aware rendering
struct PortfolioSnapshotCardView: View {
    let snapshot: PortfolioSnapshot
    var onClear: (() -> Void)? = nil
    var chartPalette: Constants.ChartColorPalette = .classic
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            // Header with name and clear button
            headerSection

            // Performance + Donut chart side by side
            HStack(alignment: .center) {
                performanceSection
                Spacer()
                MiniDonutChart(allocations: snapshot.allocations, chartPalette: chartPalette, size: 40)
            }

            // Top Holdings (simplified)
            holdingsSection
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.portfolioName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                AssetTypeBadge(type: snapshot.primaryAssetType, chartPalette: chartPalette)
            }

            Spacer()

            if let onClear = onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textTertiary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // All-time performance (main metric)
            if let percentage = snapshot.profitLossPercentage {
                HStack(spacing: 4) {
                    Image(systemName: percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text(String(format: "%+.1f%%", percentage))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundColor(percentage >= 0 ? AppColors.success : AppColors.error)
            } else {
                PrivacyMaskedValue(size: .medium)
            }

            // Asset count
            Text("\(snapshot.assetCount) assets")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Holdings Section

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(snapshot.holdings.prefix(3)) { holding in
                SimpleHoldingRow(holding: holding, chartPalette: chartPalette)
            }

            if snapshot.holdings.count > 3 {
                Text("+\(snapshot.holdings.count - 3) more")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
}

// MARK: - Asset Type Badge

struct AssetTypeBadge: View {
    let type: String
    var chartPalette: Constants.ChartColorPalette = .classic

    var body: some View {
        Text(displayName)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .cornerRadius(4)
    }

    private var displayName: String {
        switch type.lowercased() {
        case "crypto": return "Crypto"
        case "stock", "stocks": return "Stocks"
        case "metal", "metals": return "Metals"
        case "real_estate", "realestate": return "Real Estate"
        case "mixed": return "Mixed"
        default: return type.capitalized
        }
    }

    private var badgeColor: Color {
        if type.lowercased() == "mixed" {
            return Color.gray
        }
        return chartPalette.colors.color(for: type)
    }
}

// MARK: - Privacy Masked Value

struct PrivacyMaskedValue: View {
    enum Size { case small, medium, large }
    var size: Size = .medium

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }

    private var dotSize: CGFloat {
        switch size {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        }
    }
}

// MARK: - Simple Holding Row

struct SimpleHoldingRow: View {
    let holding: HoldingSnapshot
    var chartPalette: Constants.ChartColorPalette = .classic
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // Colored dot
            Circle()
                .fill(chartPalette.colors.color(for: holding.assetType))
                .frame(width: 8, height: 8)

            // Symbol
            Text(holding.symbol.uppercased())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            // Allocation percentage
            Text(String(format: "%.0f%%", holding.allocationPercentage))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            // Performance (if available)
            if let perf = holding.profitLossPercentage {
                Text(String(format: "%+.0f%%", perf))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(perf >= 0 ? AppColors.success : AppColors.error)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

// MARK: - Mini Donut Chart

struct MiniDonutChart: View {
    let allocations: [AllocationSnapshot]
    var chartPalette: Constants.ChartColorPalette = .classic
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 6)

            // Allocation segments
            ForEach(Array(allocations.enumerated()), id: \.element.id) { index, allocation in
                Circle()
                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                    .stroke(colorFor(allocation), style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    private func colorFor(_ allocation: AllocationSnapshot) -> Color {
        chartPalette.colors.color(for: allocation.category)
    }

    private func startAngle(for index: Int) -> CGFloat {
        let preceding = allocations.prefix(index).reduce(0) { $0 + $1.percentage }
        return preceding / 100
    }

    private func endAngle(for index: Int) -> CGFloat {
        let including = allocations.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return including / 100
    }
}

// MARK: - Allocation Bar (kept for compatibility)

struct AllocationBar: View {
    let allocations: [AllocationSnapshot]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(allocations) { allocation in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(allocation.swiftUIColor)
                        .frame(width: max(4, geometry.size.width * (allocation.percentage / 100)))
                }
            }
        }
        .frame(height: 6)
        .cornerRadius(3)
    }
}

// MARK: - Compact Holding Row (kept for compatibility)

struct CompactHoldingRow: View {
    let holding: HoldingSnapshot
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        SimpleHoldingRow(holding: holding)
    }
}

// MARK: - Mini Allocation Chart (kept for compatibility)

struct MiniAllocationChart: View {
    let allocations: [AllocationSnapshot]

    var body: some View {
        AllocationBar(allocations: allocations)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        PortfolioSnapshotCardView(
            snapshot: PortfolioSnapshot(
                id: UUID(),
                portfolioId: UUID(),
                portfolioName: "Crypto Portfolio",
                snapshotDate: Date(),
                privacyLevel: .percentageOnly,
                totalValue: nil,
                totalCost: nil,
                totalProfitLoss: nil,
                profitLossPercentage: 37.66,
                dayChange: nil,
                dayChangePercentage: nil,
                holdings: [
                    HoldingSnapshot(id: UUID(), symbol: "BTC", name: "Bitcoin", assetType: "crypto", iconUrl: nil, quantity: nil, currentValue: nil, profitLoss: nil, profitLossPercentage: 50, allocationPercentage: 61),
                    HoldingSnapshot(id: UUID(), symbol: "ETH", name: "Ethereum", assetType: "crypto", iconUrl: nil, quantity: nil, currentValue: nil, profitLoss: nil, profitLossPercentage: 23, allocationPercentage: 20),
                    HoldingSnapshot(id: UUID(), symbol: "SOL", name: "Solana", assetType: "crypto", iconUrl: nil, quantity: nil, currentValue: nil, profitLoss: nil, profitLossPercentage: 46, allocationPercentage: 8)
                ],
                allocations: [
                    AllocationSnapshot(category: "Crypto", percentage: 89, value: nil, color: "#6366F1"),
                    AllocationSnapshot(category: "Metal", percentage: 7, value: nil, color: "#F59E0B"),
                    AllocationSnapshot(category: "Stock", percentage: 4, value: nil, color: "#22C55E")
                ],
                assetCount: 5,
                primaryAssetType: "crypto"
            ),
            onClear: {}
        )
    }
    .padding()
    .background(Color(hex: "F5F5F7"))
}
