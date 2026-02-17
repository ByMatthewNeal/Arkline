import SwiftUI

/// A watermark overlay showing the ArkLine logo silhouette centered in a chart.
/// Uses the transparent "ArkLineLogo" asset as a mask so only the logo shape
/// is visible — adapts color to light/dark mode automatically.
struct ChartLogoWatermark: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white : Color.black)
            .mask(
                Image("ArkLineLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
            .frame(width: 170, height: 170)
            .opacity(colorScheme == .dark ? 0.08 : 0.07)
    }
}
