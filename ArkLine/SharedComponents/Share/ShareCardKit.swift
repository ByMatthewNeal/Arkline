import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Branded Share Card

/// Generic wrapper that adds ArkLine branding around any content for export
struct BrandedShareCard<Content: View>: View {
    let showBranding: Bool
    let showTimestamp: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Branded header
            if showBranding {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)

                        Text("ArkLine")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    if showTimestamp {
                        Text(Date().formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            // Content slot
            content
                .padding(.horizontal, 16)

            // Footer
            if showBranding {
                Text("Created with ArkLine")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 12)
            }
        }
        .background(Color(hex: "121212"))
    }
}

// MARK: - Share Card Renderer

enum ShareCardRenderer {

    /// Render any SwiftUI view to a high-resolution UIImage
    @MainActor
    static func renderImage<V: View>(content: V, width: CGFloat = 390, height: CGFloat = 420) -> UIImage? {
        let view = content
            .frame(width: width, height: height)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Present the native share sheet with an image
    @MainActor
    static func presentShareSheet(image: UIImage) {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topController.view
            popover.sourceRect = CGRect(
                x: topController.view.bounds.midX,
                y: topController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topController.present(activityVC, animated: true)
        #endif
    }
}

// MARK: - Share Card Sheet

/// Generic preview sheet for sharing branded cards
struct ShareCardSheet<Content: View>: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var showBranding = true
    @State private var showTimestamp = true
    @State private var isExporting = false

    let title: String
    let cardHeight: CGFloat
    @ViewBuilder let content: (_ showBranding: Bool, _ showTimestamp: Bool) -> Content

    init(title: String = "Share", cardHeight: CGFloat = 420, @ViewBuilder content: @escaping (_ showBranding: Bool, _ showTimestamp: Bool) -> Content) {
        self.title = title
        self.cardHeight = cardHeight
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        BrandedShareCard(showBranding: showBranding, showTimestamp: showTimestamp) {
                            content(showBranding, showTimestamp)
                        }
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }

                    // Options
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
                        }
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle(title)
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

        let cardView = BrandedShareCard(showBranding: showBranding, showTimestamp: showTimestamp) {
            content(showBranding, showTimestamp)
        }

        guard let image = ShareCardRenderer.renderImage(content: cardView, width: 390, height: cardHeight) else {
            logError("Share card render failed", category: .ui)
            return
        }

        ShareCardRenderer.presentShareSheet(image: image)
    }
}
