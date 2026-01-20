import SwiftUI

struct FearGreedWidget: View {
    let index: FearGreedIndex

    var body: some View {
        NavigationLink(destination: FearGreedDetailView()) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fear & Greed Index")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(index.level.rawValue)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: index.level.color))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }

                // Gauge
                FearGreedGauge(value: index.value)

                // Stats Row
                HStack(spacing: 0) {
                    FearGreedStatItem(label: "Yesterday", value: index.previousClose.map { "\($0)" } ?? "—")
                    Divider()
                        .frame(height: 30)
                        .background(Color(hex: "2A2A2A"))
                    FearGreedStatItem(label: "Last Week", value: index.weekAgo.map { "\($0)" } ?? "—")
                    Divider()
                        .frame(height: 30)
                        .background(Color(hex: "2A2A2A"))
                    FearGreedStatItem(label: "Last Month", value: index.monthAgo.map { "\($0)" } ?? "—")
                }
            }
            .padding(20)
            .background(Color(hex: "1F1F1F"))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Fear & Greed Gauge
struct FearGreedGauge: View {
    let value: Int

    private var normalizedValue: Double {
        Double(value) / 100.0
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "EF4444"),
                                Color(hex: "F97316"),
                                Color(hex: "EAB308"),
                                Color(hex: "22C55E")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .frame(width: 160, height: 160)
                    .opacity(0.3)

                // Value Arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + (normalizedValue * 0.5))
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "EF4444"),
                                Color(hex: "F97316"),
                                Color(hex: "EAB308"),
                                Color(hex: "22C55E")
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .frame(width: 160, height: 160)

                // Value Text
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
                .offset(y: 20)
            }
            .frame(height: 100)
        }
    }
}

// MARK: - Fear Greed Stat Item
struct FearGreedStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text(label)
                .font(.caption2)
                .foregroundColor(Color(hex: "A1A1AA"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Detail View
struct FearGreedDetailView: View {
    var body: some View {
        Text("Fear & Greed Detail")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

#Preview {
    FearGreedWidget(
        index: FearGreedIndex(
            value: 65,
            classification: "Greed",
            timestamp: Date()
        )
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}
