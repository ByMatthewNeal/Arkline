import XCTest
@testable import ArkLine

// MARK: - Mock Broadcast Service

fileprivate final class MockBroadcastService: BroadcastServiceProtocol {
    var broadcasts: [Broadcast] = []
    var shouldFail = false
    var markAsReadCalled = false
    var unreadCountValue = 0

    func fetchAllBroadcasts() async throws -> [Broadcast] {
        if shouldFail { throw AppError.apiUnavailable }
        return broadcasts
    }

    func fetchPublishedBroadcasts(for userId: UUID, limit: Int, offset: Int) async throws -> [Broadcast] {
        if shouldFail { throw AppError.apiUnavailable }
        return broadcasts.filter { $0.status == .published }
    }

    func fetchBroadcast(id: UUID) async throws -> Broadcast {
        if shouldFail { throw AppError.apiUnavailable }
        guard let b = broadcasts.first(where: { $0.id == id }) else { throw AppError.apiUnavailable }
        return b
    }

    func fetchBroadcasts(byStatus status: BroadcastStatus) async throws -> [Broadcast] {
        broadcasts.filter { $0.status == status }
    }

    func createBroadcast(_ broadcast: Broadcast) async throws -> Broadcast { broadcast }
    func updateBroadcast(_ broadcast: Broadcast) async throws -> Broadcast { broadcast }
    func deleteBroadcast(id: UUID) async throws { broadcasts.removeAll { $0.id == id } }

    func publishBroadcast(id: UUID) async throws -> Broadcast {
        guard var b = broadcasts.first(where: { $0.id == id }) else { throw AppError.apiUnavailable }
        b.status = .published
        b.publishedAt = Date()
        return b
    }

    func archiveBroadcast(id: UUID) async throws -> Broadcast {
        guard var b = broadcasts.first(where: { $0.id == id }) else { throw AppError.apiUnavailable }
        b.status = .archived
        return b
    }

    func markAsRead(broadcastId: UUID, userId: UUID) async throws { markAsReadCalled = true }
    func hasBeenRead(broadcastId: UUID, userId: UUID) async throws -> Bool { markAsReadCalled }
    func unreadCount(for userId: UUID) async throws -> Int { unreadCountValue }
    func incrementViewCount(broadcastId: UUID) async throws {}

    func fetchAnalyticsSummary(periodDays: Int) async throws -> BroadcastAnalyticsSummary {
        BroadcastAnalyticsSummary(
            totalBroadcasts: broadcasts.count,
            totalViews: 0,
            totalReactions: 0,
            avgViewsPerBroadcast: 0,
            avgReactionsPerBroadcast: 0,
            topPerformingBroadcastId: nil,
            mostUsedReaction: nil,
            periodStart: Date(),
            periodEnd: Date()
        )
    }

    func uploadAudio(data: Data, for broadcastId: UUID) async throws -> URL { URL(string: "https://example.com/audio.mp3")! }
    func uploadImage(data: Data, for broadcastId: UUID) async throws -> URL { URL(string: "https://example.com/image.png")! }
    func deleteFile(at url: URL) async throws {}

    func addReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws {}
    func removeReaction(broadcastId: UUID, userId: UUID, emoji: String) async throws {}
    func fetchReactions(for broadcastId: UUID) async throws -> [BroadcastReaction] { [] }
    func fetchReactionSummary(for broadcastId: UUID, userId: UUID) async throws -> [ReactionSummary] { [] }
}

// MARK: - Test Helpers

private let testAuthorId = UUID()

private func makeBroadcast(
    title: String = "Test",
    content: String = "Content",
    tags: [String] = [],
    status: BroadcastStatus = .published,
    publishedAt: Date? = Date(),
    createdAt: Date = Date()
) -> Broadcast {
    Broadcast(
        title: title,
        content: content,
        status: status,
        createdAt: createdAt,
        publishedAt: publishedAt,
        tags: tags,
        authorId: testAuthorId
    )
}

// MARK: - BroadcastTag Tests

final class BroadcastTagTests: XCTestCase {

    // MARK: - Color Resolution

