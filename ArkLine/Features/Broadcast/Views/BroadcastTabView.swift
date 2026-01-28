import SwiftUI

// MARK: - Broadcast Tab View

/// Main tab view that routes to either admin (BroadcastStudioView) or user (BroadcastFeedView)
/// based on the current user's role.
struct BroadcastTabView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        // TODO: Restore admin check after debugging
        // For now, always show studio for testing
        BroadcastStudioView()
    }
}

// MARK: - Preview

#Preview {
    BroadcastTabView()
        .environmentObject(AppState())
}
