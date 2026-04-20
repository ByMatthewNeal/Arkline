import Foundation

// MARK: - Deck Pipeline Run

struct DeckPipelineRun: Codable, Identifiable {
    let id: UUID
    var deckId: UUID?
    let weekStart: String  // DATE column comes as string
    let weekEnd: String

    var stepGatherData: String
    var stepWebResearch: String
    var stepAddContext: String
    var stepGenerateSlides: String
    var stepReview: String
    var stepPublish: String

    var errorGatherData: String?
    var errorWebResearch: String?
    var errorAddContext: String?
    var errorGenerateSlides: String?

    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case deckId = "deck_id"
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case stepGatherData = "step_gather_data"
        case stepWebResearch = "step_web_research"
        case stepAddContext = "step_add_context"
        case stepGenerateSlides = "step_generate_slides"
        case stepReview = "step_review"
        case stepPublish = "step_publish"
        case errorGatherData = "error_gather_data"
        case errorWebResearch = "error_web_research"
        case errorAddContext = "error_add_context"
        case errorGenerateSlides = "error_generate_slides"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    var isGatherComplete: Bool { stepGatherData == "done" }
    var isResearchComplete: Bool { stepWebResearch == "done" }
    var isContextComplete: Bool { stepAddContext == "done" }
    var isGenerateComplete: Bool { stepGenerateSlides == "done" }

    /// The current pipeline step based on status progression.
    var currentStep: PipelineStep {
        if stepGatherData != "done" { return .gatherData }
        if stepWebResearch != "done" { return .webResearch }
        if stepAddContext != "done" { return .addContext }
        if stepGenerateSlides != "done" { return .generateSlides }
        if stepReview != "done" { return .review }
        return .publish
    }

    /// Progress as a fraction from 0 to 1.
    var progress: Double {
        var completed = 0.0
        if isGatherComplete { completed += 1 }
        if isResearchComplete { completed += 1 }
        if isContextComplete { completed += 1 }
        if isGenerateComplete { completed += 1 }
        if stepReview == "done" { completed += 1 }
        if stepPublish == "done" { completed += 1 }
        return completed / 6.0
    }

    /// Status string for a given step.
    func status(for step: PipelineStep) -> String {
        switch step {
        case .gatherData: return stepGatherData
        case .webResearch: return stepWebResearch
        case .addContext: return stepAddContext
        case .generateSlides: return stepGenerateSlides
        case .review: return stepReview
        case .publish: return stepPublish
        }
    }

    /// Error message for a given step, if any.
    func error(for step: PipelineStep) -> String? {
        switch step {
        case .gatherData: return errorGatherData
        case .webResearch: return errorWebResearch
        case .addContext: return errorAddContext
        case .generateSlides: return errorGenerateSlides
        case .review, .publish: return nil
        }
    }
}

// MARK: - Pipeline Step

enum PipelineStep: String, CaseIterable, Identifiable {
    case gatherData
    case webResearch
    case addContext
    case generateSlides
    case review
    case publish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gatherData: return "Gather Data"
        case .webResearch: return "Web Research"
        case .addContext: return "Admin Context"
        case .generateSlides: return "Generate Slides"
        case .review: return "Review"
        case .publish: return "Publish"
        }
    }

    var icon: String {
        switch self {
        case .gatherData: return "arrow.down.circle"
        case .webResearch: return "globe"
        case .addContext: return "brain.head.profile"
        case .generateSlides: return "rectangle.stack"
        case .review: return "eye"
        case .publish: return "paperplane.fill"
        }
    }

    /// Whether this step is executed automatically by edge functions.
    var isAutomatic: Bool {
        switch self {
        case .gatherData, .webResearch, .generateSlides: return true
        case .addContext, .review, .publish: return false
        }
    }

    var stepNumber: Int {
        switch self {
        case .gatherData: return 1
        case .webResearch: return 2
        case .addContext: return 3
        case .generateSlides: return 4
        case .review: return 5
        case .publish: return 6
        }
    }
}

// MARK: - Pipeline Update Payloads

struct PipelineContextUpdate: Encodable {
    let stepAddContext: String
    let outputContext: String

    enum CodingKeys: String, CodingKey {
        case stepAddContext = "step_add_context"
        case outputContext = "output_context"
    }
}
