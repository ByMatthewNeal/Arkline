import Foundation

// MARK: - Market Update Deck Service

final class MarketUpdateDeckService: MarketUpdateDeckServiceProtocol {

    private let supabase = SupabaseManager.shared
    private let tableName = "market_update_decks"

    // 1-hour cache for published deck
    private var cachedPublished: MarketUpdateDeck?
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 3600

    init() {}

    // MARK: - Generation

    func generateDeck(weekStart: String? = nil, weekEnd: String? = nil) async throws -> MarketUpdateDeck {
        var params = ["manual": "true"]
        if let weekStart { params["week_start"] = weekStart }
        if let weekEnd { params["week_end"] = weekEnd }
        return try await invokeEdgeFunction(params: params)
    }

    func regenerateNarrative(deckId: UUID, insights: String) async throws -> MarketUpdateDeck {
        try await invokeEdgeFunction(
            params: [
                "manual": "true",
                "regenerate_narrative": "true",
                "deck_id": deckId.uuidString,
            ],
            body: ["admin_insights": insights]
        )
    }

    private func invokeEdgeFunction(params: [String: String], body: [String: String]? = nil) async throws -> MarketUpdateDeck {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let baseUrl = Constants.API.supabaseURL
        guard var components = URLComponents(string: "\(baseUrl)/functions/v1/generate-market-deck") else {
            throw AppError.custom(message: "Invalid Supabase URL")
        }
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            throw AppError.custom(message: "Invalid Supabase URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300  // Edge function needs time for web research + AI generation
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = try? await supabase.auth.session.accessToken
        request.setValue("Bearer \(token ?? Constants.API.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.custom(message: "Failed to generate deck: \(body)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }

        return try decoder.decode(MarketUpdateDeck.self, from: data)
    }

    // MARK: - Fetch

    func fetchLatestPublished() async throws -> MarketUpdateDeck? {
        if let cached = cachedPublished,
           let ts = cacheTimestamp,
           Date().timeIntervalSince(ts) < cacheTTL {
            return cached
        }

        guard supabase.isConfigured else { return nil }

        let decks: [MarketUpdateDeck] = try await supabase.database
            .from(tableName)
            .select()
            .eq("status", value: "published")
            .order("week_start", ascending: false)
            .limit(1)
            .execute()
            .value

        cachedPublished = decks.first
        cacheTimestamp = Date()
        return decks.first
    }

    func fetchDraft() async throws -> MarketUpdateDeck? {
        guard supabase.isConfigured else { return nil }

        let decks: [MarketUpdateDeck] = try await supabase.database
            .from(tableName)
            .select()
            .eq("status", value: "draft")
            .order("week_start", ascending: false)
            .limit(1)
            .execute()
            .value

        return decks.first
    }

    // MARK: - Admin Actions

    func publishDeck(id: UUID) async throws -> MarketUpdateDeck {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let updated: MarketUpdateDeck = try await supabase.database
            .from(tableName)
            .update(DeckPublishUpdate(status: "published", publishedAt: Date()))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value

        cachedPublished = nil
        cacheTimestamp = nil

        logInfo("Published market deck: \(updated.id)", category: .data)
        return updated
    }

    func saveDeck(id: UUID, slides: [DeckSlide], adminNotes: String?, adminContext: AdminContext?) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        try await supabase.database
            .from(tableName)
            .update(DeckFullUpdate(
                slides: slides,
                adminNotes: adminNotes,
                adminContext: adminContext,
                updatedAt: Date()
            ))
            .eq("id", value: id.uuidString)
            .execute()

        logInfo("Saved deck edits: \(id)", category: .data)
    }

    func fetchHistory(limit: Int) async throws -> [MarketUpdateDeck] {
        guard supabase.isConfigured else { return [] }

        let decks: [MarketUpdateDeck] = try await supabase.database
            .from(tableName)
            .select()
            .eq("status", value: "published")
            .order("week_start", ascending: false)
            .limit(limit)
            .execute()
            .value

        return decks
    }

    // MARK: - Feedback

    func submitFeedback(userId: UUID, deckId: UUID, rating: Bool, note: String?) async throws {
        guard supabase.isConfigured else { return }

        let payload = DeckFeedbackPayload(
            userId: userId.uuidString,
            deckId: deckId.uuidString,
            rating: rating,
            note: note
        )

        try await supabase.database
            .from("deck_feedback")
            .upsert(payload, onConflict: "deck_id")
            .execute()

        logDebug("Deck feedback submitted: \(rating ? "👍" : "👎") for \(deckId)", category: .data)
    }

