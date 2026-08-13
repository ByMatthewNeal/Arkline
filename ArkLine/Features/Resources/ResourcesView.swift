import SwiftUI
import Foundation
import Charts

// MARK: - Resources ("Learn") Hub
//
// A single place members can learn Arkline at their own pace: how the app works,
// how to read the signals, macro/valuation/crypto basics, security, FAQ, and more.
// Content is server-driven markdown (see ResourceService) so it can be edited
// without an app release. Some rows deep-link into existing surfaces (Dictionary,
// referral) instead of showing their own article.

struct ResourcesView: View {
    /// Passed through so the referral link row can present the existing flow.
    /// Optional, the Learn tab opens Resources without a profile context.
    var profileViewModel: ProfileViewModel? = nil

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
                    // Start Here, the guided foundations trail, front and center.
                    Section {
                        NavigationLink { StartHereTrailView() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "signpost.right.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Here")
                                        .font(AppFonts.body14Medium)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))
                                    Text("New to investing? A calm, self-paced path through the basics.")
                                        .font(AppFonts.caption12)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .listRowBackground(AppColors.cardBackground(colorScheme))

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
            if let vm = profileViewModel {
                ReferFriendView(viewModel: vm)
            }
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
            if profileViewModel != nil {
                Button { showReferral = true } label: { rowLabel(article, chevron: true) }
                    .buttonStyle(.plain)
            }
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

// MARK: - Start Here, Foundations Trail
//
// The first guided "yellow brick road": a calm, self-paced, sequential path of
// short lessons that take a total beginner from "I'm new to this" to "I get the
// basics." Copy finalized in docs/START_HERE_TRAIL_DRAFT.md and hardcoded here for
// v1 (structured to move server-side later, like Resources). Progress is stored
// per person locally; no streaks or badges, calm progress only.

/// Where a lesson or checklist step's callout takes the user.
/// Raw values match the `deep_link` column in the `trail_lessons` table.
enum LessonDeepLink: String, CaseIterable {
    case home, customizeHome, cryptoRisk, stockRisk, signalChanges, fearGreed, dca, settings, learn, market, macro, portfolio
    // Specific hedging assets — open that asset's positioning detail directly.
    case gold, silver, oil
}

extension AppState {
    /// Central navigation for Foundations-trail and Pilot's-checklist deep-links.
    func navigate(to link: LessonDeepLink) {
        switch link {
        case .home:
            selectedTab = .home
        case .customizeHome:
            selectedTab = .home
            pendingOpenCustomizeHome = true
        case .cryptoRisk:
            if !isWidgetEnabled(.assetRiskLevel) { toggleWidget(.assetRiskLevel) }
            selectedTab = .home
            pendingHomeScrollTarget = "widget_assetRiskLevel"
        case .stockRisk:
            if !isWidgetEnabled(.stockRiskLevel) { toggleWidget(.stockRiskLevel) }
            selectedTab = .home
            pendingHomeScrollTarget = "widget_stockRiskLevel"
        case .signalChanges:
            if !isWidgetEnabled(.qpsSignals) { toggleWidget(.qpsSignals) }
            selectedTab = .home
            pendingQPSAsset = "scroll"
        case .fearGreed:
            // Make sure the widget is visible so the scroll target exists.
            if !isWidgetEnabled(.fearGreedIndex) { toggleWidget(.fearGreedIndex) }
            selectedTab = .home
            pendingHomeScrollTarget = "widget_fearGreed"
        case .dca:
            selectedTab = .profile
            pendingDCAReminderId = "open"
        case .settings:
            selectedTab = .profile
            pendingOpenNotificationSettings = true
        case .learn:
            selectedTab = .insights
        case .market:
            selectedTab = .market
        case .macro:
            if !isWidgetEnabled(.macroDashboard) { toggleWidget(.macroDashboard) }
            selectedTab = .home
            pendingHomeScrollTarget = "widget_macroDashboard"
        case .portfolio:
            selectedTab = .portfolio
        case .gold:
            selectedTab = .market
            pendingMarketAssetDetail = "GOLD"
        case .silver:
            selectedTab = .market
            pendingMarketAssetDetail = "SILVER"
        case .oil:
            selectedTab = .market
            pendingMarketAssetDetail = "OIL"
        }
    }
}

struct TrailLesson: Codable, Identifiable {
    var id: UUID = UUID()
    let trailKey: String
    let position: Int          // 1-based order; stable key for progress
    let title: String
    let idea: String
    let seeInApp: String?
    let mindsetCheck: String?
    let takeaway: String
    let oneMoreThing: String?
    let preview: String
    let deepLinkRaw: String?
    var isPublished: Bool = true
    /// Optional named built-in visual rendered in the reader (e.g. "sample_allocation").
    var illustration: String? = nil

    var deepLink: LessonDeepLink? { deepLinkRaw.flatMap(LessonDeepLink.init(rawValue:)) }

    enum CodingKeys: String, CodingKey {
        case id, title, idea, takeaway, preview, position, illustration
        case trailKey = "trail_key"
        case seeInApp = "see_in_app"
        case mindsetCheck = "mindset_check"
        case oneMoreThing = "one_more_thing"
        case deepLinkRaw = "deep_link"
        case isPublished = "is_published"
    }
}

// MARK: - Trail kinds + metadata

/// Difficulty tier for a trail, so people know what they're walking into.
/// Same three tiers as the glossary difficulty field, for consistency.
enum TrailDifficulty {
    case beginner, intermediate, advanced

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    var color: Color {
        switch self {
        case .beginner: return AppColors.success
        case .intermediate: return AppColors.accent
        case .advanced: return Color(hex: "F97316")   // warm orange
        }
    }
}

enum TrailKind: String, CaseIterable {
    case foundations
    case behavioral
    case scams
    case crypto
    case markets
    case trading
    case macro
    case hedging
    case fees
    case sizing
    case beforeInvesting

    var navTitle: String {
        switch self {
        case .beforeInvesting: return "Before You Invest"
        case .foundations: return "Start Here"
        case .behavioral: return "Your Brain vs Your Money"
        case .scams: return "Spotting Scams"
        case .crypto: return "Understanding Crypto"
        case .markets: return "Understanding the Markets"
        case .trading: return "Trading vs Investing"
        case .macro: return "Understanding Macro"
        case .hedging: return "Understanding Hedges"
        case .fees: return "Fees & Taxes"
        case .sizing: return "How Much to Own"
        }
    }
    var eyebrow: String {
        switch self {
        case .beforeInvesting: return "BEFORE YOU INVEST"
        case .foundations: return "FOUNDATIONS"
        case .behavioral: return "YOUR BRAIN VS YOUR MONEY"
        case .scams: return "SPOTTING SCAMS"
        case .crypto: return "UNDERSTANDING CRYPTO"
        case .markets: return "UNDERSTANDING THE MARKETS"
        case .trading: return "TRADING VS INVESTING"
        case .macro: return "UNDERSTANDING MACRO"
        case .hedging: return "UNDERSTANDING HEDGES"
        case .fees: return "FEES & TAXES"
        case .sizing: return "HOW MUCH TO OWN"
        }
    }
    var intro: String {
        switch self {
        case .beforeInvesting:
            return "The groundwork that comes before buying anything: an emergency fund, clearing expensive debt, and only investing money you won't need soon or can't afford to lose. Boring, essential, and what makes calm investing possible."
        case .foundations:
            return "A calm, self-paced path from “I'm new to this” to “I get the basics.” Go at your own pace. There's no test."
        case .behavioral:
            return "The mental traps that make people buy high and sell low, and how to build systems that keep those instincts from driving. The master-yourself lesson in full."
        case .scams:
            return "A few steady habits that close the door on the overwhelming majority of scams, without living in fear. Practical safety, not paranoia."
        case .crypto:
            return "The next step after the basics: what crypto is, why it moves the way it does, and how to hold it calmly and safely. No hype, no picks."
        case .markets:
            return "The calm approach applied to stocks and indexes: what they are, what moves them, and how to hold them for the long run. No hype, no picks."
        case .trading:
            return "Two words people use as if they mean the same thing, but they're worlds apart. What investing and trading each are, the very different risks of both, and how to know which one you're doing. Honest, never a push."
        case .macro:
            return "The big forces that move everything at once: the Fed, interest rates, inflation, and the economic cycle. In plain English, and as calm context rather than a reason to react."
        case .hedging:
            return "The advanced step: safe havens and commodities like gold, silver, and oil. What they are, how they behave, and the honest truth that hedges can fail. Descriptive, never advice."
        case .fees:
            return "The unglamorous half of investing, and the one most people ignore: what you pay in fees, spreads, and taxes, and the calm habits that keep more of your returns yours. Practical, never tax advice."
        case .sizing:
            return "The quiet half of investing that decides how bumpy your ride is: not what you own, but how much of each. Position sizing, cash cushions, and core-and-satellite, with Arkline's model portfolios as worked examples. Descriptive, never advice."
        }
    }
    var seed: [TrailLesson] {
        switch self {
        case .beforeInvesting: return TrailSeed.beforeInvesting
        case .foundations: return TrailSeed.foundations
        case .behavioral: return TrailSeed.behavioral
        case .scams: return TrailSeed.scams
        case .crypto: return TrailSeed.crypto
        case .markets: return TrailSeed.markets
        case .trading: return TrailSeed.trading
        case .macro: return TrailSeed.macro
        case .hedging: return TrailSeed.hedging
        case .fees: return TrailSeed.fees
        case .sizing: return TrailSeed.sizing
        }
    }
    var difficulty: TrailDifficulty {
        switch self {
        case .beforeInvesting: return .beginner
        case .foundations: return .beginner
        case .behavioral: return .intermediate
        case .scams: return .beginner
        case .crypto: return .intermediate
        case .markets: return .intermediate
        case .trading: return .intermediate
        case .macro: return .intermediate
        case .hedging: return .advanced
        case .fees: return .intermediate
        case .sizing: return .intermediate
        }
    }
}

// MARK: - Per-trail progress (position-based, survives content edits)

enum TrailProgress {
    static func key(_ trailKey: String) -> String {
        // Preserve existing Foundations progress under its original key.
        trailKey == "foundations" ? "start_here_completed_v1" : "trail_completed_\(trailKey)_v1"
    }
    static func completed(_ trailKey: String) -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key(trailKey)) as? [Int] ?? [])
    }
    static func markComplete(_ trailKey: String, _ position: Int) {
        var s = completed(trailKey)
        s.insert(position)
        UserDefaults.standard.set(Array(s).sorted(), forKey: key(trailKey))
        NotificationCenter.default.post(name: .trailProgressChanged, object: nil)
    }
    static func firstIncompleteIndex(_ lessons: [TrailLesson], _ trailKey: String) -> Int {
        let done = completed(trailKey)
        return lessons.firstIndex(where: { !done.contains($0.position) }) ?? 0
    }
}

extension Notification.Name {
    /// Fired when a lesson is marked complete, so progress surfaces can refresh.
    static let trailProgressChanged = Notification.Name("trailProgressChanged")
}

// MARK: - Curriculum (the guided path across all trails)

/// A single ordered spine through the trails so the app can guide a user
/// step-by-step ("what's next?") and show overall progress, instead of leaving
/// them to browse a flat library. Pure logic over the progress already stored
/// per trail in `TrailProgress`.
enum Curriculum {
    /// Canonical order a newcomer should move through. Not a hard gate — users
    /// can still open any trail directly — but it's what "Continue" follows.
    static let path: [TrailKind] = [
        .beforeInvesting, .foundations, .behavioral, .scams,
        .crypto, .markets, .hedging, .trading, .macro, .fees, .sizing,
    ]

    enum TrailStatus: Equatable {
        case notStarted
        case inProgress(done: Int, total: Int)
        case complete
    }

    static func status(for kind: TrailKind) -> TrailStatus {
        let total = kind.seed.count
        let done = min(TrailProgress.completed(kind.rawValue).count, total)
        if done == 0 { return .notStarted }
        if done >= total { return .complete }
        return .inProgress(done: done, total: total)
    }

    /// The first not-yet-complete lesson in path order — the "up next" target.
    static func nextLesson() -> (kind: TrailKind, position: Int, title: String)? {
        for kind in path {
            let done = TrailProgress.completed(kind.rawValue)
            if let lesson = kind.seed.first(where: { !done.contains($0.position) }) {
                return (kind, lesson.position, lesson.title)
            }
        }
        return nil
    }

    /// Completed vs total lessons across the whole path.
    static func overall() -> (done: Int, total: Int) {
        var done = 0, total = 0
        for kind in path {
            let t = kind.seed.count
            total += t
            done += min(TrailProgress.completed(kind.rawValue).count, t)
        }
        return (done, total)
    }
}

// MARK: - DB service (content lives in Supabase `trail_lessons`)

final class TrailLessonService {
    static let shared = TrailLessonService()
    private init() {}
    private var db: SupabaseManager { SupabaseManager.shared }

    /// Published lessons for a trail, ordered. Members read these.
    func fetchPublished(trailKey: String) async throws -> [TrailLesson] {
        try await db.database
            .from(SupabaseTable.trailLessons.rawValue)
            .select()
            .eq("trail_key", value: trailKey)
            .eq("is_published", value: true)
            .order("position", ascending: true)
            .execute()
            .value
    }

    /// Every row for a trail (including unpublished), for the admin editor.
    func fetchAll(trailKey: String) async throws -> [TrailLesson] {
        try await db.database
            .from(SupabaseTable.trailLessons.rawValue)
            .select()
            .eq("trail_key", value: trailKey)
            .order("position", ascending: true)
            .execute()
            .value
    }

    /// Admin: create or update a lesson, keyed by (trail_key, position).
    func upsert(_ payload: TrailLessonUpsert) async throws {
        try await db.database
            .from(SupabaseTable.trailLessons.rawValue)
            .upsert(payload, onConflict: "trail_key,position")
            .execute()
    }
}

/// Admin write payload. Explicit encoding so cleared fields become JSON null
/// instead of being omitted (PostgREST treats a missing column as "unchanged").
struct TrailLessonUpsert: Encodable {
    let trailKey: String
    let position: Int
    let title: String
    let idea: String
    let seeInApp: String?
    let mindsetCheck: String?
    let takeaway: String
    let oneMoreThing: String?
    let preview: String
    let deepLink: String?
    let isPublished: Bool

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(trailKey, forKey: .trailKey)
        try c.encode(position, forKey: .position)
        try c.encode(title, forKey: .title)
        try c.encode(idea, forKey: .idea)
        try c.encode(seeInApp, forKey: .seeInApp)
        try c.encode(mindsetCheck, forKey: .mindsetCheck)
        try c.encode(takeaway, forKey: .takeaway)
        try c.encode(oneMoreThing, forKey: .oneMoreThing)
        try c.encode(preview, forKey: .preview)
        try c.encode(deepLink, forKey: .deepLink)
        try c.encode(isPublished, forKey: .isPublished)
    }
    enum CodingKeys: String, CodingKey {
        case trailKey = "trail_key"
        case position, title, idea, takeaway, preview
        case seeInApp = "see_in_app"
        case mindsetCheck = "mindset_check"
        case oneMoreThing = "one_more_thing"
        case deepLink = "deep_link"
        case isPublished = "is_published"
    }
}

