import SwiftUI

// MARK: - Broadcast Tab View

/// Main tab view that routes to either admin (BroadcastStudioView) or user (BroadcastFeedView)
/// based on the current user's role.
struct BroadcastTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showQA = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if appState.currentUser?.isAdmin == true {
                    BroadcastStudioView()
                } else {
                    BroadcastFeedView()
                }
            }

            // Member Q&A — available to everyone (admins also answer/dismiss/export here)
            Button {
                showQA = true
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AppColors.accent))
                    .shadow(color: AppColors.accent.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 90)
            .accessibilityLabel("Member Q&A")
        }
        .sheet(isPresented: $showQA) {
            MemberQAView().environmentObject(appState)
        }
    }
}

// MARK: - Preview

#Preview {
    BroadcastTabView()
        .environmentObject(AppState())
}
