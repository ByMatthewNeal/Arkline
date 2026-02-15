import SwiftUI

struct MetalDetailView: View {
    let asset: MetalAsset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                MetalDetailHeader(asset: asset)

                // Price
                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.currentPrice.asCurrency)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: 8) {
                        if asset.priceChange24h != 0 {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.caption)

                            Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                                .font(.subheadline)
                        } else {
                            Text("Price per \(asset.unit)")
                                .font(.subheadline)
                        }
                    }
                    .foregroundColor(asset.priceChange24h != 0 ? (isPositive ? AppColors.success : AppColors.error) : AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Chart placeholder
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardBackground(colorScheme))
                        .frame(height: 160)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title2)
                                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
                                Text("Chart coming soon")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        )
                }
                .padding(.horizontal, 20)

                // Stats
                MetalStatsSection(asset: asset)
                    .padding(.horizontal, 20)

                // About
                MetalAboutSection(asset: asset)
                    .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .background(AppColors.background(colorScheme))
        .navigationBarBackButtonHidden()
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
}

// MARK: - Metal Detail Header
struct MetalDetailHeader: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)

                Text(metalElementSymbol(for: asset.symbol))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Unit Badge
            Text("per \(asset.unit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }

    private func metalElementSymbol(for symbol: String) -> String {
        switch symbol.uppercased() {
        case "XAU": return "Au"
        case "XAG": return "Ag"
        case "XPT": return "Pt"
        case "XPD": return "Pd"
        default: return String(symbol.prefix(2))
        }
    }
}

// MARK: - Metal Stats Section
struct MetalStatsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                StatRow(label: "Price per \(asset.unit)", value: asset.currentPrice.asCurrency)
                StatRow(label: "Currency", value: asset.currency)
                if asset.priceChange24h != 0 {
                    StatRow(label: "24h Change", value: String(format: "%+.2f%%", asset.priceChangePercentage24h))
                }
                if let timestamp = asset.timestamp {
                    StatRow(label: "Last Updated", value: timestamp.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }
}

// MARK: - Metal About Section
struct MetalAboutSection: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(asset.name)")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                Text(metalDescription)
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
            .padding(16)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    private var metalDescription: String {
        switch asset.symbol.uppercased() {
        case "XAU":
            return "Gold is a precious metal that has been used as a store of value for thousands of years. It is widely considered a safe-haven asset during times of economic uncertainty and inflation. Central banks hold gold as part of their reserves, and it remains a key component of diversified investment portfolios."
        case "XAG":
            return "Silver is both a precious metal and an industrial commodity. It has the highest electrical conductivity of any element, making it essential in electronics, solar panels, and medical applications. Silver often tracks gold prices but with higher volatility, offering leveraged exposure to precious metals."
        case "XPT":
            return "Platinum is a rare precious metal primarily used in catalytic converters for vehicles, jewelry, and industrial processes. It is approximately 30 times rarer than gold. Platinum prices are heavily influenced by automotive industry demand and mining supply from South Africa and Russia."
        case "XPD":
            return "Palladium is a rare precious metal used primarily in catalytic converters for gasoline-powered vehicles. It has seen significant price increases due to tightening emissions regulations worldwide. Russia and South Africa are the largest producers, making supply sensitive to geopolitical events."
        default:
            return "A precious metal commodity traded on global markets."
        }
    }
}
