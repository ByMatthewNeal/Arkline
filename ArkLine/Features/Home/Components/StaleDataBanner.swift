import SwiftUI

// MARK: - Stale Data Banner
struct StaleDataBanner: View {
    let failedCount: Int
    let lastRefreshed: Date?
    let onRetry: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var timeAgo: String {
        guard let date = lastRefreshed else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.warning)

            Text("Some data couldn't be updated")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))

            Spacer()

            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.warning.opacity(0.1))
        )
    }
}
