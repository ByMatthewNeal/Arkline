import Foundation
import SwiftUI
import PDFKit

@MainActor
@Observable
class MarketDeckViewModel {
    private let service: MarketUpdateDeckServiceProtocol
    private let supabase = SupabaseManager.shared
    private let generationManager = DeckGenerationManager.shared

    // MARK: - Deck State
    var deck: MarketUpdateDeck?
    var currentSlideIndex: Int = 0
    var isLoading = false
    var isSaving = false
    var isUploading = false
    var hasUnsavedChanges = false
    var errorMessage: String?
    var successMessage: String?

    // MARK: - Admin Editing State
    var adminNotes: String = ""
    var slideNotes: [String: String] = [:]
    var adminInsights: String = ""
    var editedNarrative: String = ""
    var attachments: [InsightAttachment] = []

    // MARK: - Regeneration Changelog
    var previousNarrative: String?
    var regenerationSummary: String?

    // MARK: - Feedback State
    var feedbackRating: Bool?
    var feedbackNote: String?

    // MARK: - Per-Slide Feedback State
    var slideFeedback: [String: SlideFeedback] = [:]  // slideType -> feedback
    var isRegeneratingSlide = false
    var regeneratingSlideType: String?

    // MARK: - Generation (delegated to singleton manager)

    var isGenerating: Bool { generationManager.isGenerating }
    var isRegenerating: Bool { generationManager.isRegenerating }
    var generationStep: DeckGenerationManager.GenerationStep? { generationManager.generationStep }

    var slideCount: Int {
        deck?.slides.count ?? 0
    }

    // MARK: - Init

    init(service: MarketUpdateDeckServiceProtocol = ServiceContainer.shared.marketDeckService) {
        self.service = service
    }

    init(deck: MarketUpdateDeck, service: MarketUpdateDeckServiceProtocol = ServiceContainer.shared.marketDeckService) {
        self.service = service
        self.deck = deck
        syncEditingState()
    }

    // MARK: - State Sync

    private func syncEditingState() {
        guard let deck else { return }
        adminNotes = deck.adminNotes ?? ""
        slideNotes = deck.adminContext?.slideNotes ?? [:]
        adminInsights = deck.adminContext?.insights ?? ""
        attachments = deck.adminContext?.attachments ?? []

        if let rundownSlide = deck.slides.first(where: { $0.type == .rundown }),
           case .rundown(let data) = rundownSlide.data {
            editedNarrative = data.narrative
        }
    }

    // MARK: - User Methods

    func loadLatest() async {
        isLoading = true
        defer { isLoading = false }
        do {
            deck = try await service.fetchLatestPublished()
        } catch {
            logWarning("Failed to load latest deck: \(error)", category: .data)
        }
    }

    // MARK: - Admin: Generate

    func loadDraft() async {
        isLoading = true
        defer { isLoading = false }
        do {
            deck = try await service.fetchDraft()
            syncEditingState()
        } catch {
            logWarning("Failed to load draft deck: \(error)", category: .data)
            errorMessage = error.localizedDescription
        }
    }

    func generate(weekStart: String? = nil, weekEnd: String? = nil) {
        generationManager.generate(weekStart: weekStart, weekEnd: weekEnd)
    }

    /// Call on view appear to pick up a completed background generation.
    func checkForCompletedGeneration() {
        if let completed = generationManager.consumeCompletedDeck() {
            deck = completed
            syncEditingState()
            hasUnsavedChanges = false
            successMessage = "Deck generated — \(completed.slides.count) slides"
        }
        if let error = generationManager.errorMessage {
            errorMessage = error
            generationManager.errorMessage = nil
        }
    }

    // MARK: - Admin: Regenerate Narrative

    func regenerateNarrative() async {
        guard let deckId = deck?.id else { return }

        // Capture what was used for the regeneration
        let insightsUsed = adminInsights
        let attachmentsUsed = attachments
        previousNarrative = editedNarrative

        await save()

        generationManager.regenerateNarrative(deckId: deckId, insights: adminInsights)

        // Poll for completion so the UI updates when done
        // (manager sends notification if user leaves the screen)
        Task {
            while generationManager.isRegenerating {
                try? await Task.sleep(for: .seconds(0.5))
            }
            if let completed = generationManager.consumeCompletedDeck() {
                deck = completed
                syncEditingState()
                hasUnsavedChanges = false

                // Build regeneration summary
                var parts: [String] = []
                if !insightsUsed.isEmpty { parts.append("text insights") }
                let imageCount = attachmentsUsed.filter { $0.type == .image }.count
                let pdfCount = attachmentsUsed.filter { $0.type == .pdf }.count
                let urlCount = attachmentsUsed.filter { $0.type == .url }.count
                if imageCount > 0 { parts.append("\(imageCount) image\(imageCount > 1 ? "s" : "")") }
                if pdfCount > 0 { parts.append("\(pdfCount) PDF\(pdfCount > 1 ? "s" : "")") }
                if urlCount > 0 { parts.append("\(urlCount) URL\(urlCount > 1 ? "s" : "")") }

                let inputSummary = parts.isEmpty ? "default context" : parts.joined(separator: ", ")
                regenerationSummary = "Narrative regenerated using \(inputSummary)"
                successMessage = regenerationSummary
            }
            if let error = generationManager.errorMessage {
                previousNarrative = nil
                errorMessage = error
                generationManager.errorMessage = nil
            }
        }
    }

