import SwiftUI
import Kingfisher

struct AssetRowView: View {
    let asset: CryptoAsset

    var isPositive: Bool {
        asset.priceChangePercentage24h >= 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            KFImage(URL(string: asset.iconUrl ?? ""))
                .resizable()
                .placeholder {
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
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(asset.symbol.uppercased())
                    .font(.caption)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.currentPrice.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))

                    Text("\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(asset.name), \(asset.currentPrice.asCurrency), \(isPositive ? "up" : "down") \(String(format: "%.2f", abs(asset.priceChangePercentage24h))) percent")
    }
}

// MARK: - Compact Asset Row
struct CompactAssetRow: View {
    let symbol: String
    let name: String
    let price: Double
    let change: Double

    var isPositive: Bool { change >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "6366F1").opacity(0.2))
                    .frame(width: 36, height: 36)

                Text(symbol.prefix(1))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "6366F1"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(symbol)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(name)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(price.asCurrency)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Text("\(isPositive ? "+" : "")\(change, specifier: "%.2f")%")
                    .font(.caption2)
                    .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
            }
        }
    }
}

#Preview {
    VStack {
        AssetRowView(
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

        CompactAssetRow(
            symbol: "ETH",
            name: "Ethereum",
            price: 3456.78,
            change: -1.29
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
