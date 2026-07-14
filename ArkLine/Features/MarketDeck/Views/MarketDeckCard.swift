import SwiftUI

struct MarketDeckCard: View {
    let deck: MarketUpdateDeck
    @State private var showViewer = false
    @State private var showHistory = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Main tap area — opens the deck viewer
            Button(action: { showViewer = true }) {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    HStack {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.accent)

                        Text("Weekly Market Update")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        regimeBadge
                    }

                    Text(deck.weekLabel)
                        .font(AppFonts.number20)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // BTC weekly change from cover slide
                    if let coverData = coverSlideData {
                        HStack(spacing: ArkSpacing.xs) {
                            if let btcChange = coverData.btcWeeklyChange {
                                HStack(spacing: 4) {
                                    Text("BTC")
                                        .font(AppFonts.caption12Medium)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(String(format: "%+.1f%%", btcChange))
                                        .font(AppFonts.caption12Medium)
                                        .foregroundColor(btcChange >= 0 ? AppColors.success : AppColors.error)
                                }
                            }

                            if let fgEnd = coverData.fearGreedEnd {
                                HStack(spacing: 4) {
                                    Text("F&G")
                                        .font(AppFonts.caption12Medium)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("\(fgEnd)")
                                        .font(AppFonts.caption12Medium)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Swipe to explore")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            // Next update expectation (weekly, Sundays)
            if let nextText = nextUpdateText {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(nextText)
                        .font(AppFonts.caption12)
                }
                .foregroundColor(AppColors.textSecondary)
            }

            // Past updates link
            Button(action: { showHistory = true }) {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                    Text("Past Updates")
                        .font(AppFonts.caption12Medium)
                }
                .foregroundColor(AppColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(ArkSpacing.Component.cardPadding)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.card)
        .fullScreenCover(isPresented: $showViewer) {
            MarketDeckViewer(
                viewModel: MarketDeckViewModel(deck: deck),
                isAdmin: false
            )
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                MarketDeckHistoryView(isAdmin: false)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { showHistory = false }
                                .foregroundColor(AppColors.accent)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var regimeBadge: some View {
        if let regime = coverSlideData?.regime {
            Text(regime)
                .font(AppFonts.footnote10)
                .foregroundColor(.white)
                .padding(.horizontal, ArkSpacing.xs)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(regimeColor(regime))
                )
        }
    }

    /// The next expected weekly update — the Sunday after the shown deck was
    /// published, rolled forward so it's never a past date (updates publish
    /// weekly on Sundays; a draft auto-generates Saturday).
    private var nextUpdateDate: Date? {
        let cal = Calendar(identifier: .gregorian)
        let reference = deck.publishedAt ?? deck.weekEnd
        // Sunday == weekday 1 in the Gregorian calendar.
        guard var next = cal.nextDate(
            after: reference,
            matching: DateComponents(weekday: 1),
            matchingPolicy: .nextTime
        ) else { return nil }
        let now = Date()
        while next < now {
            guard let bumped = cal.date(byAdding: .day, value: 7, to: next) else { break }
            next = bumped
        }
        return next
    }

    private var nextUpdateText: String? {
        guard let date = nextUpdateDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, MMM d" // e.g. "Sunday, Jul 19"
        return "Next update: \(formatter.string(from: date))"
    }

    private var coverSlideData: CoverSlideData? {
        deck.slides.first.flatMap { slide in
            if case .cover(let data) = slide.data { return data }
            return nil
        }
    }

    private func regimeColor(_ regime: String) -> Color {
        switch regime.lowercased() {
        case "risk-on": return AppColors.success
        case "risk-off": return AppColors.error
        default: return AppColors.warning
        }
    }
}