    func clearRegenerationState() {
        previousNarrative = nil
        regenerationSummary = nil
    }

    // MARK: - Admin: Edit Slides

    func noteForSlide(_ type: DeckSlide.SlideType) -> String {
        slideNotes[type.rawValue] ?? ""
    }

    func setNoteForSlide(_ type: DeckSlide.SlideType, note: String) {
        slideNotes[type.rawValue] = note.isEmpty ? nil : note
        hasUnsavedChanges = true
    }

    func updateNarrative(_ text: String) {
        editedNarrative = text
        hasUnsavedChanges = true
    }

    func updateInsights(_ text: String) {
        adminInsights = text
        hasUnsavedChanges = true
    }

    // MARK: - Admin: Attachments

    func addURL(_ urlString: String, label: String? = nil) {
        let attachment = InsightAttachment(
            type: .url,
            storagePath: nil,
            url: urlString,
            label: label ?? urlString,
            extractedText: nil
        )
        attachments.append(attachment)
        hasUnsavedChanges = true
    }

    func addImage(_ imageData: Data) async {
        isUploading = true
        defer { isUploading = false }

        let filename = "img_\(UUID().uuidString.prefix(8)).jpg"
        let path = "insights/\(filename)"

        do {
            try await supabase.storage
                .from("deck-attachments")
                .upload(path, data: imageData, options: .init(contentType: "image/jpeg"))

            let attachment = InsightAttachment(
                type: .image,
                storagePath: path,
                url: nil,
                label: filename,
                extractedText: nil
            )
            attachments.append(attachment)
            hasUnsavedChanges = true
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
        }
    }