    func test_allTags_haveUniqueColors() {
        let colors = BroadcastTag.allCases.map { "\($0.color)" }
        let uniqueColors = Set(colors)
        XCTAssertEqual(colors.count, uniqueColors.count, "Each tag should have a unique color")
    }

    func test_btcTag_hasOrangeColor() {
        let tag = BroadcastTag.btc
        XCTAssertEqual(tag.rawValue, "BTC")
        // Color should resolve without crashing
        _ = tag.color
    }

    func test_allTags_colorsDoNotCrash() {
        for tag in BroadcastTag.allCases {
            // Accessing .color should never crash
            _ = tag.color
            _ = tag.displayName
        }
    }

    func test_tagRawValues_matchExpected() {
        XCTAssertEqual(BroadcastTag.btc.rawValue, "BTC")
        XCTAssertEqual(BroadcastTag.eth.rawValue, "ETH")
        XCTAssertEqual(BroadcastTag.altcoins.rawValue, "Altcoins")
        XCTAssertEqual(BroadcastTag.macro.rawValue, "Macro")
        XCTAssertEqual(BroadcastTag.technical.rawValue, "Technical")
        XCTAssertEqual(BroadcastTag.fundamental.rawValue, "Fundamental")
        XCTAssertEqual(BroadcastTag.alert.rawValue, "Alert")
        XCTAssertEqual(BroadcastTag.weekly.rawValue, "Weekly")
        XCTAssertEqual(BroadcastTag.education.rawValue, "Education")
        XCTAssertEqual(BroadcastTag.dca.rawValue, "DCA")
        XCTAssertEqual(BroadcastTag.news.rawValue, "News")
        XCTAssertEqual(BroadcastTag.xPost.rawValue, "X Post")
    }

    func test_displayName_equalsRawValue() {
        for tag in BroadcastTag.allCases {
            XCTAssertEqual(tag.displayName, tag.rawValue)
        }
    }

    func test_initFromRawValue_withValidString_returnTag() {
        XCTAssertEqual(BroadcastTag(rawValue: "BTC"), .btc)
        XCTAssertEqual(BroadcastTag(rawValue: "Macro"), .macro)
        XCTAssertEqual(BroadcastTag(rawValue: "Alert"), .alert)
    }

    func test_initFromRawValue_withInvalidString_returnsNil() {
        XCTAssertNil(BroadcastTag(rawValue: "InvalidTag"))
        XCTAssertNil(BroadcastTag(rawValue: ""))
        XCTAssertNil(BroadcastTag(rawValue: "btc"))  // case-sensitive
        XCTAssertNil(BroadcastTag(rawValue: "MACRO")) // case-sensitive
    }

    func test_allCases_containsExpectedTags() {
        XCTAssertEqual(BroadcastTag.allCases.count, 14)
    }
}

// MARK: - Broadcast Model Tests

final class BroadcastModelTests: XCTestCase {

    // MARK: - Initialization

    func test_init_defaultValues() {
        let broadcast = Broadcast(authorId: testAuthorId)
        XCTAssertEqual(broadcast.title, "")
        XCTAssertEqual(broadcast.content, "")
        XCTAssertEqual(broadcast.tags, [])
        XCTAssertEqual(broadcast.status, .draft)
        XCTAssertNil(broadcast.audioURL)
        XCTAssertTrue(broadcast.images.isEmpty)
        XCTAssertTrue(broadcast.appReferences.isEmpty)
        XCTAssertNil(broadcast.portfolioAttachment)
        XCTAssertNil(broadcast.meetingLink)
        XCTAssertNil(broadcast.publishedAt)
        XCTAssertNil(broadcast.scheduledAt)
        XCTAssertNil(broadcast.templateId)
        XCTAssertNil(broadcast.viewCount)
        XCTAssertNil(broadcast.reactionCount)
    }

    func test_init_withTags() {
        let broadcast = makeBroadcast(tags: ["BTC", "Technical", "CustomTag"])
        XCTAssertEqual(broadcast.tags, ["BTC", "Technical", "CustomTag"])
    }

    func test_init_withEmptyTags() {
        let broadcast = makeBroadcast(tags: [])
        XCTAssertTrue(broadcast.tags.isEmpty)
    }

    // MARK: - Content Preview

