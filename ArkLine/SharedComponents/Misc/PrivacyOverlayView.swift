import SwiftUI

struct PrivacyOverlayView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Image("ArkLineLogo")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.white.opacity(0.15))
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
        }
    }
}