// MARK: - Content loader (DB rows merged over the built-in seed by position)

enum TrailContent {
    static func load(_ kind: TrailKind) async -> [TrailLesson] {
        let seed = kind.seed
        guard let rows = try? await TrailLessonService.shared.fetchPublished(trailKey: kind.rawValue),
              !rows.isEmpty else { return seed }
        let byPos = Dictionary(rows.map { ($0.position, $0) }, uniquingKeysWith: { a, _ in a })
        return seed.map { byPos[$0.position] ?? $0 }
    }
}

enum TrailSeed {
    static let foundations: [TrailLesson] = [
        TrailLesson(
            trailKey: "foundations", position: 1,
            title: "Start here: you don't need to know it all",
            idea: "Welcome. Here's the first thing to relax about: you do not need to understand everything to begin. Arkline is built to teach you as you go. Almost every number and term can explain itself, in plain English, right where you see it, so you're never stuck, and you never have to feel dumb for not knowing something yet. There's no test here and no rush. Go at your own pace.",
            seeInApp: "Anywhere you spot a small “?” next to something, tap it, and you'll get a plain-English explanation of what it means (and what it doesn't). The Insights area is your home base whenever you want to come back.",
            mindsetCheck: nil,
            takeaway: "You don't have to know it all. The app teaches you as you go.",
            oneMoreThing: nil,
            preview: "The app teaches you as you go",
            deepLinkRaw: "home"
        ),
        TrailLesson(
            trailKey: "foundations", position: 2,
            title: "Master yourself, not the market",
            idea: "Here's the secret almost nobody tells beginners: the hardest part of investing isn't the market, it's you. Most people don't lose because they picked the wrong thing. They lose because they got excited and bought high, then got scared and sold low. You can't control what the market does. But you can control three things: how long you're willing to wait, how much you put at risk, and how you react when prices swing. And prices will swing. Big ups and downs (volatility) are completely normal, the price of admission, not an emergency. Get those three things right and you're already ahead of most people.",
            seeInApp: "This is exactly why Arkline is built calm: no flashing alarms, no countdowns, no noise. The tools here exist to help you think, not to make you react.",
            mindsetCheck: nil,
            takeaway: "The market, you can't control. Yourself, you can. That's where the edge is.",
            oneMoreThing: nil,
            preview: "The real edge is managing you",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "foundations", position: 3,
            title: "What “risk” actually means",
            idea: "“Risk” sounds scary, but here it means something specific and useful: how expensive or cheap a price is compared to its own history. A high risk level doesn't mean “danger, sell.” It means the price has run up a lot and there's less cushion if things turn. A low level means it's historically cheap. It measures how far the price has travelled, not a prediction of what happens next.",
            seeInApp: "Open the Crypto Risk Levels (or Stock Risk Levels) widget and tap the “?”. You'll see it in plain English: Cheap, Fair, Elevated, Overheated, and what each one means for you.",
            mindsetCheck: nil,
            takeaway: "Risk = how expensive or cheap the price is, not “danger.” It informs your decision; it doesn't make it for you.",
            oneMoreThing: nil,
            preview: "Expensive vs cheap, not danger",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "foundations", position: 4,
            title: "Why nobody can time the market",
            idea: "Everyone wishes they could buy the exact bottom and sell the exact top. Here's the freeing truth: nobody does that consistently, not the pros, not the algorithms. Short-term moves are basically unpredictable. Chasing perfect timing is how people get whipsawed: buying in excitement, selling in fear. The good news is you don't need to nail the timing. A steady approach and a little patience beat prediction almost every time.",
            seeInApp: "Remember the risk guardrail: “expensive can stay expensive, and cheap can get cheaper.” That's the market's way of reminding you it doesn't move on your schedule.",
            mindsetCheck: "This is where Lesson 2 earns its keep. Letting go of “perfect” is what keeps you calm while everyone else is panicking or chasing.",
            takeaway: "You can't time the market, and you don't need to. Patience beats prediction.",
            oneMoreThing: nil,
            preview: "Patience beats prediction",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "foundations", position: 5,
            title: "The calm way in: a little at a time",
            idea: "So if you can't time the market, what do you do? You spread it out. Dollar-cost averaging (DCA) just means putting in a set amount on a regular schedule (a little each week or month) instead of trying to pick the perfect moment. When prices are low, your money buys more; when they're high, it buys less; over time it smooths out the bumps. Best of all, it takes the agonizing “is now the right time?” question off the table entirely.",
            seeInApp: "Set up a DCA Reminder for something you care about, and the app will nudge you on your schedule, so “steady” becomes a habit instead of a willpower battle.",
            mindsetCheck: "DCA is mindset made mechanical: it quietly removes emotion from the decision, so fear and greed don't get a vote.",
            takeaway: "Invest a little, regularly. It beats guessing the perfect moment, and it keeps you calm.",
            oneMoreThing: nil,
            preview: "DCA makes steady a habit",
            deepLinkRaw: "dca"
        ),
        TrailLesson(
            trailKey: "foundations", position: 6,
            title: "Reading the market's mood",
            idea: "Markets have moods, and they swing between fear and greed. When everyone's terrified, prices are often beaten down; when everyone's euphoric, things tend to get overheated. The Fear & Greed reading is a simple gauge of that crowd emotion. It's most useful as a mirror, a reminder that when the crowd is at an extreme, it's worth pausing to think rather than getting swept along with it.",
            seeInApp: "Open the Fear & Greed widget and tap the “?” for what extreme fear and extreme greed each tend to mean.",
            mindsetCheck: "This ties straight back to mastering yourself: the crowd's mood is exactly the emotion you don't want making your decisions for you.",
            takeaway: "The crowd swings between fear and greed. Notice it, don't get swept up in it.",
            oneMoreThing: nil,
            preview: "Notice the crowd, don't join it",
            deepLinkRaw: "fearGreed"
        ),
        TrailLesson(
            trailKey: "foundations", position: 7,
            title: "Which way the wind's blowing",
            idea: "The last piece is trend and momentum, which way an asset has been moving lately. Arkline boils it down to one word: Bullish (pointing up), Neutral (mixed or sideways), or Bearish (pointing down). Think of it as which way the wind is blowing, at the asset's back or in its face. It's context about the current backdrop, not a command to do anything.",
            seeInApp: "Open Signal Changes and tap the “?” to see what Bullish, Neutral, and Bearish each mean, and just as importantly, what they don't (they're never “buy” or “sell”).",
            mindsetCheck: nil,
            takeaway: "Trend tells you the current backdrop: context for your own thinking, never a command.",
            oneMoreThing: nil,
            preview: "Trend is context, not a command",
            deepLinkRaw: "signalChanges"
        ),
        TrailLesson(
            trailKey: "foundations", position: 8,
            title: "You've got the foundations",
            idea: "That's it. You've got the foundation. You know what risk really means, why timing is a trap, how DCA keeps you steady, how to read the market's mood, and how to read a trend. And most importantly, you know the real work is managing yourself. Here's a simple, calm routine to carry forward: check in about once a week, not every hour. Glance at your risk levels and the market's mood, notice anything that changed, and then get on with your life. Investing well is mostly patient and a little boring, and that's exactly how it should feel.",
            seeInApp: "Everything you just learned lives on your Home screen, and the “?” is always right there whenever you want a refresher.",
            mindsetCheck: nil,
            takeaway: "You've got the basics. Keep it calm, keep it steady, and let time do the work.",
            oneMoreThing: "When you're ready to go deeper, there's a trail just for crypto, but this foundation carries you a long way.",
            preview: "Keep it calm, let time work",
            deepLinkRaw: "home"
        ),
    ]

    static let crypto: [TrailLesson] = [
        TrailLesson(
            trailKey: "crypto", position: 1,
            title: "What crypto actually is",
            idea: "Strip away the noise and crypto is simpler than it sounds. A cryptocurrency is a digital asset that lives on a blockchain, which is just a shared record book that thousands of computers keep in sync, with no single company or bank in charge. Bitcoin was the first. That “no one in charge” design is what makes crypto powerful, and also what makes it move fast and swing hard. You do not need to understand the engineering to invest sensibly, any more than you need to build an engine to drive.",
            seeInApp: "Open any coin in Arkline and tap the “?” next to its risk level. Everything you learned in Foundations about price and risk works here too.",
            mindsetCheck: nil,
            takeaway: "Crypto is a new kind of asset on a shared, open ledger. New, not magic, and not a scam.",
            oneMoreThing: nil,
            preview: "A new asset on an open ledger",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "crypto", position: 2,
            title: "Bitcoin, and everything else",
            idea: "It helps to picture crypto in tiers. Bitcoin sits on its own as the oldest, largest, and most established. Then there is a small group of large, well-known coins. Then thousands of smaller ones, often called altcoins. As you move down that list, the projects get younger, smaller, and far more volatile. A tiny coin can rise fast and fall just as fast. Knowing where a coin sits in that picture tells you a lot about how bumpy the ride is likely to be.",
            seeInApp: "The risk levels and signals in Arkline focus on established coins for a reason: they have enough history to read. The smaller and newer a coin, the less its numbers can tell you.",
            mindsetCheck: nil,
            takeaway: "The smaller and newer the coin, the wilder the ride. Size and history are a kind of seatbelt.",
            oneMoreThing: nil,
            preview: "Smaller coin, wilder ride",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "crypto", position: 3,
            title: "Volatility is the price of admission",
            idea: "Crypto swings harder than almost anything else you can own. Drops of twenty or thirty percent happen, and they are normal here, not a sign the sky is falling. The reason ties back to lesson 1: no central authority, a young market, and a lot of emotion. None of that is a flaw to fear. It is simply the price of admission for an asset that can also move up sharply. The people who do well are rarely the ones who react fastest. They are the ones who expected the swings and did not panic.",
            seeInApp: nil,
            mindsetCheck: "This is Foundations lesson 2 in its hardest test. You cannot control the swings. You can control whether they control you.",
            takeaway: "Big swings are the entry fee, not an emergency. Expect them, and they lose their power over you.",
            oneMoreThing: nil,
            preview: "Big swings are the entry fee",
            deepLinkRaw: "fearGreed",
            illustration: "risk_spectrum"
        ),
        TrailLesson(
            trailKey: "crypto", position: 4,
            title: "Crypto moves in cycles",
            idea: "Crypto has a rhythm. It tends to move in long cycles of building up, running hot, cooling off, and quietly rebuilding, over months and years. You will hear people tie this to Bitcoin's “halving,” an event roughly every four years that slows the creation of new coins. Treat the cycle as a season, not a schedule. Nobody can tell you the exact top or bottom, and the same guardrail from Foundations holds here: expensive can stay expensive, and cheap can get cheaper. Knowing the cycle exists just helps you stay calm when the mood is at an extreme.",
            seeInApp: "Crypto risk levels are built to show you where a coin sits against its own history, which is one honest way to feel where you might be in a cycle.",
            mindsetCheck: nil,
            takeaway: "Crypto runs hot and cold in long cycles. Notice the season, but don't try to time it.",
            oneMoreThing: nil,
            preview: "Notice the season, don't time it",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "crypto", position: 5,
            title: "Owning it safely",
            idea: "This is the one lesson where crypto asks more of you than a normal investment, and it is worth getting right. When you hold crypto, security is partly your job. A few plain rules cover most of it. Buy and hold on a reputable, regulated exchange (well-known US names include Coinbase, Kraken, and Gemini). For more control, or for larger amounts, a dedicated wallet keeps your coins in your own hands, and a hardware wallet that stores your keys offline is the gold standard (Ledger and Trezor are the established makers). Turn on two-factor authentication everywhere. Never share your recovery phrase or private keys with anyone, ever, because whoever holds those controls the coins. And treat any message promising guaranteed returns, or any stranger offering to “help,” as a scam, because it almost always is.",
            seeInApp: "Arkline never asks for your keys or recovery phrase, and no legitimate app or person ever will. If something does, that is your signal to walk away.",
            mindsetCheck: nil,
            takeaway: "In crypto, safety is part of the job. Guard your keys, doubt free money, and you have avoided most of the danger.",
            oneMoreThing: "If this feels like a lot, start small on a trusted platform. You can learn the safety habits with a little before you ever hold a lot.",
            preview: "Guard your keys, doubt free money",
            deepLinkRaw: "home"
        ),
        TrailLesson(
            trailKey: "crypto", position: 6,
            title: "Stablecoins and staying in cash",
            idea: "Not every crypto is trying to go up. A stablecoin is designed to hold a steady value, usually pegged to the US dollar, so one coin stays worth about one dollar. Think of it as a place to sit calmly between decisions, the crypto version of cash on the sidelines. It is genuinely useful for stepping back when you are unsure. Two gentle cautions: not all stablecoins are equally trustworthy, so stick to the well-known ones, and a stablecoin sitting still is not meant to earn you a fortune. Anything promising a big, guaranteed yield on “stable” money deserves deep suspicion.",
            seeInApp: "When the mood is euphoric or fearful, remember you always have the option to simply wait. Doing nothing is a position too.",
            mindsetCheck: nil,
            takeaway: "Stablecoins are the calm corner of crypto. Useful for waiting, not for chasing yield.",
            oneMoreThing: nil,
            preview: "The calm corner of crypto",
            deepLinkRaw: "fearGreed"
        ),
        TrailLesson(
            trailKey: "crypto", position: 7,
            title: "Another way in: crypto ETFs",
            idea: "Owning crypto directly means an exchange, a wallet, and guarding your keys. There's now a simpler on-ramp for some coins: crypto ETFs (exchange-traded funds), which trade like a normal stock and track the price of an asset like Bitcoin. Buy one in an ordinary brokerage account and you get exposure to the price without managing wallets or keys, the security of a familiar account instead of self-custody. The tradeoff is that you don't hold the actual coins, and there are fees. But for many people it's a calmer, more familiar way in, and it's worth knowing both paths exist so you can pick the one that fits you.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Crypto ETFs track Bitcoin's price from a normal brokerage account, no wallet or keys, in exchange for fees and not holding the coins yourself.",
            oneMoreThing: nil,
            preview: "Bitcoin without the wallet",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "crypto", position: 8,
            title: "Reading crypto in Arkline",
            idea: "You now have the concepts, so here is how they show up in the app. Risk levels tell you how expensive or cheap a coin is against its own history. Signal changes tell you which way the trend and momentum are leaning today. Fear and Greed reads the crowd's mood. None of these is a command, and none predicts the future. Together they are a calm dashboard, context for your own thinking, so you are never flying blind and never being told what to do.",
            seeInApp: "Open Signal Changes and tap the “?” to see exactly what Bullish, Neutral, and Bearish mean, and just as importantly what they do not.",
            mindsetCheck: nil,
            takeaway: "Arkline gives you context, not commands. The decision always stays yours.",
            oneMoreThing: nil,
            preview: "Context, not commands",
            deepLinkRaw: "signalChanges"
        ),
        TrailLesson(
            trailKey: "crypto", position: 9,
            title: "Putting it together calmly",
            idea: "That is the crypto foundation. You know what it is, why it swings, how its cycles breathe, how to hold it safely, and how to read the app. Here is a calm way to carry it forward. Decide how much of your money you are comfortable putting into something this volatile, and keep it a size that lets you sleep. Lean on DCA so you are not trying to time the swings. Check in a few times a week, not every hour. And when the noise gets loud in either direction, come back to lesson 3: the swings are the price of admission, and staying steady is the whole skill.",
            seeInApp: "Set a DCA reminder for a coin you believe in, and let the app turn “steady” into a habit instead of a willpower battle.",
            mindsetCheck: nil,
            takeaway: "Understand it, size it so you can sleep, DCA in, and let the cycles do the work.",
            oneMoreThing: "When you are ready, there is a trail for traditional markets too, so the calm approach carries across everything you own.",
            preview: "Size it so you can sleep",
            deepLinkRaw: "dca"
        ),
    ]