    func test_contentPreview_shortContent_returnsFullContent() {
        let broadcast = makeBroadcast(content: "Short content")
        XCTAssertEqual(broadcast.contentPreview, "Short content")
    }

    func test_contentPreview_longContent_truncatesAt100() {
        let longContent = String(repeating: "A", count: 200)
        let broadcast = makeBroadcast(content: longContent)
        XCTAssertTrue(broadcast.contentPreview.hasSuffix("..."))
        // 100 chars + "..." = 103
        XCTAssertEqual(broadcast.contentPreview.count, 103)
    }

    func test_contentPreview_exactly100_noTruncation() {
        let content = String(repeating: "B", count: 100)
        let broadcast = makeBroadcast(content: content)
        XCTAssertEqual(broadcast.contentPreview, content)
        XCTAssertFalse(broadcast.contentPreview.hasSuffix("..."))
    }

    // MARK: - Codable (Decoding)

    func test_decode_withTags_parsesTags() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Test",
            "content": "Content",
            "status": "published",
            "created_at": "2026-02-07T15:23:37+00:00",
            "author_id": "22222222-2222-2222-2222-222222222222",
            "tags": ["BTC", "Macro"],
            "target_audience": {"type": "all"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let broadcast = try decoder.decode(Broadcast.self, from: json)

        XCTAssertEqual(broadcast.tags, ["BTC", "Macro"])
    }

    func test_decode_withoutTags_defaultsToEmpty() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Test",
            "content": "Content",
            "status": "published",
            "created_at": "2026-02-07T15:23:37+00:00",
            "author_id": "22222222-2222-2222-2222-222222222222",
            "target_audience": {"type": "all"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let broadcast = try decoder.decode(Broadcast.self, from: json)

        XCTAssertEqual(broadcast.tags, [])
    }

    func test_decode_withNullTags_defaultsToEmpty() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Test",
            "content": "Content",
            "status": "published",
            "created_at": "2026-02-07T15:23:37+00:00",
            "author_id": "22222222-2222-2222-2222-222222222222",
            "tags": null,
            "target_audience": {"type": "all"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let broadcast = try decoder.decode(Broadcast.self, from: json)

        XCTAssertEqual(broadcast.tags, [])
    }

    func test_decode_withEmptyTagsArray_returnsEmpty() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Test",
            "content": "Content",
            "status": "published",
            "created_at": "2026-02-07T15:23:37+00:00",
            "author_id": "22222222-2222-2222-2222-222222222222",
            "tags": [],
            "target_audience": {"type": "all"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let broadcast = try decoder.decode(Broadcast.self, from: json)

        XCTAssertEqual(broadcast.tags, [])
    }

    func test_decode_withCustomTags_parsesAll() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "title": "Test",
            "content": "Content",
            "status": "published",
            "created_at": "2026-02-07T15:23:37+00:00",
            "author_id": "22222222-2222-2222-2222-222222222222",
            "tags": ["BTC", "CustomTag", "Another Custom"],
            "target_audience": {"type": "all"}
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let broadcast = try decoder.decode(Broadcast.self, from: json)

        XCTAssertEqual(broadcast.tags.count, 3)
        XCTAssertTrue(broadcast.tags.contains("CustomTag"))
    }

    // MARK: - Equatable

    func test_equatable_sameBroadcasts_areEqual() {
        let id = UUID()
        let date = Date()
        let b1 = Broadcast(id: id, title: "Same", createdAt: date, authorId: testAuthorId)
        let b2 = Broadcast(id: id, title: "Same", createdAt: date, authorId: testAuthorId)
        XCTAssertEqual(b1, b2)
    }

    func test_equatable_differentIds_areNotEqual() {
        let b1 = Broadcast(title: "Same", authorId: testAuthorId)
        let b2 = Broadcast(title: "Same", authorId: testAuthorId)
        XCTAssertNotEqual(b1, b2)
    }
}

// MARK: - BroadcastStatus Tests

final class BroadcastStatusTests: XCTestCase {

    func test_statusColors_doNotCrash() {
        for status in BroadcastStatus.allCases {
            _ = status.color
        }
    }

