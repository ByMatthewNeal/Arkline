import SwiftUI
import Kingfisher

// MARK: - QPS Full Grid View (Dedicated Screen)

struct QPSFullGridView: View {
    let signals: [DailyPositioningSignal]
    @Environment(\.colorScheme) var colorScheme
    @State private var searchText = ""

    private var filteredSignals: [DailyPositioningSignal] {
        guard !searchText.isEmpty else { return signals }
        let query = searchText.lowercased()
        return signals.filter {
            $0.asset.lowercased().contains(query) ||
            $0.displayName.lowercased().contains(query)
        }
    }

    private var groupedSignals: [(QPSAssetCategory, [DailyPositioningSignal])] {
        let grouped = Dictionary(grouping: filteredSignals) { $0.assetCategory }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                    TextField("Search assets...", text: $searchText)
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                )
                .padding(.horizontal, 20)

                // Momentum map entry
                NavigationLink {
                    MomentumMapView()
                } label: {
                    momentumMapBanner
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)

                if filteredSignals.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        Text("No assets matching \"\(searchText)\"")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    // Hint
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 11))
                        Text("Tap any asset to view its signal history")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .padding(.horizontal, 24)

                    ForEach(groupedSignals, id: \.0) { category, categorySignals in
                        categorySection(category, signals: categorySignals)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
        .navigationTitle("Daily Positioning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var momentumMapBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("Momentum Map")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text("Assets where the USD and BTC pair agree")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    private func categorySection(_ category: QPSAssetCategory, signals: [DailyPositioningSignal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text(category.displayName)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(0.5)
            }
            .padding(.leading, 24)

            // Signal rows
            LazyVStack(spacing: 0) {
                ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                    NavigationLink {
                        QPSDetailView(asset: signal.asset)
                    } label: {
                        signalRow(signal, showChevron: true)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < signals.count - 1 {
                        Divider().opacity(0.1).padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
            )
            .padding(.horizontal, 20)
        }
    }

    private func signalRow(_ signal: DailyPositioningSignal, showChevron: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(signal.displayName)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if signal.hasChanged {
                        Image(systemName: signal.positioningSignal == .bullish ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.warning)
                    }
                }

                // Trend strength + price (hide price for Alt/BTC pairs)
                HStack(spacing: 4) {
                    Text(trendStrengthLabel(signal.trendScore))
                        .font(.system(size: 10))
                        .foregroundColor(trendStrengthColor(signal.trendScore))

                    if signal.category != "alt_btc" {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary.opacity(0.3))

                        Text(formatSignalPrice(signal.price))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    }
                }
            }
            .frame(minWidth: 90, alignment: .leading)

            Spacer()

            Text(signal.positioningSignal.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(signal.positioningSignal.color)
                .cornerRadius(4)
                .frame(width: 70)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatSignalPrice(_ price: Double) -> String {
        if price >= 10_000 {
            return "$\(Int(price).formatted())"
        } else if price >= 100 {
            return String(format: "$%.0f", price)
        } else if price >= 1 {
            return String(format: "$%.2f", price)
        } else {
            return String(format: "$%.4f", price)
        }
    }

    private func trendStrengthLabel(_ score: Double) -> String {
        switch score {
        case 80...: return "Very Strong"
        case 70..<80: return "Strong"
        case 55..<70: return "Building"
        case 45..<55: return "Flat"
        case 30..<45: return "Weakening"
        default: return "Weak"
        }
    }

    private func trendStrengthColor(_ score: Double) -> Color {
        switch score {
        case 70...: return AppColors.success.opacity(0.7)
        case 55..<70: return AppColors.warning.opacity(0.7)
        case 45..<55: return AppColors.textSecondary.opacity(0.5)
        default: return AppColors.error.opacity(0.7)
        }
    }
}
