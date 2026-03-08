import SwiftUI

// MARK: - Trade Structure Chart

/// Visual price-level diagram showing golden pocket entry zone, targets, and stop loss.
struct TradeStructureChart: View {
    let signal: TradeSignal
    @Environment(\.colorScheme) private var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : .white }

    private var isLong: Bool { signal.signalType.isBuy }

    // All price levels for computing the chart scale
    private var levels: [PriceLevel] {
        var result: [PriceLevel] = []

        if let t2 = signal.target2 {
            result.append(PriceLevel(price: t2, label: "T2", type: .target2))
        }
        if let t1 = signal.target1 {
            result.append(PriceLevel(price: t1, label: "T1", type: .target1))
        }
        result.append(PriceLevel(price: signal.entryZoneHigh, label: "", type: .entryHigh))
        result.append(PriceLevel(price: signal.entryPriceMid, label: "Entry", type: .entryMid))
        result.append(PriceLevel(price: signal.entryZoneLow, label: "", type: .entryLow))
        result.append(PriceLevel(price: signal.stopLoss, label: "Stop", type: .stopLoss))

        return result.sorted { $0.price > $1.price }
    }

    private var priceHigh: Double {
        let prices = levels.map(\.price)
        let maxPrice = prices.max() ?? 1
        let minPrice = prices.min() ?? 0
        let padding = (maxPrice - minPrice) * 0.12
        return maxPrice + padding
    }

    private var priceLow: Double {
        let prices = levels.map(\.price)
        let maxPrice = prices.max() ?? 1
        let minPrice = prices.min() ?? 0
        let padding = (maxPrice - minPrice) * 0.12
        return minPrice - padding
    }

    private var priceRange: Double {
        max(priceHigh - priceLow, 0.0001)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                Text("Trade Structure")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(textPrimary)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack(alignment: .topLeading) {
                    // Background grid lines
                    gridLines(width: width, height: height)

                    // Entry zone band
                    entryZoneBand(width: width, height: height)

                    // Target zones
                    if let t1 = signal.target1 {
                        targetBand(price: t1, label: "T1", width: width, height: height, isPrimary: true)
                    }
                    if let t2 = signal.target2 {
                        targetBand(price: t2, label: "T2", width: width, height: height, isPrimary: false)
                    }

                    // Stop loss line
                    stopLossLine(width: width, height: height)

                    // Entry mid line
                    entryMidLine(width: width, height: height)

                    // R:R ratio arrow
                    rrArrow(width: width, height: height)

                    // Price labels on right side
                    priceLabelOverlay(width: width, height: height)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
    }

    // MARK: - Y Position

    private func yPosition(for price: Double, height: Double) -> Double {
        // Invert: higher prices at top
        (1 - (price - priceLow) / priceRange) * height
    }

    // MARK: - Grid Lines

    private func gridLines(width: Double, height: Double) -> some View {
        let steps = 5
        return ForEach(0..<steps, id: \.self) { i in
            let y = height * Double(i) / Double(steps - 1)
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width - 70, y: y))
            }
            .stroke(AppColors.textSecondary.opacity(0.08), lineWidth: 0.5)
        }
    }

    // MARK: - Entry Zone Band

    private func entryZoneBand(width: Double, height: Double) -> some View {
        let yHigh = yPosition(for: signal.entryZoneHigh, height: height)
        let yLow = yPosition(for: signal.entryZoneLow, height: height)
        let bandHeight = max(yLow - yHigh, 2)

        return Rectangle()
            .fill(AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
            .frame(width: width - 75, height: bandHeight)
            .overlay(
                Rectangle()
                    .fill(AppColors.accent.opacity(0.3))
                    .frame(height: 1),
                alignment: .top
            )
            .overlay(
                Rectangle()
                    .fill(AppColors.accent.opacity(0.3))
                    .frame(height: 1),
                alignment: .bottom
            )
            .position(x: (width - 75) / 2, y: yHigh + bandHeight / 2)
    }

    // MARK: - Entry Mid Line

    private func entryMidLine(width: Double, height: Double) -> some View {
        let y = yPosition(for: signal.entryPriceMid, height: height)

        return ZStack {
            // Dashed center line
            Path { path in
                path.move(to: CGPoint(x: 10, y: y))
                path.addLine(to: CGPoint(x: width - 75, y: y))
            }
            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            // Label
            Text("ENTRY")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AppColors.accent.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .cornerRadius(3)
                .position(x: 30, y: y - 10)
        }
    }

    // MARK: - Target Band

    private func targetBand(price: Double, label: String, width: Double, height: Double, isPrimary: Bool) -> some View {
        let y = yPosition(for: price, height: height)
        let color = AppColors.success

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10, y: y))
                path.addLine(to: CGPoint(x: width - 75, y: y))
            }
            .stroke(color.opacity(isPrimary ? 0.7 : 0.4), style: StrokeStyle(lineWidth: isPrimary ? 1.5 : 1, dash: isPrimary ? [] : [6, 3]))

            // Profit zone shading (between entry and target)
            let entryY = yPosition(for: signal.entryPriceMid, height: height)
            let shadeTop = min(y, entryY)
            let shadeHeight = abs(y - entryY)

            if isPrimary {
                Rectangle()
                    .fill(color.opacity(colorScheme == .dark ? 0.06 : 0.04))
                    .frame(width: width - 75, height: shadeHeight)
                    .position(x: (width - 75) / 2, y: shadeTop + shadeHeight / 2)
            }

            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .cornerRadius(3)
                .position(x: 16, y: y - 10)
        }
    }

    // MARK: - Stop Loss Line

    private func stopLossLine(width: Double, height: Double) -> some View {
        let y = yPosition(for: signal.stopLoss, height: height)
        let color = AppColors.error

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10, y: y))
                path.addLine(to: CGPoint(x: width - 75, y: y))
            }
            .stroke(color.opacity(0.7), lineWidth: 1.5)

            // Risk zone shading (between entry and stop)
            let entryY = yPosition(for: signal.entryPriceMid, height: height)
            let shadeTop = min(y, entryY)
            let shadeHeight = abs(y - entryY)

            Rectangle()
                .fill(color.opacity(colorScheme == .dark ? 0.06 : 0.04))
                .frame(width: width - 75, height: shadeHeight)
                .position(x: (width - 75) / 2, y: shadeTop + shadeHeight / 2)

            Text("STOP")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(color.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .cornerRadius(3)
                .position(x: 24, y: y - 10)
        }
    }

    // MARK: - R:R Arrow

    private func rrArrow(width: Double, height: Double) -> some View {
        let entryY = yPosition(for: signal.entryPriceMid, height: height)
        let stopY = yPosition(for: signal.stopLoss, height: height)
        let t1Y = signal.target1.map { yPosition(for: $0, height: height) } ?? entryY
        let arrowX = width - 90

        return ZStack {
            // Risk arrow (entry to stop)
            Path { path in
                path.move(to: CGPoint(x: arrowX, y: entryY))
                path.addLine(to: CGPoint(x: arrowX, y: stopY))
            }
            .stroke(AppColors.error.opacity(0.5), lineWidth: 2)

            Text("1R")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppColors.error)
                .position(x: arrowX, y: (entryY + stopY) / 2)

            // Reward arrow (entry to T1)
            Path { path in
                path.move(to: CGPoint(x: arrowX, y: entryY))
                path.addLine(to: CGPoint(x: arrowX, y: t1Y))
            }
            .stroke(AppColors.success.opacity(0.5), lineWidth: 2)

            Text(String(format: "%.1fR", signal.riskRewardRatio))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(AppColors.success)
                .position(x: arrowX, y: (entryY + t1Y) / 2)
        }
    }

    // MARK: - Price Labels

    private func priceLabelOverlay(width: Double, height: Double) -> some View {
        let labelLevels: [(price: Double, color: Color)] = {
            var result: [(Double, Color)] = []
            if let t2 = signal.target2 { result.append((t2, AppColors.success)) }
            if let t1 = signal.target1 { result.append((t1, AppColors.success)) }
            result.append((signal.entryPriceMid, AppColors.accent))
            result.append((signal.stopLoss, AppColors.error))
            return result
        }()

        return ForEach(Array(labelLevels.enumerated()), id: \.offset) { _, level in
            let y = yPosition(for: level.price, height: height)
            Text("$\(level.price.asSignalPrice)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(level.color)
                .monospacedDigit()
                .position(x: width - 35, y: y)
        }
    }
}

// MARK: - Price Level

private struct PriceLevel {
    let price: Double
    let label: String
    let type: LevelType

    enum LevelType {
        case target2, target1, entryHigh, entryMid, entryLow, stopLoss
    }
}
