import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Signal Changes Share Card Content

struct SignalChangesShareCardContent: View {
    let changes: [DailyPositioningSignal]
    let totalAssets: Int
    var isLight: Bool = true
    var qrImage: UIImage? = nil

    private var textPrimary: Color { isLight ? Color(hex: "1A1A2E") : .white }
    private var textSecondary: Color { isLight ? Color(hex: "64748B") : Color.white.opacity(0.6) }
    private var textMuted: Color { isLight ? Color(hex: "94A3B8") : Color.white.opacity(0.4) }
    private var dividerColor: Color { isLight ? Color(hex: "E2E8F0") : Color.white.opacity(0.08) }
    private var cardBg: Color { isLight ? Color(hex: "F8FAFC") : Color(hex: "1A1A1A") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SIGNAL CHANGES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textMuted)
                    .tracking(1.2)

                Spacer()

                Text("\(changes.count) of \(totalAssets) assets")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textMuted)
            }
            .padding(.bottom, 14)

            // Changes list
            VStack(spacing: 0) {
                ForEach(Array(changes.prefix(10).enumerated()), id: \.element.asset) { index, signal in
                    if index > 0 {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                    }

                    HStack(spacing: 10) {
                        Text(signal.asset)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(textPrimary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: 80, alignment: .leading)

                        if let prev = signal.prevSignal {
                            signalBadge(prev, dimmed: true)
                        }

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(textMuted)

                        signalBadge(signal.signal, dimmed: false)

                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardBg)
            )

            if changes.count > 10 {
                Text("+ \(changes.count - 10) more changes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textMuted)
                    .padding(.top, 8)
            }

            // QR footer
            ShareCardQRFooter(isLight: isLight, qrImage: qrImage)
                .padding(.top, 16)
        }
    }

    private func signalBadge(_ signal: String, dimmed: Bool) -> some View {
        let color: Color = {
            switch signal.lowercased() {
            case "bullish": return Color(hex: "22C55E")
            case "bearish": return Color(hex: "DC2626")
            default: return Color(hex: "F59E0B")
            }
        }()

        return Text(signal.capitalized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
    }
}

// MARK: - Signal Changes Share Sheet

struct SignalChangesShareSheet: View {
    let changes: [DailyPositioningSignal]
    let totalAssets: Int

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
            .navigationTitle("Share Signal Changes")
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
        let content = SignalChangesShareCardContent(
            changes: changes,
            totalAssets: totalAssets,
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

        let count = min(changes.count, 10)
        var height: CGFloat = 100 + CGFloat(count) * 44
        if changes.count > 10 { height += 24 }
        if showBranding { height += 60 }
        height += 80 // QR footer

        guard let image = ShareCardRenderer.renderImage(
            content: cardView,
            width: 390,
            height: height
        ) else {
            logError("Signal changes share card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
