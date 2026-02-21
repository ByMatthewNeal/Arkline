import SwiftUI

// MARK: - Portfolio Hero Card
struct PortfolioHeroCard: View {
    let totalValue: Double
    let change: Double
    let changePercent: Double
    let portfolioName: String
    let chartData: [CGFloat]
    let onPortfolioTap: () -> Void
    let onSetupTap: () -> Void
    @Binding var selectedTimePeriod: TimePeriod
    @Environment(\.colorScheme) var colorScheme

    // Track time period changes to re-trigger animation
    @State private var chartAnimationId = UUID()

    var isPositive: Bool { change >= 0 }
    private var isEmpty: Bool { totalValue == 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            if isEmpty {
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
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .onChange(of: selectedTimePeriod) { _, _ in
            chartAnimationId = UUID()
        }
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
            // Portfolio Selector
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

            TimePeriodSelector(selectedPeriod: $selectedTimePeriod)

            VStack(spacing: 8) {
                Text("FUNDS")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .tracking(1)

                Text(totalValue.asCurrency)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(textPrimary)
                    .contentTransition(.numericText())

                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(isPositive ? "+" : "")\(change.asCurrency)")
                        .font(.system(size: 16, weight: .semibold))
                        .contentTransition(.numericText())

                    Text("(\(isPositive ? "+" : "")\(changePercent, specifier: "%.2f")%)")
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
            .accessibilityLabel("\(portfolioName) portfolio, \(totalValue.asCurrency), \(isPositive ? "up" : "down") \(String(format: "%.2f", abs(changePercent))) percent")

            PortfolioSparkline(
                dataPoints: chartData,
                isPositive: isPositive,
                showGlow: true,
                showEndDot: true,
                animated: true
            )
            .id(chartAnimationId)
            .frame(height: 80)
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
    let riskLevels: [(coin: String, riskLevel: ITCRiskLevel?, daysAtLevel: Int?)]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Regression Risk")
                        .font(size == .compact ? .subheadline : .title3)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Single-factor")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }

                Spacer()

                Text("\(riskLevels.count) selected")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.xs)

            // Risk cards grid/scroll
            if riskLevels.count == 1, let first = riskLevels.first {
                // Single coin - full width
                RiskLevelWidget(
                    riskLevel: first.riskLevel,
                    coinSymbol: first.coin,
                    daysAtLevel: first.daysAtLevel,
                    size: size
                )
            } else if riskLevels.count == 2 {
                // Two coins - side by side
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(riskLevels, id: \.coin) { item in
                        CompactRiskCard(
                            riskLevel: item.riskLevel,
                            coinSymbol: item.coin,
                            daysAtLevel: item.daysAtLevel
                        )
                    }
                }
            } else {
                // Three or more - horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ArkSpacing.sm) {
                        ForEach(riskLevels, id: \.coin) { item in
                            CompactRiskCard(
                                riskLevel: item.riskLevel,
                                coinSymbol: item.coin,
                                daysAtLevel: item.daysAtLevel
                            )
                            .frame(width: 160)
                        }
                    }
                    .padding(.horizontal, ArkSpacing.xs)
                }
            }
        }
    }
}

// MARK: - Compact Risk Card (for Multi-Coin Display)
struct CompactRiskCard: View {
    let riskLevel: ITCRiskLevel?
    let coinSymbol: String
    var daysAtLevel: Int? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                // Header
                HStack {
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
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
                } else {
                    // Loading state
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary.opacity(0.3))

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
    }
}
