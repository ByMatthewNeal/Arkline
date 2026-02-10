import SwiftUI

struct PremiumRequiredModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    let feature: PremiumFeature
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        if appState.isPro {
            content
        } else {
            content
                .opacity(0.4)
                .allowsHitTesting(false)
                .overlay(alignment: .trailing) {
                    Button(action: { showPaywall = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.15))
                        .cornerRadius(ArkSpacing.Radius.xs)
                    }
                    .padding(.trailing, ArkSpacing.xs)
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(feature: feature)
                }
        }
    }
}

extension View {
    func premiumRequired(_ feature: PremiumFeature) -> some View {
        modifier(PremiumRequiredModifier(feature: feature))
    }
}
