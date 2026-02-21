import SwiftUI

// MARK: - ArkLine Score Detail View
struct ArkLineScoreDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let riskScore: ArkLineRiskScore

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
                        .font(.system(size: 48, weight: .bold, design: .rounded))
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
        components.filter { ["VIX (Volatility)", "DXY (Dollar)", "Global M2"].contains($0.name) }
    }

    private var marketStructureComponents: [RiskScoreComponent] {
        components.filter {
            !["Fear & Greed", "Altcoin Season", "App Store FOMO",
              "VIX (Volatility)", "DXY (Dollar)", "Global M2"].contains($0.name)
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

            Text("The ArkLine Score is a proprietary composite indicator combining 10 market signals across sentiment, macro conditions, and market structure. Each component is normalized to 0-100 and weighted by its predictive relevance. Missing data points redistribute weight to available indicators.")
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
