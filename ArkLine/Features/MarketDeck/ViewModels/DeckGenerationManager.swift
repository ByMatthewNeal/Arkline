import Foundation
import UserNotifications

/// Singleton that manages deck generation independently of any view lifecycle.
/// Generation continues even when the admin navigates away from the deck screen.
@MainActor
@Observable
final class DeckGenerationManager {
    static let shared = DeckGenerationManager()

    private let service: MarketUpdateDeckServiceProtocol = ServiceContainer.shared.marketDeckService

    // MARK: - State

    var isGenerating = false
    var isRegenerating = false
    var generationStep: GenerationStep?
    var completedDeck: MarketUpdateDeck?
    var errorMessage: String?

    // MARK: - Pipeline State

    var pipelineRun: DeckPipelineRun?
    var isPipelineRunning = false
    var pipelineStepInProgress: PipelineStep?
    var pipelineError: String?

    enum GenerationStep: String {
        case fetchingData = "Fetching market data..."
        case researching = "Researching this week's news..."
        case analyzing = "Generating deep analysis..."
        case assembling = "Assembling slides..."

        var icon: String {
            switch self {
            case .fetchingData: return "arrow.down.circle"
            case .researching: return "globe"
            case .analyzing: return "brain"
            case .assembling: return "rectangle.stack"
            }
        }

        var stepNumber: Int {
            switch self {
            case .fetchingData: return 1
            case .researching: return 2
            case .analyzing: return 3
            case .assembling: return 4
            }
        }
    }

    private init() {}

    // MARK: - Generate