    static let markets: [TrailLesson] = [
        TrailLesson(
            trailKey: "markets", position: 1,
            title: "What a stock actually is",
            idea: "A stock is a small piece of ownership in a real company. Buy a share and you own a sliver of that business, its products, its profits, its future. The price moves as people's views of the company's prospects change, minute to minute. Over the long run a stock tends to follow how the business actually does; in the short run it can swing on mood and headlines. You don't need to read a balance sheet to invest sensibly, but knowing a share is a piece of a business, not a lottery ticket, changes how you hold it.",
            seeInApp: "Open a stock's risk level in Arkline and tap the “?”. The same idea of expensive versus cheap from Foundations applies to stocks too.",
            mindsetCheck: nil,
            takeaway: "A stock is a piece of a real business, not a lottery ticket. Over time it follows the business.",
            oneMoreThing: nil,
            preview: "A share is a piece of a business",
            deepLinkRaw: "stockRisk"
        ),
        TrailLesson(
            trailKey: "markets", position: 2,
            title: "The index, and the whole market",
            idea: "You'll hear names like the S&P 500, the Nasdaq, and the Dow. These are indexes: simple baskets that track hundreds of companies at once, so you can see how “the market” is doing rather than one stock. They matter because the calmest way for most people to invest in stocks is to buy the whole basket through an index fund, rather than trying to pick winners. Owning the index means owning a little of everything, which spreads your risk automatically.",
            seeInApp: "Arkline tracks the major indexes so you can read the whole market's mood at a glance.",
            mindsetCheck: nil,
            takeaway: "An index is the whole market in one basket. Owning it spreads your risk without the guesswork.",
            oneMoreThing: nil,
            preview: "The whole market in one basket",
            deepLinkRaw: "market"
        ),
        TrailLesson(
            trailKey: "markets", position: 3,
            title: "Stocks swing too, just more gently",
            idea: "Stocks are calmer than crypto, but they are not a straight line up. Drops of ten percent (a “correction”) happen regularly, and bigger falls happen every so often. This is normal, the price you pay for the long-term growth stocks have historically delivered. The mistake most people make is selling in a scary moment and missing the recovery that tends to follow. Expecting the dips is what lets you sit through them.",
            seeInApp: nil,
            mindsetCheck: "Foundations lesson 2 again: you can't stop the dips, but you can decide not to panic-sell into them.",
            takeaway: "Dips and corrections are normal, not emergencies. Sitting through them is the hard part, and the whole point.",
            oneMoreThing: nil,
            preview: "Dips are normal, don't panic-sell",
            deepLinkRaw: "fearGreed"
        ),
        TrailLesson(
            trailKey: "markets", position: 4,
            title: "What actually moves the market",
            idea: "Two forces move stocks more than anything else: how much money companies are making (earnings) and interest rates set by the central bank (the Fed). When earnings grow, stocks tend to rise. When the Fed raises rates to cool inflation it can weigh on stocks; when it cuts, it can lift them. You don't need to trade around these events, and trying to is a good way to get whipsawed. Knowing what drives the market just helps the headlines make sense instead of scaring you.",
            seeInApp: "Arkline's macro dashboard reads the backdrop, growth, inflation, and rates, so you have context without the noise.",
            mindsetCheck: nil,
            takeaway: "Earnings and interest rates move the market most. Understand them for context, don't trade the headlines.",
            oneMoreThing: nil,
            preview: "Earnings and rates move the market",
            deepLinkRaw: "macro"
        ),
        TrailLesson(
            trailKey: "markets", position: 5,
            title: "Don't put it all in one stock",
            idea: "The single most reliable way to lower your risk is diversification, a long word for a simple idea: don't put all your money in one company. Any single stock can fall hard on bad news, no matter how good the company seemed. Spreading your money across many companies (which an index fund does for you) means no single failure can sink you. It has been called the only free lunch in investing, because you lower your risk without giving up your long-term return.",
            seeInApp: "If you build a portfolio in Arkline, you can see how concentrated or spread out it is at a glance.",
            mindsetCheck: nil,
            takeaway: "Never bet the house on one stock. Spreading out is the closest thing to a free lunch in investing.",
            oneMoreThing: nil,
            preview: "Never bet it all on one stock",
            deepLinkRaw: "portfolio",
            illustration: "diversification_curve"
        ),
        TrailLesson(
            trailKey: "markets", position: 6,
            title: "Time in the market beats timing the market",
            idea: "Here is the quiet superpower of stock investing: compounding over time. Money left to grow earns returns, and then those returns earn returns, and over decades that snowball becomes the bulk of your result. The market has had rough years, but over long stretches it has trended up. The people who do best are rarely the cleverest traders. They are the ones who started early, stayed in, and let time do the heavy lifting.",
            seeInApp: nil,
            mindsetCheck: "This is why the routine from Foundations matters more than any single decision. Boring and consistent wins.",
            takeaway: "Time in the market beats timing the market. Start early, stay in, and let compounding work.",
            oneMoreThing: nil,
            preview: "Time in beats timing",
            deepLinkRaw: "dca",
            illustration: "compounding_curve"
        ),
        TrailLesson(
            trailKey: "markets", position: 7,
            title: "Index funds and ETFs: the whole market in one buy",
            idea: "Back in lesson two you met the index, a basket that measures a whole market. Here's the part that makes it practical: you can actually buy that basket. An index fund, and its close cousin the ETF (exchange-traded fund), is a single investment that holds a slice of every company in an index at once. Buy one share and you instantly own a tiny piece of hundreds of companies, real diversification in one cheap purchase. It's why so many long-term investors keep it simple: instead of trying to pick winners, they own the whole market and let it compound.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "An index fund or ETF lets you buy the whole market in one cheap, diversified purchase, no stock-picking required.",
            oneMoreThing: nil,
            preview: "Own the whole market in one buy",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "markets", position: 8,
            title: "Active vs passive: matching the market",
            idea: "There are two broad ways to invest. Active means trying to beat the market, picking stocks or funds you hope will do better than average. Passive means simply matching the market by owning an index fund and accepting its return. Here's the humbling truth decades of data keep showing: most active efforts, including highly paid professionals, fail to beat a simple low-cost index fund over time, largely because fees and mistakes eat the difference. Matching the market isn't settling, it's a strategy that quietly outperforms most of the people trying to beat it. Doing less, again, tends to win.",
            seeInApp: nil,
            mindsetCheck: "It feels like enough effort should let you beat the market. The evidence says the opposite for most people, and making peace with that is its own kind of edge.",
            takeaway: "Active tries to beat the market; passive just matches it cheaply. Over time, simply matching it beats most who try to beat it.",
            oneMoreThing: nil,
            preview: "Why matching the market often wins",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "markets", position: 9,
            title: "Reading stocks in Arkline",
            idea: "You now have the ideas, so here is how they show up in the app. Stock risk levels tell you how expensive or cheap a stock is against its own history. Signal changes show which way the trend is leaning. The macro dashboard reads the bigger economic backdrop. None of these tells you to buy or sell. Together they are context for your own thinking, so the market feels readable instead of overwhelming.",
            seeInApp: "Open Stock Risk Levels and tap the “?” to see what Cheap, Fair, Elevated, and Overheated mean for a stock.",
            mindsetCheck: nil,
            takeaway: "Arkline gives you context on stocks, never commands. The decision stays yours.",
            oneMoreThing: nil,
            preview: "Context on stocks, not commands",
            deepLinkRaw: "stockRisk"
        ),
        TrailLesson(
            trailKey: "markets", position: 10,
            title: "Putting it together calmly",
            idea: "That is the foundation for traditional markets. You know a stock is a piece of a business, why the index is the calm core, that dips are normal, what moves prices, why diversification protects you, and why time is your biggest ally. A common calm approach is to treat a broad index fund as your steady core, add individual stocks only in amounts you can afford to be wrong about, spread your money out, and use DCA so you are not timing the swings. Check in a few times a week, not every hour, and let the years do the work.",
            seeInApp: "Set a DCA reminder for a stock or fund you believe in, and let the app turn steady into a habit.",
            mindsetCheck: nil,
            takeaway: "Index core, diversify, DCA in, and let time compound. Calm and consistent wins.",
            oneMoreThing: "When you're ready for a more advanced topic, there's a trail on hedges and safe havens too. The same calm approach carries across everything you own.",
            preview: "Index core, diversify, let time work",
            deepLinkRaw: "dca"
        ),
    ]

    static let hedging: [TrailLesson] = [
        TrailLesson(
            trailKey: "hedging", position: 1,
            title: "What a safe haven actually is",
            idea: "When markets get scary, money tends to flow toward a handful of assets people trust to hold their value. Those are called safe havens, and gold is the classic example. The idea is simple: in a panic, investors want something that isn't tied to the fortunes of any one company. But safe is a relative word, not a promise. Safe havens can still fall, and they can sit flat for long stretches. They are calmer, not risk-free.",
            seeInApp: "Arkline tracks gold, silver, and oil in the Market tab, so you can see how these assets move alongside your stocks and crypto.",
            mindsetCheck: nil,
            takeaway: "Safe havens are where money hides in a storm. Calmer than stocks, but safe is relative, never guaranteed.",
            oneMoreThing: nil,
            preview: "Where money hides in a storm",
            deepLinkRaw: "market"
        ),
        TrailLesson(
            trailKey: "hedging", position: 2,
            title: "Why spread beyond stocks and crypto",
            idea: "You have already met diversification: don't put everything in one basket. This lesson takes it up a level. Stocks and crypto often fall together when fear takes over, so holding both isn't as diversified as it looks. Adding assets that don't move in lockstep with them, like some commodities or safe havens, can smooth the overall ride. The goal isn't to chase returns from these assets. It's to make your whole portfolio a little steadier when things get rough.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Real diversification means owning things that don't all move together. That's what steadies the ride.",
            oneMoreThing: nil,
            preview: "Own things that don't move together",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "hedging", position: 3,
            title: "Gold: the oldest store of value",
            idea: "Gold has been treated as money for thousands of years, long before stocks or crypto existed. People hold it as a store of value, a way to park wealth that central banks can't print more of. It tends to do well when people worry about inflation or instability, and it often holds up when stocks are falling. The honest caveats: gold pays you nothing while you hold it (no dividends, no interest), and it can go through long, boring stretches where it does nothing at all.",
            seeInApp: "Open the Gold view in Arkline's Market tab to see where it sits versus its history and which way it's trending.",
            mindsetCheck: nil,
            takeaway: "Gold is a time-tested store of value. Steady in a crisis, but it pays no income and can sit flat for years.",
            oneMoreThing: nil,
            preview: "The oldest store of value",
            deepLinkRaw: "gold"
        ),
        TrailLesson(
            trailKey: "hedging", position: 4,
            title: "Silver: gold's more volatile cousin",
            idea: "Silver is often mentioned in the same breath as gold, and it shares gold's role as a precious metal you can hold. But there's a twist: silver is also an industrial metal, used in electronics, solar panels, and more. That means its price is pulled by two forces, investor demand and factory demand, which makes it swing harder than gold in both directions. If gold is the steady one, silver is the livelier, riskier cousin.",
            seeInApp: "Silver sits alongside gold in the Market tab's metals view.",
            mindsetCheck: nil,
            takeaway: "Silver is part safe haven, part industrial metal. That double life makes it swing harder than gold.",
            oneMoreThing: nil,
            preview: "Gold's livelier, riskier cousin",
            deepLinkRaw: "silver"
        ),
        TrailLesson(
            trailKey: "hedging", position: 5,
            title: "Oil and commodities: a bet on the real economy",
            idea: "Oil is the world's most important commodity, and its price is really a read on the real economy: how much the world is producing, traveling, and building. When the economy is booming, demand for oil rises; when it slumps, demand falls. On top of that, supply can shift suddenly with geopolitics, which makes oil famously volatile. Unlike gold, oil isn't a hold-forever asset, it's tied to cycles and events. It's useful to understand, but it behaves more like a fast-moving bet than a quiet store of value.",
            seeInApp: "Arkline tracks crude oil in the Market tab if you want to follow it.",
            mindsetCheck: nil,
            takeaway: "Oil is a bet on the real economy: booms, slumps, and geopolitics. Useful to watch, but volatile and event-driven.",
            oneMoreThing: nil,
            preview: "A bet on the real economy",
            deepLinkRaw: "oil"
        ),
        TrailLesson(
            trailKey: "hedging", position: 6,
            title: "How hedges behave in a storm",
            idea: "Here's the appeal of a hedge: the hope that when your stocks and crypto are falling, something else in your portfolio is holding steady or even rising, cushioning the blow. Sometimes it works beautifully, gold has had moments of shining exactly when stocks crashed. But here's the honest truth most people skip: these relationships are not reliable. In some crises, everything falls together, including the supposed safe havens, as people sell whatever they can. A hedge can reduce your risk, but it is never a guarantee, and treating it like one is its own kind of danger.",
            seeInApp: nil,
            mindsetCheck: "This is where humility matters most. A hedge is insurance that sometimes doesn't pay out. Size it as a cushion, never as a certainty.",
            takeaway: "A good hedge can soften a crash, but it can also fail. Treat it as a cushion, not a guarantee.",
            oneMoreThing: nil,
            preview: "Cushion, never a guarantee",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "hedging", position: 7,
            title: "Reading these in Arkline",
            idea: "You now know the cast: gold the steady store of value, silver its livelier cousin, and oil the economy's pulse. In Arkline, all three live in the Market tab, with the same calm read you get on everything else, where a price sits versus its history and which way it's trending. As always, none of it is a signal to buy or sell. It's context, so if you ever choose to hold a hedge, you're doing it with your eyes open rather than on a hunch.",
            seeInApp: "Open the Market tab to find gold, silver, and oil alongside your other assets.",
            mindsetCheck: nil,
            takeaway: "Arkline gives you the same calm read on gold, silver, and oil that it gives everything else. Context, not commands.",
            oneMoreThing: nil,
            preview: "The same calm read, for metals and oil",
            deepLinkRaw: "market"
        ),
        TrailLesson(
            trailKey: "hedging", position: 8,
            title: "Putting it together calmly",
            idea: "That's the hedging picture. You know what a safe haven is, why spreading beyond stocks and crypto can steady your ride, what gold, silver, and oil each bring, and the honest truth that hedges can fail. The calm way to use all this: think of hedges as a small, optional slice of a portfolio, not the main event. Most of your long-term growth still comes from the core assets you already understand. A hedge is there to smooth the bumps, sized so that if it does nothing for a while, you barely notice. Understand it, keep it modest, and let it play its quiet supporting role.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Hedges are a small, optional cushion, not the main event. Keep them modest and let your core do the heavy lifting.",
            oneMoreThing: "That completes the tour: mindset, crypto, markets, and now hedges. The same calm approach carries across everything you own.",
            preview: "A small, optional cushion",
            deepLinkRaw: nil
        ),
    ]

