import Foundation

/// Protocol defining operations for the weekly market update deck feature.
protocol MarketUpdateDeckServiceProtocol {
    /// Admin: Trigger edge function to generate a new deck
    func generateDeck(weekStart: String?, weekEnd: String?) async throws -> MarketUpdateDeck

    /// Admin: Regenerate the Rundown narrative with admin-provided insights
    func regenerateNarrative(deckId: UUID, insights: String) async throws -> MarketUpdateDeck

    /// User: Fetch the latest published deck
    func fetchLatestPublished() async throws -> MarketUpdateDeck?

    /// Admin: Fetch the current draft deck
    func fetchDraft() async throws -> MarketUpdateDeck?

    /// Admin: Publish a draft deck
    func publishDeck(id: UUID) async throws -> MarketUpdateDeck

    /// Admin: Save full deck state (slides, notes, context)
    func saveDeck(id: UUID, slides: [DeckSlide], adminNotes: String?, adminContext: AdminContext?) async throws

    /// Browse past published decks
    func fetchHistory(limit: Int) async throws -> [MarketUpdateDeck]

    /// Admin: Submit feedback (rating + optional note) for a deck
    func submitFeedback(userId: UUID, deckId: UUID, rating: Bool, note: String?) async throws

    /// Fetch feedback for a specific deck
    func fetchFeedback(deckId: UUID) async throws -> DeckFeedback?

    /// Admin: Submit per-slide feedback (rating + optional guidance)
    func submitSlideFeedback(deckId: UUID, slideType: String, rating: Bool, feedback: String?) async throws

    /// Admin: Remove per-slide feedback (un-approve)
    func deleteSlideFeedback(deckId: UUID, slideType: String) async throws

    /// Fetch all slide feedback for a deck
    func fetchSlideFeedback(deckId: UUID) async throws -> [SlideFeedback]

    /// Fetch recent slide feedback across decks (for learning context)
    func fetchRecentSlideFeedback(limit: Int) async throws -> [SlideFeedback]

    /// Admin: Regenerate a single slide based on feedback
    func regenerateSlide(deckId: UUID, slideType: String, feedback: String) async throws -> MarketUpdateDeck

    // MARK: - Pipeline

    /// Create a new pipeline run for the given week range
    func createPipelineRun(weekStart: String, weekEnd: String) async throws -> DeckPipelineRun

    /// Fetch a specific pipeline run by ID
    func fetchPipelineRun(id: UUID) async throws -> DeckPipelineRun

    /// Fetch the most recent pipeline run (any status)
    func fetchLatestPipelineRun() async throws -> DeckPipelineRun?

    /// Run a specific pipeline step via edge function
    func runPipelineStep(_ step: PipelineStep, runId: UUID) async throws

    /// Update the admin context for a pipeline run (step 3)
    func updatePipelineContext(runId: UUID, insights: String) async throws
}
