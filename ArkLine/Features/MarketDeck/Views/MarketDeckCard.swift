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
