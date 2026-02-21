import SwiftUI

// MARK: - Risk Score Card
struct RiskScoreCard: View {
    let score: Int
    var riskScore: ArkLineRiskScore? = nil
    var itcRiskLevel: ITCRiskLevel? = nil
    var size: WidgetSize = .standard
    var selectedCoin: String = "BTC"
    var onCoinChanged: ((String) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var riskLabel: String {
        if let itc = itcRiskLevel {
            return itc.riskCategory
        }
        switch score {
        case 0..<30: return "Low Risk"
        case 30..<50: return "Moderate"
        case 50..<70: return "Elevated"
        default: return "High Risk"
        }
    }

    private var riskColor: Color {
        if let itc = itcRiskLevel {
            return ITCRiskColors.color(for: itc.riskLevel, colorScheme: colorScheme)
        }
        let normalizedScore = Double(score) / 100.0
        let saturation = 0.4 + (normalizedScore * 0.5)
        let brightness = 0.9 - (normalizedScore * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var riskColorLight: Color {
        riskColor.opacity(0.6)
    }

    private var circleSize: CGFloat {
        switch size {
        case .compact: return 50
        case .standard: return 70
        case .expanded: return 90
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 5
        case .standard: return 8
        case .expanded: return 10
        }
    }

    private var indicatorCount: Int {
        riskScore?.components.count ?? 10
    }

    private var displayScore: Int {
        if let itc = itcRiskLevel {
            return Int(itc.riskPercentage)
        }
        return score
    }

    private var cardTitle: String {
        if itcRiskLevel != nil {
            return "\(selectedCoin.rawValue) Risk Level"
        }
        return "ArkLine Risk Score"
    }

    private var cardSubtitle: String {
        if itcRiskLevel != nil {
            return "Into The Cryptoverse"
        }
        return "Based on \(indicatorCount) indicators"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: size == .compact ? 12 : 16) {
                ZStack {
                    Circle()
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08),
                            lineWidth: strokeWidth
                        )
                        .frame(width: circleSize, height: circleSize)

                    Circle()
                        .trim(from: 0, to: CGFloat(displayScore) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [riskColorLight, riskColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(riskColor.opacity(0.2))
                        .blur(radius: size == .compact ? 8 : 12)
                        .frame(width: circleSize * 0.6, height: circleSize * 0.6)

                    Text("\(displayScore)")
                        .font(.system(size: size == .compact ? 18 : (size == .expanded ? 30 : 24), weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                }

                VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                    HStack(spacing: 8) {
                        Text(cardTitle)
                            .font(size == .compact ? .subheadline : .headline)
                            .foregroundColor(textPrimary)

                        if itcRiskLevel != nil && onCoinChanged != nil {
                            HStack(spacing: 0) {
                                ForEach(AssetRiskConfig.allConfigs.map(\.assetId), id: \.self) { coin in
                                    Button(action: {
                                        onCoinChanged?(coin)
                                    }) {
                                        Text(coin)
                                            .font(.system(size: size == .compact ? 9 : 10, weight: .semibold))
                                            .foregroundColor(
                                                selectedCoin == coin
                                                    ? .white
                                                    : textPrimary.opacity(0.6)
                                            )
                                            .padding(.horizontal, size == .compact ? 6 : 8)
                                            .padding(.vertical, size == .compact ? 3 : 4)
                                            .background(
                                                selectedCoin == coin
                                                    ? AppColors.accent
                                                    : Color.clear
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel("\(coin)\(selectedCoin == coin ? ", selected" : "")")
                                }
                            }
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.05)
                            )
                            .cornerRadius(6)
                        }
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(riskColor)
                            .frame(width: 8, height: 8)

                        Text(riskLabel)
                            .font(size == .compact ? .caption : .subheadline)
                            .foregroundColor(riskColor)
                    }

                    if size != .compact {
                        Text(cardSubtitle)
                            .font(.caption)
                            .foregroundColor(textPrimary.opacity(0.5))
                    }

                    if size == .expanded {
                        if let recommendation = riskScore?.recommendation {
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(textPrimary.opacity(0.6))
                                .lineLimit(2)
                                .padding(.top, 4)
                        } else if let itc = itcRiskLevel {
                            Text("Updated: \(itc.date)")
                                .font(.caption)
                                .foregroundColor(textPrimary.opacity(0.5))
                                .padding(.top, 4)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.4))
            }
            .padding(size == .compact ? 14 : 20)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cardTitle), \(displayScore) out of 100, \(riskLabel)")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            if let itc = itcRiskLevel {
                ITCRiskDetailView(riskLevel: itc)
            } else if let riskScore = riskScore {
                NavigationStack {
                    ArkLineScoreDetailView(riskScore: riskScore)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingDetail = false }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Risk Score Detail View
struct RiskScoreDetailView: View {
    let riskScore: ArkLineRiskScore?
    let score: Int
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private func colorForScore(_ value: Double) -> Color {
        let saturation = 0.4 + (value * 0.5)
        let brightness = 0.9 - (value * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var mainRiskColor: Color {
        colorForScore(Double(score) / 100.0)
    }

    var riskLabel: String {
        switch score {
        case 0..<30: return "Low Risk"
        case 30..<50: return "Moderate"
        case 50..<70: return "Elevated"
        default: return "High Risk"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    VStack(spacing: ArkSpacing.md) {
                        ZStack {
                            Circle()
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.1)
                                        : Color.black.opacity(0.08),
                                    lineWidth: 12
                                )
                                .frame(width: 140, height: 140)

                            Circle()
                                .trim(from: 0, to: CGFloat(score) / 100)
                                .stroke(
                                    LinearGradient(
                                        colors: [mainRiskColor.opacity(0.6), mainRiskColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .fill(mainRiskColor.opacity(0.2))
                                .blur(radius: 20)
                                .frame(width: 80, height: 80)

                            VStack(spacing: 2) {
                                Text("\(score)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(textPrimary)
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundColor(textPrimary.opacity(0.5))
                            }
                        }

                        Text(riskLabel)
                            .font(.title3.bold())
                            .foregroundColor(mainRiskColor)

                        if let recommendation = riskScore?.recommendation {
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, ArkSpacing.xl)

                    VStack(alignment: .leading, spacing: ArkSpacing.md) {
                        Text("Risk Indicators")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                            .padding(.horizontal)

                        if let components = riskScore?.components {
                            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                                RiskIndicatorRow(component: component, colorScheme: colorScheme)
                            }
                        } else {
                            ForEach(0..<7, id: \.self) { index in
                                RiskIndicatorPlaceholderRow(index: index, colorScheme: colorScheme)
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("How to Read")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text("The ArkLine Risk Score combines multiple market indicators to assess current market conditions. A lower score (0-30) suggests favorable buying conditions, while a higher score (70-100) indicates elevated risk and potential for correction.")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                    .padding(.horizontal)

                    Spacer(minLength: ArkSpacing.xxl)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Risk Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Risk Indicator Row
struct RiskIndicatorRow: View {
    let component: RiskScoreComponent
    let colorScheme: ColorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var indicatorColor: Color {
        let saturation = 0.4 + (component.value * 0.5)
        let brightness = 0.9 - (component.value * 0.25)
        return Color(hue: 0.6, saturation: saturation, brightness: brightness)
    }

    private var signalIcon: String {
        component.signal.icon
    }

    private var signalColor: Color {
        Color(hex: component.signal.color)
    }

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: signalIcon)
                .font(.system(size: 16))
                .foregroundColor(signalColor)
                .frame(width: 28, height: 28)
                .background(signalColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(textPrimary)

                Text("\(Int(component.weight * 100))% weight")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(indicatorColor)
                        .frame(width: geo.size.width * component.value)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(component.value * 100))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(indicatorColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, ArkSpacing.sm)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Risk Indicator Placeholder Row
struct RiskIndicatorPlaceholderRow: View {
    let index: Int
    let colorScheme: ColorScheme

    private let placeholderNames = [
        "Fear & Greed",
        "App Store Sentiment",
        "Funding Rates",
        "ETF Flows",
        "Liquidation Ratio",
        "BTC Dominance",
        "Google Trends"
    ]

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(placeholderNames[safe: index] ?? "Indicator \(index + 1)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("--% weight")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 8)

            Text("--")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(Color.gray)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, ArkSpacing.sm)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Home ArkLine Score Widget
/// Widget for Home screen that displays the ArkLine composite score
/// Same appearance as Market Overview's ArkLineScoreCard but with size support
struct HomeArkLineScoreWidget: View {
    let score: ArkLineRiskScore
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var progress: Double {
        Double(score.score) / 100.0
    }

    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 40
        case .standard: return 50
        case .expanded: return 60
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .compact: return 24
        case .standard: return 28
        case .expanded: return 32
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ArkLine Score")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(score.score)")
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundColor(textPrimary)

                        Text(score.tier.rawValue)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    // Circular Progress Gauge
                    ZStack {
                        Circle()
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.08),
                                lineWidth: 6
                            )
                            .frame(width: gaugeSize, height: gaugeSize)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: gaugeSize, height: gaugeSize)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
            .padding(size == .compact ? 12 : 16)
            .frame(maxWidth: .infinity, minHeight: size == .compact ? 100 : 120)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 16)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ArkLine Score, \(score.score) out of 100, \(score.tier.rawValue)")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                ArkLineScoreDetailView(riskScore: score)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingDetail = false }
                        }
                    }
            }
        }
    }
}

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
