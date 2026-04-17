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