    static let fees: [TrailLesson] = [
        TrailLesson(
            trailKey: "fees", position: 1,
            title: "The costs nobody notices",
            idea: "Every dollar you pay to invest is a dollar that isn't compounding for you. Fees and taxes are the quiet drag on returns, small enough to ignore day to day, large enough to reshape decades. A 1% yearly cost doesn't sound like much, but over thirty years it can quietly eat a meaningful slice of your final balance. Here's the good news: costs are one of the few things in investing you actually control. You can't control the market, but you can control what you pay to be in it.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Costs are the one part of investing you control. Small percentages, compounded over decades, quietly add up.",
            oneMoreThing: nil,
            preview: "The quiet drag on returns",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 2,
            title: "The spread: the invisible cost",
            idea: "Every asset has two prices at once: what buyers will pay (the bid) and what sellers are asking (the ask). The gap between them is the spread, and it's a cost you quietly pay on the way in and the way out, even when there's no visible fee. For big, heavily traded assets like major stocks or Bitcoin, the spread is tiny. For small, thinly traded coins or stocks, it can be surprisingly wide, costing you a few percent before the price even moves. The more obscure the asset, the more the spread matters.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "The spread is the gap between the buy and sell price, a hidden cost. It's widest on small, thinly traded assets.",
            oneMoreThing: nil,
            preview: "The gap you pay on every trade",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 3,
            title: "Why frequent trading hurts",
            idea: "Many platforms charge a fee each time you buy or sell, a flat amount or a percentage. Even where trades look free, the cost is usually baked into the spread instead. The real lesson isn't the size of any single fee, it's how they multiply with activity. Someone who trades a few times a year barely notices; someone who trades every day pays the toll over and over, and those tolls compound against them. Doing less is often the cheapest strategy there is.",
            seeInApp: nil,
            mindsetCheck: "This is where trading and costs collide: the more you churn, the more you pay, whether you win or lose. Patience is quite literally cheaper.",
            takeaway: "Fees multiply with activity. Frequent trading pays the toll again and again; doing less simply costs less.",
            oneMoreThing: nil,
            preview: "Why churning quietly bleeds you",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 4,
            title: "Fund fees: the annual bite",
            idea: "When you own a fund or ETF, you pay a small yearly fee called the expense ratio, a percentage of what you've invested. It's charged quietly, skimmed from the fund a little each day, so you never get a bill. The differences look trivial, 0.03% versus 1%, but over decades that gap can cost tens of thousands on a serious balance. Low-cost index funds became popular for exactly this reason: the same market exposure, with far less skimmed off the top.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Funds charge a yearly expense ratio, quietly skimmed. Tiny-looking differences compound into real money over time.",
            oneMoreThing: nil,
            preview: "The fee you never see billed",
            deepLinkRaw: nil,
            illustration: "fee_drag"
        ),
        TrailLesson(
            trailKey: "fees", position: 5,
            title: "Crypto's own set of costs",
            idea: "Crypto adds a few cost layers of its own. Exchanges charge trading fees, often higher than stock brokers, and the spread on smaller coins can be wide. On top of that, moving crypto between wallets or across a blockchain costs a network fee, often called gas, which can spike when the network is busy. None of this should scare you off, but it's worth knowing before you make lots of small moves, because the fees on many tiny transactions can add up to more than you'd expect.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Crypto stacks exchange fees, wider spreads on small coins, and network gas fees. Lots of small moves add up fast.",
            oneMoreThing: nil,
            preview: "Exchange fees, spreads, and gas",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 6,
            title: "Taxes: the basics of capital gains",
            idea: "When you sell an investment for more than you paid, the profit is a capital gain, and in most places it's taxed. One detail matters a lot: how long you held it. Sell after a short holding period and you're usually taxed at a higher, short-term rate; hold longer (often more than a year) and many places tax the gain at a lower, long-term rate. This is general information, not tax advice, and the rules vary by country and change over time. But the pattern is worth knowing: patience isn't just calmer, it's often taxed more gently too.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Selling at a profit usually triggers tax. Holding longer often means a lower rate, though the rules vary by place.",
            oneMoreThing: nil,
            preview: "Why holding longer can tax less",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 7,
            title: "Don't forget the tax you owe",
            idea: "A common and painful surprise: people sell at a gain, spend the proceeds, and then discover months later that they owe tax on it. That money was never fully theirs to spend. A calm habit is to mentally set aside a portion of any gain for taxes, so the bill is boring instead of brutal. It also helps to keep simple records of what you bought, when, and for how much, because that's exactly what you'll need at tax time. And again, this is general information, not tax advice, a qualified professional is worth it once your situation gets real.",
            seeInApp: nil,
            mindsetCheck: "The goal isn't to become a tax expert. It's to dodge the nasty surprise by setting money aside and keeping simple records.",
            takeaway: "Tax on a gain isn't optional. Set some aside, keep records, and the bill stays boring instead of brutal.",
            oneMoreThing: nil,
            preview: "The surprise bill you can avoid",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "fees", position: 8,
            title: "Keeping costs quiet",
            idea: "Here's the whole picture in one calm summary. Costs, spreads, fees, and taxes, are a drag you can largely manage. The levers are simple and they mostly point the same way: trade less, favor low-fee funds, hold longer, and keep decent records. None of this is about squeezing every last penny; it's about not leaking money through habits you never chose. Do the boring things well, and more of your returns simply stay yours.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Trade less, keep fees low, hold longer, keep records. The boring habits quietly keep more of your money yours.",
            oneMoreThing: "That's the unglamorous half of investing, and the half most people ignore. Getting it right costs nothing but attention.",
            preview: "Keep more of what's yours",
            deepLinkRaw: nil
        ),
    ]

    static let sizing: [TrailLesson] = [
        TrailLesson(
            trailKey: "sizing", position: 1,
            title: "Why weight is the whole game",
            idea: "Most people obsess over what to buy and barely think about how much. But weight, the share of your money in each position, often matters more than the picks themselves. Two people can own the exact same handful of assets and end up in completely different places, simply because one bet the farm on the riskiest one and the other kept it small. Choosing your assets is only half the job. Deciding how much of each to hold is the other half, and it's the half that quietly determines how bumpy your ride is.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "What you own matters, but how much of each often matters more. Weight decides how bumpy the ride gets.",
            oneMoreThing: nil,
            preview: "How much matters more than what",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 2,
            title: "The danger of one big bet",
            idea: "The fastest way to get hurt is to let one position get too big. It might be the asset you're most excited about, or one that quietly grew until it became half of everything you own. Either way, your fate is now tied to a single outcome. When it's up it feels brilliant; when it drops it takes your whole portfolio down with it. Concentration is how people make fortunes and how they lose them, often the same people. Keeping any single position to a sensible slice is the simplest protection there is.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "One oversized position ties your fate to a single outcome. Keeping each bet a modest slice is basic protection.",
            oneMoreThing: nil,
            preview: "When one position gets too big",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 3,
            title: "Size is a dial, not a switch",
            idea: "Beginners often think in all-or-nothing terms: either you own something or you don't. But position size is a dial you can turn, not a switch you flip. Believe in something strongly and understand it well? It can be a larger slice. Curious but unsure, or it's more speculative? Keep it small. That's how you express conviction without betting everything on it. A small position lets you take part and learn while capping the damage if you're wrong. You're allowed to own just a little.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "You don't have to be all-in or all-out. Size expresses conviction: bigger for what you trust, small for the speculative.",
            oneMoreThing: nil,
            preview: "Turn the dial, don't flip a switch",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 4,
            title: "Cash is a position too",
            idea: "It's easy to think of cash as money sitting on the sidelines doing nothing. But holding cash is a deliberate choice with real benefits: it steadies your portfolio, and it's dry powder, ready to buy when prices fall and everyone else is frozen. Arkline's model portfolios lean on this on purpose, they hold a meaningful cash reserve rather than being fully invested at all times. Cash won't grow much, but it's the cushion that lets you stay calm and act when opportunities appear.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Holding cash is a real position: it steadies the ride and gives you dry powder to buy when prices fall.",
            oneMoreThing: nil,
            preview: "Cash on purpose, not by accident",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 5,
            title: "A stable core, small satellites",
            idea: "A simple, sturdy way to think about weighting is core and satellite. The core is the big, stable majority of your portfolio, the diversified holdings you trust for the long run. Satellites are smaller positions around it: more thematic or speculative bets, each kept intentionally modest. Arkline's more aggressive model portfolios are built exactly this way, a large core sleeve of established names plus a smaller thematic sleeve of higher-risk ideas. The point is that even when a satellite fails, it can't sink the ship, because it was never sized to.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Build a big, stable core, then add small satellite bets around it. Keep satellites modest so a failure can't sink you.",
            oneMoreThing: nil,
            preview: "A stable core, small satellites",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 6,
            title: "The sleep-at-night test",
            idea: "Here's the most honest sizing rule there is: never hold a position so large that it costs you sleep. If a holding dropping by half would wreck you, financially or emotionally, it's too big, no matter how good the story. The right size is one where, if the worst happened, you'd be disappointed but fine, and could hold through it without panic-selling at the bottom. Sizing isn't just math; it's matching your positions to what you can actually live through.",
            seeInApp: nil,
            mindsetCheck: "This is where sizing meets psychology. A position you can't hold calmly through a crash is one that will make you sell at the worst moment. Size for your own nerves.",
            takeaway: "If a position would wreck you when it halves, it's too big. Size so you could hold through the worst without panic.",
            oneMoreThing: nil,
            preview: "Never hold more than you can sleep on",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 7,
            title: "How Arkline's models are weighted",
            idea: "You can see all of this in Arkline's model portfolios, which are built as worked examples, not templates to copy. Notice a few things: no single position dominates, the largest holdings sit in a sensible range rather than one name swallowing the portfolio. There's a real cash reserve for calm and dry powder. And the riskier, more thematic ideas are deliberately kept to small slices. It's the same calm logic this trail describes, made concrete. Read them as illustrations of sizing done thoughtfully, then decide your own weights for yourself.",
            seeInApp: "Open the Portfolio tab to see how each model portfolio is weighted, position by position.",
            mindsetCheck: nil,
            takeaway: "Arkline's models show sizing in practice: no single name dominates, a real cash cushion, and risky ideas kept small.",
            oneMoreThing: nil,
            preview: "Sizing, made concrete",
            deepLinkRaw: "portfolio"
        ),
        TrailLesson(
            trailKey: "sizing", position: 8,
            title: "Building one from scratch",
            idea: "So how do you actually arrive at weights? A calm order of decisions helps. First, start with yourself: how long is your money invested, and how much of a drop can you stand? That answer sets the split between a stable core and riskier satellites, more nerve and a longer horizon can carry a little more risk; less of either means a bigger core and more cash. Second, build the core: broad, diversified holdings you'd be comfortable owning for years, given the largest share. Third, add satellites: a few individual convictions or thematic bets, each kept small. Fourth, decide your cash cushion. Notice what you did not do, you didn't start by picking the exciting coin and working backward. You started with structure, and let the picks fit into it.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Weights come from an order: know your risk, build a broad core, add small satellites, set a cash cushion. Structure first, picks second.",
            oneMoreThing: nil,
            preview: "Structure first, picks second",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "sizing", position: 9,
            title: "A worked example",
            idea: "Here's one illustration, purely to make it concrete, not a recommendation. Picture someone with a long horizon and a moderate stomach for risk. The largest slice goes to a diversified core, say broad index exposure plus Bitcoin and Ethereum, the holdings they understand and trust most. Around it sits a handful of small satellite bets, individual convictions and a few thematic ideas, each kept modest so that being wrong on any one stings but doesn't sink them. A slice goes to a hedge like gold, there for ballast when stocks and crypto wobble together. And a real cash cushion is held back, for calm and for buying dips. Add it up and no single position dominates, the risky stuff is deliberately small, a hedge steadies the ride, and cash stands ready. That's the same shape as Arkline's model portfolios, which lean on exactly these pieces, and it's the shape most thoughtful weighting takes.",
            seeInApp: "Open the Portfolio tab and compare this shape to the model portfolios, note how the weights spread out and how much cash and hedge sit ready.",
            mindsetCheck: "Notice the sizes aren't precise to the decimal, they're rough bands chosen so no single outcome matters too much. Sizing is about sane ranges, not perfect numbers.",
            takeaway: "In practice: a large diversified core, small satellite bets, a modest hedge like gold, and a real cash cushion. Rough bands, not exact math.",
            oneMoreThing: nil,
            preview: "One portfolio, built piece by piece",
            deepLinkRaw: "portfolio",
            illustration: "sample_allocation"
        ),
        TrailLesson(
            trailKey: "sizing", position: 10,
            title: "Weighting it calmly",
            idea: "That's the whole picture. Weighting isn't a formula to perfect, it's a set of calm habits: size each position to how much you understand and trust it, keep any single bet modest, hold some cash as a cushion, and let a stable core do the heavy lifting while smaller satellites add spice. Check your weights now and then, because winners grow and can quietly become too large, and nudge them back toward sane sizes. Do this, and no single outcome can define you, which is exactly the point.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Size to conviction, keep each bet modest, hold a cushion, let the core lead, and rebalance gently. No one bet defines you.",
            oneMoreThing: "That rounds out the practical toolkit: mindset, safety, assets, macro, hedges, costs, and now sizing. The calm approach, all the way through.",
            preview: "Let no single bet define you",
            deepLinkRaw: nil
        ),
    ]

