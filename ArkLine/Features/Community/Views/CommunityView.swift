import SwiftUI

struct CommunityView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = CommunityViewModel()
    @State private var showCreatePost = false

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                MeshGradientBackground()

                // Brush effect overlay for dark mode
                if isDarkMode {
                    BrushEffectOverlay()
                }

                // Content
                VStack(spacing: 0) {
                // Tab Selector
                CommunityTabSelector(selectedTab: $viewModel.selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Content
                ScrollView {
                    switch viewModel.selectedTab {
                    case .feed:
                        FeedContent(viewModel: viewModel)
                    case .messages:
                        MessagesContent()
                    case .chat:
                        ChatRoomsContent(viewModel: viewModel)
                    }

                        Spacer(minLength: 100)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Community")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
        }
    }
}

// MARK: - Tab Selector
struct CommunityTabSelector: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedTab: CommunityTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CommunityTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(selectedTab == tab ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? AppColors.accent : Color.clear)
                        .cornerRadius(20)
                }
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 24)
    }
}

// MARK: - Feed Content
struct FeedContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: CommunityViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    CategoryFilterChip(title: "All", isSelected: viewModel.selectedCategory == nil) {
                        viewModel.selectCategory(nil)
                    }
                    ForEach(PostCategory.allCases, id: \.self) { category in
                        CategoryFilterChip(
                            title: category.displayName,
                            isSelected: viewModel.selectedCategory == category,
                            icon: category.icon
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Posts
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredPosts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCard(post: post, onLike: {
                            if post.isLikedByCurrentUser == true {
                                viewModel.unlikePost(post)
                            } else {
                                viewModel.likePost(post)
                            }
                        })
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
}

// MARK: - Messages Content
struct MessagesContent: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundColor(AppColors.textSecondary)

            Text("No Messages Yet")
                .font(AppFonts.title20)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Start a conversation with other traders")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Chat Rooms Content
struct ChatRoomsContent: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: CommunityViewModel

    var body: some View {
        VStack(spacing: 16) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.chatRooms) { room in
                    NavigationLink(destination: ChatRoomDetailView(room: room)) {
                        ChatRoomCard(room: room)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(AppFonts.caption12Medium)
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.accent : AppColors.cardBackground(colorScheme))
            .cornerRadius(20)
        }
    }
}

// MARK: - Post Card
struct PostCard: View {
    @Environment(\.colorScheme) var colorScheme
    let post: CommunityPost
    let onLike: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author & Date
            HStack(spacing: 10) {
                AvatarView(
                    imageUrl: post.author?.avatarUrl != nil ? URL(string: post.author!.avatarUrl!) : nil,
                    name: post.author?.username ?? "User",
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author?.username ?? "Anonymous")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(post.formattedDate)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let category = post.category {
                    Text(category.displayName)
                        .font(AppFonts.footnote10Bold)
                        .foregroundColor(Color(hex: category.color))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: category.color).opacity(0.15))
                        .cornerRadius(8)
                }
            }

            // Title
            Text(post.title)
                .font(AppFonts.title16)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(2)

            // Content Preview
            Text(post.contentPreview)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)

            // Actions
            HStack(spacing: 20) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLikedByCurrentUser == true ? "heart.fill" : "heart")
                            .foregroundColor(post.isLikedByCurrentUser == true ? AppColors.error : AppColors.textSecondary)
                        Text("\(post.likesCount)")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(post.commentsCount)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                ShareLink(item: "\(post.title)\n\(post.contentPreview)") {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Chat Room Card
struct ChatRoomCard: View {
    @Environment(\.colorScheme) var colorScheme
    let room: ChatRoom

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(room.isPremium ? AppColors.warning.opacity(0.15) : AppColors.accent.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: room.isPremium ? "star.fill" : "bubble.left.and.bubble.right")
                    .font(.system(size: 20))
                    .foregroundColor(room.isPremium ? AppColors.warning : AppColors.accent)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(room.name)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if room.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.warning)
                    }
                }

                if let description = room.description {
                    Text(description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Placeholder Views
struct CreatePostView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack {
                Text("Create Post")
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("New Post")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }
}

struct PostDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let post: CommunityPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title)
                    .font(AppFonts.title24)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(post.content)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(20)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Post")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ChatRoomDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let room: ChatRoom

    var body: some View {
        VStack {
            Text(room.name)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(colorScheme))
        .navigationTitle(room.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    CommunityView()
        .environmentObject(AppState())
}
