import SwiftUI

// MARK: - Error Banner
struct ErrorBanner: View {
    @Environment(\.colorScheme) var colorScheme
    let error: AppError
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "An error occurred")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if error.isRecoverable {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.error.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Loading Overlay
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Text(title)
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(message)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}