    static let beforeInvesting: [TrailLesson] = [
        TrailLesson(
            trailKey: "beforeInvesting", position: 1,
            title: "Build the base first",
            idea: "Before you buy a single stock or coin, it's worth pausing on the groundwork, because calm investing is only possible when the rest of your money is stable. Investing puts money at risk of short-term drops, and you only want to do that with money that can actually stay invested through those drops. This short trail covers the few things that belong in place first: a cash safety net, expensive debt handled, and a clear line between money you can invest and money you can't. It's the least glamorous part of investing, and the part that saves people the most pain.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Investing sits on top of a stable base. Get the groundwork right first, and the ups and downs become survivable.",
            oneMoreThing: nil,
            preview: "Get the groundwork right first",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "beforeInvesting", position: 2,
            title: "Your emergency fund comes first",
            idea: "The single most important thing to have before investing is an emergency fund: a cushion of cash, commonly three to six months of living expenses, kept somewhere safe and easy to reach. Its whole job is to absorb life's surprises, a lost job, a car repair, a medical bill, without forcing you to touch your investments. Here's why it matters so much: without it, an emergency that lands during a market dip forces you to sell at the worst possible moment, locking in losses. The emergency fund is what lets you leave your investments alone and ride out the rough patches calmly.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Keep 3 to 6 months of expenses in cash first. It's the cushion that lets you leave investments untouched when life surprises you.",
            oneMoreThing: nil,
            preview: "Cash for life's surprises, first",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "beforeInvesting", position: 3,
            title: "Clear the expensive debt",
            idea: "If you're carrying high-interest debt, credit cards are the classic example, often charging twenty percent a year or more, paying it down is usually the best investment you can make. Think about it: wiping out a debt that costs you twenty percent is a guaranteed twenty percent return, with no risk, and very few investments can reliably beat that. Not all debt is the same, a low-rate mortgage or student loan is a different conversation, but expensive, high-interest balances are a leak that quietly drains any investment gains. Plugging that leak first is simple, boring math that almost always wins.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Paying off high-interest debt is a guaranteed return few investments can beat. Clear the expensive stuff before investing.",
            oneMoreThing: nil,
            preview: "Guaranteed return: kill costly debt",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "beforeInvesting", position: 4,
            title: "Only invest what you won't need soon",
            idea: "Investing rewards patience, which means it needs money you can leave alone for years. Money earmarked for something in the next year or two, a wedding, a house deposit, a big planned expense, doesn't belong in volatile assets. The reason is timing risk: if the market happens to be down right when you need the cash, you're forced to sell at a loss. The rule of thumb is simple, the sooner you'll need the money, the safer it should be. Near-term money stays in cash or savings; only longer-term money goes into investments that can ride out the bumps.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Money you'll need within a year or two shouldn't be invested. The sooner you need it, the safer it should sit.",
            oneMoreThing: nil,
            preview: "Near-term money stays safe",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "beforeInvesting", position: 5,
            title: "Only risk what you can afford to lose",
            idea: "Some investments, crypto especially, can fall hard and fast. The honest way to hold them is to invest only money whose loss wouldn't derail your life or your sleep. Ask yourself plainly: if this dropped by half, or went to zero, would I be fine? If the answer is no, the amount is too big. This is the same idea as position sizing, applied before you even begin, match the money you put at risk to how much you can genuinely afford to lose. Do that, and volatility becomes something you can watch calmly instead of something that controls you.",
            seeInApp: nil,
            mindsetCheck: "This is where a lot of pain is avoided. Money you can't afford to lose has no business in a volatile asset, no matter how good the story sounds.",
            takeaway: "Only put money at risk that you could afford to lose entirely. If a big drop would hurt your life, the amount is too big.",
            oneMoreThing: nil,
            preview: "If losing it would hurt, size down",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "beforeInvesting", position: 6,
            title: "Ready? A calm checklist",
            idea: "Here's the whole trail as a simple gut-check before you invest. Do you have an emergency fund covering a few months of expenses? Is your expensive, high-interest debt handled? Is the money you're about to invest money you won't need for years? And are you only risking an amount you could afford to lose? If you can say yes to all four, you're on solid ground, and everything else Arkline teaches can be put to use calmly. If some answers are no, that's not a failure, it's just a sign the base comes first. Building that base is investing in itself, the most important investment you'll make.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Emergency fund, debt handled, long-term money, an amount you can afford to lose. Yes to all four, and you're ready to invest calmly.",
            oneMoreThing: "With the base in place, the rest of the trails, mindset, assets, macro, and sizing, are yours to use with a clear head.",
            preview: "Four questions before you begin",
            deepLinkRaw: nil
        ),
    ]

    static let trading: [TrailLesson] = [
        TrailLesson(
            trailKey: "trading", position: 1,
            title: "Two different games",
            idea: "Investing and trading get lumped together, but they're almost opposite activities. Investing is buying a piece of something, a company, a coin, an index, and holding it for years while it grows. Trading is trying to profit from short-term price moves, buying and selling over days, hours, or minutes, without much care for what you actually own. Same market, completely different game, the way chess and blitz chess share a board but reward different skills. Knowing which one you're playing changes everything about how you should act.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Investing is owning for the long run. Trading is betting on short-term moves. Same market, different games.",
            oneMoreThing: nil,
            preview: "Owning vs betting on moves",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 2,
            title: "What investing really is",
            idea: "When you invest, you're buying a stake in something real and giving it time to grow. Your returns come from the underlying thing doing well: a company earning more, an economy expanding, an asset gaining adoption over years. The risk is real but specific: prices swing, sometimes hard, and you have to be willing to ride through the drops without selling. What makes investing survivable is time and diversification, which tilt the odds in your favor the longer you stay in. It's slow, a little boring, and historically the most reliable way ordinary people have built wealth.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Investing is buying a real stake and giving it time. The risk is volatility you ride through; time is your ally.",
            oneMoreThing: nil,
            preview: "Buy a stake, give it time",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 3,
            title: "What trading really is",
            idea: "Trading is a different craft entirely. A trader isn't trying to own good things for years, they're trying to buy low and sell high over short windows, again and again. That means predicting short-term moves, which, as Foundations taught, are basically unpredictable. Trading can work for a small number of highly skilled, disciplined people who treat it like a full-time job. For most, it's closer to a demanding game where the edge, fees, taxes, and their own emotions, is stacked against them. It is not a shortcut, and it is not investing.",
            seeInApp: nil,
            mindsetCheck: "Foundations lesson 4 lands hard here: nobody times the market consistently. Trading is that timing problem, on repeat.",
            takeaway: "Trading is profiting from short-term moves, which are mostly unpredictable. A demanding job, not a shortcut.",
            oneMoreThing: nil,
            preview: "A demanding job, not a shortcut",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 4,
            title: "The types of trading",
            idea: "Trading comes in flavors, and the names get thrown around a lot. Day trading means opening and closing positions within a single day. Swing trading holds for days or weeks to catch a bigger move. Scalping is dozens of tiny trades for tiny gains. Then there are instruments that raise the stakes: options (contracts that bet on where a price goes by a certain date) and futures (agreements to buy or sell later). These can be used carefully, but they're complex and often involve leverage, which is the next lesson and the single biggest way people get hurt.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Day, swing, scalp, options, futures: different speeds and tools, but all short-term and all higher-risk than investing.",
            oneMoreThing: nil,
            preview: "Day, swing, scalp, options, futures",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 5,
            title: "Leverage: the amplifier",
            idea: "Leverage means trading with borrowed money to control a bigger position than your cash alone allows. It's the most seductive and most dangerous idea in trading. Here's why: leverage multiplies your gains, but it multiplies your losses by exactly the same amount. With 10x leverage, a 10 percent move against you wipes out your entire stake, and you can even owe more than you put in. That's what a margin call and liquidation mean: the position is force-closed at a loss. Leverage is the reason people don't just lose money trading, they blow up entire accounts, fast. Treat it as fire.",
            seeInApp: nil,
            mindsetCheck: "If one lesson here saves you real money, it's this one. Amplified upside always comes with amplified, sometimes total, downside.",
            takeaway: "Leverage multiplies gains and losses equally. It's the fastest way to lose everything, and then some.",
            oneMoreThing: nil,
            preview: "Borrowed money cuts both ways",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 6,
            title: "The real risks of trading",
            idea: "Here's the honest picture the ads never show. Study after study of real trading accounts finds that the large majority of active traders lose money over time, and the more they trade, the worse they tend to do. On top of the losing trades, three quiet costs add up: fees on every trade, taxes on short-term gains (usually higher than long-term), and the emotional and time toll of watching screens and riding the stress. None of this means trading is impossible. It means the odds are genuinely stacked against the average person, and anyone telling you otherwise is usually selling something.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Most active traders lose money over time, and fees, taxes, and stress make it worse. The odds are stacked.",
            oneMoreThing: nil,
            preview: "The odds are stacked, honestly",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "trading", position: 7,
            title: "The risks of investing",
            idea: "Investing isn't risk-free, and it's only fair to say so plainly. Prices fall, sometimes 20, 30, even 50 percent, and it can take years to recover. If you need your money at the wrong moment, a downturn can force you to sell low. Individual companies and coins can go to zero. The difference is the shape of the risk: with a diversified, long-term approach, time and spreading out have historically turned those scary drops into temporary dips rather than permanent losses. Investing risk is survivable and manageable. Trading risk, especially with leverage, can be sudden and total. Both are real; they are not the same size.",
            seeInApp: "Risk levels in Arkline show how far an asset has moved from its trend, one honest read on where the bumps might be.",
            mindsetCheck: nil,
            takeaway: "Investing has real risk too: drawdowns, bad timing, zeros. But diversified and patient, it's survivable in a way trading often isn't.",
            oneMoreThing: nil,
            preview: "Real risk, but survivable",
            deepLinkRaw: "cryptoRisk"
        ),
        TrailLesson(
            trailKey: "trading", position: 8,
            title: "Knowing which one you're doing",
            idea: "Here's the whole trail in one honest question: which game are you actually playing? There's no shame in either answer, but there is real danger in not knowing, in thinking you're a calm long-term investor while actually making anxious short-term bets. For the overwhelming majority of people, the evidence points the same way: patient, diversified investing is the more reliable path, and trading is a high-skill, high-risk pursuit best approached, if at all, with money you can fully afford to lose. Whatever you choose, choose it on purpose, with your eyes open to the real odds.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Decide on purpose which game you're playing. For most, patient investing wins; trading is high-skill, high-risk, eyes open.",
            oneMoreThing: "If you take one thing from this trail: know the difference, respect the risk, and never confuse a bet for an investment.",
            preview: "Choose your game on purpose",
            deepLinkRaw: nil
        ),
    ]

    static let macro: [TrailLesson] = [
        TrailLesson(
            trailKey: "macro", position: 1,
            title: "Meet the Fed",
            idea: "The Federal Reserve, the Fed, is America's central bank, and it's the most important player in markets that most people never think about. Its job is set by Congress and comes down to two goals: keep people employed and keep prices stable (that is, keep inflation in check). It pursues those goals mainly by raising or lowering interest rates. You don't need to follow its every meeting, but knowing the Fed exists and what it's trying to do explains a huge share of why markets move the way they do.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "The Fed is the central bank with two jobs: employment and stable prices. It moves markets more than almost anything.",
            oneMoreThing: nil,
            preview: "The most important player you ignore",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 2,
            title: "Interest rates: the economy's thermostat",
            idea: "Interest rates are the price of borrowing money, and the Fed nudges them up and down like a thermostat for the whole economy. When things run hot and prices climb, the Fed raises rates to cool them off: borrowing gets pricier, spending slows. When the economy is weak, it cuts rates to warm things up. Here's why you care: higher rates tend to weigh on stocks and other risk assets (safer savings suddenly pay more, and borrowing costs rise), while lower rates tend to lift them. Rates are the single biggest macro lever there is.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Rates are the economy's thermostat. Higher rates cool things and often weigh on risk assets; lower rates lift them.",
            oneMoreThing: nil,
            preview: "The thermostat for everything",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 3,
            title: "Inflation, and why it matters",
            idea: "Inflation is simply prices rising over time, your money buying a little less each year. A small, steady amount is normal and even healthy. The trouble comes when it runs too hot, because it eats away at savings and forces the Fed to raise rates hard to bring it back down, which is what tends to rattle markets. This is why you'll see investors react so strongly to a single inflation report: it hints at what the Fed will do next. Inflation itself is boring; its effect on Fed policy is what moves prices.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Inflation is prices rising. A little is normal; too much forces the Fed's hand, and that's what shakes markets.",
            oneMoreThing: nil,
            preview: "Why one number moves everything",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 4,
            title: "The economic cycle",
            idea: "Economies breathe in a long, repeating rhythm: expansion (growth, hiring, optimism), a peak, a slowdown or recession (falling activity, rising fear), and then recovery. This is the business cycle, and it plays out over years, not days. Different assets tend to behave differently in each phase, but nobody can predict the exact turning points, so the cycle is best used as a rough map, not a stopwatch. Knowing roughly where things stand helps you stay calm: downturns are a normal, recurring part of the rhythm, not the end of the world.",
            seeInApp: nil,
            mindsetCheck: "Same lesson as always: the cycle turns on its own schedule, not yours. Recessions are part of the rhythm, not a reason to panic.",
            takeaway: "Economies move in long cycles: growth, peak, slowdown, recovery. A rough map to stay calm by, not a stopwatch.",
            oneMoreThing: nil,
            preview: "Economies breathe in cycles",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 5,
            title: "How macro reaches your assets",
            idea: "Here's how these big forces trickle down to what you own. When rates rise and money gets tight, investors demand more to hold risky things, so stocks and crypto often cool. When rates fall and money is easy, that same risk appetite tends to lift them. Growth and inflation set the mood: strong growth with calm inflation is the friendliest backdrop, while slowing growth with stubborn inflation is the toughest. None of this is a precise formula, and there are always exceptions, but the direction of these forces is a big part of the tide that lifts or lowers most boats at once.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Rates, growth, and inflation are the tide that moves most assets together. Not a formula, but a powerful backdrop.",
            oneMoreThing: nil,
            preview: "The tide that moves most boats",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 6,
            title: "Reading macro in Arkline",
            idea: "You don't have to track all this yourself. Arkline's macro dashboard boils the big picture down to a simple read of the backdrop, whether growth and inflation point toward a supportive or a cautious environment. It's there to give you context at a glance, the weather report for markets, so a scary headline doesn't catch you off guard. As always, it's not a signal to buy or sell. It's background for your own calm thinking.",
            seeInApp: "Open the Macro Dashboard on your Home screen to see the current backdrop in plain English.",
            mindsetCheck: nil,
            takeaway: "Arkline's macro dashboard is your weather report for markets: the backdrop at a glance, context not commands.",
            oneMoreThing: nil,
            preview: "Your weather report for markets",
            deepLinkRaw: "macro"
        ),
        TrailLesson(
            trailKey: "macro", position: 7,
            title: "Don't trade the headlines",
            idea: "Macro news is a firehose: rate decisions, jobs reports, inflation prints, and endless commentary, all delivered with maximum drama. Here's the freeing truth: reacting to each headline is a losing game. Markets often move before the news is even public, and the knee-jerk reaction is frequently wrong. The value of understanding macro isn't to trade on it, it's the opposite: to stay calm because you understand what's happening, instead of getting yanked around by every scary headline. Knowledge here is a seatbelt, not an accelerator.",
            seeInApp: nil,
            mindsetCheck: "This is the whole point: macro understanding is there to keep you steady, not to make you act. Context, not a trigger.",
            takeaway: "Don't trade the headlines. Understanding macro is a seatbelt that keeps you calm, not a reason to react.",
            oneMoreThing: nil,
            preview: "Knowledge is a seatbelt",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "macro", position: 8,
            title: "Putting it together calmly",
            idea: "That's the macro picture. You know who the Fed is, why rates are the master lever, how inflation forces its hand, how the economy moves in cycles, and how all of it reaches the assets you own. The calm way to use it: treat macro like weather. You check the forecast so you're not surprised, you dress accordingly, but you don't cancel your life over it. Keep investing steadily through the seasons, let the cycle do what cycles do, and use your understanding to stay calm rather than to chase the next move.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Treat macro like weather: check the forecast, stay prepared, but don't let it run your decisions. Steady wins.",
            oneMoreThing: "Macro is the last big piece of the picture. Combined with the other trails, you now understand the forces behind almost everything you'll see in the app.",
            preview: "Macro is weather, not a stock tip",
            deepLinkRaw: nil
        ),
    ]

