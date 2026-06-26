import SwiftUI

// MARK: - Broadcast Tab View

/// Main tab view that routes to either admin (BroadcastStudioView) or user (BroadcastFeedView)
/// based on the current user's role.
struct BroadcastTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showQA = false
    @State private var showVoiceStudio = false

    private var isAdmin: Bool { appState.currentUser?.isAdmin == true }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if isAdmin {
                    BroadcastStudioView()
                } else {
                    BroadcastFeedView()
                }
            }

            VStack(alignment: .trailing, spacing: ArkSpacing.md) {
                // Voice Studio — admin only. Capture thoughts → content in your voice.
                if isAdmin {
                    Button {
                        showVoiceStudio = true
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(AppColors.success))
                            .shadow(color: AppColors.success.opacity(0.4), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Voice Studio")
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
                .accessibilityLabel("Member Q&A")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 90)
        }
        .sheet(isPresented: $showQA) {
            MemberQAView().environmentObject(appState)
        }
        .sheet(isPresented: $showVoiceStudio) {
            VoiceStudioView().environmentObject(appState)
        }
    }
}

// MARK: - Preview

#Preview {
    BroadcastTabView()
        .environmentObject(AppState())
}
