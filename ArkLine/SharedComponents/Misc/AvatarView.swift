import SwiftUI

// MARK: - Avatar View
struct AvatarView: View {
    let imageUrl: URL?
    let name: String
    var size: CGFloat = 40
    var showBorder: Bool = false

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

    var body: some View {
        Group {
            if let url = imageUrl {
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
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.accentLight,
                    AppColors.accent
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Convenience Initializers
extension AvatarView {
    /// Initialize with string URL
    init(urlString: String?, name: String, size: CGFloat = 40, showBorder: Bool = false) {
        self.imageUrl = urlString.flatMap { URL(string: $0) }
        self.name = name
        self.size = size
        self.showBorder = showBorder
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
}
