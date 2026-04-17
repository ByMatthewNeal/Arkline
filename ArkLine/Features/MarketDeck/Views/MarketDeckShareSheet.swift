import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Market Deck Share Sheet

struct MarketDeckShareSheet: View {
    let deck: MarketUpdateDeck
    let currentSlideIndex: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var exportMode: ExportMode = .currentSlide
    @State private var exportFormat: ExportFormat = .png
    @State private var exportTheme: ExportTheme = .system
    @State private var showBranding = true
    @State private var isExporting = false

    enum ExportMode: String, CaseIterable {
        case currentSlide = "Current Slide"
        case allSlides = "All Slides (PDF)"
    }

    enum ExportFormat: String, CaseIterable {
        case png = "PNG"
        case jpeg = "JPEG"
    }

    enum ExportTheme: String, CaseIterable {
        case system = "Current"
        case dark = "Dark"
        case light = "Light"
    }

    private var resolvedColorScheme: ColorScheme {
        switch exportTheme {
        case .system: return colorScheme
        case .dark: return .dark
        case .light: return .light
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Preview
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Preview")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        DeckShareCardContent(
                            slide: deck.slides[currentSlideIndex],
                            deck: deck,
                            showBranding: showBranding
                        )
                        .environment(\.colorScheme, resolvedColorScheme)
                        .frame(maxWidth: .infinity)
                    }

                    // Export options
                    VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                        Text("Export")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        VStack(spacing: 0) {
                            // Mode picker
                            HStack {
                                Image(systemName: "doc.richtext")
                                    .foregroundColor(AppColors.accent)
                                Text("Content")
                                    .font(AppFonts.body14)

                                Spacer()

                                Picker("", selection: $exportMode) {
                                    ForEach(ExportMode.allCases, id: \.self) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppColors.accent)
                            }
                            .padding(14)

                            Divider()

                            // Format picker (only for single slide)
                            if exportMode == .currentSlide {
                                HStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(AppColors.accent)
                                    Text("Format")
                                        .font(AppFonts.body14)

                                    Spacer()

                                    Picker("", selection: $exportFormat) {
                                        ForEach(ExportFormat.allCases, id: \.self) { fmt in
                                            Text(fmt.rawValue).tag(fmt)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 140)
                                }
                                .padding(14)

                                Divider()
                            }

                            // Theme picker
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(AppColors.accent)
                                Text("Theme")
                                    .font(AppFonts.body14)

                                Spacer()

                                Picker("", selection: $exportTheme) {
                                    ForEach(ExportTheme.allCases, id: \.self) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                            }
                            .padding(14)

                            if appState.currentUser?.isAdmin == true {
                                Divider()

                                // Branding toggle
                                Toggle(isOn: $showBranding) {
                                    HStack {
                                        Image(systemName: "star.circle")
                                            .foregroundColor(AppColors.accent)
                                        Text("Show Branding")
                                            .font(AppFonts.body14)
                                    }
                                }
                                .tint(AppColors.accent)
                                .padding(14)
                            }
                        }
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Share Market Update")
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
        }
    }

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        if exportMode == .allSlides {
            await exportPDF()
        } else {
            exportSingleSlide()
        }
    }

    @MainActor
    private func exportSingleSlide() {
        guard currentSlideIndex >= 0, currentSlideIndex < deck.slides.count else { return }
        let slide = deck.slides[currentSlideIndex]
        let cardView = DeckShareCardContent(slide: slide, deck: deck, showBranding: showBranding)
        let height = DeckShareCardContent.estimatedHeight(for: slide)

        guard let image = ShareCardRenderer.renderImage(
            content: cardView.environment(\.colorScheme, resolvedColorScheme),
            width: 390,
            height: height
        ) else {
            logError("Deck share card render failed", category: .ui)
            return
        }

        if exportFormat == .jpeg {
            guard let jpegData = image.jpegData(compressionQuality: 0.95) else { return }
            shareFile(data: jpegData, filename: "arkline-market-update-\(slide.type.rawValue).jpg")
        } else {
            guard let pngData = image.pngData() else { return }
            shareFile(data: pngData, filename: "arkline-market-update-\(slide.type.rawValue).png")
        }
    }

    @MainActor
    private func exportPDF() async {
        // Use a fixed phone-width page in points (1x). PDF coordinate system is 72 dpi.
        let pageWidth: CGFloat = 390
        let pdfData = NSMutableData()

        UIGraphicsBeginPDFContextToData(pdfData, .zero, [
            kCGPDFContextTitle as String: "Arkline Weekly Market Update - \(deck.weekLabel)",
            kCGPDFContextCreator as String: "Arkline",
        ])

        for slide in deck.slides {
            let height = DeckShareCardContent.estimatedHeight(for: slide)
            let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: height)
            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            let cardView = DeckShareCardContent(slide: slide, deck: deck, showBranding: showBranding)
                .environment(\.colorScheme, resolvedColorScheme)

            // Render at 2x for crisp text, then draw scaled into 1x page rect
            let renderer = ImageRenderer(content: cardView.frame(width: pageWidth, height: height))
            renderer.scale = 2.0

            if let image = renderer.uiImage, let cgImage = image.cgImage, let context = UIGraphicsGetCurrentContext() {
                // CGContext draws images with origin at bottom-left; flip for top-left
                context.saveGState()
                context.translateBy(x: 0, y: height)
                context.scaleBy(x: 1, y: -1)
                context.draw(cgImage, in: pageRect)
                context.restoreGState()
            }
        }

        UIGraphicsEndPDFContext()

        shareFile(data: pdfData as Data, filename: "arkline-market-update-\(deck.weekLabel.replacingOccurrences(of: " ", with: "-")).pdf")
    }

    private func shareFile(data: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
    }
}

