import SwiftUI

// MARK: - Precious Metals Section
/// Self-loading section that fetches gold/silver prices via FMP commodity futures (GCUSD/SIUSD).
/// Falls back to metalAssets from MarketViewModel if available.
struct PreciousMetalsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var metals: [MetalAsset] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "cube.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Precious Metals")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading {
                // Shimmer placeholder while loading
                VStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                            .frame(height: 72)
                    }
                }
                .padding(.horizontal)
                .redacted(reason: .placeholder)
            } else if metals.isEmpty {
                // Error / empty state
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: loadFailed ? "exclamationmark.triangle" : "cube")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary)
                        Text(loadFailed ? "Failed to load metals" : "No data available")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        if loadFailed {
                            Button("Retry") {
                                Task { await loadFromFMP() }
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                // Metal Cards
                VStack(spacing: 12) {
                    ForEach(metals) { metal in
                        PreciousMetalCard(metal: metal)
                    }
                }
                .padding(.horizontal)
            }
        }
        .task {
            await loadFromFMP()
        }
    }

    /// Fetch gold/silver prices from FMP commodity futures (GCUSD/SIUSD)
    private func loadFromFMP() async {
        // Commodity futures symbols available on FMP free tier
        let futuresMap: [(futures: String, symbol: String, name: String)] = [
            ("GCUSD", "XAU", "Gold"),
            ("SIUSD", "XAG", "Silver"),
        ]

        var loaded: [MetalAsset] = []

        for mapping in futuresMap {
            do {
                let quote = try await FMPService.shared.fetchStockQuote(symbol: mapping.futures)
                loaded.append(MetalAsset(
                    id: mapping.symbol.lowercased(),
                    symbol: mapping.symbol,
                    name: mapping.name,
                    currentPrice: quote.price,
                    priceChange24h: quote.change,
                    priceChangePercentage24h: quote.changePercentage,
                    iconUrl: nil,
                    unit: "oz",
                    currency: "USD",
                    timestamp: Date()
                ))
            } catch {
                logWarning("PreciousMetals: Failed to fetch \(mapping.futures): \(error.localizedDescription)", category: .network)
            }
        }

        metals = loaded
        loadFailed = loaded.isEmpty
        isLoading = false
    }
}

// MARK: - Precious Metal Card
struct PreciousMetalCard: View {
    let metal: MetalAsset
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var isPositive: Bool { metal.priceChangePercentage24h >= 0 }

    private var priceSignal: (color: Color, label: String) {
        if metal.priceChangePercentage24h > 2.0 { return (AppColors.success, "Bullish") }
        if metal.priceChangePercentage24h < -2.0 { return (AppColors.error, "Bearish") }
        return (AppColors.warning, "Neutral")
    }

    private var subtitleText: String {
        let priceStr = metal.currentPrice.asCurrency
        if metal.priceChange24h != 0 {
            return "\(priceStr)  \(String(format: "%+.2f%%", metal.priceChangePercentage24h))"
        }
        return "\(priceStr) per \(metal.unit)"
    }

    private var metalIcon: String {
        switch metal.symbol.uppercased() {
        case "XAU": return "Au"
        case "XAG": return "Ag"
        case "XPT": return "Pt"
        case "XPD": return "Pd"
        default: return String(metal.symbol.prefix(2))
        }
    }

    private var iconColors: [Color] {
        switch metal.symbol.uppercased() {
        case "XAU": return [Color(hex: "F59E0B"), Color(hex: "D97706")]
        case "XAG": return [Color(hex: "94A3B8"), Color(hex: "64748B")]
        default: return [Color(hex: "A78BFA"), Color(hex: "7C3AED")]
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Metal Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Text(metalIcon)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }

                // Name & Price subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(metal.name)
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text(priceSignal.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(priceSignal.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(priceSignal.color.opacity(0.15))
                    .cornerRadius(8)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                MetalDetailView(asset: metal)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showingDetail = false }
                        }
                    }
            }
        }
    }
}
