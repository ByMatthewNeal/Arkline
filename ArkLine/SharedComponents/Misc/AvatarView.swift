import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let imageUrl: URL?
    let name: String
    var size: CGFloat = 40
    var showBorder: Bool = false
    var usePhoto: Bool = true
    @EnvironmentObject var appState: AppState

    private var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var fontSize: CGFloat {
        size * 0.4
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
        Group {
            if usePhoto, let url = imageUrl {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    showBorder ? AppColors.accent : Color.clear,
                    lineWidth: showBorder ? 2 : 0
                )
        )
    }

    private var placeholderView: some View {
        ZStack {
            avatarGradient

            Text(initials)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Convenience Initializers
extension AvatarView {
    /// Initialize with string URL
    init(urlString: String?, name: String, size: CGFloat = 40, showBorder: Bool = false, usePhoto: Bool = true) {
        self.imageUrl = urlString.flatMap { URL(string: $0) }
        self.name = name
        self.size = size
        self.showBorder = showBorder
        self.usePhoto = usePhoto
    }

    /// Initialize with User object - automatically respects user's avatar preference
    init(user: User, size: CGFloat = 40, showBorder: Bool = false) {
        self.imageUrl = user.avatarUrl.flatMap { URL(string: $0) }
        self.name = user.displayName
        self.size = size
        self.showBorder = showBorder
        self.usePhoto = user.usePhotoAvatar
    }
}

// MARK: - Legacy Support
extension AvatarView {
    /// Legacy initializer with string imageUrl and initials
    init(imageUrl: String?, initials: String, size: AvatarSizeEnum = .medium, showBorder: Bool = false) {
        self.imageUrl = imageUrl.flatMap { URL(string: $0) }
        self.name = initials
        self.size = size.dimension
        self.showBorder = showBorder
        self.usePhoto = true
    }
}

// MARK: - Avatar Size Enum (for legacy support)
enum AvatarSizeEnum {
    case xs
    case small
    case medium
    case large
    case xl
    case profile

    var dimension: CGFloat {
        switch self {
        case .xs: return 24
        case .small: return 32
        case .medium: return 40
        case .large: return 48
        case .xl: return 64
        case .profile: return 100
        }
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 16) {
        AvatarView(imageUrl: nil, name: "John Doe", size: 24)
        AvatarView(imageUrl: nil, name: "John Doe", size: 32)
        AvatarView(imageUrl: nil, name: "John Doe", size: 40)
        AvatarView(imageUrl: nil, name: "John Doe", size: 48)
        AvatarView(imageUrl: nil, name: "John Doe", size: 64, showBorder: true)
    }
    .padding()
    .background(AppColors.background(.dark))
    .environmentObject(AppState())
}
