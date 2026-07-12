import SwiftUI

// MARK: - Market Breadth Section (Market Tab Widget)
struct MarketBreadthSection: View {
    var refreshId: UUID = UUID()
    var embedded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var latest: MarketBreadthPoint?
    @State private var history: [MarketBreadthPoint] = []
    @State private var isLoading = true
    @State private var showInfo = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Market Breadth")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let point = latest {
                    trendBadge(point.trend)
                }
            }

            if isLoading {
                VStack(spacing: 14) {
                    HStack {
                        RoundedRectangle(cornerRadius: 6).fill(cardBackground.opacity(0.6)).frame(width: 80, height: 32)
                        Spacer()
                        RoundedRectangle(cornerRadius: 6).fill(cardBackground.opacity(0.6)).frame(width: 80, height: 32)
                        Spacer()
                        RoundedRectangle(cornerRadius: 6).fill(cardBackground.opacity(0.6)).frame(width: 80, height: 32)
                    }
                    HStack {
                        RoundedRectangle(cornerRadius: 4).fill(cardBackground.opacity(0.4)).frame(width: 100, height: 14)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4).fill(cardBackground.opacity(0.4)).frame(width: 100, height: 14)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4).fill(cardBackground.opacity(0.4)).frame(width: 60, height: 14)
                    }
                    RoundedRectangle(cornerRadius: 4).fill(cardBackground.opacity(0.3)).frame(height: 40)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
                .redacted(reason: .placeholder)
                .shimmer(isLoading: true)
            } else if let point = latest {
                NavigationLink {
                    MarketBreadthDetailView()
                } label: {
                    VStack(spacing: 14) {
                        // Main stats row
                        HStack(spacing: 0) {
                            statBlock(
                                label: "Breadth",
                                value: point.breadthFormatted,
                                color: breadthColor(point.breadthPct)
                            )

                            Spacer()

                            statBlock(
                                label: "Trending",
                                value: "\(point.trendingTokens)/\(point.totalTokens)",
                                color: textPrimary
                            )

                            Spacer()

                            statBlock(
                                label: "BTC",
                                value: point.btcPriceFormatted,
                                color: textPrimary
                            )
                        }

                        // EMA row
                        HStack(spacing: 0) {
                            emaLabel("EMA 12", value: point.ema12Formatted, isBullish: point.isBullish)
                            Spacer()
                            emaLabel("EMA 21", value: point.ema21Formatted, isBullish: point.isBullish)
                            Spacer()
                            if point.isCrossover {
                                crossoverBadge(point)
                            } else {
                                Text(point.shortDateDisplay)
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }

                        // Mini sparkline
                        if history.count >= 7 {
                            breadthSparkline
                                .frame(height: 40)
                        }

                        // Tap affordance
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Text("Details")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Button {
                    isLoading = true
                    Task { await loadData() }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        Text("Tap to load")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(cardBackground)
                    )
                }
            }
        }
        .padding(.horizontal, embedded ? 0 : 16)
        .task(id: refreshId) {
            await loadData()
        }
        .sheet(isPresented: $showInfo) {
            MarketBreadthInfoSheet()
        }
    }

    // MARK: - Data Loading

    // Remount cache: the zone filter on Market Overview destroys and re-creates
    // this view when switching chips; a static cache avoids re-querying Supabase
    // on every remount. Breadth data updates daily, so a 5-minute TTL is generous.
    private static var cache: (latest: MarketBreadthPoint?, history: [MarketBreadthPoint], fetchedAt: Date)?
    private static let cacheTTL: TimeInterval = 300

    private func loadData() async {
        // Serve fresh-enough cached data instantly (survives view remounts)
        if let cached = Self.cache,
           Date().timeIntervalSince(cached.fetchedAt) < Self.cacheTTL {
            latest = cached.latest
            history = cached.history
            isLoading = false
            return
        }

        let service = ServiceContainer.shared.marketBreadthService
        do {
            async let latestFetch = service.fetchLatest()
            async let historyFetch = service.fetchHistory(days: 30)
            let (l, h) = try await (latestFetch, historyFetch)
            latest = l
            history = h
            Self.cache = (latest: l, history: h, fetchedAt: Date())
        } catch {
            logWarning("MarketBreadthSection: \(error.localizedDescription)", category: .network)
        }
        isLoading = false
    }

    // MARK: - Subviews

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func emaLabel(_ label: String, value: String, isBullish: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(isBullish ? AppColors.success : AppColors.error)
        }
    }

    private func trendBadge(_ trend: String) -> some View {
        let (label, color): (String, Color) = {
            switch trend {
            case "bullish": return ("Bullish", AppColors.success)
            case "bearish": return ("Bearish", AppColors.error)
            default: return ("Neutral", AppColors.warning)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
    }

    private func crossoverBadge(_ point: MarketBreadthPoint) -> some View {
        let isBull = point.isBullishCrossover
        return HStack(spacing: 3) {
            Image(systemName: isBull ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 8))
            Text(isBull ? "Bull Cross" : "Bear Cross")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(isBull ? AppColors.success : AppColors.error)
    }

    private var breadthSparkline: some View {
        GeometryReader { geo in
            let values = history.map { $0.breadthPct }
            let minVal = max(0, (values.min() ?? 0) - 5)
            let maxVal = min(100, (values.max() ?? 100) + 5)
            let range = maxVal - minVal

            ZStack {
                // Gradient fill under the line
                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = range > 0
                            ? geo.size.height * (1 - (val - minVal) / range)
                            : geo.size.height / 2
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    // Close the fill
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.15), AppColors.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Breadth line
                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = range > 0
                            ? geo.size.height * (1 - (val - minVal) / range)
                            : geo.size.height / 2
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(AppColors.accent, lineWidth: 1.5)
            }
        }
    }

    private func breadthColor(_ pct: Double) -> Color {
        if pct >= 70 { return AppColors.success }
        if pct <= 30 { return AppColors.error }
        return AppColors.warning
    }
}

// MARK: - Info Sheet
private struct MarketBreadthInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoRow("Market Breadth measures the percentage of cryptocurrency tokens currently in an uptrend (price above 7-day moving average).")

                    infoRow("High values (70-100%) indicate broad market strength with most tokens trending upward.")

                    infoRow("Low values (0-30%) suggest market weakness with most tokens trending downward.")

                    infoRow("Middle values (30-70%) show mixed market conditions with no clear directional bias.")

                    Divider()

                    Text("EMA Trend Analysis")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    infoRow("EMA 12 > EMA 21 (Bullish): Market breadth is improving — more tokens entering uptrends.")

                    infoRow("EMA 12 < EMA 21 (Bearish): Market breadth is declining — tokens losing momentum.")

                    infoRow("Crossovers mark potential turning points. A bullish crossover suggests improving conditions; bearish crossover suggests deteriorating conditions.")

                    infoRow("BTC price is shown for context — divergences between breadth and BTC price can signal narrowing or broadening rallies.")
                }
                .padding()
            }
            .navigationTitle("Market Breadth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
