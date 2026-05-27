import SwiftUI

struct FearGreedWidget: View {
    let index: FearGreedIndex

    var body: some View {
        NavigationLink(destination: FearGreedDetailView(index: index)) {
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
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fear and Greed Index, \(index.value) out of 100, \(index.level.rawValue)")
        .accessibilityAddTraits(.isButton)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fear and Greed gauge, \(value) out of 100")
        .accessibilityAddTraits(.isImage)
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
    let index: FearGreedIndex
    @Environment(\.colorScheme) var colorScheme
    @State private var history: [FearGreedIndex] = []
    @State private var isLoading = false
    @State private var selectedPoint: FearGreedIndex?

    private var levelColor: Color { Color(hex: index.level.color) }
    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current gauge
                VStack(spacing: 12) {
                    FearGreedGauge(value: index.value)

                    Text(index.level.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(levelColor)

                    // Quick stats
                    HStack(spacing: 0) {
                        FearGreedStatItem(label: "Yesterday", value: index.previousClose.map { "\($0)" } ?? "—")
                        Divider().frame(height: 30).background(textPrimary.opacity(0.1))
                        FearGreedStatItem(label: "Last Week", value: index.weekAgo.map { "\($0)" } ?? "—")
                        Divider().frame(height: 30).background(textPrimary.opacity(0.1))
                        FearGreedStatItem(label: "Last Month", value: index.monthAgo.map { "\($0)" } ?? "—")
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                )
                .padding(.horizontal)

                // History chart
                historySection
                    .padding(.horizontal)

                // Level guide
                levelGuide
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Fear & Greed Index")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.background(colorScheme))
        .task {
            await loadHistory()
        }
    }

    // MARK: - History Chart Section

    private var historySection: some View {
        let sorted = history.sorted { $0.timestamp < $1.timestamp }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HISTORY (90 DAYS)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)
                Spacer()
                if selectedPoint != nil {
                    Button { selectedPoint = nil } label: {
                        Text("Reset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if sorted.count >= 2 {
                // Tooltip
                if let point = selectedPoint {
                    let pointColor = Color(hex: point.level.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatDate(point.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        HStack(spacing: 8) {
                            Text("\(point.value)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(pointColor)
                            Text(point.level.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(pointColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(pointColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11))
                        Text("Touch chart to view historical values")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                // Chart
                fearGreedChart(data: sorted)

                // Date labels
                HStack {
                    if let first = sorted.first {
                        Text(formatShortDate(first.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                    Spacer()
                    if let last = sorted.last {
                        Text(formatShortDate(last.timestamp))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                }
            } else {
                Text("Not enough history data")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    // MARK: - Interactive Chart

    private func fearGreedChart(data: [FearGreedIndex]) -> some View {
        let values = data.map { Double($0.value) }
        let maxVal = 100.0
        let minVal = 0.0
        let range = maxVal - minVal

        return HStack(spacing: 0) {
            // Y-axis
            VStack {
                Text("100")
                Spacer()
                Text("50")
                Spacer()
                Text("0")
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(AppColors.textSecondary.opacity(0.5))
            .frame(width: 22)

            // Chart area
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let stepX = w / CGFloat(max(data.count - 1, 1))

                ZStack(alignment: .topLeading) {
                    // Zone bands
                    ForEach([25.0, 45.0, 55.0, 75.0], id: \.self) { threshold in
                        let y = h * CGFloat((maxVal - threshold) / range)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(AppColors.textSecondary.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    }

                    // Line with color segments
                    Path { path in
                        for (i, val) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - val) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(levelColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Gradient fill
                    Path { path in
                        for (i, val) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - val) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(values.count - 1) * stepX, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [levelColor.opacity(0.15), levelColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                    // Selection indicator
                    if let selected = selectedPoint,
                       let idx = data.firstIndex(where: { $0.timestamp == selected.timestamp }) {
                        let x = CGFloat(idx) * stepX
                        let y = h * CGFloat((maxVal - Double(selected.value)) / range)
                        let pointColor = Color(hex: selected.level.color)

                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(pointColor.opacity(0.4), lineWidth: 1)

                        Circle()
                            .fill(pointColor)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = value.location.x
                            let idx = max(0, min(data.count - 1, Int(round(x / stepX))))
                            withAnimation(.easeOut(duration: 0.1)) {
                                selectedPoint = data[idx]
                            }
                        }
                )
            }
            .frame(height: 160)
        }
    }

    // MARK: - Level Guide

    private var levelGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEVEL GUIDE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            ForEach([
                ("0–24", "Extreme Fear", "#EF4444", "Market panic — historically a buying opportunity"),
                ("25–44", "Fear", "#F97316", "Investors are worried — caution dominates"),
                ("45–55", "Neutral", "#EAB308", "No strong bias in either direction"),
                ("56–75", "Greed", "#84CC16", "Optimism rising — markets trending up"),
                ("76–100", "Extreme Greed", "#22C55E", "Euphoria — historically a time to be cautious"),
            ], id: \.0) { range, label, color, desc in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(range)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(textPrimary)
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: color))
                        }
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    // MARK: - Data Loading

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = ServiceContainer.shared.sentimentService
            history = try await service.fetchFearGreedHistory(days: 90)
        } catch {
            logWarning("Failed to load F&G history: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: date)
    }

    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: date)
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
