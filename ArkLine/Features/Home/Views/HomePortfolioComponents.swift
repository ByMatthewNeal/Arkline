import SwiftUI
import Kingfisher

// MARK: - Portfolio Hero Card
struct PortfolioHeroCard: View {
    let totalValue: Double
    let change: Double
    let changePercent: Double
    let portfolioName: String
    let chartData: [CGFloat]
    let onPortfolioTap: () -> Void
    let onSetupTap: () -> Void
    var onAddPosition: (() -> Void)? = nil
    @Binding var selectedTimePeriod: TimePeriod
    var hasLoadedPortfolios: Bool = true
    var hasPortfolios: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage(Constants.UserDefaults.portfolioHidden) private var isHidden = false
    @State private var showShareSheet = false

    private var currency: String { appState.preferredCurrency }

    // Track time period changes to re-trigger animation
    @State private var chartAnimationId = UUID()

    var isPositive: Bool { change >= 0 }
    private var isEmpty: Bool { !hasPortfolios && hasLoadedPortfolios }
    private var isLoadingPortfolio: Bool { !hasLoadedPortfolios }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            if isLoadingPortfolio {
                loadingStateContent
            } else if isEmpty {
                emptyStateContent
            } else {
                portfolioContent
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 6)
        .onChange(of: selectedTimePeriod) { _, _ in
            chartAnimationId = UUID()
        }
        .sheet(isPresented: $showShareSheet) {
            PortfolioShareSheet(
                portfolioName: portfolioName,
                totalValue: totalValue,
                change: change,
                changePercent: changePercent,
                timePeriod: selectedTimePeriod.rawValue,
                chartData: chartData
            )
        }
    }

    // MARK: - Loading State
    private var loadingStateContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)
                .tint(AppColors.accent)

            Text("Loading portfolio...")
                .font(.system(size: 14))
                .foregroundColor(textPrimary.opacity(0.5))
        }
        .padding(.vertical, 24)
    }

    // MARK: - Empty State
    private var emptyStateContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppColors.accent.opacity(0.6))

            VStack(spacing: 6) {
                Text("Track Your Portfolio")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textPrimary)

                Text("Add your holdings to see your total value, performance, and allocation.")
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button(action: onSetupTap) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Set Up Portfolio")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(AppColors.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Portfolio Content
    private var portfolioContent: some View {
        Group {
            // Portfolio Selector + Privacy Toggle
            HStack {
                Button(action: onPortfolioTap) {
                    HStack(spacing: 6) {
                        Text(portfolioName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                if let onAddPosition = onAddPosition {
                    Button(action: onAddPosition) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }

                if totalValue > 0 {
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textPrimary.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isHidden.toggle() }
                } label: {
                    Image(systemName: isHidden ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                        )
                }
                .buttonStyle(.plain)
            }

            TimePeriodSelector(selectedPeriod: $selectedTimePeriod)

            VStack(spacing: 8) {
                Text("FUNDS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .tracking(1)

                Text(isHidden ? "••••••" : totalValue.asCurrency(code: currency))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(textPrimary)
                    .contentTransition(.numericText())

                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))

                    Text(isHidden ? "••••" : "\(isPositive ? "+" : "")\(change.asCurrency(code: currency))")
                        .font(.system(size: 16, weight: .semibold))
                        .contentTransition(.numericText())

                    Text(isHidden ? "" : "(\(isPositive ? "+" : "")\(changePercent, specifier: "%.2f")%)")
                        .font(.system(size: 14))
                        .opacity(0.8)
                        .contentTransition(.numericText())
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((isPositive ? AppColors.success : AppColors.error).opacity(0.15))
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isHidden ? "Portfolio hidden" : "\(portfolioName) portfolio, \(totalValue.asCurrency(code: currency)), \(isPositive ? "up" : "down") \(String(format: "%.2f", abs(changePercent))) percent")

            PortfolioSparkline(
                dataPoints: chartData,
                isPositive: isPositive,
                showGlow: true,
                showEndDot: true,
                animated: true
            )
            .id(chartAnimationId)
            .frame(height: 80)

            Text("Prices update every 60s")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
        }
    }
}

