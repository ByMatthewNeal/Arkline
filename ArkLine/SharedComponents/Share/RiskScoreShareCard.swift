import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Risk Score Share Card Content

struct RiskScoreShareCardContent: View {
    let riskScore: ArkLineRiskScore
    let fearGreedValue: Int?
    let fearGreedClassification: String?
    var isLight: Bool = true
    var qrImage: UIImage? = nil

    private var textPrimary: Color { isLight ? Color(hex: "1A1A2E") : .white }
    private var textSecondary: Color { isLight ? Color(hex: "64748B") : Color.white.opacity(0.6) }
    private var textMuted: Color { isLight ? Color(hex: "94A3B8") : Color.white.opacity(0.4) }
    private var dividerColor: Color { isLight ? Color(hex: "E2E8F0") : Color.white.opacity(0.08) }
    private var cardBg: Color { isLight ? Color(hex: "F8FAFC") : Color(hex: "1A1A1A") }

    private var tierColor: Color { Color(hex: riskScore.tier.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("ARKLINE RISK SCORE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textMuted)
                .tracking(1.2)
                .padding(.bottom, 16)

            // Score display
            HStack(alignment: .bottom, spacing: 12) {
                Text("\(riskScore.score)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundColor(tierColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("/ 100")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textMuted)

                    Text(riskScore.tier.rawValue)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(tierColor)
                }
                .padding(.bottom, 8)

                Spacer()
            }

            // Risk gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background gradient bar
                    LinearGradient(
                        colors: [
                            Color(hex: "22C55E"), // Low risk (green)
                            Color(hex: "FACC15"), // Neutral (yellow)
                            Color(hex: "F97316"), // Elevated (orange)
                            Color(hex: "DC2626")  // High risk (red)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .cornerRadius(4)

                    // Position indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: geo.size.width * CGFloat(riskScore.score) / 100 - 7)
                }
            }
            .frame(height: 14)
            .padding(.top, 8)

            HStack {
                Text("Low Risk")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(textMuted)
                Spacer()
                Text("High Risk")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(textMuted)
            }
            .padding(.top, 4)
            .padding(.bottom, 16)

            // Components breakdown
            VStack(spacing: 0) {
                ForEach(Array(riskScore.components.enumerated()), id: \.element.name) { index, component in
                    if index > 0 {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                    }

                    HStack {
                        Text(component.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)

                        Spacer()

                        // Component bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dividerColor)
                                .frame(width: 60, height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: component.signal.color))
                                .frame(width: 60 * component.value, height: 4)
                        }

                        Text(component.signal.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: component.signal.color))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBg)
            )

            // Fear & Greed comparison
            if let fg = fearGreedValue, let fgClass = fearGreedClassification {
                HStack {
                    Text("Fear & Greed Index")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)

                    Spacer()

                    Text("\(fg)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimary)

                    Text(fgClass)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(fearGreedColor(fg))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cardBg)
                )
                .padding(.top, 8)
            }

            // Recommendation
            Text(riskScore.recommendation)
                .font(.system(size: 12))
                .foregroundColor(textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            // QR footer
            ShareCardQRFooter(isLight: isLight, qrImage: qrImage)
                .padding(.top, 16)
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        switch value {
        case 0..<25: return AppColors.error
        case 25..<45: return Color(hex: "F97316")
        case 45..<55: return AppColors.warning
        case 55..<75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }
}

// MARK: - Risk Score Share Sheet

struct RiskScoreShareSheet: View {
    let riskScore: ArkLineRiskScore
    var fearGreedValue: Int? = nil
    var fearGreedClassification: String? = nil

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showBranding = true
    @State private var showTimestamp = true
    @State private var useLightTheme = false
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
            .navigationTitle("Share Risk Score")
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
        let content = RiskScoreShareCardContent(
            riskScore: riskScore,
            fearGreedValue: fearGreedValue,
            fearGreedClassification: fearGreedClassification,
            isLight: useLightTheme,
            qrImage: qrImage
        )

        VStack(spacing: 0) {
            if showBranding {
                brandedHeader
            }
            content.padding(.horizontal, 16)
            if !showBranding { Spacer().frame(height: 12) }
        }
        .background(useLightTheme ? Color.white : Color(hex: "121212"))
    }

    private var brandedHeader: some View {
        let textColor: Color = useLightTheme ? Color(hex: "1A1A2E") : .white
        let tsColor: Color = useLightTheme ? Color(hex: "64748B") : Color.white.opacity(0.5)

        return HStack {
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
                    .foregroundColor(tsColor)
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

        let componentCount = riskScore.components.count
        var height: CGFloat = 280 + CGFloat(componentCount) * 36
        if fearGreedValue != nil { height += 50 }
        height += 60 // recommendation text
        if showBranding { height += 60 }
        height += 80 // QR footer

        guard let image = ShareCardRenderer.renderImage(
            content: cardView,
            width: 390,
            height: height
        ) else {
            logError("Risk score share card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
