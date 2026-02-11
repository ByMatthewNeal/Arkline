import SwiftUI

// MARK: - Sparkline View
/// Minimal trend line showing recent history with optional gradient fill
struct SparklineView: View {
    let data: [CGFloat]  // Normalized values 0-1
    let color: Color
    let height: CGFloat
    let showGradientFill: Bool

    init(data: [CGFloat], color: Color = .white, height: CGFloat = 14, showGradientFill: Bool = false) {
        self.data = data
        self.color = color
        self.height = height
        self.showGradientFill = showGradientFill
    }

    var body: some View {
        GeometryReader { geometry in
            if data.count >= 2 {
                let width = geometry.size.width
                let stepX = width / CGFloat(data.count - 1)

                ZStack {
                    // Gradient fill under the line
                    if showGradientFill {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height))

                            for (index, value) in data.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height - (value * height)
                                path.addLine(to: CGPoint(x: x, y: y))
                            }

                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // The line itself
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (value * height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Sparkline Data Generator
/// Generates representative sparkline data when historical data isn't available
enum SparklineGenerator {

    /// Generate VIX sparkline (7 days)
    /// VIX typically mean-reverts around 15-20, with occasional spikes
    static func vixSparkline(current: Double, seed: Int = 0) -> [CGFloat] {
        srand48(seed)
        var data: [CGFloat] = []

        // Work backwards from current value
        var value = current
        for _ in 0..<7 {
            // Normalize VIX to 0-1 scale (10-40 range)
            let normalized = CGFloat(max(0, min(1, (value - 10) / 30)))
            data.insert(normalized, at: 0)

            // Generate previous day with mean reversion toward 18
            let meanReversion = (18 - value) * 0.1
            let noise = (drand48() - 0.5) * 3
            value = max(10, min(40, value - meanReversion + noise))
        }

        return data
    }

    /// Generate DXY sparkline (7 days)
    /// DXY is typically stable with small movements (90-110 range)
    static func dxySparkline(current: Double, seed: Int = 0) -> [CGFloat] {
        srand48(seed)
        var data: [CGFloat] = []

        var value = current
        for _ in 0..<7 {
            // Normalize DXY to 0-1 scale (95-115 range)
            let normalized = CGFloat(max(0, min(1, (value - 95) / 20)))
            data.insert(normalized, at: 0)

            // DXY moves slowly
            let noise = (drand48() - 0.5) * 0.8
            value = max(95, min(115, value + noise))
        }

        return data
    }

    /// Generate M2 sparkline from actual history or simulated
    static func m2Sparkline(history: [GlobalLiquidityData]?, current: Double, monthlyChange: Double) -> [CGFloat] {
        // Use actual history if available
        if let history = history, history.count >= 2 {
            let values = history.suffix(7).map { $0.value }
            let minVal = values.min() ?? current * 0.98
            let maxVal = values.max() ?? current * 1.02
            let range = max(maxVal - minVal, current * 0.01) // Avoid division by zero

            return values.map { CGFloat(($0 - minVal) / range) }
        }

        // Otherwise generate based on monthly trend
        var data: [CGFloat] = []
        let dailyChange = monthlyChange / 30.0
        var value = current

        srand48(Int(current) % 1000)

        for _ in 0..<7 {
            data.insert(0.5, at: 0) // Will normalize after
            let noise = (drand48() - 0.5) * 0.1
            value = value / (1 + (dailyChange + noise) / 100)
        }

        // Create trend line
        let trendUp = monthlyChange > 0
        return (0..<7).map { i in
            let progress = CGFloat(i) / 6.0
            let base: CGFloat = trendUp ? 0.3 : 0.7
            let trend: CGFloat = trendUp ? 0.4 : -0.4
            let noise = CGFloat(drand48() - 0.5) * 0.1
            return max(0, min(1, base + trend * progress + noise))
        }
    }
}