// MARK: - Time Period Selector
struct TimePeriodSelector: View {
    @Binding var selectedPeriod: TimePeriod
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TimePeriod.allCases) { period in
                TimePeriodPill(
                    period: period,
                    isSelected: selectedPeriod == period,
                    onTap: { selectedPeriod = period }
                )
            }
        }
    }
}

// MARK: - Time Period Pill
struct TimePeriodPill: View {
    let period: TimePeriod
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onTap) {
            Text(period.displayName)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : textPrimary.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : textPrimary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(period.displayName)\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Portfolio Picker Sheet
struct PortfolioPickerSheet: View {
    let portfolios: [Portfolio]
    @Binding var selectedPortfolio: Portfolio?
    var onCreatePortfolio: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(portfolios) { portfolio in
                            PortfolioPickerRow(
                                portfolio: portfolio,
                                isSelected: selectedPortfolio?.id == portfolio.id,
                                onSelect: {
                                    selectedPortfolio = portfolio
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }

                Button(action: {
                    dismiss()
                    onCreatePortfolio?()
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 44, height: 44)

                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColors.accent)
                        }

                        Text("Create New Portfolio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardBackground)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Select Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Portfolio Picker Row
struct PortfolioPickerRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(portfolioColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: portfolioIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(portfolioColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(portfolio.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.accent)
                } else {
                    Circle()
                        .stroke(textPrimary.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(portfolio.name)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(.isButton)
    }

    private var portfolioIcon: String {
        switch portfolio.name.lowercased() {
        case let name where name.contains("crypto"):
            return "bitcoinsign.circle"
        case let name where name.contains("long"):
            return "chart.line.uptrend.xyaxis"
        case let name where name.contains("main"):
            return "briefcase"
        default:
            return "folder"
        }
    }

    private var portfolioColor: Color {
        AppColors.accent
    }
}

// MARK: - Macro Trend Signal
enum MacroTrendSignal: String {
    case bullish = "Bullish"
    case bearish = "Bearish"
    case neutral = "Neutral"

    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .bearish: return AppColors.error
        case .neutral: return AppColors.warning
        }
    }

    var icon: String {
        switch self {
        case .bullish: return "arrow.up.right.circle.fill"
        case .bearish: return "arrow.down.right.circle.fill"
        case .neutral: return "minus.circle.fill"
        }
    }
}

// MARK: - Multi-Coin Risk Section
struct MultiCoinRiskSection: View {
    let riskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?, weeklyAvgRisk: Double?)]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crypto Risk Levels")
                        .font(size == .compact ? .subheadline : .title3)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Regression from genesis")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }

                Spacer()

                Text("\(riskLevels.count) selected")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.xs)

            // Horizontal scrolling risk cards
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: ArkSpacing.sm) {
                    ForEach(riskLevels, id: \.coin) { item in
                        CompactRiskCard(
                            riskLevel: item.riskLevel,
                            coinSymbol: item.coin,
                            daysAtLevel: item.daysAtLevel,
                            weeklyAvgRisk: item.weeklyAvgRisk
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, ArkSpacing.xs)
            }
            .clipped()
        }
    }
}

// MARK: - Compact Risk Card (for Multi-Coin Display)
struct CompactRiskCard: View {
    let riskLevel: ITCRiskLevel?
    let coinSymbol: String
    var daysAtLevel: Int? = nil
    var weeklyAvgRisk: Double? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false
    @State private var hasTimedOut = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var cryptoIconFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F7931A"), Color(hex: "E8830C")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
            Text(coinSymbol.prefix(1))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                // Header with logo
                HStack(spacing: 8) {
                    if let logoURL = AssetRiskConfig.forCoin(coinSymbol)?.logoURL {
                        KFImage(logoURL)
                            .resizable()
                            .placeholder {
                                cryptoIconFallback
                            }
                            .fade(duration: 0.2)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                    } else {
                        cryptoIconFallback
                    }

                    Text(coinSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                }

                if let risk = riskLevel {
                    // Risk value
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))

                    // Category badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(RiskColors.color(for: risk.riskLevel))
                            .frame(width: 6, height: 6)