// MARK: - Shareable Slide Content

/// Renders the actual slide view with an optional branded footer — matches the in-app look.
struct DeckShareCardContent: View {
    let slide: DeckSlide
    let deck: MarketUpdateDeck
    var showBranding: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Actual slide content — same views used in the deck viewer
            VStack(spacing: 0) {
                switch slide.data {
                case .cover(let data):
                    CoverSlideView(data: data, deck: deck)
                case .marketPulse(let data):
                    MarketPulseSlideView(data: data, title: slide.title)
                case .macro(let data):
                    MacroSlideView(data: data, title: slide.title)
                case .positioning(let data):
                    PositioningSlideView(data: data, title: slide.title)
                case .economic(let data):
                    EconomicSlideView(data: data, title: slide.title)
                case .setups(let data):
                    SetupsSlideView(data: data, title: slide.title)
                case .rundown(let data):
                    RundownSlideView(data: data, title: slide.title)
                case .sectionTitle(let data):
                    SectionTitleSlideView(data: data, title: slide.title)
                case .editorial(let data):
                    EditorialSlideView(data: data, title: slide.title)
                case .snapshot(let data):
                    SnapshotSlideView(data: data, title: slide.title)
                case .weeklyOutlook(let data):
                    WeeklyOutlookSlideView(data: data, title: slide.title)
                case .correlation(let data):
                    CorrelationSlideView(data: data, title: slide.title)
                }
            }
            .padding(.horizontal, ArkSpacing.xl)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Branded footer
            if showBranding {
                DeckShareFooter()
                    .padding(.horizontal, ArkSpacing.xl)
                    .padding(.bottom, 16)
            }
        }
        .background(AppColors.background(colorScheme))
    }

    /// Estimated height for rendering
    static func estimatedHeight(for slide: DeckSlide) -> CGFloat {
        let footerHeight: CGFloat = 60
        let padding: CGFloat = 40
        let contentHeight: CGFloat = {
            switch slide.data {
            case .cover: return 580
            case .weeklyOutlook(let data):
                return CGFloat(300 + data.lookAhead.count * 50)
            case .correlation: return 540
            case .editorial(let data):
                return CGFloat(180 + data.bullets.count * 90)
            case .sectionTitle: return 200
            case .marketPulse: return 500
            case .snapshot: return 540
            case .macro: return 400
            case .positioning(let data):
                return CGFloat(220 + data.signalChanges.prefix(8).count * 40)
            case .economic(let data):
                return CGFloat(220 + data.thisWeek.count * 46 + data.nextWeek.count * 34)
            case .setups(let data):
                return CGFloat(220 + data.signals.prefix(6).count * 54)
            case .rundown(let data):
                return CGFloat(200 + max(CGFloat(data.narrative.count) / 2.5, 220))
            }
        }()
        return contentHeight + footerHeight + padding
    }
}

// MARK: - Branded Footer

struct DeckShareFooter: View {
    @Environment(\.colorScheme) private var colorScheme
    private var qrImage: UIImage? { QRCodeGenerator.generate(forURL: "https://arkline.io", size: 120) }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.textPrimary(colorScheme).opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 10)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("arkline.io")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)

                    Text("Data Over Noise")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                        .italic()
                }

                Spacer()

                if let qr = qrImage {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(4)
                }
            }
        }
    }
}
