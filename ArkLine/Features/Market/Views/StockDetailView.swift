import SwiftUI
import Charts
import Kingfisher

struct StockDetailView: View {
    let asset: StockAsset
    @State private var selectedTimeframe: StockChartTimeframe = .month
    @State private var chartData: [PricePoint] = []
    @State private var isLoadingChart = false
    @State private var chartAnimationId = UUID()
    @State private var profile: FMPCompanyProfile?
    @State private var isLoadingProfile = false
    @State private var riskLevel: RiskHistoryPoint?
    @State private var riskHistory: [RiskHistoryPoint] = []
    @State private var isLoadingRisk = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var chartIsPositive: Bool {
        guard let first = chartData.first?.price, let last = chartData.last?.price else {
            return isPositive
        }
        return last >= first
    }

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                DetailHeaderGradient(
                    primaryColor: Color(hex: "3B82F6"),
                    secondaryColor: Color(hex: "1D4ED8")
                )

                VStack(spacing: 24) {
                    // Header
                    StockDetailHeader(asset: asset, profile: profile)

                    // Price
                    VStack(alignment: .leading, spacing: 8) {
                        Text(asset.currentPrice.asCurrency)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .contentTransition(.numericText())

                        HStack(spacing: 8) {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.caption)

                            Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                                .font(.subheadline)
                                .contentTransition(.numericText())
                        }
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    // Chart
                    VStack(spacing: 16) {
                        AssetPriceChart(
                            data: chartData,
                            isPositive: chartIsPositive,
                            isLoading: isLoadingChart
                        )
                        .frame(height: 200)
                        .id(chartAnimationId)
                        .transition(.opacity)

                        // Timeframe Selector
                        StockTimeframeSelector(selected: $selectedTimeframe)
                    }
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.3), value: chartAnimationId)

                    // Risk Level
                    if AssetRiskConfig.forStock(asset.symbol) != nil {
                        StockRiskSection(
                            symbol: asset.symbol,
                            riskLevel: riskLevel,
                            riskHistory: riskHistory,
                            isLoading: isLoadingRisk
                        )
                        .padding(.horizontal, 20)
                    }

                    // Stats
                    StockStatsSection(asset: asset)
                        .padding(.horizontal, 20)

                    // About
                    if let profile = profile {
                        StockAboutSection(profile: profile)
                            .padding(.horizontal, 20)
                    } else if isLoadingProfile {
                        SkeletonCard()
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .background(AppColors.background(colorScheme))
        .refreshable { await loadData() }
        .navigationBarBackButtonHidden()
        .enableSwipeBack()
        .task { await loadData() }
        .onChange(of: selectedTimeframe) { _, _ in
            Task { await loadChart() }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }
        }
        #endif
    }

    private func loadData() async {
        async let chartTask: () = loadChart()
        async let profileTask: () = loadProfile()
        async let riskTask: () = loadRisk()
        _ = await (chartTask, profileTask, riskTask)
    }

    private func loadRisk() async {
        guard AssetRiskConfig.forStock(asset.symbol) != nil else { return }
        isLoadingRisk = true
        defer { isLoadingRisk = false }

        let riskService = ServiceContainer.shared.itcRiskService as? APIITCRiskService
        guard let service = riskService else { return }

        do {
            async let currentRisk = service.calculateStockCurrentRisk(symbol: asset.symbol)
            async let history = service.fetchStockRiskHistory(symbol: asset.symbol, days: 365)

            let (risk, hist) = try await (currentRisk, history)
            riskLevel = risk
            riskHistory = hist
        } catch {
            logWarning("Failed to load stock risk for \(asset.symbol): \(error.localizedDescription)", category: .network)
        }
    }

    private func loadChart() async {
        isLoadingChart = true
        defer { isLoadingChart = false }

        do {
            let prices = try await FMPService.shared.fetchHistoricalPrices(
                symbol: asset.symbol,
                limit: selectedTimeframe.tradingDays
            )
            let newData = prices.compactMap { price in
                guard let date = price.dateValue else { return nil as PricePoint? }
                return PricePoint(date: date, price: price.close)
            }.sorted { $0.date < $1.date }
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = newData
            }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                chartAnimationId = UUID()
                chartData = []
            }
        }
    }

    private func loadProfile() async {
        guard profile == nil else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }

        do {
            profile = try await FMPService.shared.fetchCompanyProfile(symbol: asset.symbol)
        } catch {
            // Profile is optional, fail silently
        }
    }
}

