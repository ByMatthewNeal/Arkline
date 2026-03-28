import SwiftUI

struct DeckSlideView: View {
    let slide: DeckSlide
    let deck: MarketUpdateDeck

    private var adminNote: String? {
        let note = deck.adminContext?.slideNotes[slide.type.rawValue]
        return (note?.isEmpty ?? true) ? nil : note
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                switch slide.data {
                case .cover(let data):
                    CoverSlideView(data: data, deck: deck)
                case .marketPulse(let data):
                    MarketPulseSlideView(data: data, title: slide.title)
                case .macro(let data):
                    MacroSlideView(data: data, title: slide.title)
                case .positioning(let data):
                    PositioningSlideView(data: data, title: slide.title)
                case .economic(let data):
                    EconomicSlideView(data: data, title: slide.title)
                case .setups(let data):
                    SetupsSlideView(data: data, title: slide.title)
                case .rundown(let data):
                    RundownSlideView(data: data, title: slide.title)
                case .sectionTitle(let data):
                    SectionTitleSlideView(data: data, title: slide.title)
                case .editorial(let data):
                    EditorialSlideView(data: data, title: slide.title)
                case .snapshot(let data):
                    SnapshotSlideView(data: data, title: slide.title)
                case .weeklyOutlook(let data):
                    WeeklyOutlookSlideView(data: data, title: slide.title)
                case .correlation(let data):
                    CorrelationSlideView(data: data, title: slide.title)
                }

                if let note = adminNote {
                    AdminNoteFooter(note: note)
                        .padding(.top, ArkSpacing.lg)
                }
            }
            .padding(.horizontal, ArkSpacing.xl)
            .padding(.top, 56)
            .padding(.bottom, 72)
        }
    }
}

// MARK: - Admin Note Footer

struct AdminNoteFooter: View {
    let note: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: ArkSpacing.xs) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.3))
                .frame(width: 2)

            Text(note)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.03))
        .cornerRadius(ArkSpacing.Radius.sm)
    }
}