                        Text(RiskColors.category(for: risk.riskLevel))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RiskColors.color(for: risk.riskLevel))
                            .lineLimit(1)
                    }

                    // Days at level indicator
                    if let days = daysAtLevel {
                        Text("\(days) day\(days == 1 ? "" : "s") at this level")
                            .font(.system(size: 9))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .padding(.top, 2)
                    }

                    // 7-day rolling average
                    if let weeklyAvg = weeklyAvgRisk {
                        Divider().padding(.vertical, 2)
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.textSecondary)
                            Text("7d Avg")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text(String(format: "%.3f", weeklyAvg))
                                .font(.system(size: 11, weight: .bold, design: .default))
                                .foregroundColor(RiskColors.color(for: weeklyAvg))
                        }
                    }
                } else if hasTimedOut {
                    // Failed / timed out state
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .default))
                        .foregroundColor(textPrimary.opacity(0.3))

                    Text("Tap to retry")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                } else {
                    // Loading state
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 24)

                    Text("Loading...")
                        .font(.system(size: 10))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
            .padding(ArkSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(riskLevel.map { "\(coinSymbol), risk \(String(format: "%.3f", $0.riskLevel)), \(RiskColors.category(for: $0.riskLevel))" } ?? "\(coinSymbol), loading")
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView(initialCoin: RiskCoin(rawValue: coinSymbol) ?? .btc)
        }
        .task(id: riskLevel == nil) {
            guard riskLevel == nil else {
                hasTimedOut = false
                return
            }
            try? await Task.sleep(for: .seconds(5))
            if riskLevel == nil { hasTimedOut = true }
        }
    }
}

// MARK: - Stock Risk Level Section

struct StockRiskLevelSection: View {
    let riskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?, weeklyAvgRisk: Double?)]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stock Risk Levels")
                        .font(size == .compact ? .subheadline : .title3)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Regression from IPO")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }

                Spacer()

                Text("\(riskLevels.count) stocks")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.xs)

            // Horizontal scrolling cards (stocks will always be 3+)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: ArkSpacing.sm) {
                    ForEach(riskLevels, id: \.coin) { item in
                        StockCompactRiskCard(
                            riskLevel: item.riskLevel,
                            symbol: item.coin,
                            daysAtLevel: item.daysAtLevel,
                            weeklyAvgRisk: item.weeklyAvgRisk
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, ArkSpacing.xs)
            }
            .clipped()
        }
    }
}

// MARK: - Stock Compact Risk Card

private struct StockCompactRiskCard: View {
    let riskLevel: ITCRiskLevel?
    let symbol: String
    var daysAtLevel: Int? = nil
    var weeklyAvgRisk: Double? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var hasTimedOut = false
    @State private var showingDetail = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    private var displayName: String {
        AssetRiskConfig.forStock(symbol)?.displayName ?? symbol
    }

    private var stockIconFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
            Text(symbol.prefix(1))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header with logo
            HStack(spacing: 8) {
                if let logoURL = AssetRiskConfig.forStock(symbol)?.logoURL {
                    KFImage(logoURL)
                        .resizable()
                        .placeholder {
                            stockIconFallback
                        }
                        .fade(duration: 0.2)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                } else {
                    stockIconFallback
                }

                Text(symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
            }

            if let risk = riskLevel {
                // Risk value
                Text(String(format: "%.3f", risk.riskLevel))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(RiskColors.color(for: risk.riskLevel))

                // Category badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(RiskColors.color(for: risk.riskLevel))
                        .frame(width: 6, height: 6)

                    Text(RiskColors.category(for: risk.riskLevel))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))
                        .lineLimit(1)
                }

                // Days at level
                if let days = daysAtLevel {
                    Text("\(days) day\(days == 1 ? "" : "s") at this level")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .padding(.top, 2)
                }

                // 7-day average
                if let weeklyAvg = weeklyAvgRisk {
                    Divider().padding(.vertical, 2)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.textSecondary)
                        Text("7d Avg")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(String(format: "%.3f", weeklyAvg))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(RiskColors.color(for: weeklyAvg))
                    }
                }
            } else if hasTimedOut {
                Text("--")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimary.opacity(0.3))
                Text("Unavailable")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(height: 24)
                Text("Loading...")
                    .font(.system(size: 10))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .arkShadow(ArkSpacing.Shadow.card)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            StockRiskDetailSheet(symbol: symbol)
                .presentationDetents([.large])
        }
        .task(id: riskLevel == nil) {
            guard riskLevel == nil else {
                hasTimedOut = false
                return
            }
            try? await Task.sleep(for: .seconds(6))
            if riskLevel == nil { hasTimedOut = true }
        }
    }
}

