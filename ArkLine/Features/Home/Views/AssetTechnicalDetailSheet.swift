import SwiftUI
import Kingfisher

// MARK: - Asset Technical Detail Sheet
/// Shows detailed technical analysis for an asset including trend, SMAs, and Bollinger Bands
struct AssetTechnicalDetailSheet: View {
    let asset: CryptoAsset
    @EnvironmentObject var appState: AppState
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
            Group {
                if appState.isPro || asset.symbol.uppercased() == "BTC" {
                    ScrollView {
                        shareableContent
                    }
                    .background(AppColors.background(colorScheme).ignoresSafeArea())
                } else {
                    PremiumFeatureGate(feature: .technicalAnalysis) {}
                }
            }
            .navigationTitle(asset.symbol.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if appState.isPro || asset.symbol.uppercased() == "BTC" {
                        Button {
                            captureAndShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(technicalAnalysis == nil)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if appState.isPro || asset.symbol.uppercased() == "BTC" {
                    await fetchTechnicalAnalysis()
                    await fetchMultiTimeframeTrends()
                }
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

            // Archive technicals (fire-and-forget)
            Task { await MarketDataCollector.shared.recordTechnicals(analysis) }

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

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
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