    func generate(weekStart: String? = nil, weekEnd: String? = nil) {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        completedDeck = nil
        generationStep = .fetchingData

        Task { @MainActor in
            // Progress stepper runs independently
            let progressTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.generationStep = .researching }

                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.generationStep = .analyzing }

                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.generationStep = .assembling }
            }

            do {
                let deck = try await service.generateDeck(weekStart: weekStart, weekEnd: weekEnd)
                progressTask.cancel()
                self.completedDeck = deck
                self.isGenerating = false
                self.generationStep = nil
                await self.sendNotification(
                    title: "Market Deck Ready",
                    body: "Your weekly update is ready to preview — \(deck.slides.count) slides generated."
                )
            } catch {
                progressTask.cancel()
                self.errorMessage = error.localizedDescription
                self.isGenerating = false
                self.generationStep = nil
                await self.sendNotification(
                    title: "Deck Generation Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    // MARK: - Regenerate Narrative

    func regenerateNarrative(deckId: UUID, insights: String) {
        guard !isRegenerating else { return }
        isRegenerating = true
        errorMessage = nil
        completedDeck = nil
        generationStep = .analyzing

        Task { @MainActor in
            do {
                let deck = try await service.regenerateNarrative(deckId: deckId, insights: insights)
                self.completedDeck = deck
                self.isRegenerating = false
                self.generationStep = nil
                await self.sendNotification(
                    title: "Narrative Updated",
                    body: "The weekly narrative has been regenerated with your insights."
                )
            } catch {
                self.errorMessage = error.localizedDescription
                self.isRegenerating = false
                self.generationStep = nil
                await self.sendNotification(
                    title: "Narrative Regeneration Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    /// Clear the completed deck after the admin view has consumed it.
    func consumeCompletedDeck() -> MarketUpdateDeck? {
        let deck = completedDeck
        completedDeck = nil
        return deck
    }

    // MARK: - Pipeline

    /// Start a full pipeline run: creates the run, then executes gather -> research -> generate sequentially.
    /// Step 3 (add context) is skipped here — the admin fills it in via the UI before step 4 runs.
    func runPipeline(weekStart: String, weekEnd: String) {
        guard !isPipelineRunning else { return }
        isPipelineRunning = true
        pipelineError = nil

        Task { @MainActor in
            do {
                // Create the pipeline run
                let run = try await service.createPipelineRun(weekStart: weekStart, weekEnd: weekEnd)
                self.pipelineRun = run

                // Step 1: Gather Data
                self.pipelineStepInProgress = .gatherData
                try await service.runPipelineStep(.gatherData, runId: run.id)
                self.pipelineRun = try await service.fetchPipelineRun(id: run.id)

                // Step 2: Web Research
                self.pipelineStepInProgress = .webResearch
                try await service.runPipelineStep(.webResearch, runId: run.id)
                self.pipelineRun = try await service.fetchPipelineRun(id: run.id)

                // Pause here — wait for admin to add context (step 3)
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false

                await self.sendNotification(
                    title: "Pipeline Ready for Context",
                    body: "Data gathered and research complete. Add your insights to continue."
                )
            } catch {
                self.pipelineError = error.localizedDescription
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false
                // Refresh run state on error
                if let runId = self.pipelineRun?.id {
                    self.pipelineRun = try? await service.fetchPipelineRun(id: runId)
                }
                await self.sendNotification(
                    title: "Pipeline Step Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    /// Continue the pipeline after admin context has been added — runs step 4 (generate slides).
    func continuePipelineGeneration() {
        guard let run = pipelineRun, !isPipelineRunning else { return }
        isPipelineRunning = true
        pipelineError = nil

        Task { @MainActor in
            do {
                self.pipelineStepInProgress = .generateSlides
                try await service.runPipelineStep(.generateSlides, runId: run.id)
                self.pipelineRun = try await service.fetchPipelineRun(id: run.id)
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false

                await self.sendNotification(
                    title: "Slides Generated",
                    body: "Pipeline complete. Review and publish your deck."
                )
            } catch {
                self.pipelineError = error.localizedDescription
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false
                if let runId = self.pipelineRun?.id {
                    self.pipelineRun = try? await service.fetchPipelineRun(id: runId)
                }
                await self.sendNotification(
                    title: "Slide Generation Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    /// Retry a single failed pipeline step.
    func retryStep(_ step: PipelineStep) {
        guard let run = pipelineRun, !isPipelineRunning else { return }

        if step == .addContext {
            // Context step is manual — nothing to retry
            return
        }

        isPipelineRunning = true
        pipelineError = nil

        Task { @MainActor in
            do {
                self.pipelineStepInProgress = step
                try await service.runPipelineStep(step, runId: run.id)
                self.pipelineRun = try await service.fetchPipelineRun(id: run.id)
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false
            } catch {
                self.pipelineError = error.localizedDescription
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false
                if let runId = self.pipelineRun?.id {
                    self.pipelineRun = try? await service.fetchPipelineRun(id: runId)
                }
            }
        }
    }

    /// Save admin context to the pipeline run (step 3).
    func savePipelineContext(insights: String, attachments: [InsightAttachment] = []) async {
        guard let run = pipelineRun else { return }
        do {
            try await service.updatePipelineContext(runId: run.id, insights: insights, attachments: attachments)
            pipelineRun = try await service.fetchPipelineRun(id: run.id)
        } catch {
            pipelineError = error.localizedDescription
        }
    }

    /// Load the latest pipeline run from the server.
    func loadLatestPipelineRun() async {
        do {
            pipelineRun = try await service.fetchLatestPipelineRun()
        } catch {
            logWarning("Failed to load pipeline run: \(error)", category: .data)
        }
    }

    func resetPipeline() async {
        guard let run = pipelineRun else { return }
        do {
            // Reuse createPipelineRun which resets all steps for the same week
            let reset = try await service.createPipelineRun(weekStart: run.weekStart, weekEnd: run.weekEnd)
            await MainActor.run {
                self.pipelineRun = reset
                self.pipelineError = nil
                self.pipelineStepInProgress = nil
                self.isPipelineRunning = false
            }
        } catch {
            logWarning("Failed to reset pipeline: \(error)", category: .data)
        }
    }

    // MARK: - Local Notification

    private func sendNotification(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "deck-generation-\(UUID().uuidString.prefix(8))",
            content: content,
            trigger: nil // deliver immediately
        )

        try? await center.add(request)
    }
}
