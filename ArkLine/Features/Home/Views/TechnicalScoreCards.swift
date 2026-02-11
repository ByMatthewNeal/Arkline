import SwiftUI

// MARK: - Dual Score Card (Trend + Opportunity)
struct DualScoreCard: View {
    let trendScore: Int
    let opportunityScore: Int
    let colorScheme: ColorScheme
    @State private var showTrendInfo = false
    @State private var showValuationInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Info buttons row
            HStack {
                Button {
                    showTrendInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                Spacer()

                Button {
                    showValuationInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            HStack(spacing: ArkSpacing.md) {
                // Trend Score
                ScoreGauge(
                    score: trendScore,
                    label: "Trend",
                    subtitle: trendLabel,
                    color: trendColor,
                    colorScheme: colorScheme
                )

                // Divider
                Rectangle()
                    .fill(AppColors.divider(colorScheme))
                    .frame(width: 1)
                    .padding(.vertical, 12)

                // Valuation Score
                ScoreGauge(
                    score: opportunityScore,
                    label: "Valuation",
                    subtitle: valuationLabel,
                    color: valuationColor,
                    colorScheme: colorScheme
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Trend Score", isPresented: $showTrendInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Measures price direction based on trend strength and position relative to key moving averages (21, 50, 200). Higher scores indicate upward momentum.")
        }
        .alert("Valuation", isPresented: $showValuationInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Shows if price is stretched using RSI and Bollinger Bands. Oversold may indicate a bounce, but consider trend direction before entering.")
        }
    }

    private var trendColor: Color {
        switch trendScore {
        case 0..<25: return AppColors.error
        case 25..<40: return Color(hex: "F97316")
        case 40..<60: return AppColors.warning
        case 60..<75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private var trendLabel: String {
        switch trendScore {
        case 0..<25: return "Strong Down"
        case 25..<40: return "Down"
        case 40..<60: return "Sideways"
        case 60..<75: return "Up"
        default: return "Strong Up"
        }
    }

    private var valuationColor: Color {
        switch opportunityScore {
        case 0..<25: return AppColors.error
        case 25..<40: return Color(hex: "F97316")
        case 40..<60: return AppColors.warning
        case 60..<75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private var valuationLabel: String {
        switch opportunityScore {
        case 0..<25: return "Overbought"
        case 25..<40: return "Extended"
        case 40..<60: return "Neutral"
        case 60..<75: return "Oversold"
        default: return "Deeply Oversold"
        }
    }
}

// MARK: - Score Gauge
struct ScoreGauge: View {
    let score: Int
    let label: String
    let subtitle: String
    let color: Color
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 6
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            // Labels
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(subtitle)
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RSI Indicator Card
struct RSIIndicatorCard: View {
    let rsi: RSIData
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("RSI (14)")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                Spacer()

                // Zone badge
                Text(rsi.zone.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(rsi.zone.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(rsi.zone.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            // RSI gauge
            VStack(spacing: 8) {
                // Value display
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(rsi.displayValue)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(rsi.zone.color)

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Visual gauge
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background with zones
                        HStack(spacing: 0) {
                            // Oversold zone (0-30)
                            Rectangle()
                                .fill(AppColors.success.opacity(0.2))
                                .frame(width: geo.size.width * 0.3)

                            // Neutral zone (30-70)
                            Rectangle()
                                .fill(AppColors.warning.opacity(0.15))
                                .frame(width: geo.size.width * 0.4)

                            // Overbought zone (70-100)
                            Rectangle()
                                .fill(AppColors.error.opacity(0.2))
                                .frame(width: geo.size.width * 0.3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // RSI position indicator
                        let positionX = geo.size.width * (rsi.value / 100)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .overlay(
                                Circle()
                                    .fill(rsi.zone.color)
                                    .frame(width: 10, height: 10)
                            )
                            .offset(x: positionX - 8)
                    }
                }
                .frame(height: 20)

                // Zone labels
                HStack {
                    Text("30")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 30, alignment: .leading)
                        .offset(x: 20)

                    Spacer()

                    Text("70")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 30, alignment: .trailing)
                        .offset(x: -20)
                }
            }

            // Signal description
            Text(rsi.zone.description)
                .font(.caption)
                .foregroundColor(rsi.zone.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("RSI (Relative Strength Index)", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Measures momentum on a 0-100 scale. Below 30 suggests oversold (potential bounce), above 70 suggests overbought (potential pullback).")
        }
    }
}

// MARK: - Market Outlook Card (Short/Long Term)
struct MarketOutlookCard: View {
    let sentiment: MarketSentimentAnalysis
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Market Outlook")
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                Spacer()
            }

            HStack(spacing: 0) {
                // Short Term
                OutlookIndicator(
                    label: "Short Term",
                    sentiment: sentiment.shortTerm,
                    colorScheme: colorScheme
                )

                // Divider
                Rectangle()
                    .fill(AppColors.divider(colorScheme))
                    .frame(width: 1)
                    .padding(.vertical, 8)

                // Long Term
                OutlookIndicator(
                    label: "Long Term",
                    sentiment: sentiment.longTerm,
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Market Outlook", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Short term outlook is based on recent RSI momentum. Long term outlook reflects price position relative to the 200-day moving average.")
        }
    }
}

// MARK: - Outlook Indicator
struct OutlookIndicator: View {
    let label: String
    let sentiment: AssetSentiment
    let colorScheme: ColorScheme

    private var sentimentLabel: String {
        switch sentiment {
        case .stronglyBullish: return "Very Bullish"
        case .bullish: return "Bullish"
        case .neutral: return "Neutral"
        case .bearish: return "Bearish"
        case .stronglyBearish: return "Very Bearish"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(sentiment.color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: sentiment.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(sentiment.color)
            }

            // Labels
            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Text(sentimentLabel)
                    .font(.caption.bold())
                    .foregroundColor(sentiment.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Technical Score Card
struct TechnicalScoreCard: View {
    let score: Int
    let colorScheme: ColorScheme

    private var scoreColor: Color {
        switch score {
        case 0..<30: return AppColors.error
        case 30..<50: return Color(hex: "F97316")
        case 50..<70: return AppColors.warning
        case 70..<85: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private var scoreLabel: String {
        switch score {
        case 0..<30: return "Bearish"
        case 30..<50: return "Slightly Bearish"
        case 50..<70: return "Neutral"
        case 70..<85: return "Bullish"
        default: return "Strongly Bullish"
        }
    }

    var body: some View {
        VStack(spacing: ArkSpacing.md) {
            Text("Technical Score")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Score gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08),
                        lineWidth: 10
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Text(scoreLabel)
                .font(.subheadline.bold())
                .foregroundColor(scoreColor)

            Text("Based on trend, moving averages, and Bollinger Bands analysis")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Legacy Single Score Card
struct PremiumScoreCard: View {
    let score: Int
    let trend: TrendAnalysis
    let colorScheme: ColorScheme

    private var scoreColor: Color {
        switch score {
        case 0..<30: return AppColors.error
        case 30..<50: return Color(hex: "F97316")
        case 50..<70: return AppColors.warning
        case 70..<85: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private var scoreLabel: String {
        switch score {
        case 0..<30: return "Bearish"
        case 30..<50: return "Weak"
        case 50..<70: return "Neutral"
        case 70..<85: return "Bullish"
        default: return "Strong"
        }
    }

    var body: some View {
        HStack(spacing: ArkSpacing.lg) {
            // Score gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                        lineWidth: 8
                    )
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Technical Score")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(scoreLabel)
                    .font(.title2.bold())
                    .foregroundColor(scoreColor)

                // Trend badge
                HStack(spacing: 4) {
                    Image(systemName: trend.direction.icon)
                        .font(.caption)
                    Text(trend.direction.shortLabel)
                        .font(.caption.bold())
                }
                .foregroundColor(trend.direction.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(trend.direction.color.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}
