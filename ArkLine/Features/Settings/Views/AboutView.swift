import SwiftUI

// MARK: - About View
struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    /// Marketing version (e.g. "1.0.0") pulled from Info.plist at runtime
    /// so the displayed version always matches the shipping build.
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number (e.g. "1") pulled from Info.plist at runtime.
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// Current calendar year for the copyright line. Auto-rolls each January.
    private var currentYear: String {
        "\(Calendar.current.component(.year, from: Date()))"
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            VStack(spacing: 20) {
                #if canImport(UIKit)
                if let uiImage = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                #endif

                Text("ArkLine")
                    .font(AppFonts.title30)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)

                Text("Crypto & Finance Sentiment Tracker")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Spacer().frame(height: 16)

                VStack(spacing: 4) {
                    Text("Arkline Technologies LLC")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                    Text("© \(currentYear) Arkline Technologies LLC. All rights reserved.")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://arkline.io/privacy")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 14))
                            Text("Privacy Policy")
                                .font(AppFonts.body14)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.accent)
                    }

                    Link(destination: URL(string: "https://arkline.io/terms")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                            Text("Terms of Service")
                                .font(AppFonts.body14)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("About")
    }
}
