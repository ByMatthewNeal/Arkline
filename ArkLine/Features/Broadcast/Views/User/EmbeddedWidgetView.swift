import SwiftUI

// MARK: - Embedded Widget View

/// Displays live data widgets inline within broadcast content.
/// Provides compact, read-only versions of app section widgets.
struct EmbeddedWidgetView: View {
    let section: AppSection
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = EmbeddedWidgetViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: section.iconName)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)

                Text(section.displayName)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Widget Content
            widgetContent
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .task {
            await viewModel.loadData(for: section)
        }
    }

    // MARK: - Widget Content

    @ViewBuilder
    private var widgetContent: some View {
        switch section {
        case .vix:
            vixWidget
        case .dxy:
            dxyWidget
        case .m2:
            m2Widget
        case .bitcoinRisk:
            bitcoinRiskWidget
        case .fearGreed:
            fearGreedWidget
        case .upcomingEvents:
            upcomingEventsWidget
        case .sentiment:
            sentimentWidget
        case .rainbowChart:
            rainbowChartWidget
        case .technicalAnalysis:
            technicalAnalysisWidget
        case .portfolioShowcase:
            portfolioShowcaseWidget
        }
    }

    // MARK: - VIX Widget

    private var vixWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let vix = viewModel.vixData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", vix.value))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(vixColor(vix.value))

                    Text(vixLabel(vix.value))
                        .font(ArkFonts.caption)
                        .foregroundColor(vixColor(vix.value))
                }

                Spacer()

                // Signal badge
                Text(vix.signalDescription)
                    .font(ArkFonts.caption)
                    .foregroundColor(vixColor(vix.value))
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background(vixColor(vix.value).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func vixColor(_ value: Double) -> Color {
        if value < 15 { return AppColors.success }
        if value < 20 { return Color(hex: "4ADE80") }
        if value < 25 { return AppColors.warning }
        return AppColors.error
    }

    private func vixLabel(_ value: Double) -> String {
        if value < 15 { return "Low Volatility" }
        if value < 20 { return "Normal" }
        if value < 25 { return "Elevated" }
        return "High Volatility"
    }

    // MARK: - DXY Widget

    private var dxyWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let dxy = viewModel.dxyData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", dxy.value))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Dollar Index")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let change = dxy.changePercent {
                    changeIndicator(change: change, inverted: true)
                }
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - M2 Widget

    private var m2Widget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let m2 = viewModel.liquidityData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatLiquidity(m2.current))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: 4) {
                        Text(m2.monthlyChange >= 0 ? "+" : "")
                        Text(String(format: "%.1f%%", m2.monthlyChange))
                    }
                    .font(ArkFonts.caption)
                    .foregroundColor(m2.monthlyChange >= 0 ? AppColors.success : AppColors.error)
                }

                Spacer()

                Text(m2.monthlyChange > 0 ? "Expanding" : "Contracting")
                    .font(ArkFonts.caption)
                    .foregroundColor(m2.monthlyChange > 0 ? AppColors.success : AppColors.error)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background((m2.monthlyChange > 0 ? AppColors.success : AppColors.error).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1fT", value / 1_000_000_000_000)
        }
        return String(format: "$%.0fB", value / 1_000_000_000)
    }

    // MARK: - Bitcoin Risk Widget

    private var bitcoinRiskWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let risk = viewModel.riskLevel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(riskColor(risk.riskLevel))

                    Text(riskCategory(risk.riskLevel))
                        .font(ArkFonts.caption)
                        .foregroundColor(riskColor(risk.riskLevel))
                }

                Spacer()

                // Risk gauge mini
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: risk.riskLevel)
                        .stroke(riskColor(risk.riskLevel), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                }
            } else {
                placeholderContent
            }
        }
    }

    private func riskColor(_ value: Double) -> Color {
        if value < 0.25 { return AppColors.success }
        if value < 0.5 { return Color(hex: "4ADE80") }
        if value < 0.75 { return AppColors.warning }
        return AppColors.error
    }

    private func riskCategory(_ value: Double) -> String {
        if value < 0.25 { return "Low Risk" }
        if value < 0.5 { return "Moderate Risk" }
        if value < 0.75 { return "Elevated Risk" }
        return "High Risk"
    }

    // MARK: - Fear & Greed Widget

    private var fearGreedWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let fg = viewModel.fearGreedIndex {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fg.value)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(fearGreedColor(fg.value))

                    Text(fg.level.rawValue)
                        .font(ArkFonts.caption)
                        .foregroundColor(fearGreedColor(fg.value))
                }

                Spacer()

                // Mini gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: Double(fg.value) / 100.0)
                        .stroke(fearGreedColor(fg.value), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    Text("\(fg.value)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(fearGreedColor(fg.value))
                }
            } else {
                placeholderContent
            }
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        if value < 25 { return AppColors.error }
        if value < 45 { return AppColors.warning }
        if value < 55 { return Color.gray }
        if value < 75 { return Color(hex: "4ADE80") }
        return AppColors.success
    }

    // MARK: - Upcoming Events Widget

    private var upcomingEventsWidget: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            if viewModel.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.upcomingEvents.prefix(3)) { event in
                    HStack(spacing: ArkSpacing.sm) {
                        Circle()
                            .fill(impactColor(event.impact))
                            .frame(width: 6, height: 6)

                        Text(event.title)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1)

                        Spacer()

                        Text(formatEventDate(event.date))
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func impactColor(_ impact: EventImpact) -> Color {
        switch impact {
        case .high: return AppColors.error
        case .medium: return AppColors.warning
        case .low: return AppColors.success
        }
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - Sentiment Widget

    private var sentimentWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Market Sentiment")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Analyzing social & on-chain data")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("Not Yet Available")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Rainbow Chart Widget

    private var rainbowChartWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rainbow Chart")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Long-term BTC valuation bands")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("Not Yet Available")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Technical Analysis Widget

    private var technicalAnalysisWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Technical Analysis")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Charts & indicators")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("Not Yet Available")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Portfolio Showcase Widget

    private var portfolioShowcaseWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio Showcase")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Compare portfolios side-by-side")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "square.split.2x1")
                .font(.title2)
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - Helper Views

    private var placeholderContent: some View {
        HStack {
            Text("Loading...")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    private func changeIndicator(change: Double, inverted: Bool = false) -> some View {
        let isPositive = inverted ? change < 0 : change > 0
        let color = isPositive ? AppColors.success : AppColors.error
        let icon = change >= 0 ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change)))
                .font(ArkFonts.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xxs)
        .background(color.opacity(0.1))
        .cornerRadius(ArkSpacing.xs)
    }
}

