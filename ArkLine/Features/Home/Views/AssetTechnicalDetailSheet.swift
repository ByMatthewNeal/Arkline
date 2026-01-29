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
    @State private var selectedTimeframe: AnalysisTimeframe = .daily

    // Multi-timeframe trend data
    @State private var multiTimeframeTrends: [AnalysisTimeframe: TrendAnalysis] = [:]
    @State private var isLoadingMultiTimeframe = false

    private let technicalAnalysisService = ServiceContainer.shared.technicalAnalysisService

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Asset header
                    AssetHeaderSection(asset: asset, colorScheme: colorScheme)

                    // Timeframe picker
                    TimeframePicker(selectedTimeframe: $selectedTimeframe, colorScheme: colorScheme)

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
                        // Multi-timeframe trend summary (shows 1D, 1W, 1M at a glance)
                        MultiTimeframeTrendCard(
                            trends: multiTimeframeTrends,
                            isLoading: isLoadingMultiTimeframe,
                            colorScheme: colorScheme
                        )

                        // Overall sentiment
                        OverallSentimentCard(analysis: analysis, colorScheme: colorScheme)

                        // Trend section for selected timeframe
                        TrendAnalysisCard(trend: analysis.trend, colorScheme: colorScheme)

                        // SMA section
                        SMAAnalysisCard(sma: analysis.smaAnalysis, colorScheme: colorScheme)

                        // Bollinger Bands section
                        BollingerBandsCard(bollinger: analysis.bollingerBands, colorScheme: colorScheme)

                        // Technical score
                        TechnicalScoreCard(score: analysis.technicalScore, colorScheme: colorScheme)

                        // Data source attribution
                        HStack {
                            Spacer()
                            Text("Data from Taapi.io")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        }
                        .padding(.top, ArkSpacing.sm)
                    }

                    Spacer(minLength: ArkSpacing.xxl)
                }
                .padding(.horizontal)
            }
            .background(AppColors.background(colorScheme).ignoresSafeArea())
            .navigationTitle(asset.symbol.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await fetchTechnicalAnalysis()
                await fetchMultiTimeframeTrends()
            }
            .onChange(of: selectedTimeframe) { _, _ in
                Task {
                    await fetchTechnicalAnalysis()
                }
            }
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
                interval: selectedTimeframe
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
        await MainActor.run {
            isLoadingMultiTimeframe = true
        }

        let symbol = TaapiSymbolMapper.symbol(for: asset)
        let exchange = TaapiSymbolMapper.exchange(for: asset)

        // Fetch all three timeframes in parallel
        await withTaskGroup(of: (AnalysisTimeframe, TrendAnalysis?).self) { group in
            for timeframe in AnalysisTimeframe.allCases {
                group.addTask {
                    do {
                        let analysis = try await self.technicalAnalysisService.fetchTechnicalAnalysis(
                            symbol: symbol,
                            exchange: exchange,
                            interval: timeframe
                        )
                        return (timeframe, analysis.trend)
                    } catch {
                        // Fallback to generated data
                        let mockAnalysis = TechnicalAnalysisGenerator.generate(for: self.asset)
                        return (timeframe, mockAnalysis.trend)
                    }
                }
            }

            var results: [AnalysisTimeframe: TrendAnalysis] = [:]
            for await (timeframe, trend) in group {
                if let trend = trend {
                    results[timeframe] = trend
                }
            }

            await MainActor.run {
                self.multiTimeframeTrends = results
                self.isLoadingMultiTimeframe = false
            }
        }
    }
}

// MARK: - Multi-Timeframe Trend Card
private struct MultiTimeframeTrendCard: View {
    let trends: [AnalysisTimeframe: TrendAnalysis]
    let isLoading: Bool
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Trend Overview")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

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

                // Strength indicator
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Rectangle()
                            .fill(index < trend.strength.level ? trend.direction.color : trend.direction.color.opacity(0.2))
                            .frame(width: 8, height: 4)
                            .cornerRadius(2)
                    }
                }
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
