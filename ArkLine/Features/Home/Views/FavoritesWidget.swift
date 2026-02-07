import SwiftUI

struct FavoritesWidget: View {
    let assets: [CryptoAsset]
    @State private var selectedAsset: CryptoAsset?
    @State private var showTechnicalDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Favorites")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(assets) { asset in
                    Button {
                        selectedAsset = asset
                        showTechnicalDetail = true
                    } label: {
                        AssetRowView(asset: asset)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
        .sheet(isPresented: $showTechnicalDetail) {
            if let asset = selectedAsset {
                AssetTechnicalDetailSheet(asset: asset)
            }
        }
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