    static let behavioral: [TrailLesson] = [
        TrailLesson(
            trailKey: "behavioral", position: 1,
            title: "Your brain wasn't built for this",
            idea: "Here's a liberating fact: you are not bad at investing, you're human. The instincts that kept our ancestors alive, run from danger, follow the herd, grab a reward now, are exactly the instincts that hurt investors. Your brain is a survival machine, not a wealth machine. Nearly every costly mistake in investing comes from this ancient wiring doing exactly what it evolved to do. The good news: once you can name these traps, you can catch them in the act. This trail is a tour of the ones your own mind sets, and how to step around them.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "You're not bad at investing, you're human. The instincts that kept us alive are the ones that trip up investors.",
            oneMoreThing: nil,
            preview: "Built for survival, not investing",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 2,
            title: "Loss aversion: why losing hurts more",
            idea: "Studies find that losing money hurts about twice as much as making the same amount feels good. That imbalance quietly drives some of the worst investing behavior. It's why people sell their winners too early, to lock in a good feeling, and cling to their losers too long, to avoid the pain of admitting a loss. It's why a red day can feel like an emergency when it's really just noise. Knowing that your brain over-weights losses helps you take its panic signals with a grain of salt.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Losses hurt about twice as much as gains feel good. That imbalance makes us sell winners early and hold losers too long.",
            oneMoreThing: nil,
            preview: "Losing hurts twice as much",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 3,
            title: "FOMO and the herd",
            idea: "We're wired to follow the crowd, because for most of human history, going against the group could get you killed. In markets, that same instinct shows up as FOMO: the fear of missing out. When everyone's talking about an asset that's soaring, the pull to jump in feels almost physical, and that's usually exactly when prices are highest and riskiest. The herd feels safe, but in investing, the crowd is often most confident right before it's wrong. Noticing the pull is the first step to not being dragged by it.",
            seeInApp: "The Fear & Greed reading is a mirror for exactly this herd emotion. When it's screaming greed, the herd is at its loudest.",
            mindsetCheck: "This ties straight to Foundations: the crowd's mood is the emotion you least want making your decisions.",
            takeaway: "FOMO is the herd instinct in disguise. The crowd is often loudest and most confident right before it's wrong.",
            oneMoreThing: nil,
            preview: "The herd is loudest before it's wrong",
            deepLinkRaw: "fearGreed"
        ),
        TrailLesson(
            trailKey: "behavioral", position: 4,
            title: "Recency bias and overconfidence",
            idea: "Your brain assumes whatever just happened will keep happening. After a long rally, it feels like prices only go up; after a crash, it feels like they'll fall forever. That's recency bias, and it gets people buying high and selling low with total conviction. Its partner in crime is overconfidence: surveys consistently show most people believe they're above-average investors, which is statistically impossible. A few lucky wins can convince you that you've cracked the code, right before the market humbles you. Staying a little humble is a genuine edge.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Your brain assumes the recent past will continue, and thinks you're above average. Both lead to buying high and selling low.",
            oneMoreThing: nil,
            preview: "The recent past isn't the future",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 5,
            title: "Anchoring and the sunk cost trap",
            idea: "Once a number lodges in your head, it's hard to let go, that's anchoring. The classic example is the price you paid: “I'll sell when it gets back to what I bought it for.” But the market doesn't know or care what you paid, and waiting to break even has trapped countless people in bad positions for years. Close behind is the sunk cost trap: throwing good money after bad because you've already put so much in. The hard truth is that what you've already lost is gone. The only question that matters is what makes sense from here.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "The market doesn't care what you paid. Waiting to break even and chasing sunk costs keeps people stuck.",
            oneMoreThing: nil,
            preview: "The market forgot your buy price",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 6,
            title: "Confirmation bias and echo chambers",
            idea: "We love information that agrees with us and quietly ignore anything that doesn't. That's confirmation bias, and social media pours fuel on it. Once you own something, the algorithms happily feed you a stream of people who agree it's going to the moon, and hide the voices raising real concerns. The result is a false sense of certainty built entirely from one side of the story. The antidote isn't to doom-scroll the doubters, it's to stay aware that a feed full of agreement is a warning sign, not a confirmation.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "We seek out what we already believe, and social feeds amplify it. A feed full of agreement is a warning, not proof.",
            oneMoreThing: nil,
            preview: "Your feed agrees with you on purpose",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 7,
            title: "The antidote: rules over willpower",
            idea: "Here's the key insight: you can't out-discipline your own brain in the heat of the moment, and you don't have to. The winning move is to make good decisions in advance, when you're calm, and then automate them so your emotional self can't interfere. That's the whole logic behind dollar-cost averaging, a set schedule, and a plan you write down. Rules and automation quietly remove the moments where fear and greed get a vote. You're not trying to become a robot, you're building guardrails so a bad five minutes can't undo years of good decisions.",
            seeInApp: "A DCA reminder is exactly this: a calm decision, made once, that runs on autopilot so emotion can't hijack it.",
            mindsetCheck: nil,
            takeaway: "You can't out-willpower your brain in the moment. Decide in advance and automate, so emotion doesn't get a vote.",
            oneMoreThing: nil,
            preview: "Rules beat willpower",
            deepLinkRaw: "dca"
        ),
        TrailLesson(
            trailKey: "behavioral", position: 8,
            title: "A paper loss isn't a real loss",
            idea: "When an investment drops, it's tempting to feel the money is already gone. But a fall on the screen is a paper loss, unrealized, and it isn't real until you act on it. Prices routinely swing below an asset's true worth, especially when everyone's fearful, and they often recover. A loss only becomes permanent when you sell at the bottom, or when the thing you own is genuinely broken, a single company going under, or borrowed money wiping you out. So the drops in a diversified, unborrowed portfolio are usually the temporary kind, the kind patient investors ride through. The danger isn't the dip; it's letting the dip panic you into making it permanent.",
            seeInApp: nil,
            mindsetCheck: "The market can't take your money on a red day, only your own sell order can. That's how a paper loss becomes a permanent one.",
            takeaway: "A drop on screen is a paper loss, not a real one. It turns permanent only if you sell at the bottom or the asset is truly broken.",
            oneMoreThing: nil,
            preview: "It's not a loss until you sell",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "behavioral", position: 9,
            title: "Master yourself",
            idea: "This whole trail is Foundations lesson 2 in full: master yourself, not the market. You can't delete loss aversion, FOMO, or any of these instincts, they're part of being human. But you can see them clearly, expect them, and build simple systems that keep them from driving. The calmest, most successful investors aren't the ones with no emotions. They're the ones who noticed their emotions and quietly chose not to obey them. That awareness, more than any chart or signal, is the real edge.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "You can't delete these instincts, but you can notice them and refuse to obey them. That awareness is the real edge.",
            oneMoreThing: "This is the trail behind all the others. Every calm decision you make elsewhere starts here, with knowing your own mind.",
            preview: "Notice the instinct, don't obey it",
            deepLinkRaw: nil
        ),
    ]

    static let scams: [TrailLesson] = [
        TrailLesson(
            trailKey: "scams", position: 1,
            title: "The one rule that stops most scams",
            idea: "If you learn nothing else about scams, learn this: there is no such thing as guaranteed, risk-free, high returns. None. Every legitimate investment can lose money, and anyone promising otherwise is lying to you, full stop. Scammers succeed by dangling exactly what your hopeful brain wants: easy money, no risk, act now. The instant you hear “guaranteed returns,” “risk-free,” or “double your money,” a door should slam shut in your mind. That single reflex protects you from the large majority of financial scams out there.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "There is no guaranteed, risk-free, high return. Anyone promising it is lying. That one reflex stops most scams.",
            oneMoreThing: nil,
            preview: "Guaranteed returns = a lie",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 2,
            title: "Urgency and pressure are red flags",
            idea: "Scammers' favorite weapon is urgency. “The offer ends tonight.” “Spots are almost gone.” “Send now or miss out.” Pressure is designed to switch off the slow, careful part of your brain and trigger the fast, fearful one, the same FOMO you met in the mindset trail. Real investments don't vanish if you take a day to think. A legitimate opportunity will still be there tomorrow, after you've researched it. So make this a rule: the more someone rushes you, the slower you should go. Urgency isn't a reason to act, it's a reason to walk away.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Urgency is a manipulation tactic. Real opportunities survive a night's sleep. The more they rush you, the slower you go.",
            oneMoreThing: nil,
            preview: "Pressure is a red flag, not a reason",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 3,
            title: "Guard your keys and your logins",
            idea: "This one is mostly about crypto, but the spirit applies everywhere. Your recovery phrase (also called a seed phrase) and private keys are the master password to your crypto. Whoever has them owns your coins, permanently, with no bank to call and no way to reverse it. So the rules are simple and absolute: never type your recovery phrase into a website, never share it with anyone, never store it in a photo or a cloud note, and know that no legitimate company or support agent will ever ask for it. On the traditional side, the same instinct protects your passwords and two-factor codes.",
            seeInApp: "Arkline will never ask for your recovery phrase or private keys. Nothing legitimate ever will.",
            mindsetCheck: nil,
            takeaway: "Your recovery phrase is the master key to your crypto. Never share it, never type it into a site. No one legit will ask.",
            oneMoreThing: nil,
            preview: "Never share your recovery phrase",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 4,
            title: "Ponzi schemes and “too good” returns",
            idea: "Some scams don't look like a stranger in your messages, they look like a real, professional investment. A Ponzi scheme pays early investors with money from new investors, not from any actual profit, so it looks fantastic and pays out reliably, until the new money dries up and it collapses, taking everyone's savings. The tells are always the same: unusually high but suspiciously steady returns, vague explanations of how the money is actually made, and pressure to recruit your friends. Famous frauds fooled thousands of smart people this way. If the returns seem too good and too smooth to be true, they are.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Ponzi schemes pay old investors with new investors' money and look great, until they collapse. Too good and too smooth is the tell.",
            oneMoreThing: nil,
            preview: "Too good and too smooth to be true",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 5,
            title: "The classic crypto scams",
            idea: "A few scams are so common it's worth knowing their names. A rug pull is when the creators of a new coin hype it up, take everyone's money, and vanish. Pig butchering is a long con where a stranger builds a friendship or romance online, then lures you into a fake investment platform. Fake giveaways promise to double any crypto you send, you send it, nothing comes back. And impersonators pose as celebrities, support staff, or even friends with hacked accounts. The common thread: they all exploit trust and greed. If a stranger online is helping you get rich, you are the product.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Rug pulls, pig butchering, fake giveaways, impersonators. If a stranger online is making you rich, you're the mark.",
            oneMoreThing: nil,
            preview: "If a stranger makes you rich, beware",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 6,
            title: "Verify before you trust",
            idea: "Scammers rely on you not checking, so build a habit of verifying. Before using an exchange, app, or wallet, look it up: is it well-known and reputable, does it have a real track record? Before clicking a link in a message or email, stop, because fake sites that look identical to the real thing are a scammer's bread and butter. Type addresses in yourself rather than clicking, and double-check you're on the official website. A few seconds of verifying beats a lifetime of regret, and legitimate services never mind you taking the time to be sure.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "Scams rely on you not checking. Verify apps, double-check links, type addresses yourself. Seconds now save everything later.",
            oneMoreThing: nil,
            preview: "Verify first, trust second",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 7,
            title: "If it already happened",
            idea: "Scams work on smart people every single day, so if it happens to you, feel the embarrassment for a moment and then act, because shame is the scammer's last weapon. Move fast: stop sending money immediately, secure your accounts (change passwords, turn on two-factor), and move any remaining crypto to a fresh, secure wallet if your keys may be exposed. Report it to the platform and the relevant authorities. And here's the hard part to hear: be extra wary of anyone who then offers to recover your lost funds for a fee, that is very often a second scam targeting people who were already hit. Don't let embarrassment stop you from protecting what's left.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "If you're scammed, act fast and skip the shame: stop payments, secure accounts, report it. Beware recovery offers, they're often a second scam.",
            oneMoreThing: nil,
            preview: "Act fast, skip the shame",
            deepLinkRaw: nil
        ),
        TrailLesson(
            trailKey: "scams", position: 8,
            title: "Putting it together",
            idea: "Staying safe doesn't require paranoia, just a few steady habits. Treat “guaranteed” and “risk-free” as instant lies. Slow down when someone rushes you. Guard your keys and logins like the master passwords they are. Verify before you trust, and know the common cons by name. Do these, and you've closed the door on the overwhelming majority of scams, without living in fear. The same calm, skeptical mindset that makes you a good investor is exactly what keeps you safe.",
            seeInApp: nil,
            mindsetCheck: nil,
            takeaway: "A few steady habits, doubt guarantees, slow down, guard your keys, verify, close the door on almost every scam.",
            oneMoreThing: "The calm, skeptical mindset that protects your money from scams is the same one that makes you a good investor.",
            preview: "A few habits close the door",
            deepLinkRaw: nil
        ),
    ]
}

// Compatibility shim so the Home Start Here card keeps working unchanged.
enum StartHereTrail {
    static var lessons: [TrailLesson] { TrailSeed.foundations }
    static func completedIDs() -> Set<Int> { TrailProgress.completed("foundations") }
    static var firstIncompleteIndex: Int {
        TrailProgress.firstIncompleteIndex(TrailSeed.foundations, "foundations")
    }
}

// Wrapper so the reader can be presented via .fullScreenCover(item:)
private struct TrailStart: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Guided Path Scaffold (shared by the trail and the checklist)
//
// A calm "connected path" overview: a threaded line runs through numbered nodes
// that show done / current / upcoming state, each with a one-line preview, and a
// "continue where you left off" card with a progress ring up top.

enum PathNodeState { case done, current, upcoming }

struct PathRow: Identifiable {
    let id: Int          // display number
    let index: Int       // array index (for tap → open)
    let title: String
    let preview: String
    let state: PathNodeState
}

