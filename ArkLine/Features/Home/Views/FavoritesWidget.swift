import SwiftUI

struct FavoritesWidget: View {
    let assets: [CryptoAsset]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Favorites")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                NavigationLink(destination: MarketAssetsView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }

            VStack(spacing: 8) {
                ForEach(assets) { asset in
                    AssetRowView(asset: asset)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Placeholder Market Assets View
struct MarketAssetsView: View {
    var body: some View {
        Text("Market Assets")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
    }
}

#Preview {
    FavoritesWidget(
        assets: [
            CryptoAsset(
                id: "bitcoin",
                symbol: "BTC",
                name: "Bitcoin",
                currentPrice: 67234.50,
                priceChange24h: 1523.40,
                priceChangePercentage24h: 2.32,
                iconUrl: nil,
                marketCap: 1324500000000,
                marketCapRank: 1
            ),
            CryptoAsset(
                id: "ethereum",
                symbol: "ETH",
                name: "Ethereum",
                currentPrice: 3456.78,
                priceChange24h: -45.23,
                priceChangePercentage24h: -1.29,
                iconUrl: nil,
                marketCap: 415600000000,
                marketCapRank: 2
            )
        ]
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}
