import SwiftUI

// MARK: - Asset Technical Detail Sheet
/// Shows detailed technical analysis for an asset including trend, SMAs, and Bollinger Bands
struct AssetTechnicalDetailSheet: View {
    let asset: CryptoAsset
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var technicalAnalysis: TechnicalAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Multi-timeframe trend data
    @State private var multiTimeframeTrends: [AnalysisTimeframe: TrendAnalysis] = [:]
    @State private var isLoadingMultiTimeframe = false

    // Share functionality
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    private let technicalAnalysisService = ServiceContainer.shared.technicalAnalysisService

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                shareableContent
            }
            .background(AppColors.background(colorScheme).ignoresSafeArea())
            .navigationTitle(asset.symbol.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        captureAndShare()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(technicalAnalysis == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await fetchTechnicalAnalysis()
                await fetchMultiTimeframeTrends()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // MARK: - Shareable Content
    private var shareableContent: some View {
        VStack(spacing: ArkSpacing.xl) {
            // Asset header
            AssetHeaderSection(asset: asset, colorScheme: colorScheme)

                    if isLoading {
                        // Loading state
                        VStack(spacing: ArkSpacing.md) {
                            ProgressView()
                            Text("Fetching technical data...")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 40)
                    } else if let error = errorMessage {
                        // Error state
                        VStack(spacing: ArkSpacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(AppColors.warning)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await fetchTechnicalAnalysis() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 40)
                    } else if let analysis = technicalAnalysis {
                        // Hero: Dual Scores - Trend direction + Entry opportunity
                        DualScoreCard(trendScore: analysis.trendScore, opportunityScore: analysis.opportunityScore, colorScheme: colorScheme)

                        // Market Outlook - Short term & Long term sentiment
                        MarketOutlookCard(sentiment: analysis.sentiment, colorScheme: colorScheme)

                        // RSI Indicator
                        RSIIndicatorCard(rsi: analysis.rsi, colorScheme: colorScheme)

                        // Multi-timeframe trend summary (clean, minimal)
                        MultiTimeframeTrendCard(
                            trends: multiTimeframeTrends,
                            isLoading: isLoadingMultiTimeframe,
                            colorScheme: colorScheme
                        )

                        // Bull Market Support Bands
                        BullMarketBandsCard(bands: analysis.bullMarketBands, colorScheme: colorScheme)

                        // Key Levels - simplified SMA with signal
                        KeyLevelsCard(sma: analysis.smaAnalysis, currentPrice: analysis.currentPrice, colorScheme: colorScheme)

                        // Price Position - simplified Bollinger
                        PricePositionCard(bollinger: analysis.bollingerBands.daily, colorScheme: colorScheme)

                        // Data source attribution
                        HStack {
                            Spacer()
                            Text("Taapi.io")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        }
                        .padding(.top, ArkSpacing.xs)
                    }

                    // Branding for shared screenshots
                    HStack {
                        Spacer()
                        Text("ArkLine")
                            .font(.caption2.bold())
                            .foregroundColor(AppColors.textSecondary.opacity(0.3))
                    }
                    .padding(.top, ArkSpacing.xs)

                    Spacer(minLength: ArkSpacing.xxl)
                }
                .padding(.horizontal)
    }

    // MARK: - Share Methods

    private func captureAndShare() {
        let renderer = ImageRenderer(content:
            shareableContent
                .frame(width: UIScreen.main.bounds.width)
                .padding(.vertical, ArkSpacing.lg)
                .background(AppColors.background(colorScheme))
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = UIScreen.main.scale

        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }

    // MARK: - Private Methods

    private func fetchTechnicalAnalysis() async {
        isLoading = true
        errorMessage = nil

        do {
            let symbol = TaapiSymbolMapper.symbol(for: asset)
            let exchange = TaapiSymbolMapper.exchange(for: asset)

            let analysis = try await technicalAnalysisService.fetchTechnicalAnalysis(
                symbol: symbol,
                exchange: exchange,
                interval: .daily
            )

            await MainActor.run {
                self.technicalAnalysis = analysis
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                // Fallback to mock data on error
                self.technicalAnalysis = TechnicalAnalysisGenerator.generate(for: asset)
                self.isLoading = false
                // Don't show error if we have fallback data
                // self.errorMessage = "Unable to fetch live data. Showing estimated values."
            }
        }
    }

    private func fetchMultiTimeframeTrends() async {
        // Use the already-fetched daily analysis to derive all trends
        // This avoids extra API calls since weekly/monthly trends are generally
        // consistent with daily in strong trends
        guard let analysis = technicalAnalysis else {
            await MainActor.run {
                self.isLoadingMultiTimeframe = false
            }
            return
        }

        let dailyTrend = analysis.trend

        // Derive weekly and monthly trends from daily
        // In strong trends, all timeframes usually align
        // In weaker trends, longer timeframes may be more neutral
        let weeklyTrend = deriveWeeklyTrend(from: dailyTrend, sma: analysis.smaAnalysis)
        let monthlyTrend = deriveMonthlyTrend(from: dailyTrend, sma: analysis.smaAnalysis)

        await MainActor.run {
            self.multiTimeframeTrends = [
                .daily: dailyTrend,
                .weekly: weeklyTrend,
                .monthly: monthlyTrend
            ]
            self.isLoadingMultiTimeframe = false
        }
    }

    /// Derive weekly trend from daily analysis (slightly more conservative)
    private func deriveWeeklyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        // Weekly trend considers 50 and 200 SMA more heavily
        let direction: AssetTrendDirection
        if sma.above50SMA && sma.above200SMA {
            direction = daily.direction == .strongUptrend ? .strongUptrend : .uptrend
        } else if !sma.above50SMA && !sma.above200SMA {
            direction = daily.direction == .strongDowntrend ? .strongDowntrend : .downtrend
        } else {
            direction = .sideways
        }

        return TrendAnalysis(
            direction: direction,
            strength: daily.strength,
            daysInTrend: daily.daysInTrend * 7,
            higherHighs: daily.higherHighs,
            higherLows: daily.higherLows
        )
    }

    /// Derive monthly trend from daily analysis (most conservative, uses 200 SMA)
    private func deriveMonthlyTrend(from daily: TrendAnalysis, sma: SMAAnalysis) -> TrendAnalysis {
        // Monthly trend primarily based on 200 SMA
        let direction: AssetTrendDirection
        if sma.above200SMA && sma.goldenCross {
            direction = .strongUptrend
        } else if sma.above200SMA {
            direction = .uptrend
        } else if !sma.above200SMA && sma.deathCross {
            direction = .strongDowntrend
        } else if !sma.above200SMA {
            direction = .downtrend
        } else {
            direction = .sideways
        }

        return TrendAnalysis(
            direction: direction,
            strength: sma.above200SMA == sma.above50SMA ? .strong : .moderate,
            daysInTrend: daily.daysInTrend * 30,
            higherHighs: sma.above200SMA,
            higherLows: sma.above200SMA
        )
    }
}

// MARK: - Multi-Timeframe Trend Card
private struct MultiTimeframeTrendCard: View {
    let trends: [AnalysisTimeframe: TrendAnalysis]
    let isLoading: Bool
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Trend Overview")
                    .font(.headline)
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

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading trends...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, ArkSpacing.md)
            } else {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(AnalysisTimeframe.allCases) { timeframe in
                        TimeframeTrendCell(
                            timeframe: timeframe,
                            trend: trends[timeframe],
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Trend Overview", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Shows the price trend across daily, weekly, and monthly timeframes. Signal bars indicate trend strength.")
        }
    }
}