struct GuidedPathScaffold: View {
    let eyebrow: String
    let intro: String
    let doneCount: Int
    let total: Int
    let upNextTitle: String
    let continueLabel: String
    let rows: [PathRow]
    var level: TrailDifficulty? = nil
    let onContinue: () -> Void
    let onTapRow: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var progress: CGFloat { total > 0 ? CGFloat(doneCount) / CGFloat(total) : 0 }
    private var lineColor: Color { AppColors.accent.opacity(0.18) }
    private var allDone: Bool { doneCount >= total }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Eyebrow + intro
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(eyebrow)
                                .font(.system(size: 12, weight: .bold)).tracking(0.6)
                                .foregroundColor(AppColors.accent)
                            if let level {
                                Text(level.label)
                                    .font(.system(size: 10, weight: .bold)).tracking(0.3)
                                    .foregroundColor(level.color)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(level.color.opacity(0.15)))
                            }
                        }
                        Text(intro)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Hero "continue" card
                    Button(action: onContinue) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().stroke(AppColors.accent.opacity(0.15), lineWidth: 5)
                                Circle().trim(from: 0, to: progress)
                                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(doneCount)/\(total)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                            }
                            .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(allDone ? "ALL DONE" : "UP NEXT")
                                    .font(.system(size: 11, weight: .bold)).tracking(0.4)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(upNextTitle)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 6)

                            Text(continueLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground(colorScheme)))
                    }
                    .buttonStyle(.plain)

                    // The connected path
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            Button {
                                onTapRow(row.index)
                            } label: {
                                pathRowView(row, isFirst: row.index == 0, isLast: row.index == rows.count - 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func pathRowView(_ row: PathRow, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Node + connector column
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : lineColor)
                    .frame(width: 2, height: 6)
                nodeCircle(row.state, number: row.id)
                Rectangle()
                    .fill(isLast ? Color.clear : lineColor)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 44)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 15, weight: row.state == .current ? .semibold : .medium))
                    .foregroundColor(row.state == .upcoming ? AppColors.textTertiary : AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.preview)
                    .font(.system(size: 12))
                    .foregroundColor(row.state == .upcoming ? AppColors.textTertiary : AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 16)
            .padding(.bottom, 16)

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    private func nodeCircle(_ state: PathNodeState, number: Int) -> some View {
        ZStack {
            switch state {
            case .done:
                Circle().fill(AppColors.success).frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            case .current:
                Circle().fill(AppColors.accent.opacity(0.18)).frame(width: 44, height: 44)
                Circle().fill(AppColors.accent).frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            case .upcoming:
                Circle().fill(AppColors.cardBackground(colorScheme)).frame(width: 32, height: 32)
                Circle().stroke(lineColor, lineWidth: 2).frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - Trail Overview

struct TrailOverviewView: View {
    let kind: TrailKind
    @Environment(\.colorScheme) private var colorScheme
    @State private var lessons: [TrailLesson]
    @State private var completed: Set<Int>
    @State private var start: TrailStart? = nil

    init(kind: TrailKind) {
        self.kind = kind
        _lessons = State(initialValue: kind.seed)
        _completed = State(initialValue: TrailProgress.completed(kind.rawValue))
    }

    private var doneCount: Int { completed.count }
    private var total: Int { lessons.count }
    private var firstIncomplete: Int { TrailProgress.firstIncompleteIndex(lessons, kind.rawValue) }

    private var continueLabel: String {
        if doneCount == 0 { return "Start" }
        if doneCount >= total { return "Review" }
        return "Continue"
    }

    private var rows: [PathRow] {
        let current = firstIncomplete
        return Array(lessons.enumerated()).map { idx, lesson in
            let state: PathNodeState = completed.contains(lesson.position)
                ? .done
                : (idx == current && doneCount < total ? .current : .upcoming)
            return PathRow(id: lesson.position, index: idx, title: lesson.title, preview: lesson.preview, state: state)
        }
    }

    var body: some View {
        GuidedPathScaffold(
            eyebrow: kind.eyebrow,
            intro: kind.intro,
            doneCount: doneCount,
            total: total,
            upNextTitle: lessons.isEmpty ? "" : lessons[min(firstIncomplete, lessons.count - 1)].title,
            continueLabel: continueLabel,
            rows: rows,
            level: kind.difficulty,
            onContinue: { start = TrailStart(index: firstIncomplete) },
            onTapRow: { idx in start = TrailStart(index: idx) }
        )
        .navigationTitle(kind.navTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            lessons = await TrailContent.load(kind)
        }
        .fullScreenCover(item: $start) { s in
            TrailLessonReaderView(lessons: lessons, startIndex: s.index) {
                completed = TrailProgress.completed(kind.rawValue)
                start = nil
            }
        }
    }
}

/// Foundations entry point. Thin wrapper kept so existing call sites (Home card,
/// Learn tab, onboarding intro) don't change.
struct StartHereTrailView: View {
    var body: some View { TrailOverviewView(kind: .foundations) }
}

// MARK: - Lesson Reader (the calm page)

// MARK: - Lesson illustrations
//
// Small, reusable visuals rendered inside a lesson when its `illustration` field
// names one. All are clearly labelled as illustrative, never projections.

/// Shared card chrome (eyebrow title + content + caption) for lesson visuals.
struct IllustrationFrame<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let caption: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold)).tracking(0.6)
                .foregroundColor(AppColors.accent)
            content()
            Text(caption)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color(hex: "F5F5F7"))
        )
    }
}

/// Compounding growth curve — money growing steadily over decades.
struct CompoundingChart: View {
    private struct P: Identifiable { let id = UUID(); let year: Int; let value: Double }
    private var data: [P] { (0...30).map { P(year: $0, value: 1000 * pow(1.08, Double($0))) } }

    var body: some View {
        IllustrationFrame(title: "HOW $1,000 CAN COMPOUND",
                          caption: "Illustrative steady growth over 30 years. Not a projection or a promise.") {
            Chart(data) { p in
                AreaMark(x: .value("Year", p.year), y: .value("Value", p.value))
                    .foregroundStyle(LinearGradient(colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Year", p.year), y: .value("Value", p.value))
                    .foregroundStyle(AppColors.accent)
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis { AxisMarks(values: [0, 10, 20, 30]) { v in
                AxisValueLabel { if let y = v.as(Int.self) { Text("Yr \(y)") } }
            } }
            .chartYAxis(.hidden)
            .frame(height: 130)
        }
    }
}

/// Diversification curve — portfolio risk dropping as holdings increase.
struct DiversificationChart: View {
    private struct P: Identifiable { let id = UUID(); let holdings: Int; let risk: Double }
    private var data: [P] { (1...25).map { P(holdings: $0, risk: 20 + 80 * exp(-Double($0 - 1) / 4.0)) } }

    var body: some View {
        IllustrationFrame(title: "RISK FALLS AS YOU DIVERSIFY",
                          caption: "Adding holdings cuts risk fast, then levels off around a dozen or two. Illustrative.") {
            Chart(data) { p in
                LineMark(x: .value("Holdings", p.holdings), y: .value("Risk", p.risk))
                    .foregroundStyle(AppColors.accent)
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis { AxisMarks(values: [1, 10, 20]) { v in
                AxisValueLabel { if let n = v.as(Int.self) { Text("\(n)") } }
            } }
            .chartYAxis(.hidden)
            .frame(height: 120)
        }
    }
}

/// Fee drag — two otherwise-identical portfolios diverging on fees alone.
struct FeeDragChart: View {
    private struct P: Identifiable { let id = UUID(); let year: Int; let value: Double; let series: String }
    private var data: [P] {
        var pts: [P] = []
        for y in 0...30 {
            pts.append(P(year: y, value: 10000 * pow(1.069, Double(y)), series: "0.1% fee"))
            pts.append(P(year: y, value: 10000 * pow(1.06, Double(y)), series: "1% fee"))
        }
        return pts
    }

    var body: some View {
        IllustrationFrame(title: "WHAT A 1% FEE COSTS OVER 30 YEARS",
                          caption: "Same market return; one keeps 0.1% in fees, the other 1%. The gap quietly compounds. Illustrative.") {
            Chart(data) { p in
                LineMark(x: .value("Year", p.year), y: .value("Value", p.value))
                    .foregroundStyle(by: .value("Fees", p.series))
                    .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale(["0.1% fee": AppColors.success, "1% fee": AppColors.error])
            .chartXAxis { AxisMarks(values: [0, 10, 20, 30]) { v in
                AxisValueLabel { if let y = v.as(Int.self) { Text("Yr \(y)") } }
            } }
            .chartYAxis(.hidden)
            .frame(height: 130)
        }
    }
}

/// Risk spectrum — where common assets sit from calm to wild.
struct RiskSpectrumBar: View {
    @Environment(\.colorScheme) var colorScheme
    private let items: [(name: String, frac: Double)] = [
        ("Cash", 0.04), ("Bonds", 0.20), ("Index funds", 0.42),
        ("Big-name stocks", 0.60), ("Bitcoin & Ethereum", 0.82), ("Small alt-coins", 0.96),
    ]
    private func color(_ f: Double) -> Color {
        if f < 0.4 { return AppColors.success }
        if f < 0.68 { return Color(hex: "EAB308") }
        return AppColors.error
    }
    private func word(_ f: Double) -> String {
        if f < 0.25 { return "Calm" }
        if f < 0.5 { return "Moderate" }
        if f < 0.72 { return "Elevated" }
        return "Wild"
    }

    var body: some View {
        IllustrationFrame(title: "THE RISK SPECTRUM",
                          caption: "Calmer at the top, wilder toward the bottom. Where an asset sits shapes how much to hold. Illustrative.") {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [AppColors.success, Color(hex: "EAB308"), AppColors.error], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                    .padding(.bottom, 10)
                ForEach(items, id: \.name) { item in
                    HStack(spacing: 10) {
                        Circle().fill(color(item.frac)).frame(width: 8, height: 8)
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Spacer()
                        Text(word(item.frac))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(color(item.frac))
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }
}

/// Dispatches a lesson's named illustration to the matching visual.
struct LessonIllustration: View {
    let name: String
    var body: some View {
        switch name {
        case "sample_allocation": SampleAllocationChart()
        case "compounding_curve": CompoundingChart()
        case "diversification_curve": DiversificationChart()
        case "fee_drag": FeeDragChart()
        case "risk_spectrum": RiskSpectrumBar()
        default: EmptyView()
        }
    }
}

/// Illustrative, role-based portfolio split shown inside the "How Much to Own"
/// worked-example lesson. Deliberately grouped by role (core / convictions /
/// speculative / cash) rather than tickers, and labelled as an illustration —
/// it teaches shape, not specific holdings, and is never a recommendation.
struct SampleAllocationChart: View {
    @Environment(\.colorScheme) var colorScheme

    private struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let pct: Double
        let color: Color
    }

    private let slices: [Slice] = [
        Slice(label: "Diversified core", pct: 50, color: AppColors.accent),
        Slice(label: "Small satellite bets", pct: 15, color: Color(hex: "10B981")),
        Slice(label: "Hedge (e.g. gold)", pct: 10, color: Color(hex: "EAB308")),
        Slice(label: "Cash cushion", pct: 25, color: AppColors.textSecondary),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accent)
                Text("AN ILLUSTRATIVE SPLIT")
                    .font(.system(size: 11, weight: .bold)).tracking(0.6)
                    .foregroundColor(AppColors.accent)
            }

            HStack(spacing: 16) {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Weight", slice.pct),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(slice.color)
                    .cornerRadius(3)
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(slices) { slice in
                        HStack(spacing: 8) {
                            Circle().fill(slice.color).frame(width: 8, height: 8)
                            Text(slice.label)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Spacer()
                            Text("\(Int(slice.pct))%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }

            Text("Illustration only, not a recommendation. Rough bands to show the shape, not exact targets.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color(hex: "F5F5F7"))
        )
    }
}

struct TrailLessonReaderView: View {
    let lessons: [TrailLesson]
    let startIndex: Int
    let onClose: () -> Void
    @State private var index: Int
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    init(lessons: [TrailLesson], startIndex: Int, onClose: @escaping () -> Void) {
        self.lessons = lessons
        self.startIndex = startIndex
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    private var lesson: TrailLesson { lessons[index] }
    private var isLast: Bool { index == lessons.count - 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("LESSON \(index + 1) OF \(lessons.count)")
                            .font(.system(size: 11, weight: .bold)).tracking(0.6)
                            .foregroundColor(AppColors.accent)

                        Text(lesson.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(lesson.idea)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)

                        if let illustration = lesson.illustration {
                            LessonIllustration(name: illustration)
                        }

                        if let seeInApp = lesson.seeInApp {
                            if let link = lesson.deepLink {
                                Button {
                                    openDeepLink(link)
                                } label: {
                                    calloutBox(icon: "sparkles", label: "SEE IT IN YOUR APP", text: seeInApp, tint: AppColors.accent, showsOpen: true)
                                }
                                .buttonStyle(.plain)
                            } else {
                                calloutBox(icon: "sparkles", label: "SEE IT IN YOUR APP", text: seeInApp, tint: AppColors.accent)
                            }
                        }

                        if let mindset = lesson.mindsetCheck {
                            calloutBox(icon: "brain.head.profile", label: "MINDSET CHECK", text: mindset, tint: Color(hex: "8B5CF6"))
                        }

                        // Takeaway
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                            Text(lesson.takeaway)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.success.opacity(colorScheme == .dark ? 0.12 : 0.08)))

                        if let more = lesson.oneMoreThing {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ONE MORE THING")
                                    .font(.system(size: 11, weight: .bold)).tracking(0.6)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(more)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Advance
                        Button {
                            TrailProgress.markComplete(lesson.trailKey, lesson.position)
                            if isLast {
                                onClose()
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
                            }
                        } label: {
                            Text(isLast ? "Finish" : "Next lesson")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        if index > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
                            } label: {
                                Text("← Previous lesson")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(20)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
    }

    @ViewBuilder
    private func calloutBox(icon: String, label: String, text: String, tint: Color, showsOpen: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .bold)).tracking(0.5)
            }
            .foregroundColor(tint)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            if showsOpen {
                HStack(spacing: 4) {
                    Text("Open in the app")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(colorScheme == .dark ? 0.12 : 0.07)))
    }

    private func openDeepLink(_ link: LessonDeepLink) {
        // Record the intent and close. MainTabView (the tab container, outside this
        // full-screen cover) runs the actual navigation once the cover is gone.
        appState.pendingLessonDeepLink = link
        onClose()
    }
}

// MARK: - Pilot's Checklist, Getting the most out of Arkline
//
// The companion to the Foundations trail. Where Foundations teaches investing,
// this teaches Arkline: a short list of habits that make the app do its job.
// Habits, not features. Process, not picks. Same calm-page format as the trail,
// and every step deep-links to the live surface it describes.
// Copy finalized in docs/PILOT_CHECKLIST_DRAFT.md.

struct ChecklistStep: Identifiable {
    let id: Int            // 1-based, also the display number and order
    let title: String
    let idea: String
    let doThis: String
    let takeaway: String
    let oneMoreThing: String?
    let deepLink: LessonDeepLink?
}

enum PilotChecklist {
    static let steps: [ChecklistStep] = [
        ChecklistStep(
            id: 1,
            title: "Make the home screen yours",
            idea: "The dashboard works best when it reflects what you actually own and care about. A screen full of noise is tiring to read. A screen built around your handful of assets is calm and quick to scan. You don't need everything switched on, just the things that help you.",
            doThis: "Add your core assets and turn off the widgets you don't use, so Home opens to a view that's yours.",
            takeaway: "A calm dashboard is one you built on purpose.",
            oneMoreThing: nil,
            deepLink: .customizeHome
        ),
        ChecklistStep(
            id: 2,
            title: "Set one DCA reminder, then let it run",
            idea: "The most useful habit in the app is also the simplest: invest a little, on a schedule, and stop trying to time the perfect moment. A reminder turns a good intention into a routine you don't have to think about. One is plenty to start.",
            doThis: "Create a DCA reminder for an asset you're comfortable holding, pick a rhythm that fits your budget, and let the app do the nudging.",
            takeaway: "Consistency beats timing. Set it once, let it work.",
            oneMoreThing: "You can pause or adjust it anytime. It's a helper, not a commitment.",
            deepLink: .dca
        ),
        ChecklistStep(
            id: 3,
            title: "Check in a few times a week",
            idea: "Prices move every second; your decisions shouldn't. Risk levels, signal changes, and announcements are here to give you context when you check in, not a feed to refresh all day. A good check-in takes about two minutes. Watching too closely tends to turn calm investors into anxious ones.",
            doThis: "Look in a few times a week. Glance at risk levels, any signal changes, and the latest announcements, then close the app.",
            takeaway: "A couple of minutes, a few times a week. That's the rhythm.",
            oneMoreThing: nil,
            deepLink: .cryptoRisk
        ),
        ChecklistStep(
            id: 4,
            title: "Read the room before you read the price",
            idea: "The Fear & Greed reading shows you the mood of the crowd. It won't tell you what to do, but knowing whether the market is fearful or greedy helps you notice when your own reaction is really just an echo of everyone else's.",
            doThis: "Before reacting to a big move, check where Fear & Greed sits. When the crowd is at an extreme, treat it as a cue to slow down, not speed up.",
            takeaway: "Notice the mood. Don't get swept up in it.",
            oneMoreThing: nil,
            deepLink: .fearGreed
        ),
        ChecklistStep(
            id: 5,
            title: "Keep the notifications that matter, mute the rest",
            idea: "The right notifications keep you informed without pulling you in. You want the ones that support your routine, like your DCA nudge and meaningful signal changes, and none of the ones that just add noise. Fewer, better pings keep the app calm.",
            doThis: "Open your notification settings, keep DCA reminders and signal changes on, and leave the rest off until you know you want them.",
            takeaway: "Let the app reach you when it counts, and stay quiet otherwise.",
            oneMoreThing: nil,
            deepLink: .settings
        ),
        ChecklistStep(
            id: 6,
            title: "When something's unclear, tap the “?”",
            idea: "You don't have to understand everything at once. Wherever you see a small “?”, it's a plain-English explanation of what you're looking at: what it is, what it means for you, and what it doesn't mean. Tapping it is how you learn the app as you go.",
            doThis: "Next time a number or signal isn't obvious, look for the “?” beside it and give it a tap.",
            takeaway: "The app teaches you in place. Curiosity is the whole skill.",
            oneMoreThing: nil,
            deepLink: .cryptoRisk
        ),
        ChecklistStep(
            id: 7,
            title: "Follow along with From the Desk",
            idea: "The posts in your Insights tab under “From the Desk” are me walking alongside you: context on what's happening, why it matters, and how to think about it without the panic. Reading them regularly is what turns the app from a dashboard into a copilot.",
            doThis: "Make a habit of opening the Insights tab and reading the latest post.",
            takeaway: "You're not doing this alone.",
            oneMoreThing: nil,
            deepLink: .learn
        ),
    ]

    private static let completedKey = "pilot_checklist_completed_v1"

    static func completedIDs() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: completedKey) as? [Int] ?? [])
    }

    static func markComplete(_ id: Int) {
        var set = completedIDs()
        set.insert(id)
        UserDefaults.standard.set(Array(set).sorted(), forKey: completedKey)
    }

    /// Array index of the first not-yet-completed step (0 if all done, review).
    static var firstIncompleteIndex: Int {
        let done = completedIDs()
        return steps.firstIndex(where: { !done.contains($0.id) }) ?? 0
    }
}

// Wrapper so the reader can be presented via .fullScreenCover(item:)
private struct ChecklistStart: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Checklist Overview

struct PilotChecklistView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var completed: Set<Int> = PilotChecklist.completedIDs()
    @State private var start: ChecklistStart? = nil

    private var doneCount: Int { completed.count }
    private var total: Int { PilotChecklist.steps.count }

    private var continueLabel: String {
        if doneCount == 0 { return "Start" }
        if doneCount >= total { return "Review" }
        return "Continue"
    }

    private var rows: [PathRow] {
        let current = PilotChecklist.firstIncompleteIndex
        return Array(PilotChecklist.steps.enumerated()).map { idx, step in
            let state: PathNodeState = completed.contains(step.id)
                ? .done
                : (idx == current && doneCount < total ? .current : .upcoming)
            return PathRow(id: step.id, index: idx, title: step.title, preview: Self.preview(step.id), state: state)
        }
    }

    private static func preview(_ id: Int) -> String {
        switch id {
        case 1: return "Build Home around what you own"
        case 2: return "Set it once, let it run"
        case 3: return "Two minutes, a few times a week"
        case 4: return "Notice the mood, stay calm"
        case 5: return "Keep the pings that matter"
        case 6: return "Learn in place as you go"
        case 7: return "I'm walking alongside you"
        default: return ""
        }
    }

    var body: some View {
        GuidedPathScaffold(
            eyebrow: "PILOT'S CHECKLIST",
            intro: "A short list of habits that make Arkline work for you. Small things, big difference. Go at your own pace.",
            doneCount: doneCount,
            total: total,
            upNextTitle: PilotChecklist.steps[PilotChecklist.firstIncompleteIndex].title,
            continueLabel: continueLabel,
            rows: rows,
            onContinue: { start = ChecklistStart(index: PilotChecklist.firstIncompleteIndex) },
            onTapRow: { idx in start = ChecklistStart(index: idx) }
        )
        .navigationTitle("Get the Most Out")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .fullScreenCover(item: $start) { s in
            ChecklistStepReaderView(startIndex: s.index) {
                completed = PilotChecklist.completedIDs()
                start = nil
            }
        }
    }
}

// MARK: - Checklist Step Reader (the calm page)

struct ChecklistStepReaderView: View {
    let startIndex: Int
    let onClose: () -> Void
    @State private var index: Int
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    init(startIndex: Int, onClose: @escaping () -> Void) {
        self.startIndex = startIndex
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    private var steps: [ChecklistStep] { PilotChecklist.steps }
    private var step: ChecklistStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("STEP \(index + 1) OF \(steps.count)")
                            .font(.system(size: 11, weight: .bold)).tracking(0.6)
                            .foregroundColor(AppColors.accent)

                        Text(step.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(step.idea)
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(3)

                        if let link = step.deepLink {
                            Button {
                                // Record intent; MainTabView navigates after the
                                // reader cover dismisses.
                                appState.pendingLessonDeepLink = link
                                onClose()
                            } label: {
                                calloutBox(icon: "checklist", label: "DO THIS", text: step.doThis, tint: AppColors.accent, showsOpen: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            calloutBox(icon: "checklist", label: "DO THIS", text: step.doThis, tint: AppColors.accent)
                        }

                        // Takeaway
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.success)
                            Text(step.takeaway)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.success.opacity(colorScheme == .dark ? 0.12 : 0.08)))

                        if let more = step.oneMoreThing {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("ONE MORE THING")
                                    .font(.system(size: 11, weight: .bold)).tracking(0.6)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(more)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // Advance
                        Button {
                            PilotChecklist.markComplete(step.id)
                            if isLast {
                                onClose()
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
                            }
                        } label: {
                            Text(isLast ? "Done" : "Next")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        if index > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
                            } label: {
                                Text("← Previous")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(20)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
    }

    @ViewBuilder
    private func calloutBox(icon: String, label: String, text: String, tint: Color, showsOpen: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .bold)).tracking(0.5)
            }
            .foregroundColor(tint)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
            if showsOpen {
                HStack(spacing: 4) {
                    Text("Open in the app")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(colorScheme == .dark ? 0.12 : 0.07)))
    }
}

// MARK: - Start Here, Home entry card
//
// Makes the trail findable where a beginner is actually looking. Sits near the
// top of Home, opens the trail directly, and quietly steps aside once someone
// finishes it, or is dismissed (so long-time users aren't nagged forever).

// MARK: - Start Here — one-time intro cover for brand-new users
//
// Presented once by MainTabView right after onboarding. Drops the newcomer
// straight into the Start Here overview (already a calm, self-explanatory
// landing) with a clear way out, so nobody feels trapped.

struct StartHereIntroCover: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            // Drop a brand-new user onto the first step of the guided path
            // (Before You Invest) rather than a hardcoded trail, so onboarding
            // hands off straight into "step 1" of the curriculum.
            TrailOverviewView(kind: Curriculum.nextLesson()?.kind ?? .beforeInvesting)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { onClose() }
                    }
                }
        }
    }
}