// MARK: - Stock Risk Detail Sheet

private struct StockRiskDetailSheet: View {
    let symbol: String
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var riskLevel: RiskHistoryPoint?
    @State private var riskHistory: [RiskHistoryPoint] = []
    @State private var isLoading = true
    @State private var selectedTimeRange: RiskTimeRange = .oneYear
    @State private var showChart = true
    @State private var selectedDate: Date?
    @State private var multiFactorRisk: MultiFactorRiskPoint?
    @State private var isLoadingMultiFactor = false
    @State private var showFactorBreakdown = true
    @State private var multiFactorElapsed = 0

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var config: AssetRiskConfig? { AssetRiskConfig.forStock(symbol) }

    private var detailIconFallback: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            Text(symbol.prefix(2))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var filteredHistory: [RiskHistoryPoint] {
        guard let days = selectedTimeRange.days else { return riskHistory }
        return Array(riskHistory.suffix(days))
    }

    private var selectedPoint: RiskHistoryPoint? {
        guard let selectedDate else { return nil }
        // Find nearest point by date
        return filteredHistory.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                ScrollView {
                    VStack(spacing: ArkSpacing.xl) {
                        // Stock name header
                        stockHeader
                            .padding(.top, ArkSpacing.md)

                        // Time range picker
                        timeRangePicker

                        // Chart
                        chartSection

                        // Multi-factor risk value (matches crypto latestValueSection)
                        multiFactorSection

                        // Factor breakdown (matches crypto factorBreakdownSection)
                        factorBreakdownSection

                        // Risk legend
                        riskLegendSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                }
            }
            .navigationTitle("\(symbol) Risk Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .task {
            // Run chart/risk data and multi-factor in parallel
            async let dataTask: () = loadData()
            async let mfTask: () = loadMultiFactor()
            _ = await (dataTask, mfTask)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            Task { await loadData(days: daysForFetch(newRange)) }
        }
    }

    private func daysForFetch(_ range: RiskTimeRange) -> Int? {
        guard let days = range.days else { return nil }
        return max(days, 30)
    }

    private func loadData(days: Int? = 365) async {
        guard let service = ServiceContainer.shared.itcRiskService as? APIITCRiskService else {
            isLoading = false
            return
        }
        do {
            async let risk = service.calculateStockCurrentRisk(symbol: symbol)
            async let history = service.fetchStockRiskHistory(symbol: symbol, days: days)
            let (r, h) = try await (risk, history)
            riskLevel = r
            riskHistory = h
        } catch {
            logWarning("Stock risk detail failed for \(symbol): \(error.localizedDescription)", category: .network)
        }
        isLoading = false
    }

