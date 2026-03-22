import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Portfolio Share Card Content

struct PortfolioShareCardContent: View {
    let portfolioName: String
    let totalValue: Double
    let change: Double
    let changePercent: Double
    let timePeriod: String
    let chartData: [CGFloat]
    var isLight: Bool = true
    var qrImage: UIImage? = nil

    private var textPrimary: Color { isLight ? Color(hex: "1A1A2E") : .white }
    private var textSecondary: Color { isLight ? Color(hex: "64748B") : Color.white.opacity(0.6) }
    private var textMuted: Color { isLight ? Color(hex: "94A3B8") : Color.white.opacity(0.4) }
    private var dividerColor: Color { isLight ? Color(hex: "E2E8F0") : Color.white.opacity(0.08) }
    private var cardBg: Color { isLight ? Color(hex: "F8FAFC") : Color(hex: "1A1A1A") }

    private var isPositive: Bool { change >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("PORTFOLIO PERFORMANCE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textMuted)
                .tracking(1.2)
                .padding(.bottom, 6)

            Text(portfolioName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textSecondary)
                .padding(.bottom, 16)

            // Value
            Text(totalValue.asCurrency)
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundColor(textPrimary)
                .monospacedDigit()

            // Change
            HStack(spacing: 6) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 12, weight: .bold))

                Text(String(format: "%+.2f%%", changePercent))
                    .font(.system(size: 16, weight: .bold))

                Text("(\(change >= 0 ? "+" : "")$\(abs(change).formatted(.number.precision(.fractionLength(2)))))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textSecondary)

                Spacer()

                Text(timePeriod)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isLight ? Color(hex: "E2E8F0") : Color.white.opacity(0.08))
                    )
            }
            .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            .padding(.top, 4)

            // Chart
            if chartData.count > 1 {
                SparklineChart(data: chartData.map { Double($0) }, isPositive: isPositive, lineWidth: 2)
                    .frame(height: 100)
                    .padding(.top, 16)
            }

            // QR footer
            ShareCardQRFooter(isLight: isLight, qrImage: qrImage)
                .padding(.top, 20)
        }
    }
}

// MARK: - Portfolio Share Sheet

struct PortfolioShareSheet: View {
    let portfolioName: String
    let totalValue: Double
    let change: Double
    let changePercent: Double
    let timePeriod: String
    let chartData: [CGFloat]

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showBranding = true
    @State private var showTimestamp = true
    @State private var useLightTheme = true
    @State private var isExporting = false
    @State private var logoImage: UIImage?
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        cardView
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                    }

                    optionsSection
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Share Portfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await exportAndShare() }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .task {
                logoImage = UIImage(named: "ArkLineAppIcon")
                qrImage = QRCodeGenerator.generate(forURL: "https://arkline.io")
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Options")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 0) {
                Toggle(isOn: $showBranding) {
                    HStack {
                        Image(systemName: "star.circle")
                            .foregroundColor(AppColors.accent)
                        Text("Show ArkLine Branding")
                            .font(AppFonts.body14)
                    }
                }
                .tint(AppColors.accent)
                .padding(14)

                Divider()

                Toggle(isOn: $showTimestamp) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(AppColors.accent)
                        Text("Show Timestamp")
                            .font(AppFonts.body14)
                    }
                }
                .tint(AppColors.accent)
                .padding(14)

                Divider()

                Toggle(isOn: $useLightTheme) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(AppColors.accent)
                        Text("Light Theme")
                            .font(AppFonts.body14)
                    }
                }
                .tint(AppColors.accent)
                .padding(14)
            }
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var cardView: some View {
        let content = PortfolioShareCardContent(
            portfolioName: portfolioName,
            totalValue: totalValue,
            change: change,
            changePercent: changePercent,
            timePeriod: timePeriod,
            chartData: chartData,
            isLight: useLightTheme,
            qrImage: qrImage
        )

        if useLightTheme {
            lightBrandedCard { content }
        } else {
            darkBrandedCard { content }
        }
    }

    private func lightBrandedCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            if showBranding {
                brandedHeader(textColor: Color(hex: "1A1A2E"), timestampColor: Color(hex: "64748B"))
            }
            content().padding(.horizontal, 16)
            if !showBranding { Spacer().frame(height: 12) }
        }
        .background(Color.white)
    }

    private func darkBrandedCard<C: View>(@ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            if showBranding {
                brandedHeader(textColor: .white, timestampColor: Color.white.opacity(0.5))
            }
            content().padding(.horizontal, 16)
            if !showBranding { Spacer().frame(height: 12) }
        }
        .background(Color(hex: "121212"))
    }

    private func brandedHeader(textColor: Color, timestampColor: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                if let logo = logoImage {
                    Image(uiImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("ArkLine")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
            }
            Spacer()
            if showTimestamp {
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(timestampColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        var height: CGFloat = 340
        if chartData.count > 1 { height += 120 }
        if showBranding { height += 60 }
        height += 80 // QR footer

        guard let image = ShareCardRenderer.renderImage(
            content: cardView,
            width: 390,
            height: height
        ) else {
            logError("Portfolio share card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