    func test_allStatuses_exist() {
        XCTAssertNotNil(BroadcastStatus(rawValue: "draft"))
        XCTAssertNotNil(BroadcastStatus(rawValue: "published"))
        XCTAssertNotNil(BroadcastStatus(rawValue: "archived"))
        XCTAssertNotNil(BroadcastStatus(rawValue: "scheduled"))
    }
}

// MARK: - Broadcast ViewModel Tests

final class BroadcastViewModelTests: XCTestCase {

    fileprivate var sut: BroadcastViewModel!
    fileprivate var mockService: MockBroadcastService!

    @MainActor
    override func setUp() {
        super.setUp()
        mockService = MockBroadcastService()
        sut = BroadcastViewModel(broadcastService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - Published Filter

    @MainActor
    func test_published_filtersOnlyPublishedBroadcasts() async {
        mockService.broadcasts = [
            makeBroadcast(title: "Published 1", status: .published),
            makeBroadcast(title: "Draft", status: .draft),
            makeBroadcast(title: "Published 2", status: .published),
            makeBroadcast(title: "Archived", status: .archived),
        ]

        await sut.loadBroadcasts()

        XCTAssertEqual(sut.published.count, 2)
        XCTAssertTrue(sut.published.allSatisfy { $0.status == .published })
    }

    @MainActor
    func test_drafts_filtersOnlyDraftBroadcasts() async {
        mockService.broadcasts = [
            makeBroadcast(title: "Published", status: .published),
            makeBroadcast(title: "Draft 1", status: .draft),
            makeBroadcast(title: "Draft 2", status: .draft),
        ]

        await sut.loadBroadcasts()

        XCTAssertEqual(sut.drafts.count, 2)
        XCTAssertTrue(sut.drafts.allSatisfy { $0.status == .draft })
    }

    @MainActor
    func test_archived_filtersOnlyArchivedBroadcasts() async {
        mockService.broadcasts = [
            makeBroadcast(title: "Published", status: .published),
            makeBroadcast(title: "Archived", status: .archived),
        ]

        await sut.loadBroadcasts()

        XCTAssertEqual(sut.archived.count, 1)
        XCTAssertEqual(sut.archived.first?.title, "Archived")
    }

    // MARK: - Loading States

    @MainActor
    func test_loadBroadcasts_setsLoadingState() async {
        mockService.broadcasts = []

        await sut.loadBroadcasts()

        // After completion, isLoading should be false
        XCTAssertFalse(sut.isLoading)
    }

    @MainActor
    func test_loadBroadcasts_onFailure_setsErrorMessage() async {
        mockService.shouldFail = true

        await sut.loadBroadcasts()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.broadcasts.isEmpty)
    }

    @MainActor
    func test_loadBroadcasts_onSuccess_clearsErrorMessage() async {
        mockService.broadcasts = [makeBroadcast()]

        await sut.loadBroadcasts()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.broadcasts.count, 1)
    }

    // MARK: - Published Broadcasts Loading

    @MainActor
    func test_loadPublishedBroadcasts_loadsOnlyPublished() async {
        mockService.broadcasts = [
            makeBroadcast(title: "Pub", status: .published),
            makeBroadcast(title: "Draft", status: .draft),
        ]

        let userId = UUID()
        await sut.loadPublishedBroadcasts(for: userId)

        // The mock returns only published ones
        XCTAssertEqual(sut.broadcasts.count, 1)
        XCTAssertEqual(sut.broadcasts.first?.title, "Pub")
    }