    func fetchFeedback(deckId: UUID) async throws -> DeckFeedback? {
        guard supabase.isConfigured else { return nil }

        let rows: [DeckFeedback] = try await supabase.database
            .from("deck_feedback")
            .select("rating, note")
            .eq("deck_id", value: deckId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    // MARK: - Per-Slide Feedback

    func submitSlideFeedback(deckId: UUID, slideType: String, rating: Bool, feedback: String?) async throws {
        guard supabase.isConfigured else { return }

        let payload = SlideFeedbackPayload(
            deckId: deckId.uuidString,
            slideType: slideType,
            rating: rating,
            feedback: feedback
        )

        try await supabase.database
            .from("deck_slide_feedback")
            .upsert(payload, onConflict: "deck_id,slide_type")
            .execute()

        logDebug("Slide feedback: \(rating ? "👍" : "👎") for \(slideType)", category: .data)
    }

    func deleteSlideFeedback(deckId: UUID, slideType: String) async throws {
        guard supabase.isConfigured else { return }

        try await supabase.database
            .from("deck_slide_feedback")
            .delete()
            .eq("deck_id", value: deckId.uuidString)
            .eq("slide_type", value: slideType)
            .execute()

        logDebug("Slide feedback removed for \(slideType)", category: .data)
    }

    func fetchSlideFeedback(deckId: UUID) async throws -> [SlideFeedback] {
        guard supabase.isConfigured else { return [] }

        return try await supabase.database
            .from("deck_slide_feedback")
            .select()
            .eq("deck_id", value: deckId.uuidString)
            .execute()
            .value
    }

    func fetchRecentSlideFeedback(limit: Int) async throws -> [SlideFeedback] {
        guard supabase.isConfigured else { return [] }

        return try await supabase.database
            .from("deck_slide_feedback")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func regenerateSlide(deckId: UUID, slideType: String, feedback: String) async throws -> MarketUpdateDeck {
        try await invokeEdgeFunction(params: [
            "manual": "true",
            "regenerate_slide": "true",
            "deck_id": deckId.uuidString,
            "slide_type": slideType,
            "slide_feedback": feedback
        ])
    }

    // MARK: - Pipeline

    private let pipelineTable = "deck_pipeline_runs"

    func createPipelineRun(weekStart: String, weekEnd: String) async throws -> DeckPipelineRun {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        let payload: [String: String] = [
            "week_start": weekStart,
            "week_end": weekEnd,
            "step_gather_data": "pending",
            "step_web_research": "pending",
            "step_add_context": "pending",
            "step_generate_slides": "pending",
            "step_review": "pending",
            "step_publish": "pending"
        ]

        let run: DeckPipelineRun = try await supabase.database
            .from(pipelineTable)
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        logInfo("Created pipeline run: \(run.id)", category: .data)
        return run
    }

    func fetchPipelineRun(id: UUID) async throws -> DeckPipelineRun {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        return try await supabase.database
            .from(pipelineTable)
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
    }

    func fetchLatestPipelineRun() async throws -> DeckPipelineRun? {
        guard supabase.isConfigured else { return nil }

        let runs: [DeckPipelineRun] = try await supabase.database
            .from(pipelineTable)
            .select()
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return runs.first
    }

    func runPipelineStep(_ step: PipelineStep, runId: UUID) async throws {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        let functionName: String
        switch step {
        case .gatherData:
            functionName = "deck-pipeline-gather"
        case .webResearch:
            functionName = "deck-pipeline-research"
        case .generateSlides:
            functionName = "deck-pipeline-generate"
        case .addContext, .review, .publish:
            // These are not edge-function steps
            return
        }

        let baseUrl = Constants.API.supabaseURL
        guard var components = URLComponents(string: "\(baseUrl)/functions/v1/\(functionName)") else {
            throw AppError.custom(message: "Invalid Supabase URL")
        }
        components.queryItems = [URLQueryItem(name: "pipeline_run_id", value: runId.uuidString)]

        guard let url = components.url else {
            throw AppError.custom(message: "Invalid Supabase URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = try? await supabase.auth.session.accessToken
        request.setValue("Bearer \(token ?? Constants.API.supabaseAnonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.custom(message: "Pipeline step \(step.displayName) failed: \(body)")
        }

        logInfo("Pipeline step \(step.displayName) completed for run \(runId)", category: .data)
    }

    func updatePipelineContext(runId: UUID, insights: String) async throws {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }

        let payload = PipelineContextUpdate(
            stepAddContext: "done",
            outputContext: insights
        )

        try await supabase.database
            .from(pipelineTable)
            .update(payload)
            .eq("id", value: runId.uuidString)
            .execute()

        logInfo("Pipeline context updated for run \(runId)", category: .data)
    }
}
