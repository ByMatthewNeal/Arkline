import SwiftUI

// MARK: - Splash View
struct SplashView: View {
    @State private var isAnimating = false
    @State private var showLogo = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "0F0F0F"),
                    Color(hex: "1A1A2E")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "6366F1").opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 1 : 0.5)

                    // Logo icon
                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "6366F1"),
                                    Color(hex: "8B5CF6")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showLogo ? 1 : 0.5)
                        .opacity(showLogo ? 1 : 0)
                }

                // App name
                VStack(spacing: 8) {
                    Text("ArkLine")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(showLogo ? 1 : 0)
                        .offset(y: showLogo ? 0 : 20)

                    Text("Track • Analyze • Grow")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "A1A1AA"))
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 10)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showLogo = true
        }

        // Tagline animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                showTagline = true
            }
        }

        // Glow pulse animation
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            isAnimating = true
        }
    }
}

// MARK: - Preview
#Preview {
    SplashView()
}
