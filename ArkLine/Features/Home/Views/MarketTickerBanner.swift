import SwiftUI

// MARK: - Market Ticker Banner
/// A thin, auto-scrolling ticker strip under the Home header — desktop-finance style.
/// Alternates market stats (BTC/ETH/SOL, Risk Score, Fear & Greed, regime) with top
/// news headlines. Tapping it deep-links to the Market tab. Fixed position, toggleable
/// via Customize Home (`.marketTicker`), no size variants.
struct MarketTickerBanner: View {
    var viewModel: HomeViewModel
    let onTap: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var contentWidth: CGFloat = 0

    private let itemSpacing: CGFloat = 24
    private let scrollSpeed: CGFloat = 30 // points per second

    // MARK: - Ticker items

    private enum TickerItem: Identifiable {
        case stat(label: String, value: String, change: Double?)
        case headline(source: String, title: String)

        var id: String {
            switch self {
            case .stat(let label, let value, _): return "stat-\(label)-\(value)"
            case .headline(let source, let title): return "news-\(source)-\(title)"
            }
        }
    }

    private var items: [TickerItem] {
        var stats: [TickerItem] = []

        for symbol in ["BTC", "ETH", "SOL"] {
            if let asset = viewModel.cachedCryptoAssets.first(where: { $0.symbol.uppercased() == symbol }) {
                stats.append(.stat(
                    label: symbol,
                    value: asset.currentPrice.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                    change: asset.priceChangePercentage24h
                ))
            }
        }

        if let score = viewModel.compositeRiskScore {
            stats.append(.stat(label: "RISK", value: "\(score)", change: nil))
        }

        if let fg = viewModel.fearGreedIndex {
            stats.append(.stat(label: "F&G", value: "\(fg.value) \(fg.classification)", change: nil))
        }

        if let regime = viewModel.currentRegimeResult {
            stats.append(.stat(label: "REGIME", value: regime.quadrant.rawValue, change: nil))
        }

        let headlines: [TickerItem] = viewModel.newsItems.prefix(3).map {
            .headline(source: $0.source, title: $0.title)
        }

        // Alternate: a few stats, then a headline, and so on
        guard !headlines.isEmpty else { return stats }
        var result: [TickerItem] = []
        let chunkSize = max(1, Int((Double(stats.count) / Double(headlines.count)).rounded(.up)))
        var headlineIterator = headlines.makeIterator()
        for (index, stat) in stats.enumerated() {
            result.append(stat)
            if (index + 1) % chunkSize == 0, let next = headlineIterator.next() {
                result.append(next)
            }
        }
        while let remaining = headlineIterator.next() {
            result.append(remaining)
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            Group {
                if reduceMotion {
                    // Accessibility: manual scroll instead of a moving marquee
                    ScrollView(.horizontal, showsIndicators: false) {
                        tickerContent
                            .padding(.horizontal, 20)
                    }
                } else {
                    marquee
                }
            }
            .frame(height: 34)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
            )
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Market ticker. Tap to open Market tab.")
        }
    }

    /// Seamless marquee: two copies of the content slide left; when one copy's width
    /// has passed, the modulo wraps invisibly back to the start.
    private var marquee: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let period = contentWidth + itemSpacing
            let shift = period > 0 ? CGFloat(t * Double(scrollSpeed)).truncatingRemainder(dividingBy: period) : 0

            HStack(spacing: itemSpacing) {
                tickerContent
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onAppear { contentWidth = proxy.size.width }
                        }
                    )
                tickerContent
            }
            .offset(x: -shift)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tickerContent: some View {
        HStack(spacing: itemSpacing) {
            ForEach(items) { item in
                HStack(spacing: itemSpacing) {
                    itemView(item)

                    Text("◆")
                        .font(.system(size: 6))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func itemView(_ item: TickerItem) -> some View {
        switch item {
        case .stat(let label, let value, let change):
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let change {
                    Text(String(format: "%+.1f%%", change))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
            }

        case .headline(let source, let title):
            HStack(spacing: 6) {
                Text(source.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.accent)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.85))
                    .lineLimit(1)
            }
        }
    }
}