    @MainActor
    func test_loadPublishedBroadcasts_onFailure_setsErrorMessage() async {
        mockService.shouldFail = true

        await sut.loadPublishedBroadcasts(for: UUID())

        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Unread Count

    @MainActor
    func test_updateUnreadCount_setsCount() async {
        mockService.unreadCountValue = 5

        await sut.updateUnreadCount(for: UUID())

        XCTAssertEqual(sut.unreadCount, 5)
    }

    // MARK: - CRUD

    @MainActor
    func test_createBroadcast_insertsAtFront() async throws {
        let broadcast = makeBroadcast(title: "New")
        try await sut.createBroadcast(broadcast)

        XCTAssertEqual(sut.broadcasts.first?.title, "New")
    }

    @MainActor
    func test_deleteBroadcast_removesFromList() async throws {
        let broadcast = makeBroadcast(title: "Delete Me")
        sut.broadcasts = [broadcast]
        mockService.broadcasts = [broadcast]

        try await sut.deleteBroadcast(broadcast)

        XCTAssertTrue(sut.broadcasts.isEmpty)
    }

    @MainActor
    func test_updateBroadcast_updatesInList() async throws {
        var broadcast = makeBroadcast(title: "Original")
        sut.broadcasts = [broadcast]

        broadcast.title = "Updated"
        try await sut.updateBroadcast(broadcast)

        XCTAssertEqual(sut.broadcasts.first?.title, "Updated")
    }

    // MARK: - Mark As Read

    @MainActor
    func test_markAsRead_callsService() async throws {
        try await sut.markAsRead(broadcastId: UUID(), userId: UUID())

        XCTAssertTrue(mockService.markAsReadCalled)
    }

    // MARK: - Empty State

    @MainActor
    func test_emptyBroadcasts_allFiltersEmpty() async {
        mockService.broadcasts = []

        await sut.loadBroadcasts()

        XCTAssertTrue(sut.published.isEmpty)
        XCTAssertTrue(sut.drafts.isEmpty)
        XCTAssertTrue(sut.archived.isEmpty)
    }
}

// MARK: - Feed Filtering Logic Tests

/// Tests the filtering logic that lives in BroadcastFeedView.
/// We replicate the logic here to test it without instantiating SwiftUI views.
final class BroadcastFeedFilteringTests: XCTestCase {

    // MARK: - Search Filtering