// MARK: - Your Path (curriculum-level guided map)

/// A single connected map of the whole curriculum: every trail as a node with
/// completed / current / upcoming state, so the library reads as one journey.
struct CurriculumPathView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var version = 0

    private var overall: (done: Int, total: Int) { Curriculum.overall() }
    private var nextKind: TrailKind? { Curriculum.nextLesson()?.kind }

    var body: some View {
        _ = version
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                VStack(spacing: 0) {
                    ForEach(Array(Curriculum.path.enumerated()), id: \.offset) { idx, kind in
                        NavigationLink { TrailOverviewView(kind: kind) } label: {
                            nodeRow(kind, isLast: idx == Curriculum.path.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Your Path")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .trailProgressChanged)) { _ in version += 1 }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                let pct = overall.total > 0 ? Double(overall.done) / Double(overall.total) : 0
                Circle().stroke(AppColors.accent.opacity(0.15), lineWidth: 5)
                Circle().trim(from: 0, to: pct)
                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR LEARNING PATH")
                    .font(.system(size: 10, weight: .bold)).tracking(0.6)
                    .foregroundColor(AppColors.accent)
                Text("\(overall.done) of \(overall.total) lessons complete")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text("A calm, ordered path. Go at your own pace.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }

    private func nodeRow(_ kind: TrailKind, isLast: Bool) -> some View {
        let status = Curriculum.status(for: kind)
        let isCurrent = kind == nextKind
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                statusCircle(status, isCurrent: isCurrent)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.divider(colorScheme))
                        .frame(width: 2, height: 34)
                }
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kind.navTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1).minimumScaleFactor(0.85)
                    if isCurrent {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .bold)).tracking(0.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent))
                    }
                }
                Text(statusText(kind, status))
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, 4)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
                .padding(.top, 8)
        }
        .padding(.bottom, isLast ? 4 : 0)
    }

    @ViewBuilder
    private func statusCircle(_ status: Curriculum.TrailStatus, isCurrent: Bool) -> some View {
        ZStack {
            switch status {
            case .complete:
                Circle().fill(AppColors.success)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            case .inProgress, .notStarted:
                if isCurrent {
                    Circle().fill(AppColors.accent)
                    Image(systemName: "play.fill").font(.system(size: 11)).foregroundColor(.white)
                } else {
                    Circle().stroke(AppColors.divider(colorScheme), lineWidth: 2)
                    if case .inProgress = status {
                        Circle().fill(AppColors.accent).frame(width: 10, height: 10)
                    }
                }
            }
        }
        .frame(width: 30, height: 30)
    }

    private func statusText(_ kind: TrailKind, _ status: Curriculum.TrailStatus) -> String {
        switch status {
        case .complete: return "Complete"
        case .inProgress(let done, let total): return "\(done) of \(total) lessons"
        case .notStarted: return "\(kind.seed.count) lessons · \(kind.difficulty.label)"
        }
    }
}

struct StartHereHomeCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var dismissed: Bool = UserDefaults.standard.bool(forKey: "start_here_home_dismissed_v1")
    // Done-count per trail, in order. Refreshed on appear so the card advances
    // as the person finishes trails, instead of just disappearing.
    @State private var progressSig: [Int] = StartHereHomeCard.signature()

    /// Signature over the full curriculum so the card refreshes as any trail
    /// advances, and stays in lock-step with the Insights "Continue" card.
    static func signature() -> [Int] {
        Curriculum.path.map { TrailProgress.completed($0.rawValue).count }
    }

    /// The next lesson in the shared curriculum path, or nil once all are done.
    /// Same source of truth as the Insights Lessons list, so Home and Insights
    /// always agree on "what's next."
    private var selection: (kind: TrailKind, done: Int, total: Int)? {
        _ = progressSig
        guard let next = Curriculum.nextLesson() else { return nil }
        return (next.kind, TrailProgress.completed(next.kind.rawValue).count, next.kind.seed.count)
    }

    var body: some View {
        if !dismissed, let next = selection {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    TrailOverviewView(kind: next.kind)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: icon(next.kind))
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(headline(next.kind, done: next.done))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Text(subtitle(next.kind, done: next.done, total: next.total))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 20)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground(colorScheme)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Dismiss (sibling of the NavigationLink so taps don't conflict)
                Button {
                    dismissed = true
                    UserDefaults.standard.set(true, forKey: "start_here_home_dismissed_v1")
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        .padding(7)
                }
                .buttonStyle(.plain)
            }
            .onAppear { progressSig = StartHereHomeCard.signature() }
            .onReceive(NotificationCenter.default.publisher(for: .trailProgressChanged)) { _ in
                progressSig = StartHereHomeCard.signature()
            }
        }
    }

    private func icon(_ kind: TrailKind) -> String {
        switch kind {
        case .beforeInvesting: return "checklist"
        case .foundations: return "signpost.right.fill"
        case .behavioral: return "brain.head.profile"
        case .scams: return "exclamationmark.shield.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .markets: return "chart.line.uptrend.xyaxis"
        case .trading: return "arrow.left.arrow.right"
        case .macro: return "building.columns.fill"
        case .hedging: return "shield.lefthalf.filled"
        case .fees: return "percent"
        case .sizing: return "scalemass.fill"
        }
    }

    private func headline(_ kind: TrailKind, done: Int) -> String {
        switch kind {
        case .beforeInvesting:
            return done == 0 ? "First things first: Before You Invest" : "Continue: Before You Invest"
        case .foundations:
            return done == 0 ? "New to investing? Start here." : "Continue learning the basics"
        case .behavioral:
            return done == 0 ? "Go deeper: Your Brain vs Your Money" : "Continue: Your Brain vs Your Money"
        case .scams:
            return done == 0 ? "Go deeper: Spotting Scams" : "Continue: Spotting Scams"
        case .crypto:
            return done == 0 ? "Ready for more? Understanding Crypto" : "Continue: Understanding Crypto"
        case .markets:
            return done == 0 ? "Keep going: Understanding the Markets" : "Continue: Understanding the Markets"
        case .trading:
            return done == 0 ? "Go deeper: Trading vs Investing" : "Continue: Trading vs Investing"
        case .macro:
            return done == 0 ? "Go deeper: Understanding Macro" : "Continue: Understanding Macro"
        case .hedging:
            return done == 0 ? "Go deeper: Understanding Hedges" : "Continue: Understanding Hedges"
        case .fees:
            return done == 0 ? "Go deeper: Fees & Taxes" : "Continue: Fees & Taxes"
        case .sizing:
            return done == 0 ? "Go deeper: How Much to Own" : "Continue: How Much to Own"
        }
    }

    private func subtitle(_ kind: TrailKind, done: Int, total: Int) -> String {
        if done > 0 { return "\(done) of \(total) lessons complete." }
        switch kind {
        case .beforeInvesting: return "The groundwork that comes first."
        case .foundations: return "A calm, self-paced path through the foundations."
        case .behavioral: return "The mental traps, and how to beat them."
        case .scams: return "Protect yourself and your money."
        case .crypto: return "You've got the basics. Go deeper on crypto."
        case .markets: return "Next up: how stocks and markets work."
        case .trading: return "Trading and investing, and the real risks of each."
        case .macro: return "The Fed, rates, and the economic cycle."
        case .hedging: return "Gold, silver, and oil, and how hedges work."
        case .fees: return "Fees, spreads, and taxes, and keeping them low."
        case .sizing: return "How much of each to own, and why it matters."
        }
    }
}