// MARK: - Embedded Widget ViewModel

@MainActor
class EmbeddedWidgetViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var vixData: VIXData?
    @Published var dxyData: DXYData?
    @Published var liquidityData: GlobalLiquidityChanges?
    @Published var riskLevel: ITCRiskLevel?
    @Published var fearGreedIndex: FearGreedIndex?
    @Published var upcomingEvents: [EconomicEvent] = []

    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol
    private let sentimentService: SentimentServiceProtocol
    private let newsService: NewsServiceProtocol

    init() {
        self.vixService = ServiceContainer.shared.vixService
        self.dxyService = ServiceContainer.shared.dxyService
        self.globalLiquidityService = ServiceContainer.shared.globalLiquidityService
        self.itcRiskService = ServiceContainer.shared.itcRiskService
        self.sentimentService = ServiceContainer.shared.sentimentService
        self.newsService = ServiceContainer.shared.newsService
    }

    func loadData(for section: AppSection) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch section {
            case .vix:
                vixData = try await vixService.fetchLatestVIX()
            case .dxy:
                dxyData = try await dxyService.fetchLatestDXY()
            case .m2:
                liquidityData = try await globalLiquidityService.fetchLiquidityChanges()
            case .bitcoinRisk:
                riskLevel = try await itcRiskService.fetchLatestRiskLevel(coin: "BTC")
            case .fearGreed:
                fearGreedIndex = try await sentimentService.fetchFearGreedIndex()
            case .upcomingEvents:
                upcomingEvents = try await newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])
            default:
                break
            }
        } catch {
            // Silently fail - widget will show placeholder
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EmbeddedWidgetView(section: .vix)
        EmbeddedWidgetView(section: .fearGreed)
        EmbeddedWidgetView(section: .bitcoinRisk)
    }
    .padding()
}
