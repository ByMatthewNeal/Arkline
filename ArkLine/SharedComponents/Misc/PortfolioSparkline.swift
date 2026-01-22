import SwiftUI

// MARK: - Portfolio Sparkline Chart
/// A polished, animated sparkline chart with gradient fill and glow effects
/// Enhanced version for hero cards and prominent displays
struct PortfolioSparkline: View {
    let dataPoints: [CGFloat]
    var lineColor: Color = AppColors.accent
    var isPositive: Bool = true
    var showGlow: Bool = true
    var showEndDot: Bool = true
    var animated: Bool = true

    @State private var animationProgress: CGFloat = 0
    @State private var dotPulse: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var effectiveLineColor: Color {
        isPositive ? AppColors.success : AppColors.error
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Gradient fill under the line
                gradientFill(width: width, height: height)
                    .opacity(animated ? animationProgress : 1)

                // Glow effect (subtle blur behind the line)
                if showGlow {
                    smoothLine(width: width, height: height)
                        .stroke(
                            effectiveLineColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                        )
                        .blur(radius: 8)
                        .opacity((animated ? animationProgress : 1) * 0.4)
                }

                // Main line with trim animation
                smoothLine(width: width, height: height)
                    .trim(from: 0, to: animated ? animationProgress : 1)
                    .stroke(
                        LinearGradient(
                            colors: [
                                effectiveLineColor.opacity(0.6),
                                effectiveLineColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                // End point dot with pulse animation
                if showEndDot && !dataPoints.isEmpty {
                    let lastPoint = normalizedPoint(
                        at: dataPoints.count - 1,
                        width: width,
                        height: height
                    )

                    ZStack {
                        // Pulse ring
                        Circle()
                            .fill(effectiveLineColor.opacity(0.3))
                            .frame(width: dotPulse ? 20 : 10, height: dotPulse ? 20 : 10)

                        // Inner dot
                        Circle()
                            .fill(effectiveLineColor)
                            .frame(width: 8, height: 8)

                        // White center
                        Circle()
                            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                            .frame(width: 4, height: 4)
                    }
                    .position(lastPoint)
                    .opacity(animated ? animationProgress : 1)
                }
            }
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 1.2)) {
                    animationProgress = 1
                }

                // Start pulse animation after line draws
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                    ) {
                        dotPulse = true
                    }
                }
            }
        }
    }

    // MARK: - Smooth Bezier Line
    private func smoothLine(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let points = dataPoints.enumerated().map { index, value in
                normalizedPoint(at: index, width: width, height: height)
            }

            path.move(to: points[0])

            // Use Catmull-Rom spline for smooth curves
            for i in 0..<points.count {
                let p0 = points[max(0, i - 1)]
                let p1 = points[i]
                let p2 = points[min(points.count - 1, i + 1)]
                let p3 = points[min(points.count - 1, i + 2)]

                if i == 0 {
                    path.move(to: p1)
                } else {
                    // Calculate control points for smooth curve
                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }
        }
    }

    // MARK: - Gradient Fill
    private func gradientFill(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let points = dataPoints.enumerated().map { index, value in
                normalizedPoint(at: index, width: width, height: height)
            }

            // Start from bottom-left
            path.move(to: CGPoint(x: 0, y: height))
            path.addLine(to: points[0])

            // Draw the curved line
            for i in 0..<points.count {
                let p0 = points[max(0, i - 1)]
                let p1 = points[i]
                let p2 = points[min(points.count - 1, i + 1)]
                let p3 = points[min(points.count - 1, i + 2)]

                if i == 0 {
                    continue
                } else {
                    let cp1 = CGPoint(
                        x: p1.x + (p2.x - p0.x) / 6,
                        y: p1.y + (p2.y - p0.y) / 6
                    )
                    let cp2 = CGPoint(
                        x: p2.x - (p3.x - p1.x) / 6,
                        y: p2.y - (p3.y - p1.y) / 6
                    )

                    path.addCurve(to: p2, control1: cp1, control2: cp2)
                }
            }

            // Close the path at the bottom
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    effectiveLineColor.opacity(colorScheme == .dark ? 0.3 : 0.2),
                    effectiveLineColor.opacity(colorScheme == .dark ? 0.05 : 0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Helper
    private func normalizedPoint(at index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        guard !dataPoints.isEmpty else { return .zero }

        let minValue = dataPoints.min() ?? 0
        let maxValue = dataPoints.max() ?? 1
        let range = max(maxValue - minValue, 0.001) // Avoid division by zero

        let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
        let normalizedY = (dataPoints[index] - minValue) / range
        let y = height * (1 - normalizedY) * 0.85 + height * 0.075 // Add padding

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Compact Sparkline (for smaller spaces)
struct CompactSparkline: View {
    let dataPoints: [CGFloat]
    var isPositive: Bool = true

    @Environment(\.colorScheme) var colorScheme

    private var lineColor: Color {
        isPositive ? AppColors.success : AppColors.error
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Simple gradient fill
                simpleFill(width: width, height: height)

                // Line
                simpleLine(width: width, height: height)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }

    private func simpleLine(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let minValue = dataPoints.min() ?? 0
            let maxValue = dataPoints.max() ?? 1
            let range = max(maxValue - minValue, 0.001)

            for (index, value) in dataPoints.enumerated() {
                let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let normalizedY = (value - minValue) / range
                let y = height * (1 - normalizedY) * 0.8 + height * 0.1

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func simpleFill(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            guard dataPoints.count >= 2 else { return }

            let minValue = dataPoints.min() ?? 0
            let maxValue = dataPoints.max() ?? 1
            let range = max(maxValue - minValue, 0.001)

            path.move(to: CGPoint(x: 0, y: height))

            for (index, value) in dataPoints.enumerated() {
                let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let normalizedY = (value - minValue) / range
                let y = height * (1 - normalizedY) * 0.8 + height * 0.1

                if index == 0 {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    lineColor.opacity(0.15),
                    lineColor.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 30) {
        // Full sparkline - positive
        VStack(alignment: .leading) {
            Text("Portfolio Performance")
                .font(.headline)
                .foregroundColor(.white)

            PortfolioSparkline(
                dataPoints: [0.3, 0.35, 0.32, 0.5, 0.45, 0.6, 0.55, 0.7, 0.65, 0.8, 0.75, 0.9],
                isPositive: true
            )
            .frame(height: 80)
        }
        .padding()
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)

        // Full sparkline - negative
        VStack(alignment: .leading) {
            Text("Declining Asset")
                .font(.headline)
                .foregroundColor(.white)

            PortfolioSparkline(
                dataPoints: [0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.55, 0.5, 0.45, 0.4],
                isPositive: false
            )
            .frame(height: 80)
        }
        .padding()
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)

        // Compact sparklines
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("BTC")
                    .font(.caption)
                    .foregroundColor(.gray)
                CompactSparkline(
                    dataPoints: [0.3, 0.5, 0.4, 0.7, 0.6, 0.8],
                    isPositive: true
                )
                .frame(width: 60, height: 24)
            }

            VStack(alignment: .leading) {
                Text("ETH")
                    .font(.caption)
                    .foregroundColor(.gray)
                CompactSparkline(
                    dataPoints: [0.8, 0.7, 0.75, 0.6, 0.5, 0.4],
                    isPositive: false
                )
                .frame(width: 60, height: 24)
            }
        }
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
