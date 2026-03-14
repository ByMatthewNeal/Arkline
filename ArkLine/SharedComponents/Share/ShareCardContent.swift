import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif
import Kingfisher

// MARK: - Asset Share Card Content

struct AssetShareCardContent: View {
    let asset: CryptoAsset
    let iconImage: UIImage?

    private var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Asset identity
            HStack(spacing: 12) {
                // Icon (pre-fetched UIImage or gradient fallback)
                Group {
                    if let uiImage = iconImage {
                        Image(uiImage: uiImage)
                            .resizable()
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text(asset.symbol.prefix(1).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(asset.symbol.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Spacer()

                // Rank badge
                if let rank = asset.marketCapRank {
                    Text("#\(rank)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            // Price + change
            HStack(alignment: .firstTextBaseline) {
                Text(asset.currentPrice >= 1
                    ? asset.currentPrice.asCurrency
                    : String(format: "$%.6f", asset.currentPrice))
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(String(format: "%+.2f%%", asset.priceChangePercentage24h))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            // Sparkline chart
            if let sparkline = asset.sparklinePrices, sparkline.count > 1 {
                SparklineChart(data: sparkline, isPositive: isPositive, lineWidth: 2)
                    .frame(height: 120)
                    .overlay {
                        ChartLogoWatermark()
                            .opacity(0.5) // Slightly more visible for export
                    }
            } else {
                // Fallback: no chart data
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 120)
                    .overlay(
                        Text("7d chart unavailable")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.3))
                    )
            }

            // Stats row
            HStack(spacing: 0) {
                if let marketCap = asset.marketCap {
                    ShareStatColumn(label: "Market Cap", value: marketCap.asCurrencyCompact)
                }

                Spacer()

                if let volume = asset.totalVolume {
                    ShareStatColumn(label: "24h Volume", value: volume.asCurrencyCompact)
                }

                Spacer()

                if let high = asset.high24h, let low = asset.low24h {
                    ShareStatColumn(label: "24h Range", value: "\(low.asCurrencyCompact) – \(high.asCurrencyCompact)")
                }
            }
        }
    }
}

// MARK: - Risk Share Card Content

struct RiskShareCardContent: View {
    let coinSymbol: String
    let riskLevel: ITCRiskLevel
    let history: [ITCRiskLevel]
    let timeRange: RiskTimeRange

    private var riskValue: Double { riskLevel.riskLevel }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Coin identity + risk value
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(coinSymbol) Risk Level")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(RiskColors.color(for: riskValue))
                            .frame(width: 10, height: 10)

                        Text(String(format: "%.3f", riskValue))
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(RiskColors.color(for: riskValue))

                        Text(RiskColors.category(for: riskValue))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(RiskColors.color(for: riskValue).opacity(0.8))
                    }
                }

                Spacer()

                // Timeframe badge
                Text(timeRange.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }

            // Risk chart
            RiskLevelChart(
                history: history,
                timeRange: timeRange,
                colorScheme: .dark
            )
            .frame(height: 160)

            // Price + additional info
            HStack {
                if let price = riskLevel.price, price > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Price")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                        Text(price >= 1
                            ? price.asCurrencyWhole
                            : String(format: "$%.4f", price))
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                if let fairValue = riskLevel.fairValue, fairValue > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Fair Value")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.4))
                        Text(fairValue >= 1
                            ? fairValue.asCurrencyWhole
                            : String(format: "$%.4f", fairValue))
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }
                }
            }

            // CTA + QR Code
            Divider().opacity(0.15)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Get real-time risk levels")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("arkline.io")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "3369FF"))
                }

                Spacer()

                // QR code for arkline.io
                if let qrImage = Self.generateQRCode(from: "https://arkline.io") {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .cornerRadius(4)
                }
            }
        }
    }

    /// Generate a QR code UIImage from a string
    private static func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale = 256.0 / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Supporting Views

private struct ShareStatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Icon Pre-fetch Utility

enum ShareCardIconLoader {
    /// Pre-fetch a remote image via Kingfisher for use in ImageRenderer
    @MainActor
    static func loadIcon(from urlString: String?) async -> UIImage? {
        #if canImport(UIKit)
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return await withCheckedContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: url) { result in
                switch result {
                case .success(let imageResult):
                    continuation.resume(returning: imageResult.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        #else
        return nil
        #endif
    }
}
