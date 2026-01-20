import SwiftUI

// MARK: - Sparkline Chart
struct SparklineChart: View {
    let data: [Double]
    let isPositive: Bool
    let lineWidth: CGFloat

    init(data: [Double], isPositive: Bool? = nil, lineWidth: CGFloat = 1.5) {
        self.data = data
        // If not specified, determine based on first vs last value
        if let isPositive = isPositive {
            self.isPositive = isPositive
        } else {
            self.isPositive = (data.last ?? 0) >= (data.first ?? 0)
        }
        self.lineWidth = lineWidth
    }

    private var lineColor: Color {
        isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444")
    }

    var body: some View {
        GeometryReader { geometry in
            if data.count > 1 {
                let minValue = data.min() ?? 0
                let maxValue = data.max() ?? 1
                let range = maxValue - minValue
                let safeRange = range == 0 ? 1 : range

                Path { path in
                    let stepX = geometry.size.width / CGFloat(data.count - 1)
                    let heightRatio = geometry.size.height / safeRange

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (value - minValue) * heightRatio

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                // Optional: Gradient fill under the line
                Path { path in
                    let stepX = geometry.size.width / CGFloat(data.count - 1)
                    let heightRatio = geometry.size.height / safeRange

                    path.move(to: CGPoint(x: 0, y: geometry.size.height))

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - (value - minValue) * heightRatio
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0.3), lineColor.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }
}

// MARK: - Mini Sparkline (for cards)
struct MiniSparkline: View {
    let data: [Double]
    let isPositive: Bool

    init(data: [Double], isPositive: Bool? = nil) {
        self.data = data
        if let isPositive = isPositive {
            self.isPositive = isPositive
        } else {
            self.isPositive = (data.last ?? 0) >= (data.first ?? 0)
        }
    }

    var body: some View {
        SparklineChart(data: data, isPositive: isPositive, lineWidth: 1.5)
            .frame(height: 30)
    }
}

// MARK: - Sample Data Generator
extension SparklineChart {
    static let samplePositiveData: [Double] = [
        2.8, 2.9, 3.0, 2.95, 3.1, 3.2, 3.15, 3.25, 3.3, 3.32
    ]

    static let sampleNegativeData: [Double] = [
        3.5, 3.4, 3.3, 3.35, 3.2, 3.1, 3.15, 3.0, 2.9, 2.85
    ]

    static let sampleFlatData: [Double] = [
        3.0, 3.05, 2.98, 3.02, 3.0, 3.03, 2.99, 3.01, 3.0, 3.02
    ]
}

#Preview {
    VStack(spacing: 20) {
        // Positive trend
        VStack(alignment: .leading) {
            Text("Positive Trend")
                .font(.caption)
                .foregroundColor(.gray)
            SparklineChart(data: SparklineChart.samplePositiveData)
                .frame(width: 100, height: 40)
        }

        // Negative trend
        VStack(alignment: .leading) {
            Text("Negative Trend")
                .font(.caption)
                .foregroundColor(.gray)
            SparklineChart(data: SparklineChart.sampleNegativeData)
                .frame(width: 100, height: 40)
        }

        // Mini version
        VStack(alignment: .leading) {
            Text("Mini Sparkline")
                .font(.caption)
                .foregroundColor(.gray)
            MiniSparkline(data: SparklineChart.samplePositiveData, isPositive: true)
                .frame(width: 60)
        }
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
