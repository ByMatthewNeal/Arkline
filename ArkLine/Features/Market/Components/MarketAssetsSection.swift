import SwiftUI
import Kingfisher

// MARK: - Asset Category for Segment Control
enum AssetSegment: String, CaseIterable {
    case crypto = "Crypto"
    case stocks = "Stocks"
    case metals = "Metals"
}

// MARK: - Market Assets Section
struct MarketAssetsSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MarketViewModel
    @State private var selectedSegment: AssetSegment = .crypto

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Market Assets")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .padding(.horizontal, 20)

            // Segment Control
            SegmentedControl(selection: $selectedSegment)
                .padding(.horizontal, 20)

            // Asset List
            VStack(spacing: 0) {
                switch selectedSegment {
                case .crypto:
                    ForEach(viewModel.cryptoAssets) { asset in
                        NavigationLink(destination: AssetDetailView(asset: asset)) {
                            CryptoAssetRow(asset: asset)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if asset.id != viewModel.cryptoAssets.last?.id {
                            Divider()
                                .background(Color(hex: "2A2A2A"))
                                .padding(.horizontal, 20)
                        }
                    }
                case .stocks:
                    ForEach(viewModel.stockAssets) { asset in
                        StockAssetRow(asset: asset)

                        if asset.id != viewModel.stockAssets.last?.id {
                            Divider()
                                .background(Color(hex: "2A2A2A"))
                                .padding(.horizontal, 20)
                        }
                    }
                case .metals:
                    ForEach(viewModel.metalAssets) { asset in
                        MetalAssetRow(asset: asset)

                        if asset.id != viewModel.metalAssets.last?.id {
                            Divider()
                                .background(Color(hex: "2A2A2A"))
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .glassCard(cornerRadius: 16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Segmented Control
struct SegmentedControl: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selection: AssetSegment

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AssetSegment.allCases, id: \.self) { segment in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = segment
                    }
                }) {
                    Text(segment.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selection == segment ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selection == segment
                                ? AppColors.accent
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Crypto Asset Row
struct CryptoAssetRow: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: CryptoAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

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

            // Name & Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Price & Change
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.currentPrice.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
    }
}

// MARK: - Stock Asset Row
struct StockAssetRow: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: StockAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(asset.symbol.prefix(1))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(width: 40, height: 40)

            // Name & Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Price & Change
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.currentPrice.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
    }
}

// MARK: - Metal Asset Row
struct MetalAssetRow: View {
    @Environment(\.colorScheme) var colorScheme
    let asset: MetalAsset

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

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

                Text(metalEmoji(for: asset.symbol))
                    .font(.system(size: 20))
            }
            .frame(width: 40, height: 40)

            // Name & Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Price & Change
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.currentPrice.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
    }

    private func metalEmoji(for symbol: String) -> String {
        switch symbol.uppercased() {
        case "XAU": return "Au"
        case "XAG": return "Ag"
        case "XPT": return "Pt"
        case "XPD": return "Pd"
        default: return symbol.prefix(2).uppercased()
        }
    }
}

#Preview {
    ScrollView {
        MarketAssetsSection(viewModel: MarketViewModel())
    }
    .background(Color(hex: "0F0F0F"))
}