// MARK: - Stock Chart Timeframe
enum StockChartTimeframe: String, CaseIterable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "ALL"

    var tradingDays: Int {
        switch self {
        case .week: return 5
        case .month: return 22
        case .threeMonths: return 66
        case .year: return 252
        case .all: return 1260
        }
    }
}

// MARK: - Stock Timeframe Selector
struct StockTimeframeSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selected: StockChartTimeframe
    @Namespace private var timeframeAnimation

    var body: some View {
        HStack(spacing: 4) {
            ForEach(StockChartTimeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = timeframe
                    }
                }) {
                    Text(timeframe.rawValue)
                        .font(AppFonts.caption12Medium)
                        .fontWeight(selected == timeframe ? .semibold : .regular)
                        .foregroundColor(selected == timeframe ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if selected == timeframe {
                                Capsule()
                                    .fill(AppColors.accent)
                                    .matchedGeometryEffect(id: "stockTimeframe", in: timeframeAnimation)
                            }
                        }
                }
            }
        }
        .padding(4)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }
}

// MARK: - Stock Detail Header
struct StockDetailHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: StockAsset
    let profile: FMPCompanyProfile?

    var body: some View {
        HStack(spacing: 12) {
            // Icon - use company logo if available
            if let imageUrl = profile?.image, let url = URL(string: imageUrl) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        stockIconPlaceholder
                    }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                stockIconPlaceholder
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Exchange Badge
            if let exchange = asset.exchange {
                Text(exchange)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
    }

    private var stockIconPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)

            Text(asset.symbol.prefix(1))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Stock Stats Section