    private func loadMultiFactor() async {
        guard let service = ServiceContainer.shared.itcRiskService as? APIITCRiskService else { return }
        isLoadingMultiFactor = true
        multiFactorElapsed = 0

        // Timer for elapsed display
        let timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { multiFactorElapsed += 1 }
            }
        }

        do {
            let risk = try await service.calculateStockMultiFactorRisk(symbol: symbol)
            multiFactorRisk = risk
        } catch {
            logWarning("Stock multi-factor failed for \(symbol): \(error.localizedDescription)", category: .network)
        }

        timerTask.cancel()
        isLoadingMultiFactor = false
    }

    // MARK: - Multi-Factor Section

    // MARK: - Multi-Factor Section (matches crypto latestValueSection)

    private var multiFactorSection: some View {
        VStack(spacing: ArkSpacing.md) {
            HStack(spacing: 6) {
                Text(multiFactorRisk != nil
                     ? "Multi-Factor \(symbol) Risk"
                     : "Regression \(symbol) Risk")
                    .font(.callout)
                    .foregroundColor(AppColors.textSecondary.opacity(0.85))

                if isLoadingMultiFactor {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                }
            }

            if let mfRisk = multiFactorRisk {
                VStack(spacing: ArkSpacing.xs) {
                    // Large colored value
                    Text(String(format: "%.3f", mfRisk.riskLevel))
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(RiskColors.color(for: mfRisk.riskLevel))

                    // Category with dot
                    HStack(spacing: ArkSpacing.xs) {
                        Circle()
                            .fill(RiskColors.color(for: mfRisk.riskLevel))
                            .frame(width: 12, height: 12)
                        Text(RiskColors.category(for: mfRisk.riskLevel))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(RiskColors.color(for: mfRisk.riskLevel))
                    }

                    // Date
                    let dateFmt = DateFormatter()
                    let _ = dateFmt.dateFormat = "MMMM d, yyyy"
                    Text("As of \(dateFmt.string(from: Date()))")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary.opacity(0.85))

                    // Regression vs composite comparison
                    if let regRisk = riskLevel {
                        stockRegressionComparison(
                            regressionValue: regRisk.riskLevel,
                            compositeValue: mfRisk.riskLevel,
                            factorCount: mfRisk.availableFactorCount
                        )
                    }
                }
            } else if let risk = riskLevel {
                // Fallback: show regression-only risk if multi-factor not loaded yet
                VStack(spacing: ArkSpacing.xs) {
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(RiskColors.color(for: risk.riskLevel))

                    HStack(spacing: ArkSpacing.xs) {
                        Circle()
                            .fill(RiskColors.color(for: risk.riskLevel))
                            .frame(width: 12, height: 12)
                        Text(RiskColors.category(for: risk.riskLevel))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(RiskColors.color(for: risk.riskLevel))
                    }

                    let dateFmt = DateFormatter()
                    let _ = dateFmt.dateFormat = "MMMM d, yyyy"
                    Text("As of \(dateFmt.string(from: Date()))")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary.opacity(0.85))
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(textPrimary.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.xl)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    private func stockRegressionComparison(regressionValue: Double, compositeValue: Double, factorCount: Int) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.top, ArkSpacing.sm)

            HStack(spacing: ArkSpacing.md) {
                VStack(spacing: 4) {
                    Text("Regression Only")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary.opacity(0.85))
                    Text(String(format: "%.3f", regressionValue))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(RiskColors.color(for: regressionValue))
                    Text(RiskColors.category(for: regressionValue))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(RiskColors.color(for: regressionValue))
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))

                VStack(spacing: 4) {
                    Text("\(factorCount)-Factor Composite")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary.opacity(0.85))
                    Text(String(format: "%.3f", compositeValue))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(RiskColors.color(for: compositeValue))
                    Text(RiskColors.category(for: compositeValue))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(RiskColors.color(for: compositeValue))
                }
                .frame(maxWidth: .infinity)
            }

            Text("The home page shows regression risk (1 factor). This view combines \(factorCount) indicators for a broader assessment.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.sm)
        }
    }

    // MARK: - Factor Breakdown Section (matches crypto)

    @ViewBuilder
    private var factorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Button(action: { withAnimation { showFactorBreakdown.toggle() } }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)

                    Text("Multi-Factor Analysis")
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Spacer()

                    if isLoadingMultiFactor {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if let risk = multiFactorRisk {
                        HStack(spacing: 4) {
                            Text("\(risk.availableFactorCount)/\(RiskFactorType.allCases.count)")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary.opacity(0.85))

                            Image(systemName: showFactorBreakdown ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textSecondary.opacity(0.85))
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showFactorBreakdown {
                if isLoadingMultiFactor {
                    HStack {
                        Spacer()
                        VStack(spacing: ArkSpacing.sm) {
                            ProgressView()
                            Text("Running multi-factor analysis...")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary.opacity(0.85))
                            Text("\(multiFactorElapsed)s elapsed")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                                .monospacedDigit()
                        }
                        Spacer()
                    }
                    .padding(.vertical, ArkSpacing.lg)
                } else if let risk = multiFactorRisk {
                    RiskFactorBreakdownView(multiFactorRisk: risk)
                } else {
                    VStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        Text("Unable to load factor data")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary.opacity(0.85))
                        Button("Retry") {
                            Task { await loadMultiFactor() }
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.lg)
                }
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Stock Header

    private var stockHeader: some View {
        HStack(spacing: 12) {
            // Stock logo
            if let logoURL = config?.logoURL {
                KFImage(logoURL)
                    .resizable()
                    .placeholder {
                        detailIconFallback
                    }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                detailIconFallback
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(config?.displayName ?? symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("Tap to change asset")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.textSecondary.opacity(colorScheme == .dark ? 0.08 : 0.05))
        )
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(RiskTimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: selectedTimeRange == range ? .semibold : .regular))
                        .foregroundColor(selectedTimeRange == range ? .white : AppColors.textSecondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedTimeRange == range ?
                            AnyView(Capsule().fill(AppColors.accent)) :
                            AnyView(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(AppColors.textSecondary.opacity(colorScheme == .dark ? 0.1 : 0.06))
        )
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && riskHistory.isEmpty {
                VStack(spacing: ArkSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Calculating \(config?.displayName ?? symbol) risk levels...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .glassCard(cornerRadius: ArkSpacing.Radius.lg)
            } else {
                // Header
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showChart.toggle() } }) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Risk Level")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Spacer()

                        if showChart && selectedDate != nil {
                            Button(action: { selectedDate = nil }) {
                                Text("Reset")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.accent)
                            }
                        }

                        HStack(spacing: 4) {
                            Text(showChart ? "Hide" : "Show")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: showChart ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                        )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, ArkSpacing.md)
                .padding(.top, ArkSpacing.md)
                .padding(.bottom, showChart ? ArkSpacing.sm : ArkSpacing.md)

                if showChart {
                    // Tooltip overlay
                    if let point = selectedPoint {
                        RiskTooltipView(
                            date: point.date,
                            riskLevel: point.riskLevel,
                            price: point.price,
                            fairValue: point.fairValue
                        )
                        .padding(.horizontal, ArkSpacing.md)
                        .padding(.bottom, ArkSpacing.sm)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeOut(duration: 0.15), value: selectedDate)
                    }

                    if filteredHistory.count >= 2 {
                        RiskLevelChart(
                            history: [],
                            timeRange: selectedTimeRange,
                            colorScheme: colorScheme,
                            enhancedHistory: filteredHistory,
                            selectedDate: $selectedDate
                        )
                        .id(selectedTimeRange)
                        .frame(height: 280)
                        .padding(.horizontal, 4)

                        // Touch hint
                        if selectedDate == nil {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw")
                                    .font(.system(size: 11))
                                Text("Touch chart to explore historical values")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                            .padding(.top, 4)
                            .padding(.bottom, ArkSpacing.sm)
                        } else {
                            Spacer().frame(height: ArkSpacing.md)
                        }
                    } else {
                        Text("Not enough data for this range")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }
                }
            }
        }
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Risk Legend

    private var riskLegendSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Risk Level Guide")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(spacing: ArkSpacing.sm) {
                RiskLevelLegendRow(
                    range: "0.00 - 0.20",
                    category: "Very Low Risk",
                    description: "Deep value range, historically excellent accumulation zone",
                    color: RiskColors.veryLowRisk
                )
                RiskLevelLegendRow(
                    range: "0.20 - 0.40",
                    category: "Low Risk",
                    description: "Still favorable accumulation, attractive for multi-year investors",
                    color: RiskColors.lowRisk
                )
                RiskLevelLegendRow(
                    range: "0.40 - 0.55",
                    category: "Neutral",
                    description: "Mid-cycle territory, neither strong buy nor sell",
                    color: RiskColors.neutral
                )
                RiskLevelLegendRow(
                    range: "0.55 - 0.70",
                    category: "Elevated Risk",
                    description: "Late-cycle behavior, higher probability of corrections",
                    color: RiskColors.elevatedRisk
                )
                RiskLevelLegendRow(
                    range: "0.70 - 0.90",
                    category: "High Risk",
                    description: "Historically blow-off-top region, major cycle tops occur here",
                    color: RiskColors.highRisk
                )
                RiskLevelLegendRow(
                    range: "0.90 - 1.00",
                    category: "Extreme Risk",
                    description: "Historically where macro tops happen, smart-money distribution",
                    color: RiskColors.extremeRisk
                )
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }
}
