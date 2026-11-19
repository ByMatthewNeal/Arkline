import SwiftUI

// MARK: - Paywall presentation

/// Presents the Pro paywall as a sheet and refreshes the subscription gate when
/// it finishes. Attach once where you need it and drive it with the binding.
private struct PaywallSheetModifier: ViewModifier {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            ArkPaywallSheet(
                isFoundingMember: appState.currentUser?.isFoundingMember ?? false
            ) { _ in
                isPresented = false
                Task { await appState.refreshSubscriptionStatus() }
            }
        }
    }
}

extension View {
    /// Present the Pro paywall; on completion the subscription gate is refreshed.
    func paywallSheet(isPresented: Binding<Bool>) -> some View {
        modifier(PaywallSheetModifier(isPresented: isPresented))
    }
}

// MARK: - Visible-but-locked Pro gate

/// Wraps Pro-only content. Subscribers see it normally. Free users see it
/// blurred and non-interactive, with an "Unlock with Pro" affordance that opens
/// the paywall. This is the "visible but locked" teaser: free users see that the
/// feature exists and looks valuable, but can't use it yet.
///
/// While `paidModeEnabled` is off, `appState.isPro` is always true, so this is
/// inert (renders content unchanged). It goes live when paid mode flips on.
struct ProLocked<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var blurRadius: CGFloat = 7
    @ViewBuilder var content: () -> Content

    @State private var showPaywall = false

    var body: some View {
        if appState.isPro {
            content()
        } else {
            content()
                .blur(radius: blurRadius)
                .disabled(true)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay(lockOverlay)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { showPaywall = true }
                .paywallSheet(isPresented: $showPaywall)
        }
    }

    private var lockOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill((colorScheme == .dark ? Color.black : Color.white).opacity(0.35))
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)
                Text("Unlock with Pro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppColors.accent))
            }
            .padding(16)
        }
    }
}
