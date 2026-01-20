import SwiftUI
import Charts

struct AssetDetailView: View {
    let asset: CryptoAsset
    @State private var selectedTimeframe: ChartTimeframe = .day
    @State private var isFavorite = false
    @Environment(\.dismiss) private var dismiss

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                AssetDetailHeader(asset: asset, isFavorite: $isFavorite)

                // Price
                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.currentPrice.asCurrency)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.caption)

                        Text("\(abs(asset.priceChange24h).asCurrency) (\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%)")
                            .font(.subheadline)
                    }
                    .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // Chart
                VStack(spacing: 16) {
                    // Placeholder Chart
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1F1F1F"))
                        .frame(height: 200)
                        .overlay(
                            Text("Price Chart")
                                .foregroundColor(Color(hex: "A1A1AA"))
                        )

                    // Timeframe Selector
                    TimeframeSelector(selected: $selectedTimeframe)
                }
                .padding(.horizontal, 20)

                // Stats
                AssetStatsSection(asset: asset)
                    .padding(.horizontal, 20)

                // About
                AboutSection(asset: asset)
                    .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
            .padding(.top, 16)
        }
        .background(Color(hex: "0F0F0F"))
        .navigationBarBackButtonHidden()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { isFavorite.toggle() }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? Color(hex: "EAB308") : .white)
                    }

                    Button(action: { }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        #endif
    }
}

// MARK: - Chart Timeframe
enum ChartTimeframe: String, CaseIterable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "ALL"
}

// MARK: - Asset Detail Header
struct AssetDetailHeader: View {
    let asset: CryptoAsset
    @Binding var isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            AsyncImage(url: URL(string: asset.iconUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(asset.symbol.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }

            Spacer()

            // Rank Badge
            Text("#\(asset.marketCapRank)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: "A1A1AA"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "2A2A2A"))
                .cornerRadius(8)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Timeframe Selector
struct TimeframeSelector: View {
    @Binding var selected: ChartTimeframe

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ChartTimeframe.allCases, id: \.self) { timeframe in
                Button(action: { selected = timeframe }) {
                    Text(timeframe.rawValue)
                        .font(.caption)
                        .fontWeight(selected == timeframe ? .semibold : .regular)
                        .foregroundColor(selected == timeframe ? .white : Color(hex: "A1A1AA"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == timeframe ? Color(hex: "6366F1") : Color.clear)
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(12)
    }
}

// MARK: - Asset Stats Section
struct AssetStatsSection: View {
    let asset: CryptoAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                StatRow(label: "Market Cap", value: (asset.marketCap ?? 0).asCurrencyCompact)
                StatRow(label: "Market Cap Rank", value: "#\(asset.marketCapRank ?? 0)")
                StatRow(label: "24h High", value: (asset.currentPrice * 1.02).asCurrency)
                StatRow(label: "24h Low", value: (asset.currentPrice * 0.98).asCurrency)
                StatRow(label: "24h Volume", value: ((asset.marketCap ?? 0) * 0.05).asCurrencyCompact)
                StatRow(label: "Circulating Supply", value: "\(((asset.marketCap ?? 0) / asset.currentPrice).formattedCompact) \(asset.symbol.uppercased())")
            }
            .padding(16)
            .background(Color(hex: "1F1F1F"))
            .cornerRadius(12)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(hex: "A1A1AA"))

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}

// MARK: - About Section
struct AboutSection: View {
    let asset: CryptoAsset
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About \(asset.name)")
                .font(.headline)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text(assetDescription)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "A1A1AA"))
                    .lineLimit(isExpanded ? nil : 3)

                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "Show Less" : "Read More")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }
            .padding(16)
            .background(Color(hex: "1F1F1F"))
            .cornerRadius(12)
        }
    }

    private var assetDescription: String {
        switch asset.id {
        case "bitcoin":
            return "Bitcoin is a decentralized cryptocurrency originally described in a 2008 whitepaper by a person, or group of people, using the alias Satoshi Nakamoto. It was launched soon after, in January 2009. Bitcoin is a peer-to-peer online currency, meaning that all transactions happen directly between equal, independent network participants."
        case "ethereum":
            return "Ethereum is a decentralized open-source blockchain system that features its own cryptocurrency, Ether. ETH works as a platform for numerous other cryptocurrencies, as well as for the execution of decentralized smart contracts."
        default:
            return "A cryptocurrency asset available for trading on major exchanges worldwide."
        }
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(
            asset: CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: nil,
                marketCap: 1324500000000,
                marketCapRank: 1
            )
        )
    }
}