    func addPDF(from url: URL) async {
        isUploading = true
        defer { isUploading = false }

        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let filename = "pdf_\(UUID().uuidString.prefix(8)).pdf"
            let path = "insights/\(filename)"

            // Extract text from PDF on device
            var extractedText: String?
            if let pdfDoc = PDFDocument(data: data) {
                var texts: [String] = []
                for i in 0..<min(pdfDoc.pageCount, 20) {
                    if let page = pdfDoc.page(at: i), let text = page.string {
                        texts.append(text)
                    }
                }
                extractedText = texts.joined(separator: "\n\n")
            }

            try await supabase.storage
                .from("deck-attachments")
                .upload(path, data: data, options: .init(contentType: "application/pdf"))

            let attachment = InsightAttachment(
                type: .pdf,
                storagePath: path,
                url: nil,
                label: url.lastPathComponent,
                extractedText: extractedText
            )
            attachments.append(attachment)
            hasUnsavedChanges = true
        } catch {
            errorMessage = "Failed to upload PDF: \(error.localizedDescription)"
        }
    }

    func removeAttachment(_ attachment: InsightAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        hasUnsavedChanges = true

        // Clean up storage if applicable
        if let path = attachment.storagePath {
            Task {
                try? await supabase.storage
                    .from("deck-attachments")
                    .remove(paths: [path])
            }
        }
    }

    // MARK: - Admin: Save

    func save() async {
        guard var deck = deck else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if let rundownIndex = deck.slides.firstIndex(where: { $0.type == .rundown }) {
                deck.slides[rundownIndex].data = .rundown(RundownSlideData(narrative: editedNarrative))
            }

            let context = AdminContext(
                slideNotes: slideNotes,
                insights: adminInsights,
                attachments: attachments.isEmpty ? nil : attachments
            )

            try await service.saveDeck(
                id: deck.id,
                slides: deck.slides,
                adminNotes: adminNotes.isEmpty ? nil : adminNotes,
                adminContext: context
            )

            self.deck = deck
            self.deck?.adminNotes = adminNotes.isEmpty ? nil : adminNotes
            self.deck?.adminContext = context
            hasUnsavedChanges = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Admin: Feedback

    func loadFeedback() async {
        guard let deckId = deck?.id else { return }
        do {
            let feedback = try await service.fetchFeedback(deckId: deckId)
            feedbackRating = feedback?.rating
            feedbackNote = feedback?.note
        } catch {
            logWarning("Failed to load deck feedback: \(error)", category: .data)
        }
    }

    func submitFeedback(rating: Bool, note: String?, userId: UUID) async {
        guard let deckId = deck?.id else { return }

        // Optimistic update
        feedbackRating = rating
        feedbackNote = note

        do {
            try await service.submitFeedback(
                userId: userId,
                deckId: deckId,
                rating: rating,
                note: note
            )
        } catch {
            logError("Failed to submit deck feedback: \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Per-Slide Feedback

    func loadSlideFeedback() async {
        guard let deckId = deck?.id else { return }
        do {
            let feedback = try await service.fetchSlideFeedback(deckId: deckId)
            slideFeedback = Dictionary(uniqueKeysWithValues: feedback.map { ($0.slideType, $0) })
        } catch {
            logWarning("Failed to load slide feedback: \(error)", category: .data)
        }
    }

    func rateSlideFeedback(for slideType: DeckSlide.SlideType) -> SlideFeedback? {
        slideFeedback[slideType.rawValue]
    }

    func submitSlideFeedback(slideType: DeckSlide.SlideType, rating: Bool, feedback: String?) async {
        guard let deckId = deck?.id else { return }

        // Optimistic update
        slideFeedback[slideType.rawValue] = SlideFeedback(
            deckId: deckId,
            slideType: slideType.rawValue,
            rating: rating,
            feedback: feedback,
            createdAt: Date()
        )

        do {
            try await service.submitSlideFeedback(
                deckId: deckId,
                slideType: slideType.rawValue,
                rating: rating,
                feedback: feedback
            )
        } catch {
            logError("Failed to submit slide feedback: \(error)", category: .network)
        }
    }

    func removeSlideFeedback(slideType: DeckSlide.SlideType) async {
        guard let deckId = deck?.id else { return }

        // Optimistic removal
        slideFeedback.removeValue(forKey: slideType.rawValue)

        do {
            try await service.deleteSlideFeedback(deckId: deckId, slideType: slideType.rawValue)
        } catch {
            logError("Failed to remove slide feedback: \(error)", category: .network)
        }
    }

    func regenerateSlide(slideType: DeckSlide.SlideType, feedback: String) async {
        guard let deckId = deck?.id else { return }

        isRegeneratingSlide = true
        regeneratingSlideType = slideType.rawValue

        do {
            let updatedDeck = try await service.regenerateSlide(
                deckId: deckId,
                slideType: slideType.rawValue,
                feedback: feedback
            )

            // Replace just the regenerated slide(s) in our local deck
            if var currentDeck = deck {
                for updatedSlide in updatedDeck.slides {
                    if let idx = currentDeck.slides.firstIndex(where: { $0.type == updatedSlide.type && $0.title == updatedSlide.title }) {
                        currentDeck.slides[idx] = updatedSlide
                    }
                }
                deck = currentDeck
                syncEditingState()
            }

            successMessage = "\(slideType.displayName) regenerated"
        } catch {
            errorMessage = "Failed to regenerate slide: \(error.localizedDescription)"
        }

        isRegeneratingSlide = false
        regeneratingSlideType = nil
    }

    // MARK: - Admin: Publish

    func publish(authorId: UUID) async {
        guard let deckId = deck?.id else { return }
        await save()

        isLoading = true
        defer { isLoading = false }
        do {
            deck = try await service.publishDeck(id: deckId)
            syncEditingState()

            // Create a broadcast insight + send push notification
            if let deck {
                await createBroadcastFromDeck(deck, authorId: authorId)
            }

            successMessage = "Published to all users"
            NotificationCenter.default.post(name: Constants.Notifications.marketDeckPublished, object: deck)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Broadcast Integration

    private func createBroadcastFromDeck(_ deck: MarketUpdateDeck, authorId: UUID) async {
        let broadcastService = ServiceContainer.shared.broadcastService
        let notificationService = BroadcastNotificationService.shared

        // Build content from deck slides
        var contentParts: [String] = []

        // Weekly outlook headline
        if let outlookSlide = deck.slides.first(where: { $0.type == .weeklyOutlook }),
           case .weeklyOutlook(let data) = outlookSlide.data {
            contentParts.append("**\(data.headline)**")
            contentParts.append(data.riskAssetImpact)
        }

        // Cover stats
        if let coverSlide = deck.slides.first(where: { $0.type == .cover }),
           case .cover(let data) = coverSlide.data {
            var stats: [String] = []
            if let btcChange = data.btcWeeklyChange {
                stats.append(String(format: "BTC %+.1f%%", btcChange))
            }
            if let fg = data.fearGreedEnd {
                stats.append("Fear & Greed: \(fg)")
            }
            stats.append("Regime: \(data.regime)")
            contentParts.append(stats.joined(separator: " · "))
        }

        // Admin notes if any
        if let notes = deck.adminNotes, !notes.isEmpty {
            contentParts.append(notes)
        }

        contentParts.append("Swipe through all \(deck.slides.count) slides in the Weekly Market Update.")

        let broadcast = Broadcast(
            title: "Weekly Market Update — \(deck.weekLabel)",
            content: contentParts.joined(separator: "\n\n"),
            targetAudience: .all,
            status: .published,
            publishedAt: Date(),
            tags: ["marketUpdate", "weekly"],
            authorId: authorId
        )

        do {
            let created = try await broadcastService.createBroadcast(broadcast)
            logInfo("Created broadcast from deck: \(created.id)", category: .data)

            // Send push notification
            await notificationService.sendBroadcastNotification(for: created, audience: .all)
        } catch {
            logWarning("Failed to create broadcast from deck: \(error)", category: .data)
        }
    }
}
