import SwiftUI
import Foundation

// MARK: - Sentiment Gauge View (Half Circle)
struct SentimentGaugeView: View {
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

    private var gaugeColor: Color {
        switch value {
        case 0...24: return Color(hex: "EF4444") // Extreme Fear - Red
        case 25...44: return Color(hex: "F97316") // Fear - Orange
        case 45...55: return Color(hex: "EAB308") // Neutral - Yellow
        case 56...75: return Color(hex: "84CC16") // Greed - Light Green
        default: return Color(hex: "22C55E") // Extreme Greed - Green
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background Arc
                SemiCircleArc()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "EF4444"),
                                Color(hex: "F97316"),
                                Color(hex: "EAB308"),
                                Color(hex: "84CC16"),
                                Color(hex: "22C55E")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 40)
                    .opacity(0.3)

                // Value Arc
                SemiCircleArc()
                    .trim(from: 0, to: normalizedValue)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "EF4444"),
                                Color(hex: "F97316"),
                                Color(hex: "EAB308"),
                                Color(hex: "84CC16"),
                                Color(hex: "22C55E")
                            ],
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
                    .foregroundColor(.white)
                    .offset(y: 10)
            }
            .frame(height: 50)

            // Label
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(gaugeColor)
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
    let normalizedValue: Double

    private var angle: Double {
        // Convert normalized value (0-1) to angle (-90 to 90 degrees)
        -90 + (normalizedValue * 180)
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
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .position(center)
            }
        }
    }
}

// MARK: - Compact Gauge for Cards
struct CompactSentimentGauge: View {
    let value: Int

    private var normalizedValue: Double {
        Double(value) / 100.0
    }

    var body: some View {
        ZStack {
            // Background
            SemiCircleArc()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "EF4444"),
                            Color(hex: "F97316"),
                            Color(hex: "EAB308"),
                            Color(hex: "84CC16"),
                            Color(hex: "22C55E")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 60, height: 30)
                .opacity(0.3)

            // Value
            SemiCircleArc()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "EF4444"),
                            Color(hex: "F97316"),
                            Color(hex: "EAB308"),
                            Color(hex: "84CC16"),
                            Color(hex: "22C55E")
                        ],
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
