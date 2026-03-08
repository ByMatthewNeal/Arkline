import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Light Branded Card (Telegram Export)
private struct LightBrandedCard<Content: View>: View {
    let showBranding: Bool
    let showTimestamp: Bool
    let logoImage: UIImage?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showBranding {
                HStack {
                    HStack(spacing: 8) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Text("ArkLine")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }

                    Spacer()

                    if showTimestamp {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "64748B"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            content
                .padding(.horizontal, 16)

            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Dark Branded Card (with pre-loaded logo)
private struct DarkBrandedCard<Content: View>: View {
    let showBranding: Bool
    let showTimestamp: Bool
    let logoImage: UIImage?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showBranding {
                HStack {
                    HStack(spacing: 8) {
                        if let logo = logoImage {
                            Image(uiImage: logo)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Text("ArkLine")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if showTimestamp {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            content
                .padding(.horizontal, 16)

            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(Color(hex: "121212"))
    }
}

// MARK: - Color Constants
private enum LightCard {
    static let textPrimary = Color(hex: "1A1A2E")
    static let textSecondary = Color(hex: "64748B")
    static let textMuted = Color(hex: "94A3B8")
    static let divider = Color(hex: "E2E8F0")
}

// MARK: - Daily Market Update Card Content
struct DailyMarketUpdateCardContent: View {
    let btcData: AssetUpdateData?
    let ethData: AssetUpdateData?
    let fearGreedIndex: FearGreedIndex?
    let vixValue: Double?
    let vixDirection: DailyMarketUpdateViewModel.TrendArrow
    let dxyValue: Double?
    let dxyDirection: DailyMarketUpdateViewModel.TrendArrow
    var isLight: Bool = true

    private var textPrimary: Color { isLight ? LightCard.textPrimary : .white }
    private var textMuted: Color { isLight ? LightCard.textMuted : Color.white.opacity(0.4) }
    private var textSecondary: Color { isLight ? LightCard.textSecondary : Color.white.opacity(0.6) }
    private var dividerColor: Color { isLight ? LightCard.divider : Color.white.opacity(0.08) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DAILY MARKET UPDATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(textMuted)
                .tracking(1.5)
                .padding(.bottom, 14)

            if let btc = btcData {
                assetSection(data: btc)
            }

            sectionDivider

            if let eth = ethData {
                assetSection(data: eth)
            }

            sectionDivider

            marketOverviewSection

            // Risk level guide
            riskLevelGuide
                .padding(.top, 12)

            HStack {
                Spacer()
                Text("Get full analysis at arkline.io")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                Spacer()
            }
            .padding(.top, 10)
        }
    }

    // MARK: - Risk Level Guide
    private var riskLevelGuide: some View {
        VStack(spacing: 4) {
            // Color bar
            HStack(spacing: 2) {
                ForEach(riskGuideTiers, id: \.label) { tier in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tier.color)
                        .frame(height: 4)
                }
            }

            // Labels
            HStack(spacing: 0) {
                Text("Accumulate")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(textMuted)
                Spacer()
                Text("DCA RISK SCALE")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(textMuted)
                    .tracking(0.5)
                Spacer()
                Text("Distribute")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(textMuted)
            }
        }
        .padding(.horizontal, 4)
    }

    private var riskGuideTiers: [(label: String, color: Color)] {
        [
            ("Very Low", RiskColors.veryLowRisk),
            ("Low", RiskColors.lowRisk),
            ("Neutral", RiskColors.neutral),
            ("Elevated", RiskColors.elevatedRisk),
            ("High", RiskColors.highRisk),
            ("Extreme", RiskColors.extremeRisk)
        ]
    }

    // MARK: - Asset Section
    private func assetSection(data: AssetUpdateData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(data.symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textPrimary)

                Spacer()

                Text(data.price >= 1
                    ? data.price.asCurrency
                    : String(format: "$%.4f", data.price))
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(textPrimary)

                HStack(spacing: 3) {
                    Image(systemName: data.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(format: "%+.2f%%", data.change24h))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(data.isPositive ? AppColors.success : AppColors.error)
            }

            if let sparkline = data.sparkline, sparkline.count > 1 {
                SparklineChart(data: sparkline, isPositive: data.isPositive, lineWidth: 1.5)
                    .frame(height: 60)
            }

            // Trend + RSI row
            HStack(spacing: 0) {
                trendBadge(label: "1H", direction: data.trend1H)
                Spacer()
                trendBadge(label: "4H", direction: data.trend4H)
                Spacer()
                trendBadge(label: "1D", direction: data.trend1D)
                Spacer()
                rsiBadge(value: data.rsi)
            }

            // Per-asset DCA risk score
            if let risk = data.riskScore {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DCA Risk Level")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                        Text("Accumulation guide — not trade advice")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundColor(textMuted)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Circle()
                            .fill(RiskColors.color(for: risk.riskLevel))
                            .frame(width: 7, height: 7)

                        Text(String(format: "%.3f", risk.riskLevel))
                            .font(.system(size: 11, weight: .bold, design: .default))
                            .foregroundColor(textPrimary)

                        Text(risk.riskCategory)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RiskColors.color(for: risk.riskLevel))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func trendBadge(label: String, direction: AssetTrendDirection) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textMuted)
            Image(systemName: direction.icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(direction.color)
            Text(direction.shortLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(direction.color)
        }
    }

    private func rsiBadge(value: Double) -> some View {
        let rsi = RSIData(value: value, period: 14)
        return HStack(spacing: 4) {
            Text("RSI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textMuted)
            Text(String(format: "%.1f", value))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(rsi.zone.color)
        }
    }

    // MARK: - Divider
    private var sectionDivider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: 1)
            .padding(.vertical, 12)
    }

    // MARK: - Market Overview (Fear & Greed + Macro only)
    private var marketOverviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MARKET OVERVIEW")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textMuted)
                .tracking(1.2)

            VStack(spacing: 6) {
                if let fg = fearGreedIndex {
                    indicatorRow(
                        label: "Fear & Greed",
                        value: "\(fg.value)",
                        detail: fg.classification,
                        detailColor: fearGreedColor(fg.value)
                    )
                }

                if let vix = vixValue {
                    indicatorRow(
                        label: "VIX",
                        value: String(format: "%.1f", vix),
                        icon: vixDirection.rawValue,
                        iconColor: vixDirection.color
                    )
                }

                if let dxy = dxyValue {
                    indicatorRow(
                        label: "DXY",
                        value: String(format: "%.1f", dxy),
                        icon: dxyDirection.rawValue,
                        iconColor: dxyDirection.color
                    )
                }
            }
        }
    }

    private func indicatorRow(
        label: String,
        value: String,
        detail: String? = nil,
        detailColor: Color = .black,
        icon: String? = nil,
        iconColor: Color = .black
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textSecondary)

            Spacer()

            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(iconColor)
                }

                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundColor(textPrimary)

                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(detailColor)
                }
            }
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        switch value {
        case 0..<25: return AppColors.error
        case 25..<45: return Color(hex: "F97316")
        case 45..<55: return AppColors.warning
        case 55..<75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }
}