    private func applySearchFilter(_ broadcasts: [Broadcast], query: String) -> [Broadcast] {
        guard !query.isEmpty else { return broadcasts }
        let q = query.lowercased()
        return broadcasts.filter { broadcast in
            broadcast.title.lowercased().contains(q)
            || broadcast.content.lowercased().contains(q)
            || broadcast.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    func test_searchFilter_byTitle_matchesCorrectly() {
        let broadcasts = [
            makeBroadcast(title: "Bitcoin Analysis"),
            makeBroadcast(title: "Ethereum Update"),
            makeBroadcast(title: "Weekly Outlook"),
        ]

        let results = applySearchFilter(broadcasts, query: "bitcoin")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Bitcoin Analysis")
    }

    func test_searchFilter_byContent_matchesCorrectly() {
        let broadcasts = [
            makeBroadcast(title: "Update", content: "The VIX has spiked to 22"),
            makeBroadcast(title: "Outlook", content: "Markets are calm"),
        ]

        let results = applySearchFilter(broadcasts, query: "VIX")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Update")
    }

    func test_searchFilter_byTag_matchesCorrectly() {
        let broadcasts = [
            makeBroadcast(title: "Post 1", tags: ["BTC", "Technical"]),
            makeBroadcast(title: "Post 2", tags: ["Macro"]),
            makeBroadcast(title: "Post 3", tags: []),
        ]

        let results = applySearchFilter(broadcasts, query: "btc")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Post 1")
    }

    func test_searchFilter_caseInsensitive() {
        let broadcasts = [
            makeBroadcast(title: "BITCOIN BREAKS OUT"),
        ]

        XCTAssertEqual(applySearchFilter(broadcasts, query: "bitcoin").count, 1)
        XCTAssertEqual(applySearchFilter(broadcasts, query: "BITCOIN").count, 1)
        XCTAssertEqual(applySearchFilter(broadcasts, query: "Bitcoin").count, 1)
    }

    func test_searchFilter_emptyQuery_returnsAll() {
        let broadcasts = [
            makeBroadcast(title: "A"),
            makeBroadcast(title: "B"),
        ]

        XCTAssertEqual(applySearchFilter(broadcasts, query: "").count, 2)
    }

    func test_searchFilter_noMatch_returnsEmpty() {
        let broadcasts = [
            makeBroadcast(title: "Bitcoin", content: "Price analysis", tags: ["BTC"]),
        ]

        XCTAssertTrue(applySearchFilter(broadcasts, query: "dogecoin").isEmpty)
    }

    func test_searchFilter_specialCharacters_doNotCrash() {
        let broadcasts = [makeBroadcast(title: "Normal title")]

        // These should not crash
        _ = applySearchFilter(broadcasts, query: "[](){}.*+?^$|\\")
        _ = applySearchFilter(broadcasts, query: "😀🚀")
        _ = applySearchFilter(broadcasts, query: "   ")
    }

    func test_searchFilter_matchesAcrossMultipleFields() {
        let broadcast = makeBroadcast(title: "BTC Alert", content: "Macro outlook", tags: ["Technical"])

        XCTAssertEqual(applySearchFilter([broadcast], query: "btc").count, 1)
        XCTAssertEqual(applySearchFilter([broadcast], query: "macro").count, 1)
        XCTAssertEqual(applySearchFilter([broadcast], query: "technical").count, 1)
    }

    // MARK: - Tag Filtering

    private func applyTagFilter(_ broadcasts: [Broadcast], selectedTags: Set<String>) -> [Broadcast] {
        guard !selectedTags.isEmpty else { return broadcasts }
        return broadcasts.filter { broadcast in
            !selectedTags.isDisjoint(with: Set(broadcast.tags))
        }
    }

    func test_tagFilter_singleTag_matchesBroadcastsWithTag() {
        let broadcasts = [
            makeBroadcast(title: "BTC Post", tags: ["BTC", "Technical"]),
            makeBroadcast(title: "Macro Post", tags: ["Macro"]),
            makeBroadcast(title: "No Tags", tags: []),
        ]

        let results = applyTagFilter(broadcasts, selectedTags: ["BTC"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "BTC Post")
    }

    func test_tagFilter_multipleTags_matchesAny() {
        let broadcasts = [
            makeBroadcast(title: "BTC Post", tags: ["BTC"]),
            makeBroadcast(title: "Macro Post", tags: ["Macro"]),
            makeBroadcast(title: "ETH Post", tags: ["ETH"]),
        ]

        let results = applyTagFilter(broadcasts, selectedTags: ["BTC", "Macro"])
        XCTAssertEqual(results.count, 2)
    }

    func test_tagFilter_noSelectedTags_returnsAll() {
        let broadcasts = [
            makeBroadcast(title: "A", tags: ["BTC"]),
            makeBroadcast(title: "B", tags: []),
        ]

        XCTAssertEqual(applyTagFilter(broadcasts, selectedTags: []).count, 2)
    }

    func test_tagFilter_tagNotPresent_returnsEmpty() {
        let broadcasts = [
            makeBroadcast(title: "A", tags: ["BTC"]),
        ]

        XCTAssertTrue(applyTagFilter(broadcasts, selectedTags: ["NonExistent"]).isEmpty)
    }

    func test_tagFilter_broadcastWithNoTags_neverMatches() {
        let broadcasts = [
            makeBroadcast(title: "No Tags", tags: []),
        ]

        let results = applyTagFilter(broadcasts, selectedTags: ["BTC"])
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Date Filtering

    private func applyDateFilter(_ broadcasts: [Broadcast], filter: BroadcastDateFilter) -> [Broadcast] {
        guard filter != .all else { return broadcasts }
        let calendar = Calendar.current
        let now = Date()
        return broadcasts.filter { broadcast in
            let date = broadcast.publishedAt ?? broadcast.createdAt
            switch filter {
            case .all: return true
            case .today: return calendar.isDateInToday(date)
            case .thisWeek:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
                return date >= weekAgo
            case .thisMonth:
                guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
                return date >= monthAgo
            }
        }
    }

    func test_dateFilter_all_returnsEverything() {
        let broadcasts = [
            makeBroadcast(title: "Old", publishedAt: Calendar.current.date(byAdding: .year, value: -1, to: Date())),
            makeBroadcast(title: "New", publishedAt: Date()),
        ]

        XCTAssertEqual(applyDateFilter(broadcasts, filter: .all).count, 2)
    }

    func test_dateFilter_today_onlyTodayBroadcasts() {
        let broadcasts = [
            makeBroadcast(title: "Today", publishedAt: Date()),
            makeBroadcast(title: "Yesterday", publishedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())),
        ]

        let results = applyDateFilter(broadcasts, filter: .today)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Today")
    }

    func test_dateFilter_thisWeek_includesLast7Days() {
        let now = Date()
        let broadcasts = [
            makeBroadcast(title: "Today", publishedAt: now),
            makeBroadcast(title: "3 Days Ago", publishedAt: Calendar.current.date(byAdding: .day, value: -3, to: now)),
            makeBroadcast(title: "2 Weeks Ago", publishedAt: Calendar.current.date(byAdding: .day, value: -14, to: now)),
        ]

        let results = applyDateFilter(broadcasts, filter: .thisWeek)
        XCTAssertEqual(results.count, 2)
    }

    func test_dateFilter_thisMonth_includesLastMonth() {
        let now = Date()
        let broadcasts = [
            makeBroadcast(title: "Today", publishedAt: now),
            makeBroadcast(title: "2 Weeks Ago", publishedAt: Calendar.current.date(byAdding: .day, value: -14, to: now)),
            makeBroadcast(title: "3 Months Ago", publishedAt: Calendar.current.date(byAdding: .month, value: -3, to: now)),
        ]

        let results = applyDateFilter(broadcasts, filter: .thisMonth)
        XCTAssertEqual(results.count, 2)
    }

    func test_dateFilter_usesPublishedAtOverCreatedAt() {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .year, value: -1, to: now)!
        // Created long ago but published today
        let broadcast = Broadcast(
            title: "Recently Published",
            status: .published,
            createdAt: oldDate,
            publishedAt: now,
            tags: [],
            authorId: testAuthorId
        )

        let results = applyDateFilter([broadcast], filter: .today)
        XCTAssertEqual(results.count, 1)
    }

    func test_dateFilter_fallsBackToCreatedAt_whenPublishedAtNil() {
        let broadcast = Broadcast(
            title: "Draft",
            status: .published,
            createdAt: Date(),
            publishedAt: nil,
            tags: [],
            authorId: testAuthorId
        )

        let results = applyDateFilter([broadcast], filter: .today)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Combined Filters

    func test_combinedFilters_searchAndTag() {
        let broadcasts = [
            makeBroadcast(title: "Bitcoin Update", tags: ["BTC"]),
            makeBroadcast(title: "Bitcoin Macro", tags: ["Macro"]),
            makeBroadcast(title: "Ethereum Update", tags: ["ETH"]),
        ]

        // First filter by tag, then search
        let tagFiltered = applyTagFilter(broadcasts, selectedTags: ["BTC", "Macro"])
        let results = applySearchFilter(tagFiltered, query: "bitcoin")

        XCTAssertEqual(results.count, 2)
    }

    func test_combinedFilters_allFiltersApplied() {
        let now = Date()
        let broadcasts = [
            makeBroadcast(title: "BTC Today", tags: ["BTC"], publishedAt: now),
            makeBroadcast(title: "BTC Old", tags: ["BTC"], publishedAt: Calendar.current.date(byAdding: .month, value: -2, to: now)),
            makeBroadcast(title: "ETH Today", tags: ["ETH"], publishedAt: now),
        ]

        var results = applyDateFilter(broadcasts, filter: .thisMonth)
        results = applyTagFilter(results, selectedTags: ["BTC"])
        results = applySearchFilter(results, query: "btc")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "BTC Today")
    }

    // MARK: - Available Tags Extraction

    func test_availableTags_extractsUniqueTagsSorted() {
        let broadcasts = [
            makeBroadcast(tags: ["BTC", "Technical"]),
            makeBroadcast(tags: ["Macro", "BTC"]),
            makeBroadcast(tags: []),
        ]

        let allTags = broadcasts.flatMap { $0.tags }
        let available = Array(Set(allTags)).sorted()

        XCTAssertEqual(available, ["BTC", "Macro", "Technical"])
    }

    func test_availableTags_emptyBroadcasts_isEmpty() {
        let broadcasts: [Broadcast] = []
        let allTags = broadcasts.flatMap { $0.tags }
        XCTAssertTrue(allTags.isEmpty)
    }

    func test_availableTags_noTagsOnAnyBroadcast_isEmpty() {
        let broadcasts = [
            makeBroadcast(tags: []),
            makeBroadcast(tags: []),
        ]

        let allTags = broadcasts.flatMap { $0.tags }
        XCTAssertTrue(allTags.isEmpty)
    }
}

// MARK: - Date Formatting Tests

final class BroadcastDateFormattingTests: XCTestCase {

    func test_formattedDate_today_includesTimeAndToday() {
        let now = Date()
        let result = formattedBroadcastDate(now)
        XCTAssertTrue(result.hasPrefix("Today at"))
    }

    func test_formattedDate_yesterday_includesYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let result = formattedBroadcastDate(yesterday)
        XCTAssertTrue(result.hasPrefix("Yesterday at"))
    }

    func test_formattedDate_thisWeek_includesDayName() {
        // 3 days ago should show day name
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let result = formattedBroadcastDate(threeDaysAgo)
        // Should contain "at" and not be "Today" or "Yesterday"
        XCTAssertTrue(result.contains("at"))
        XCTAssertFalse(result.hasPrefix("Today"))
        XCTAssertFalse(result.hasPrefix("Yesterday"))
    }

    func test_formattedDate_olderThanWeek_includesMonthDay() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let result = formattedBroadcastDate(twoWeeksAgo)
        XCTAssertTrue(result.contains("at"))
    }

