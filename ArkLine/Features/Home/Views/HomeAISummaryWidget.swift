import SwiftUI

// MARK: - AI Daily Market Summary Widget
struct HomeAISummaryWidget: View {
    let summary: MarketSummary?
    let isLoading: Bool
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(AppColors.accent)

                    Text("Daily Briefing")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                if let summary {
                    Text(relativeTime(from: summary.generatedAt))
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            // Body
            if summary == nil && isLoading {
                shimmerPlaceholder
            } else if let summary {
                Text(summary.summary)
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Market briefing unavailable")
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.3))
            }
        }
        .padding(size == .compact ? 14 : 18)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Shimmer Placeholder

    private var shimmerPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            shimmerLine(maxWidth: .infinity)
            shimmerLine(maxWidth: .infinity)
            shimmerLine(maxWidth: 200)
        }
    }

    private func shimmerLine(maxWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.06)
                    : Color.black.opacity(0.06)
            )
            .frame(maxWidth: maxWidth, minHeight: 14, maxHeight: 14)
    }

    // MARK: - Relative Time

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