// MARK: - Share Sheet View
struct DailyMarketUpdateShareSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var viewModel = DailyMarketUpdateViewModel()
    @State private var showBranding = true
    @State private var showTimestamp = true
    @State private var useLightTheme = true
    @State private var isExporting = false
    @State private var logoImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading market data...")
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            cardView
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Options")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            VStack(spacing: 0) {
                                Toggle(isOn: $showBranding) {
                                    HStack {
                                        Image(systemName: "star.circle")
                                            .foregroundColor(AppColors.accent)
                                        Text("Show ArkLine Branding")
                                            .font(AppFonts.body14)
                                    }
                                }
                                .tint(AppColors.accent)
                                .padding(14)

                                Divider()

                                Toggle(isOn: $showTimestamp) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(AppColors.accent)
                                        Text("Show Timestamp")
                                            .font(AppFonts.body14)
                                    }
                                }
                                .tint(AppColors.accent)
                                .padding(14)

                                Divider()

                                Toggle(isOn: $useLightTheme) {
                                    HStack {
                                        Image(systemName: "sun.max.fill")
                                            .foregroundColor(AppColors.accent)
                                        Text("Light Theme")
                                            .font(AppFonts.body14)
                                    }
                                }
                                .tint(AppColors.accent)
                                .padding(14)
                            }
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Telegram Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await exportAndShare() }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .disabled(isExporting || viewModel.isLoading)
                }
            }
            .task {
                // Pre-load logo as UIImage so ImageRenderer can access it
                logoImage = UIImage(named: "ArkLineAppIcon")
                await viewModel.loadData()
            }
        }
    }

    private var cardContent: DailyMarketUpdateCardContent {
        DailyMarketUpdateCardContent(
            btcData: viewModel.btcData,
            ethData: viewModel.ethData,
            fearGreedIndex: viewModel.fearGreedIndex,
            vixValue: viewModel.vixValue,
            vixDirection: viewModel.vixDirection,
            dxyValue: viewModel.dxyValue,
            dxyDirection: viewModel.dxyDirection,
            isLight: useLightTheme
        )
    }

    @ViewBuilder
    private var cardView: some View {
        if useLightTheme {
            LightBrandedCard(showBranding: showBranding, showTimestamp: showTimestamp, logoImage: logoImage) {
                cardContent
            }
        } else {
            DarkBrandedCard(showBranding: showBranding, showTimestamp: showTimestamp, logoImage: logoImage) {
                cardContent
            }
        }
    }

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        guard let image = ShareCardRenderer.renderImage(
            content: cardView,
            width: 390,
            height: 760
        ) else {
            logError("Daily market update card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