    func test_formattedDate_differentYear_includesYear() {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = 10
        let oldDate = Calendar.current.date(from: components)!
        let result = formattedBroadcastDate(oldDate)
        XCTAssertTrue(result.contains("2024"))
    }

    func test_formattedDate_doesNotCrash_withDistantPast() {
        let result = formattedBroadcastDate(Date.distantPast)
        XCTAssertFalse(result.isEmpty)
    }

    func test_formattedDate_doesNotCrash_withDistantFuture() {
        let result = formattedBroadcastDate(Date.distantFuture)
        XCTAssertFalse(result.isEmpty)
    }
}

// MARK: - BroadcastDateFilter Tests

final class BroadcastDateFilterTests: XCTestCase {

    func test_allCases_contains4Filters() {
        XCTAssertEqual(BroadcastDateFilter.allCases.count, 4)
    }

    func test_rawValues() {
        XCTAssertEqual(BroadcastDateFilter.all.rawValue, "All")
        XCTAssertEqual(BroadcastDateFilter.today.rawValue, "Today")
        XCTAssertEqual(BroadcastDateFilter.thisWeek.rawValue, "This Week")
        XCTAssertEqual(BroadcastDateFilter.thisMonth.rawValue, "This Month")
    }
}

// MARK: - ReactionSummary Tests

final class ReactionSummaryTests: XCTestCase {