struct StockStatsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: StockAsset

    private var hasAnyStats: Bool {
        (asset.marketCap ?? 0) > 0 || (asset.peRatio ?? 0) > 0 ||
        (asset.volume ?? 0) > 0 || (asset.high ?? 0) > 0 ||
        (asset.low ?? 0) > 0 || (asset.week52High ?? 0) > 0 ||
        (asset.week52Low ?? 0) > 0 || (asset.previousClose ?? 0) > 0 ||
        (asset.dividendYield ?? 0) > 0
    }

    var body: some View {
        if hasAnyStats {
            VStack(alignment: .leading, spacing: 16) {
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                VStack(spacing: 12) {
                    if let marketCap = asset.marketCap, marketCap > 0 {
                        StatRow(label: "Market Cap", value: marketCap.asCurrencyCompact)
                    }
                    if let pe = asset.peRatio, pe > 0 {
                        StatRow(label: "P/E Ratio", value: String(format: "%.2f", pe))
                    }
                    if let volume = asset.volume, volume > 0 {
                        StatRow(label: "Volume", value: Double(volume).formattedCompact)
                    }
                    if let high = asset.high, high > 0 {
                        StatRow(label: "Day High", value: high.asCurrency)
                    }
                    if let low = asset.low, low > 0 {
                        StatRow(label: "Day Low", value: low.asCurrency)
                    }
                    if let high52 = asset.week52High, high52 > 0 {
                        StatRow(label: "52-Week High", value: high52.asCurrency)
                    }
                    if let low52 = asset.week52Low, low52 > 0 {
                        StatRow(label: "52-Week Low", value: low52.asCurrency)
                    }
                    if let prevClose = asset.previousClose, prevClose > 0 {
                        StatRow(label: "Previous Close", value: prevClose.asCurrency)
                    }
                    if let divYield = asset.dividendYield, divYield > 0 {
                        StatRow(label: "Dividend Yield", value: String(format: "%.2f%%", divYield))
                    }
                }
                .padding(16)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Stock About Section
struct StockAboutSection: View {
    @Environment(\.colorScheme) var colorScheme
    let profile: FMPCompanyProfile
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(profile.companyName)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                if let description = profile.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(isExpanded ? nil : 3)

                    Button(action: { isExpanded.toggle() }) {
                        Text(isExpanded ? "Show Less" : "Read More")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.accent)
                    }
                }

                // Company details
                VStack(spacing: 8) {
                    if let sector = profile.sector, !sector.isEmpty {
                        companyDetailRow(label: "Sector", value: sector)
                    }
                    if let industry = profile.industry, !industry.isEmpty {
                        companyDetailRow(label: "Industry", value: industry)
                    }
                    if let ceo = profile.ceo, !ceo.isEmpty {
                        companyDetailRow(label: "CEO", value: ceo)
                    }
                    if let employees = profile.fullTimeEmployees, !employees.isEmpty {
                        companyDetailRow(label: "Employees", value: employees)
                    }
                    if let country = profile.country, !country.isEmpty {
                        companyDetailRow(label: "Country", value: country)
                    }
                    if let ipo = profile.ipoDate, !ipo.isEmpty {
                        companyDetailRow(label: "IPO Date", value: ipo)
                    }
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private func companyDetailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - Stock Risk Section

struct StockRiskSection: View {
    @Environment(\.colorScheme) var colorScheme
    let symbol: String
    let riskLevel: RiskHistoryPoint?
    let riskHistory: [RiskHistoryPoint]
    let isLoading: Bool

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private func riskColor(_ level: Double) -> Color {
        if level < 0.20 { return Color(hex: "3B82F6") }     // Deep value — blue
        if level < 0.40 { return AppColors.success }         // Low risk — green
        if level < 0.55 { return AppColors.warning }         // Neutral — yellow
        if level < 0.70 { return Color(hex: "F97316") }      // Elevated — orange
        if level < 0.90 { return AppColors.error }           // High risk — red
        return Color(hex: "DC2626")                          // Extreme — dark red
    }

    private func riskLabel(_ level: Double) -> String {
        if level < 0.20 { return "Deep Value" }
        if level < 0.40 { return "Low Risk" }
        if level < 0.55 { return "Neutral" }
        if level < 0.70 { return "Elevated Risk" }
        if level < 0.90 { return "High Risk" }
        return "Extreme Risk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                Text("Risk Level")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()

                if let config = AssetRiskConfig.forStock(symbol) {
                    HStack(spacing: 3) {
                        ForEach(0..<9, id: \.self) { i in
                            Circle()
                                .fill(i < config.confidenceLevel ? AppColors.accent : AppColors.textSecondary.opacity(0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 20)
                    Spacer()
                }
            } else if let risk = riskLevel {
                // Risk gauge
                HStack(spacing: 16) {
                    // Circular gauge
                    ZStack {
                        Circle()
                            .stroke(riskColor(risk.riskLevel).opacity(0.15), lineWidth: 6)

                        Circle()
                            .trim(from: 0, to: min(max(risk.riskLevel, 0), 1))
                            .stroke(riskColor(risk.riskLevel), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text(String(format: "%.2f", risk.riskLevel))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(riskColor(risk.riskLevel))
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(riskLabel(risk.riskLevel))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(riskColor(risk.riskLevel))

                        if risk.fairValue > 0 {
                            Text("Fair Value: \(risk.fairValue.asCurrency)")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        let devPct = risk.deviation * 100
                        Text(String(format: "%+.1f%% from fair value", devPct))
                            .font(.system(size: 11))
                            .foregroundColor(devPct >= 0 ? AppColors.error : AppColors.success)
                    }

                    Spacer()
                }

                // Mini risk chart (last 90 days)
                if riskHistory.count >= 5 {
                    let displayHistory = Array(riskHistory.suffix(90))
                    miniRiskChart(displayHistory)
                }
            } else {
                Text("Risk data unavailable")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
    }

    private func miniRiskChart(_ data: [RiskHistoryPoint]) -> some View {
        let maxVal = data.map(\.riskLevel).max() ?? 1
        let minVal = data.map(\.riskLevel).min() ?? 0
        let range = max(maxVal - minVal, 0.01)
        let latest = data.last?.riskLevel ?? 0.5

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let stepX = w / CGFloat(max(data.count - 1, 1))

                ZStack(alignment: .topLeading) {
                    // Threshold zones
                    let zones: [(threshold: Double, color: Color)] = [
                        (0.7, AppColors.error.opacity(0.06)),
                        (0.55, Color(hex: "F97316").opacity(0.04)),
                    ]

                    ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                        let y = h * CGFloat((maxVal - zone.threshold) / range)
                        if y > 0 && y < h {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: w, y: y))
                            }
                            .stroke(zone.color.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        }
                    }

                    // Line
                    Path { path in
                        for (i, point) in data.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - point.riskLevel) / range)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        riskColor(latest),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )

                    // Gradient fill
                    Path { path in
                        for (i, point) in data.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * CGFloat((maxVal - point.riskLevel) / range)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [riskColor(latest).opacity(0.15), riskColor(latest).opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 60)

            // Date labels
            if let first = data.first, let last = data.last {
                let fmt = DateFormatter()
                let _ = fmt.dateFormat = "MMM d"
                HStack {
                    Text(fmt.string(from: first.date))
                        .font(.system(size: 8))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Spacer()
                    Text(fmt.string(from: last.date))
                        .font(.system(size: 8))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                }
            }
        }
    }
}
