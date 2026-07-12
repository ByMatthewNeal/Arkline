import SwiftUI

// MARK: - Market Zone Chip Row
/// Sticky chip filter pinned above the Market widget stack.
/// "All" shows every enabled section; zone chips filter the stack to that group.
struct MarketZoneChipRow: View {
    @Binding var selectedZone: MarketZone
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MarketZone.allCases) { zone in
                    ZoneChip(
                        zone: zone,
                        isSelected: selectedZone == zone,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedZone = zone
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - Zone Chip
private struct ZoneChip: View {
    let zone: MarketZone
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var unselectedBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var unselectedText: Color {
        AppColors.textPrimary(colorScheme).opacity(0.7)
    }

    var body: some View {
        Button(action: onTap) {
            Text(zone.displayName)
                .font(AppFonts.caption12Medium)
                .foregroundColor(isSelected ? .white : unselectedText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.accent : unselectedBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(zone.displayName) sections\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State var zone: MarketZone = .all
        var body: some View {
            MarketZoneChipRow(selectedZone: $zone)
        }
    }
    return PreviewWrapper()
}