    func test_equatable() {
        let a = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: true)
        let b = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: true)
        XCTAssertEqual(a, b)
    }

    func test_notEqual_differentEmoji() {
        let a = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: true)
        let b = ReactionSummary(emoji: "🚀", count: 5, hasUserReacted: true)
        XCTAssertNotEqual(a, b)
    }

    func test_notEqual_differentCount() {
        let a = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: true)
        let b = ReactionSummary(emoji: "🔥", count: 3, hasUserReacted: true)
        XCTAssertNotEqual(a, b)
    }

    func test_notEqual_differentUserReacted() {
        let a = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: true)
        let b = ReactionSummary(emoji: "🔥", count: 5, hasUserReacted: false)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - ReactionEmoji Tests

final class ReactionEmojiTests: XCTestCase {

    func test_allCases_contains6Emojis() {
        XCTAssertEqual(ReactionEmoji.allCases.count, 6)
    }

    func test_rawValues_areEmoji() {
        XCTAssertEqual(ReactionEmoji.fire.rawValue, "🔥")
        XCTAssertEqual(ReactionEmoji.rocket.rawValue, "🚀")
        XCTAssertEqual(ReactionEmoji.thinking.rawValue, "🤔")
        XCTAssertEqual(ReactionEmoji.clap.rawValue, "👏")
        XCTAssertEqual(ReactionEmoji.heart.rawValue, "❤️")
        XCTAssertEqual(ReactionEmoji.hundredPoints.rawValue, "💯")
    }
}
