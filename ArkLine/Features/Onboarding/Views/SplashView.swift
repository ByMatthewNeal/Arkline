import SwiftUI

// MARK: - Splash View
/// Animated launch screen with ArkLine branding
struct SplashView: View {
    @State private var isAnimating = false
    @State private var showLogo = false
    @State private var showTagline = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Background
            AppColors.background(colorScheme)
                .ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.surface(colorScheme),
                    AppColors.background(colorScheme)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: ArkSpacing.xl) {
                // Logo with glow
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    AppColors.fillPrimary.opacity(0.3),
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
                                colors: [AppColors.fillPrimary, AppColors.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(showLogo ? 1 : 0.5)
                        .opacity(showLogo ? 1 : 0)
                }

                // App name and tagline
                VStack(spacing: ArkSpacing.xs) {
                    Text("ArkLine")
                        .font(AppFonts.title32)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .opacity(showLogo ? 1 : 0)
                        .offset(y: showLogo ? 0 : 20)

                    Text("Track • Analyze • Grow")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)
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
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    SplashView()
        .preferredColorScheme(.light)
}
