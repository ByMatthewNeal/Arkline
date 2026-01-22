import SwiftUI
import Foundation

// MARK: - Sentiment Gauge View (Half Circle)
struct SentimentGaugeView: View {
    @Environment(\.colorScheme) var colorScheme
    let value: Int
    let maxValue: Int
    let label: String

    init(value: Int, maxValue: Int = 100, label: String = "") {
        self.value = value
        self.maxValue = maxValue
        self.label = label
    }

    private var normalizedValue: Double {
        Double(value) / Double(maxValue)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background Arc - simplified monochrome
                SemiCircleArc()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.1),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 40)

                // Value Arc - blue gradient
                SemiCircleArc()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.5), AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 40)

                // Needle/Indicator
                NeedleIndicator(normalizedValue: normalizedValue)
                    .frame(width: 80, height: 40)

                // Value Text
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .offset(y: 10)
            }
            .frame(height: 50)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Semi Circle Arc Shape
struct SemiCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        return path
    }
}

// MARK: - Needle Indicator
struct NeedleIndicator: View {
    @Environment(\.colorScheme) var colorScheme
    let normalizedValue: Double

    private var angle: Double {
        // Convert normalized value (0-1) to angle (-90 to 90 degrees)
        -90 + (normalizedValue * 180)
    }

    private var needleColor: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height)
            let radius = min(geometry.size.width, geometry.size.height * 2) / 2 - 4

            // Calculate needle endpoint
            let needleAngle = Angle(degrees: angle - 90)
            let needleLength = radius * 0.7
            let endPoint = CGPoint(
                x: center.x + needleLength * Darwin.cos(needleAngle.radians),
                y: center.y + needleLength * Darwin.sin(needleAngle.radians)
            )

            ZStack {
                // Needle line
                Path { path in
                    path.move(to: center)
                    path.addLine(to: endPoint)
                }
                .stroke(needleColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Center dot
                Circle()
                    .fill(needleColor)
                    .frame(width: 6, height: 6)
                    .position(center)
            }
        }
    }
}

// MARK: - Compact Gauge for Cards
struct CompactSentimentGauge: View {
    @Environment(\.colorScheme) var colorScheme
    let value: Int

    private var normalizedValue: Double {
        Double(value) / 100.0
    }

    var body: some View {
        ZStack {
            // Background - simplified monochrome
            SemiCircleArc()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.1),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 60, height: 30)

            // Value - blue gradient
            SemiCircleArc()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.5), AppColors.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 60, height: 30)
        }
        .frame(height: 35)
    }
}

#Preview {
    VStack(spacing: 30) {
        SentimentGaugeView(value: 25, label: "Fear")
        SentimentGaugeView(value: 49, label: "Neutral")
        SentimentGaugeView(value: 75, label: "Greed")

        CompactSentimentGauge(value: 65)
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
