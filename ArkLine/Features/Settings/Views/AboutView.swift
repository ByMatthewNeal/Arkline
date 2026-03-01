import SwiftUI

// MARK: - About View
struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
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

                Text("Version 1.0.0")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)

                Text("Crypto & Finance Sentiment Tracker")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("About")
    }
}
