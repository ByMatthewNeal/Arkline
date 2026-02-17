import SwiftUI
import Kingfisher

// MARK: - Glass Header (Hedge Fund Style)
struct GlassHeader: View {
    let greeting: String
    let userName: String
    let avatarUrl: URL?
    @ObservedObject var appState: AppState
    var onCustomizeTap: (() -> Void)? = nil
    var onNotificationsTap: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var currentDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 16) {
            // Profile Avatar + Name → navigates to Profile
            NavigationLink(destination: ProfileView()) {
                HStack(spacing: 16) {
                    ProfessionalAvatar(imageUrl: avatarUrl, name: userName, size: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentDateFormatted.uppercased())
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(textPrimary.opacity(0.4))
                            .tracking(1.2)

                        Text(userName.isEmpty ? "Welcome" : userName)
                            .font(AppFonts.title24)
                            .foregroundColor(textPrimary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Action buttons - minimal, refined
            HStack(spacing: 8) {
                if let onCustomizeTap = onCustomizeTap {
                    HeaderIconButton(icon: "slider.horizontal.3", action: onCustomizeTap)
                }

                HeaderIconButton(icon: "bell", hasNotification: true, action: {
                    onNotificationsTap?()
                })
            }
        }
    }
}

// MARK: - Header Icon Button (Refined)
struct HeaderIconButton: View {
    let icon: String
    var hasNotification: Bool = false
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Subtle background
                Circle()
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.04))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .frame(width: 40, height: 40)

                // Notification indicator
                if hasNotification {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Professional Avatar (Hedge Fund Style)
struct ProfessionalAvatar: View {
    let imageUrl: URL?
    let name: String
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // Use the selected avatar color theme from AppState
    private var avatarGradient: LinearGradient {
        let colors = appState.avatarColorTheme.gradientColors
        return LinearGradient(
            colors: [colors.light, colors.dark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            if let url = imageUrl {
                // Image avatar
                KFImage(url)
                    .resizable()
                    .placeholder { initialsView }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Initials avatar with gradient
                initialsView
            }
        }
        // Subtle shadow for depth
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
    }

    private var initialsView: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(avatarGradient)
                .frame(width: size, height: size)

            // Subtle inner border
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: size, height: size)

            // Initials - using Inter Bold
            Text(String(name.prefix(1)).uppercased())
                .font(AppFonts.interFont(size: size * 0.38, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Legacy Notification Indicator (for compatibility)
struct NotificationIndicator: View {
    var hasNotification: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HeaderIconButton(icon: "bell", hasNotification: hasNotification, action: {})
    }
}
