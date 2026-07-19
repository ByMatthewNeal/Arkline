import SwiftUI

// MARK: - Resources ("Learn") Hub
//
// A single place members can learn Arkline at their own pace: how the app works,
// how to read the signals, macro/valuation/crypto basics, security, FAQ, and more.
// Content is server-driven markdown (see ResourceService) so it can be edited
// without an app release. Some rows deep-link into existing surfaces (Dictionary,
// referral) instead of showing their own article.

struct ResourcesView: View {
    /// Passed through so the referral link row can present the existing flow.
    var profileViewModel: ProfileViewModel

    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var articles: [ResourceArticle] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showDictionary = false
    @State private var showReferral = false
    @State private var showAdmin = false

    private var isAdmin: Bool { appState.currentUser?.isAdmin == true }

    private var sections: [(section: ResourceSection, items: [ResourceArticle])] {
        let grouped = Dictionary(grouping: articles) { $0.section }
        return ResourceSection.allCases
            .sorted { $0.order < $1.order }
            .compactMap { sec in
                guard let items = grouped[sec], !items.isEmpty else { return nil }
                return (sec, items.sorted { $0.sortOrder < $1.sortOrder })
            }
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isLoading {
                ProgressView()
            } else if articles.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sections, id: \.section) { group in
                        Section {
                            ForEach(group.items) { article in
                                row(for: article)
                            }
                        } header: {
                            Text(group.section.title)
                        }
                        .listRowBackground(AppColors.cardBackground(colorScheme))
                    }

                    Section {} footer: {
                        Spacer().frame(height: 40)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Resources")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAdmin = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Manage resources")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showDictionary) {
            NavigationStack { DictionaryView() }
        }
        .sheet(isPresented: $showReferral) {
            ReferFriendView(viewModel: profileViewModel)
        }
        .sheet(isPresented: $showAdmin, onDismiss: { Task { await load() } }) {
            ResourceAdminView()
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(for article: ResourceArticle) -> some View {
        if article.linkType == "dictionary" {
            Button { showDictionary = true } label: { rowLabel(article, chevron: true) }
                .buttonStyle(.plain)
        } else if article.linkType == "referral" {
            Button { showReferral = true } label: { rowLabel(article, chevron: true) }
                .buttonStyle(.plain)
        } else {
            NavigationLink { ResourceArticleView(article: article) } label: {
                rowLabel(article, chevron: false)
            }
        }
    }

    private func rowLabel(_ article: ResourceArticle, chevron: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: article.resolvedIcon)
                .font(.system(size: 18))
                .foregroundColor(AppColors.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }

            if chevron {
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: loadFailed ? "wifi.exclamationmark" : "books.vertical")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
            Text(loadFailed ? "Couldn't load resources" : "No resources yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            if loadFailed {
                Button("Retry") { Task { await load() } }
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.accent)
            }
        }
    }

    private func load() async {
        loadFailed = false
        do {
            articles = try await ResourceService.shared.fetchPublished()
        } catch {
            loadFailed = true
            logError("Failed to load resources: \(error)", category: .data)
        }
        isLoading = false
    }
}

// MARK: - Article Detail

struct ResourceArticleView: View {
    let article: ResourceArticle
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            MeshGradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = article.summary, !summary.isEmpty {
                        Text(summary)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    MarkdownContentView(content: article.body ?? "", headingColor: AppColors.accent)

                    Spacer(minLength: 60)
                }
                .padding(20)
            }
        }
        .navigationTitle(article.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
