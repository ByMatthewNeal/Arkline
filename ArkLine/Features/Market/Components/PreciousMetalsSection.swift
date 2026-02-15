import SwiftUI

// MARK: - Precious Metals Section
/// Self-loading section that fetches gold/silver prices via FMP (GLD/SLV ETFs).
/// Falls back to metalAssets from MarketViewModel if available.
struct PreciousMetalsSection: View {
    var metalAssets: [MetalAsset] = []
    @Environment(\.colorScheme) var colorScheme
    @State private var metals: [MetalAsset] = []
    @State private var hasLoaded = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    /// Use passed-in metals if available, otherwise use self-loaded FMP data
    private var displayMetals: [MetalAsset] {
        let source = metalAssets.filter { ["XAU", "XAG"].contains($0.symbol.uppercased()) }
        return source.isEmpty ? metals : source
    }

    var body: some View {
        if !displayMetals.isEmpty {
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

                // Metal Cards
                VStack(spacing: 12) {
                    ForEach(displayMetals) { metal in
                        PreciousMetalCard(metal: metal)
                    }
                }
                .padding(.horizontal)
            }
        } else if !hasLoaded {
            // Show nothing while loading (avoids flash)
            Color.clear
                .frame(height: 0)
                .task { await loadFromFMP() }
        }
    }

    /// Fetch gold/silver prices from FMP using ETF proxies
    private func loadFromFMP() async {
        defer { hasLoaded = true }

        do {
            let quotes = try await withThrowingTaskGroup(of: (String, FMPQuote).self) { group in
                let etfMap = [("GLD", "XAU", "Gold"), ("SLV", "XAG", "Silver")]

                for (etf, _, _) in etfMap {
                    group.addTask {
                        let quote = try await FMPService.shared.fetchStockQuote(symbol: etf)
                        return (etf, quote)
                    }
                }

                var results: [(String, FMPQuote)] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }

            // Convert ETF prices to approximate spot prices
            // GLD ≈ 1/10th gold spot, SLV ≈ silver spot
            let etfToMetal: [(etf: String, symbol: String, name: String, multiplier: Double)] = [
                ("GLD", "XAU", "Gold", 10.73),   // GLD share ≈ 0.0932 oz gold
                ("SLV", "XAG", "Silver", 1.075),  // SLV share ≈ 0.93 oz silver
            ]

            var loaded: [MetalAsset] = []
            for mapping in etfToMetal {
                if let (_, quote) = quotes.first(where: { $0.0 == mapping.etf }) {
                    let spotPrice = quote.price * mapping.multiplier
                    let spotChange = quote.change * mapping.multiplier
                    loaded.append(MetalAsset(
                        id: mapping.symbol.lowercased(),
                        symbol: mapping.symbol,
                        name: mapping.name,
                        currentPrice: spotPrice,
                        priceChange24h: spotChange,
                        priceChangePercentage24h: quote.changePercentage,
                        iconUrl: nil,
                        unit: "oz",
                        currency: "USD",
                        timestamp: Date()
                    ))
                }
            }

            metals = loaded
        } catch {
            // Silent failure — section just won't show
        }
    }
}

// MARK: - Precious Metal Card
struct PreciousMetalCard: View {
    let metal: MetalAsset
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var isPositive: Bool { metal.priceChangePercentage24h >= 0 }

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

                // Name & Symbol
                VStack(alignment: .leading, spacing: 2) {
                    Text(metal.name)
                        .font(.headline)
                        .foregroundColor(textPrimary)

                    Text(metal.symbol.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Price & Change
                VStack(alignment: .trailing, spacing: 4) {
                    Text(metal.currentPrice.asCurrency)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(textPrimary)

                    if metal.priceChange24h != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(isPositive ? "+" : "")\(metal.priceChangePercentage24h, specifier: "%.2f")%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                    } else {
                        Text("per \(metal.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

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
