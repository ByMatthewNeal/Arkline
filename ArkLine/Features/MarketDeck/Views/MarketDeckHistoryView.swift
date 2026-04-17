import SwiftUI

struct MarketDeckHistoryView: View {
    let isAdmin: Bool
    var userId: UUID? = nil
    @State private var decks: [MarketUpdateDeck] = []
    @State private var isLoading = false
    @State private var selectedDeck: MarketUpdateDeck?
    @Environment(\.colorScheme) var colorScheme

    private let service: MarketUpdateDeckServiceProtocol = ServiceContainer.shared.marketDeckService

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isLoading && decks.isEmpty {
                ProgressView("Loading history...")
                    .tint(AppColors.accent)
            } else if decks.isEmpty {
                VStack(spacing: ArkSpacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textSecondary)
                    Text("No past updates yet")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: ArkSpacing.sm) {
                        ForEach(decks) { deck in
                            deckRow(deck)
                        }
                    }
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.vertical, ArkSpacing.sm)
                }
            }
        }
        .refreshable { await loadHistory() }
        .navigationTitle("Past Updates")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task { await loadHistory() }
        .fullScreenCover(item: $selectedDeck) { deck in
            MarketDeckViewer(
                viewModel: MarketDeckViewModel(deck: deck),
                isAdmin: isAdmin,
                userId: userId
            )
        }
    }

    private func deckRow(_ deck: MarketUpdateDeck) -> some View {
        Button(action: { selectedDeck = deck }) {
            HStack(spacing: ArkSpacing.md) {
                // Week indicator
                VStack(spacing: 2) {
                    if let coverData = coverData(for: deck) {
                        Circle()
                            .fill(regimeColor(coverData.regime))
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.weekLabel)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: ArkSpacing.sm) {
                        Text("\(deck.slides.count) slides")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)

                        if let coverData = coverData(for: deck) {
                            if let btcChange = coverData.btcWeeklyChange {
                                HStack(spacing: 2) {
                                    Text("BTC")
                                        .font(AppFonts.caption12)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(String(format: "%+.1f%%", btcChange))
                                        .font(AppFonts.caption12Medium)
                                        .foregroundColor(btcChange >= 0 ? AppColors.success : AppColors.error)
                                }
                            }

                            Text(coverData.regime)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(regimeColor(coverData.regime))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(regimeColor(coverData.regime).opacity(0.15)))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground(colorScheme))
            )
        }
        .buttonStyle(.plain)
    }

    private func coverData(for deck: MarketUpdateDeck) -> CoverSlideData? {
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

    private func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            decks = try await service.fetchHistory(limit: 52)
        } catch {
            logWarning("Failed to load deck history: \(error)", category: .data)
        }
    }
}
