import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Performance Export Sheet

struct PerformanceExportSheet: View {
    let stats: SignalStats
    let signals: [TradeSignal]
    let periodLabel: String

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var exportMode: ExportMode = .card
    @State private var showBranding = true
    @State private var useLightTheme = false
    @State private var isExporting = false
    @State private var logoImage: UIImage?

    enum ExportMode: String, CaseIterable {
        case card = "Branded Card"
        case text = "Text Only"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode picker
                    Picker("Export Mode", selection: $exportMode) {
                        ForEach(ExportMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if exportMode == .card {
                        // Card preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            cardView
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        }

                        // Card options
                        cardOptions
                    } else {
                        // Text preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text(buildTextExport())
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.cardBackground(colorScheme))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Export Performance")
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
            }
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private var cardView: some View {
        if useLightTheme {
            LightPerformanceCard(showBranding: showBranding, logoImage: logoImage) {
                cardContent
            }
        } else {
            DarkPerformanceCard(showBranding: showBranding, logoImage: logoImage) {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        let isDark = !useLightTheme
        let textColor = isDark ? Color.white : Color(hex: "1A1A2E")
        let secondaryColor = isDark ? Color.white.opacity(0.5) : Color(hex: "64748B")
        let greenColor = Color(hex: "22C55E")
        let redColor = Color(hex: "EF4444")
        let totalPnl = signals.compactMap(\.outcomePct).reduce(0, +)

        return VStack(spacing: 14) {
            // Period + Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Signal Performance")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(textColor)
                    Text(periodLabel)
                        .font(.system(size: 11))
                        .foregroundColor(secondaryColor)
                }
                Spacer()
                Text(String(format: "%+.1f%%", totalPnl))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(totalPnl >= 0 ? greenColor : redColor)
            }

            Divider().opacity(isDark ? 0.2 : 0.15)

            // Win rate + core stats
            HStack(spacing: 0) {
                statColumn("Win Rate", String(format: "%.0f%%", stats.hitRate), stats.hitRate >= 50 ? greenColor : redColor, textColor, secondaryColor)
                statColumn("Trades", "\(stats.totalSignals)", textColor, textColor, secondaryColor)
                statColumn("Profit Factor", stats.profitFactor.isInfinite ? "---" : String(format: "%.2f", stats.profitFactor),
                           stats.profitFactor >= 1.5 ? greenColor : (stats.profitFactor >= 1.0 ? Color(hex: "F59E0B") : redColor), textColor, secondaryColor)
                statColumn("Avg Win", String(format: "+%.1f%%", stats.avgWinPct), greenColor, textColor, secondaryColor)
            }

            Divider().opacity(isDark ? 0.2 : 0.15)

            // W/L/P row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(greenColor).frame(width: 6, height: 6)
                    Text("\(stats.wins) Wins").font(.system(size: 11, weight: .medium)).foregroundColor(textColor)
                }
                HStack(spacing: 4) {
                    Circle().fill(redColor).frame(width: 6, height: 6)
                    Text("\(stats.losses) Losses").font(.system(size: 11, weight: .medium)).foregroundColor(textColor)
                }
                if stats.partials > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "F59E0B")).frame(width: 6, height: 6)
                        Text("\(stats.partials) Partial").font(.system(size: 11, weight: .medium)).foregroundColor(textColor)
                    }
                }
                Spacer()
            }

            // Asset breakdown (top 5)
            if !stats.assetBreakdown.isEmpty {
                Divider().opacity(isDark ? 0.2 : 0.15)

                VStack(spacing: 6) {
                    ForEach(stats.assetBreakdown.prefix(5)) { asset in
                        HStack {
                            Text(asset.asset)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(textColor)
                                .frame(width: 50, alignment: .leading)

                            // Mini bar
                            GeometryReader { geo in
                                let total = max(asset.total, 1)
                                let winW = geo.size.width * CGFloat(asset.wins + asset.partials) / CGFloat(total)
                                HStack(spacing: 1) {
                                    Rectangle().fill(greenColor).frame(width: max(winW, 0))
                                    Rectangle().fill(redColor)
                                }
                                .cornerRadius(2)
                            }
                            .frame(height: 6)

                            Text(String(format: "%.0f%%", asset.hitRate))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(secondaryColor)
                                .frame(width: 32, alignment: .trailing)

                            Text(String(format: "%+.1f%%", asset.avgReturnPct))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(asset.avgReturnPct >= 0 ? greenColor : redColor)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func statColumn(_ label: String, _ value: String, _ valueColor: Color, _ textColor: Color, _ secondaryColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(secondaryColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Card Options

    private var cardOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Options")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 0) {
                if appState.currentUser?.isAdmin == true {
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
                }

                Toggle(isOn: $useLightTheme) {
                    HStack {
                        Image(systemName: useLightTheme ? "sun.max.fill" : "moon.fill")
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

    // MARK: - Text Export

    private static let exportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private func buildTextExport() -> String {
        let totalPnl = signals.compactMap(\.outcomePct).reduce(0, +)
        let df = Self.exportDateFormatter

        var text = "ArkLine Signal Performance — \(periodLabel)\n"
        text += String(repeating: "─", count: 40) + "\n\n"
        text += "Total P&L: \(String(format: "%+.1f%%", totalPnl))\n"
        text += "Win Rate: \(String(format: "%.0f%%", stats.hitRate)) (\(stats.wins)W / \(stats.losses)L"
        if stats.partials > 0 { text += " / \(stats.partials)P" }
        text += ")\n"
        text += "Profit Factor: \(stats.profitFactor.isInfinite ? "∞" : String(format: "%.2f", stats.profitFactor))\n"
        text += "Avg Win: \(String(format: "+%.1f%%", stats.avgWinPct)) | Avg Loss: \(String(format: "%.1f%%", stats.avgLossPct))\n"
        text += "Trades: \(stats.totalSignals)\n\n"

        if !stats.assetBreakdown.isEmpty {
            text += "By Asset:\n"
            for asset in stats.assetBreakdown {
                text += "  \(asset.asset): \(String(format: "%.0f%%", asset.hitRate)) win rate, \(String(format: "%+.1f%%", asset.avgReturnPct)) avg\n"
            }
            text += "\n"
        }

        text += "Trades:\n"
        let sorted = signals.sorted { ($0.closedAt ?? .distantPast) > ($1.closedAt ?? .distantPast) }
        for s in sorted {
            let dir = s.signalType.isBuy ? "L" : "S"
            let pnl = s.outcomePct.map { String(format: "%+.2f%%", $0) } ?? "—"
            let date = s.closedAt.map { df.string(from: $0) } ?? "—"
            text += "  \(s.asset) \(dir) \(pnl) [\(date)]\n"
        }

        text += "\nGenerated by ArkLine"
        return text
    }

    // MARK: - Export

    @MainActor
    private func exportAndShare() async {
        isExporting = true
        defer { isExporting = false }

        if exportMode == .card {
            let rowCount = min(stats.assetBreakdown.count, 5)
            let cardHeight: CGFloat = 260 + CGFloat(rowCount * 18)

            guard let image = ShareCardRenderer.renderImage(
                content: cardView,
                width: 390,
                height: cardHeight
            ) else {
                logError("Performance card render failed", category: .ui)
                return
            }
            ShareCardRenderer.presentShareSheet(image: image)
        } else {
            let text = buildTextExport()
            let fileName = "arkline_performance_\(periodLabel.lowercased().replacingOccurrences(of: " ", with: "_")).txt"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try text.write(to: tempURL, atomically: true, encoding: .utf8)
                #if canImport(UIKit)
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
                #endif
            } catch {
                logError("Text export failed: \(error.localizedDescription)", category: .data)
            }
        }
    }
}

// MARK: - Light Performance Card

private struct LightPerformanceCard<Content: View>: View {
    let showBranding: Bool
    let logoImage: UIImage?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showBranding {
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
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }
                    Spacer()
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "64748B"))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            content.padding(.horizontal, 16)

            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "94A3B8"))
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .background(Color.white)
    }
}

// MARK: - Dark Performance Card

private struct DarkPerformanceCard<Content: View>: View {
    let showBranding: Bool
    let logoImage: UIImage?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showBranding {
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
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            content.padding(.horizontal, 16)

            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .background(Color(hex: "121212"))
    }
}