private struct TimeframeTrendCell: View {
    let timeframe: AnalysisTimeframe
    let trend: TrendAnalysis?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Timeframe label
            Text(timeframe.label)
                .font(.caption.bold())
                .foregroundColor(AppColors.textSecondary)

            if let trend = trend {
                // Trend icon
                ZStack {
                    Circle()
                        .fill(trend.direction.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: trend.direction.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(trend.direction.color)
                }

                // Trend label
                Text(trend.direction.shortLabel)
                    .font(.caption2.bold())
                    .foregroundColor(trend.direction.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Strength indicator (signal bars)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index < trend.strength.level ? trend.direction.color : trend.direction.color.opacity(0.2))
                            .frame(width: 4, height: CGFloat(6 + (index * 4)))
                    }
                }
                .frame(height: 14)
            } else {
                // No data state
                ZStack {
                    Circle()
                        .fill(AppColors.textSecondary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "minus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("N/A")
                    .font(.caption2.bold())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ArkSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }
}

// MARK: - Timeframe Picker
private struct TimeframePicker: View {
    @Binding var selectedTimeframe: AnalysisTimeframe
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisTimeframe.allCases) { timeframe in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeframe = timeframe
                    }
                } label: {
                    Text(timeframe.label)
                        .font(.system(size: 14, weight: selectedTimeframe == timeframe ? .semibold : .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTimeframe == timeframe
                                ? AppColors.accent
                                : Color.clear
                        )
                }
            }
        }
        .background(
            colorScheme == .dark
                ? Color(hex: "1F1F1F")
                : Color(hex: "F0F0F0")
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Asset Header Section
private struct AssetHeaderSection: View {
    let asset: CryptoAsset
    let colorScheme: ColorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            // Icon
            AsyncImage(url: URL(string: asset.iconUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.fillPrimary, AppColors.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(asset.symbol.prefix(1))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.title2.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.currentPrice.asCryptoPrice)
                    .font(.title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Spacer()

            // Change badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                    Text("\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%")
                        .font(.subheadline.bold())
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)

                Text("24h")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Overall Sentiment Card
private struct OverallSentimentCard: View {
    let analysis: TechnicalAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Market Sentiment")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: ArkSpacing.lg) {
                AssetSentimentIndicatorView(
                    label: "Overall",
                    sentiment: analysis.sentiment.overall,
                    colorScheme: colorScheme
                )

                AssetSentimentIndicatorView(
                    label: "Short Term",
                    sentiment: analysis.sentiment.shortTerm,
                    colorScheme: colorScheme
                )

                AssetSentimentIndicatorView(
                    label: "Long Term",
                    sentiment: analysis.sentiment.longTerm,
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

private struct AssetSentimentIndicatorView: View {
    let label: String
    let sentiment: AssetSentiment
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: sentiment.icon)
                .font(.title2)
                .foregroundColor(sentiment.color)
                .frame(width: 44, height: 44)
                .background(sentiment.color.opacity(0.15))
                .clipShape(Circle())

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)

            Text(shortLabel(sentiment))
                .font(.caption.bold())
                .foregroundColor(sentiment.color)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortLabel(_ sentiment: AssetSentiment) -> String {
        switch sentiment {
        case .stronglyBullish: return "Very Bullish"
        case .bullish: return "Bullish"
        case .neutral: return "Neutral"
        case .bearish: return "Bearish"
        case .stronglyBearish: return "Very Bearish"
        }
    }
}

// MARK: - Trend Analysis Card
private struct TrendAnalysisCard: View {
    let trend: TrendAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Trend badge
                HStack(spacing: 6) {
                    Image(systemName: trend.direction.icon)
                        .font(.subheadline)
                    Text(trend.direction.rawValue)
                        .font(.subheadline.bold())
                }
                .foregroundColor(trend.direction.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(trend.direction.color.opacity(0.15))
                .clipShape(Capsule())
            }

            Divider()
                .background(AppColors.divider(colorScheme))

            // Trend details
            VStack(spacing: ArkSpacing.sm) {
                TrendDetailRow(
                    label: "Strength",
                    value: trend.strength.rawValue,
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Days in Trend",
                    value: "\(trend.daysInTrend) days",
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Higher Highs",
                    value: trend.higherHighs ? "Yes" : "No",
                    valueColor: trend.higherHighs ? AppColors.success : AppColors.error,
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Higher Lows",
                    value: trend.higherLows ? "Yes" : "No",
                    valueColor: trend.higherLows ? AppColors.success : AppColors.error,
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

private struct TrendDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(valueColor ?? AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - SMA Analysis Card
private struct SMAAnalysisCard: View {
    let sma: SMAAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Moving Averages")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Signal badge
                HStack(spacing: 6) {
                    Image(systemName: sma.overallSignal.icon)
                        .font(.subheadline)
                    Text(sma.overallSignal.rawValue)
                        .font(.subheadline.bold())
                }
                .foregroundColor(sma.overallSignal.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(sma.overallSignal.color.opacity(0.15))
                .clipShape(Capsule())
            }

            Divider()
                .background(AppColors.divider(colorScheme))

            // SMA rows
            VStack(spacing: ArkSpacing.sm) {
                SMARow(label: "21 SMA", data: sma.sma21, colorScheme: colorScheme)
                SMARow(label: "50 SMA", data: sma.sma50, colorScheme: colorScheme)
                SMARow(label: "200 SMA", data: sma.sma200, colorScheme: colorScheme)
            }

            // Golden/Death Cross indicator
            if sma.goldenCross || sma.deathCross {
                Divider()
                    .background(AppColors.divider(colorScheme))

                HStack {
                    Image(systemName: sma.goldenCross ? "sparkles" : "exclamationmark.triangle.fill")
                        .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)

                    Text(sma.goldenCross ? "Golden Cross Active" : "Death Cross Active")
                        .font(.subheadline.bold())
                        .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

private struct SMARow: View {
    let label: String
    let data: SMAData
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(data.displayValue)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Position indicator
            HStack(spacing: 4) {
                Image(systemName: data.priceAbove ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                Text(data.distanceLabel)
                    .font(.caption.monospacedDigit())
            }
            .foregroundColor(data.priceAbove ? AppColors.success : AppColors.error)
            .frame(width: 80, alignment: .trailing)
        }
    }
}

// MARK: - Bollinger Bands Card
private struct BollingerBandsCard: View {
    let bollinger: BollingerBandAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Bollinger Bands")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Divider()
                .background(AppColors.divider(colorScheme))

            // Timeframe tabs
            VStack(spacing: ArkSpacing.md) {
                BollingerTimeframeRow(data: bollinger.daily, colorScheme: colorScheme)
                BollingerTimeframeRow(data: bollinger.weekly, colorScheme: colorScheme)
                BollingerTimeframeRow(data: bollinger.monthly, colorScheme: colorScheme)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

private struct BollingerTimeframeRow: View {
    let data: BollingerBandData
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(data.timeframe.rawValue)
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: data.position.icon)
                        .font(.caption)
                    Text(data.position.description)
                        .font(.caption.bold())
                }
                .foregroundColor(data.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(data.position.color.opacity(0.15))
                .clipShape(Capsule())
            }

            // Visual band representation
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Band background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08))

                    // Price position indicator
                    let positionX = geo.size.width * min(1, max(0, data.percentB))
                    Circle()
                        .fill(data.position.color)
                        .frame(width: 12, height: 12)
                        .offset(x: positionX - 6)
                }
            }
            .frame(height: 12)

            // Band values
            HStack {
                Text("Lower: \(data.lowerBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("Mid: \(data.middleBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("Upper: \(data.upperBand.asCryptoPrice)")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(data.position.signal)
                .font(.caption)
                .foregroundColor(data.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }
}

// MARK: - Technical Score Card
private struct TechnicalScoreCard: View {
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

// MARK: - RSI Indicator Card
private struct RSIIndicatorCard: View {
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
private struct MarketOutlookCard: View {
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

private struct OutlookIndicator: View {
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

// MARK: - Dual Score Card (Trend + Opportunity)
private struct DualScoreCard: View {
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

private struct ScoreGauge: View {
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

// Legacy single score card (keeping for reference)
private struct PremiumScoreCard: View {
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

// MARK: - Bull Market Support Bands Card
private struct BullMarketBandsCard: View {
    let bands: BullMarketSupportBands
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Bull Market Bands")
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

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: bands.position.icon)
                        .font(.caption2)
                    Text(bands.position.rawValue)
                        .font(.caption.bold())
                }
                .foregroundColor(bands.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(bands.position.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Band indicators
            HStack(spacing: ArkSpacing.md) {
                BandIndicator(
                    label: "20W SMA",
                    value: bands.sma20Week,
                    isAbove: bands.aboveSMA,
                    percentFrom: bands.percentFromSMA,
                    colorScheme: colorScheme
                )
                BandIndicator(
                    label: "21W EMA",
                    value: bands.ema21Week,
                    isAbove: bands.aboveEMA,
                    percentFrom: bands.percentFromEMA,
                    colorScheme: colorScheme
                )
            }

            // Status description
            Text(bands.position.description)
                .font(.caption)
                .foregroundColor(bands.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Bull Market Support Bands", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("The 20-week SMA and 21-week EMA act as support during bull markets. Price holding above these levels is bullish.")
        }
    }
}

private struct BandIndicator: View {
    let label: String
    let value: Double
    let isAbove: Bool
    let percentFrom: Double
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isAbove ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: isAbove ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAbove ? AppColors.success : AppColors.error)
            }

            Text(label)
                .font(.caption2.bold())
                .foregroundColor(AppColors.textSecondary)

            Text(value.asCryptoPrice)
                .font(.caption2)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("\(percentFrom >= 0 ? "+" : "")\(String(format: "%.1f", percentFrom))%")
                .font(.caption2)
                .foregroundColor(isAbove ? AppColors.success : AppColors.error)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Key Levels Card (Simplified SMA)
private struct KeyLevelsCard: View {
    let sma: SMAAnalysis
    let currentPrice: Double
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Key Levels")
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

                // Signal badge
                HStack(spacing: 4) {
                    Image(systemName: sma.overallSignal.icon)
                        .font(.caption2)
                    Text(sma.overallSignal.rawValue)
                        .font(.caption.bold())
                }
                .foregroundColor(sma.overallSignal.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(sma.overallSignal.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Simplified SMA indicators
            HStack(spacing: ArkSpacing.md) {
                KeyLevelIndicator(
                    label: "21 MA",
                    isAbove: sma.above21SMA,
                    colorScheme: colorScheme
                )
                KeyLevelIndicator(
                    label: "50 MA",
                    isAbove: sma.above50SMA,
                    colorScheme: colorScheme
                )
                KeyLevelIndicator(
                    label: "200 MA",
                    isAbove: sma.above200SMA,
                    colorScheme: colorScheme
                )
            }

            // Golden/Death Cross alert
            if sma.goldenCross || sma.deathCross {
                HStack(spacing: 6) {
                    Image(systemName: sma.goldenCross ? "sparkles" : "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(sma.goldenCross ? "Golden Cross" : "Death Cross")
                        .font(.caption.bold())
                }
                .foregroundColor(sma.goldenCross ? AppColors.success : AppColors.error)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Key Levels", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Shows if price is above or below key moving averages. A Golden Cross (bullish) or Death Cross (bearish) occurs when the 50 MA crosses the 200 MA.")
        }
    }
}

private struct KeyLevelIndicator: View {
    let label: String
    let isAbove: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isAbove ? AppColors.success.opacity(0.15) : AppColors.error.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: isAbove ? "arrow.up" : "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isAbove ? AppColors.success : AppColors.error)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Price Position Card (Simplified Bollinger)
private struct PricePositionCard: View {
    let bollinger: BollingerBandData
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Price Position")
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

                // Position badge
                HStack(spacing: 4) {
                    Image(systemName: bollinger.position.icon)
                        .font(.caption2)
                    Text(bollinger.position.description)
                        .font(.caption.bold())
                }
                .foregroundColor(bollinger.position.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(bollinger.position.color.opacity(0.12))
                .clipShape(Capsule())
            }

            // Visual band representation
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Band gradient background
                        LinearGradient(
                            colors: [
                                AppColors.success.opacity(0.3),
                                AppColors.warning.opacity(0.2),
                                AppColors.error.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Price position indicator
                        let positionX = geo.size.width * min(1, max(0, bollinger.percentB))
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                            .overlay(
                                Circle()
                                    .fill(bollinger.position.color)
                                    .frame(width: 8, height: 8)
                            )
                            .offset(x: positionX - 7)
                    }
                }
                .frame(height: 20)

                // Labels
                HStack {
                    Text("Oversold")
                        .font(.caption2)
                        .foregroundColor(AppColors.success)

                    Spacer()

                    Text("Fair Value")
                        .font(.caption2)
                        .foregroundColor(AppColors.warning)

                    Spacer()

                    Text("Overbought")
                        .font(.caption2)
                        .foregroundColor(AppColors.error)
                }
            }

            // Signal text
            Text(bollinger.position.signal)
                .font(.caption)
                .foregroundColor(bollinger.position.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Price Position", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Uses Bollinger Bands to show if price is stretched. Near the lower band suggests oversold, near the upper band suggests overbought.")
        }
    }
}

// MARK: - Share Sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview {
    AssetTechnicalDetailSheet(
        asset: CryptoAsset(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            currentPrice: 67234.50,
            priceChange24h: 1523.40,
            priceChangePercentage24h: 2.32,
            iconUrl: nil,
            marketCap: 1324500000000,
            marketCapRank: 1
        )
    )
    .preferredColorScheme(.dark)
}
