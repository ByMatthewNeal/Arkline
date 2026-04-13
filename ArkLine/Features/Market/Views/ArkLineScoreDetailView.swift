import SwiftUI

// MARK: - ArkLine Score Detail View
struct ArkLineScoreDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let riskScore: ArkLineRiskScore
    var fearGreedValue: Int? = nil
    var fearGreedClassification: String? = nil
    @State private var showShareSheet = false
    @State private var scoreHistory: [RiskSnapshotDTO] = []
    @State private var isLoadingHistory = false
    @State private var selectedHistoryPoint: RiskSnapshotDTO?

    private var tierColor: Color {
        Color(hex: riskScore.tier.color)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ArkSpacing.xl) {
                // Score Gauge Section
                ScoreGaugeSection(score: riskScore.score, tier: riskScore.tier)

                // Recommendation
                RecommendationSection(
                    recommendation: riskScore.recommendation,
                    tier: riskScore.tier
                )

                // Tier Spectrum Bar
                TierSpectrumBar(score: riskScore.score)
                    .padding(.horizontal, ArkSpacing.lg)

                // Score History
                scoreHistorySection

                // Component Breakdown
                ComponentBreakdownSection(components: riskScore.components)

                // How It Works
                HowItWorksSection()

                Spacer(minLength: ArkSpacing.xxl)
            }
            .padding(.vertical, ArkSpacing.md)
        }
        .background(
            colorScheme == .dark
                ? Color(hex: "0F0F0F")
                : Color(hex: "F5F5F7")
        )
        .navigationTitle("ArkLine Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            RiskScoreShareSheet(
                riskScore: riskScore,
                fearGreedValue: fearGreedValue,
                fearGreedClassification: fearGreedClassification
            )
        }
        .task {
            await loadScoreHistory()
        }
    }

    // MARK: - Score History

    private var scoreHistorySection: some View {
        let sortedHistory = scoreHistory.sorted { $0.recordedDate < $1.recordedDate }

        return VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("SCORE HISTORY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)

                Spacer()

                if selectedHistoryPoint != nil {
                    Button { selectedHistoryPoint = nil } label: {
                        Text("Reset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .padding(.horizontal, ArkSpacing.lg)

            if isLoadingHistory {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if sortedHistory.count >= 2 {
                // Selected point tooltip
                if let point = selectedHistoryPoint {
                    let pointTier = SentimentTier(rawValue: point.tier)
                    let pointColor = Color(hex: pointTier?.color ?? "3B82F6")

                    VStack(alignment: .leading, spacing: 6) {
                        Text(formatScoreDate(point.recordedDate))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: 8) {
                            Text("\(point.compositeScore)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(pointColor)
                            Text(point.tier.capitalized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(pointColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(pointColor.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                    .transition(.opacity)
                } else {
                    // Hint
                    HStack(spacing: 6) {
                        Image(systemName: "hand.draw")
                            .font(.system(size: 11))
                        Text("Touch chart to view historical scores")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .padding(.horizontal, ArkSpacing.lg)
                }

                // Interactive chart
                scoreChart(data: sortedHistory)
                    .padding(.horizontal, ArkSpacing.lg)

                // Date labels
                HStack {
                    if let first = sortedHistory.first {
                        Text(formatShortDate(first.recordedDate))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                    Spacer()
                    if let last = sortedHistory.last {
                        Text(formatShortDate(last.recordedDate))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, ArkSpacing.lg)
            } else {
                Text("Not enough history data yet")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(.vertical, ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
        .padding(.horizontal, ArkSpacing.lg)
    }

    private func scoreChart(data: [RiskSnapshotDTO]) -> some View {
        let scores = data.map { Double($0.compositeScore) }
        let maxVal = max(scores.max() ?? 100, 60)
        let minVal = min(scores.min() ?? 0, 20)
        let range = max(maxVal - minVal, 1)

        return HStack(spacing: 0) {
            // Y-axis labels
            VStack {
                Text("\(Int(maxVal))")
                Spacer()
                Text("50")
                Spacer()
                Text("\(Int(minVal))")
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
                    // Threshold lines
                    ForEach([30.0, 50.0, 70.0], id: \.self) { threshold in
                        let y = h * CGFloat((maxVal - threshold) / range)
                        if y > 0 && y < h {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: w, y: y))
                            }
                            .stroke(AppColors.textSecondary.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        }
                    }

                    // Line
                    Path { path in
                        for (i, score) in scores.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - score) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(tierColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Gradient fill
                    Path { path in
                        for (i, score) in scores.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - score) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(scores.count - 1) * stepX, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tierColor.opacity(0.15), tierColor.opacity(0.02)], startPoint: .top, endPoint: .bottom))

                    // Selection indicator
                    if let selected = selectedHistoryPoint,
                       let idx = data.firstIndex(where: { $0.recordedDate == selected.recordedDate }) {
                        let x = CGFloat(idx) * stepX
                        let y = h * CGFloat((maxVal - Double(selected.compositeScore)) / range)

                        // Vertical line
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(tierColor.opacity(0.4), lineWidth: 1)

                        // Dot
                        Circle()
                            .fill(tierColor)
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
                                selectedHistoryPoint = data[idx]
                            }
                        }
                )
            }
            .frame(height: 160)
        }
    }

    private func formatScoreDate(_ dateStr: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "EEEE, MMMM d, yyyy"
        guard let date = input.date(from: dateStr) else { return dateStr }
        return output.string(from: date)
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.dateFormat = "MMM d"
        guard let date = input.date(from: dateStr) else { return dateStr }
        return output.string(from: date)
    }

    private func loadScoreHistory() async {
        guard SupabaseManager.shared.isConfigured else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let rows: [RiskSnapshotDTO] = try await SupabaseManager.shared.client
                .from(SupabaseTable.riskSnapshots.rawValue)
                .select()
                .order("recorded_date", ascending: false)
                .limit(90)
                .execute()
                .value
            scoreHistory = rows
        } catch {
            logWarning("Failed to load score history: \(error.localizedDescription)", category: .network)
        }
    }
}

// MARK: - Score Gauge Section
private struct ScoreGaugeSection: View {
    @Environment(\.colorScheme) var colorScheme
    let score: Int
    let tier: SentimentTier

    private var tierColor: Color {
        Color(hex: tier.color)
    }

    private var progress: Double {
        Double(score) / 100.0
    }

    var body: some View {
        VStack(spacing: ArkSpacing.md) {
            ZStack {
                // Track
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06),
                        lineWidth: 14
                    )
                    .frame(width: 160, height: 160)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [tierColor.opacity(0.4), tierColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                // Glow
                Circle()
                    .fill(tierColor.opacity(0.15))
                    .blur(radius: 24)
                    .frame(width: 90, height: 90)

                // Score text
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Tier badge
            HStack(spacing: 6) {
                Image(systemName: tier.icon)
                    .font(.system(size: 14))
                Text(tier.rawValue)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(tierColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(tierColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .padding(.top, ArkSpacing.lg)
    }
}

// MARK: - Recommendation Section
private struct RecommendationSection: View {
    @Environment(\.colorScheme) var colorScheme
    let recommendation: String
    let tier: SentimentTier

    var body: some View {
        Text(recommendation)
            .font(.subheadline)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, ArkSpacing.xl)
    }
}

// MARK: - Tier Spectrum Bar
private struct TierSpectrumBar: View {
    @Environment(\.colorScheme) var colorScheme
    let score: Int

    private let tiers: [(label: String, color: String, range: ClosedRange<Int>)] = [
        ("Extreme Fear", "#3B82F6", 0...20),
        ("Fear", "#0EA5E9", 21...40),
        ("Neutral", "#64748B", 41...60),
        ("Greed", "#F59E0B", 61...80),
        ("Extreme Greed", "#DC2626", 81...100)
    ]

    var body: some View {
        VStack(spacing: ArkSpacing.xs) {
            // Spectrum bar with marker
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let markerX = totalWidth * CGFloat(score) / 100.0

                ZStack(alignment: .leading) {
                    // Gradient bar
                    HStack(spacing: 2) {
                        ForEach(tiers, id: \.label) { tier in
                            let fraction = Double(tier.range.count) / 101.0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: tier.color))
                                .frame(width: max(totalWidth * fraction - 2, 0))
                        }
                    }
                    .frame(height: 8)

                    // Marker
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .overlay(
                            Circle()
                                .fill(colorForScore(score))
                                .frame(width: 8, height: 8)
                        )
                        .offset(x: markerX - 7)
                }
            }
            .frame(height: 14)

            // Labels
            HStack {
                Text("0")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Fear")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Neutral")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Greed")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("100")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        )
    }

    private func colorForScore(_ score: Int) -> Color {
        for tier in tiers where tier.range.contains(score) {
            return Color(hex: tier.color)
        }
        return Color.yellow
    }
}

// MARK: - Component Breakdown Section
private struct ComponentBreakdownSection: View {
    @Environment(\.colorScheme) var colorScheme
    let components: [RiskScoreComponent]

    // Group components by category for cleaner display
    private var sentimentComponents: [RiskScoreComponent] {
        components.filter { ["Fear & Greed", "Altcoin Season", "App Store FOMO"].contains($0.name) }
    }

    private var macroComponents: [RiskScoreComponent] {
        components.filter { ["VIX (Volatility)", "DXY (Dollar)", "US Net Liquidity", "WTI Crude Oil"].contains($0.name) }
    }

    private var marketStructureComponents: [RiskScoreComponent] {
        components.filter {
            !["Fear & Greed", "Altcoin Season", "App Store FOMO",
              "VIX (Volatility)", "DXY (Dollar)", "US Net Liquidity", "WTI Crude Oil"].contains($0.name)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            Text("Component Breakdown")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .padding(.horizontal, ArkSpacing.lg)

            if !marketStructureComponents.isEmpty {
                ComponentGroup(title: "Market Structure", icon: "chart.bar.fill", components: marketStructureComponents)
            }

            if !sentimentComponents.isEmpty {
                ComponentGroup(title: "Sentiment", icon: "face.smiling.inverse", components: sentimentComponents)
            }

            if !macroComponents.isEmpty {
                ComponentGroup(title: "Macro", icon: "globe.americas.fill", components: macroComponents)
            }
        }
    }
}

// MARK: - Component Group
private struct ComponentGroup: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String
    let components: [RiskScoreComponent]

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.lg)

            VStack(spacing: 2) {
                ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                    ScoreComponentRow(component: component)
                }
            }
            .padding(.horizontal, ArkSpacing.md)
        }
    }
}

// MARK: - Score Component Row
private struct ScoreComponentRow: View {
    @Environment(\.colorScheme) var colorScheme
    let component: RiskScoreComponent

    private var signalColor: Color {
        Color(hex: component.signal.color)
    }

    private var barColor: Color {
        signalColor
    }

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            // Signal indicator
            Image(systemName: component.signal.icon)
                .font(.system(size: 14))
                .foregroundColor(signalColor)
                .frame(width: 26, height: 26)
                .background(signalColor.opacity(0.12))
                .clipShape(Circle())

            // Name + weight
            VStack(alignment: .leading, spacing: 1) {
                Text(component.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(Int(component.weight * 100))% weight")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(max(component.value, 0), 1))
                }
            }
            .frame(width: 72, height: 6)

            // Value
            Text("\(Int(component.value * 100))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(signalColor)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, ArkSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }
}

// MARK: - How It Works Section
private struct HowItWorksSection: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("How It Works")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("The ArkLine Score is a proprietary composite indicator combining 11 market signals across sentiment, macro conditions, and market structure. Each component is normalized to 0-100 and weighted by its predictive relevance. Missing data points redistribute weight to available indicators.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)

            HStack(spacing: ArkSpacing.sm) {
                ScoreLegendItem(range: "81-100", label: "Extreme Greed", color: "#DC2626")
                ScoreLegendItem(range: "61-80", label: "Greed", color: "#F59E0B")
                ScoreLegendItem(range: "41-60", label: "Neutral", color: "#64748B")
                ScoreLegendItem(range: "21-40", label: "Fear", color: "#0EA5E9")
                ScoreLegendItem(range: "0-20", label: "Extreme Fear", color: "#3B82F6")
            }
            .padding(.top, 4)
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        )
        .padding(.horizontal, ArkSpacing.lg)
    }
}

// MARK: - Score Legend Item
private struct ScoreLegendItem: View {
    let range: String
    let label: String
    let color: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)
            Text(range)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundColor(Color(hex: color))
        }
    }
}
