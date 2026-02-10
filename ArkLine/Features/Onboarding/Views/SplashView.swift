import SwiftUI

// MARK: - Splash View
/// Animated launch screen with ArkLine branding
struct SplashView: View {
    @State private var isAnimating = false
    @State private var showLogo = false
    @State private var showTagline = false
    @State private var showSlogan = false

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

                    // App logo
                    Image("LaunchIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .scaleEffect(showLogo ? 1 : 0.5)
                        .opacity(showLogo ? 1 : 0)
                }

                // App name and slogan
                VStack(spacing: ArkSpacing.md) {
                    Text("ArkLine")
                        .font(AppFonts.title32)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .opacity(showLogo ? 1 : 0)
                        .offset(y: showLogo ? 0 : 20)

                    VStack(spacing: 4) {
                        Text("Everyone sees the price.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .opacity(showTagline ? 1 : 0)
                            .offset(y: showTagline ? 0 : 10)

                        Text("Few see the shift.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .opacity(showSlogan ? 1 : 0)
                            .offset(y: showSlogan ? 0 : 10)
                    }
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

        // First line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) {
                showTagline = true
            }
        }

        // Second line (staggered)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.5)) {
                showSlogan = true
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
