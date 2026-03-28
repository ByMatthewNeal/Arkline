import SwiftUI

struct MarketDeckViewer: View {
    @Bindable var viewModel: MarketDeckViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let isAdmin: Bool
    var userId: UUID?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            AppColors.background(colorScheme)
                .ignoresSafeArea()

            if let deck = viewModel.deck {
                TabView(selection: $viewModel.currentSlideIndex) {
                    ForEach(Array(deck.slides.enumerated()), id: \.offset) { index, slide in
                        DeckSlideView(slide: slide, deck: deck)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Overlay controls
                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(AppColors.textPrimary(colorScheme).opacity(0.1)))
                        }

                        Spacer()

                        // Regeneration indicator
                        if viewModel.isRegeneratingSlide {
                            HStack(spacing: ArkSpacing.xs) {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(AppColors.accent)
                                Text("Regenerating...")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.accent)
                            }
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, ArkSpacing.xxs)
                            .background(Capsule().fill(AppColors.accent.opacity(0.1)))
                        }

                        Spacer()

                        // Share button
                        if isAdmin {
                            Button(action: { showShareSheet = true }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(AppColors.textPrimary(colorScheme).opacity(0.1)))
                            }
                        }

                        // Slide counter pill
                        Text("\(viewModel.currentSlideIndex + 1) / \(viewModel.slideCount)")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, ArkSpacing.xxs)
                            .background(Capsule().fill(AppColors.textPrimary(colorScheme).opacity(0.08)))
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.top, ArkSpacing.xs)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(AppColors.textPrimary(colorScheme).opacity(0.06))
                                .frame(height: 2)

                            Rectangle()
                                .fill(AppColors.accent)
                                .frame(
                                    width: geo.size.width * CGFloat(viewModel.currentSlideIndex + 1) / CGFloat(max(viewModel.slideCount, 1)),
                                    height: 2
                                )
                                .animation(.easeInOut(duration: 0.25), value: viewModel.currentSlideIndex)
                        }
                    }
                    .frame(height: 2)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.top, ArkSpacing.sm)

                    Spacer()

                    // Per-slide feedback for draft decks (admin QA)
                    if isAdmin && deck.status == .draft, let currentSlide = currentSlide(in: deck) {
                        SlideReviewBar(
                            slideType: currentSlide.type,
                            existingFeedback: viewModel.rateSlideFeedback(for: currentSlide.type),
                            isRegenerating: viewModel.isRegeneratingSlide && viewModel.regeneratingSlideType == currentSlide.type.rawValue,
                            canRegenerate: currentSlide.type.isRegeneratable,
                            onRate: { rating, feedback in
                                Task { await viewModel.submitSlideFeedback(slideType: currentSlide.type, rating: rating, feedback: feedback) }
                            },
                            onRemove: {
                                Task { await viewModel.removeSlideFeedback(slideType: currentSlide.type) }
                            },
                            onRegenerate: { feedback in
                                Task { await viewModel.regenerateSlide(slideType: currentSlide.type, feedback: feedback) }
                            }
                        )
                        .padding(.horizontal, ArkSpacing.lg)
                        .padding(.bottom, ArkSpacing.xs)
                        .id(viewModel.currentSlideIndex) // Reset state when switching slides
                    }

                    // Post-publish deck-level feedback (last slide only)
                    if isAdmin && deck.status == .published &&
                       viewModel.currentSlideIndex == viewModel.slideCount - 1 {
                        DeckFeedbackBar(
                            rating: viewModel.feedbackRating,
                            onFeedback: { rating, note in
                                guard let userId else { return }
                                Task { await viewModel.submitFeedback(rating: rating, note: note, userId: userId) }
                            }
                        )
                        .padding(.horizontal, ArkSpacing.lg)
                        .padding(.bottom, ArkSpacing.sm)
                    }

                    // Admin publish button
                    if isAdmin && deck.status == .draft, let userId {
                        Button(action: {
                            Task { await viewModel.publish(authorId: userId) }
                        }) {
                            HStack(spacing: ArkSpacing.xs) {
                                Image(systemName: "paperplane.fill")
                                Text("Publish")
                            }
                            .font(AppFonts.body14Medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, ArkSpacing.lg)
                            .padding(.vertical, ArkSpacing.sm)
                            .background(Capsule().fill(AppColors.accent))
                        }
                        .padding(.bottom, ArkSpacing.lg)
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(AppColors.accent)
            }
        }
        .task {
            if isAdmin {
                await viewModel.loadFeedback()
                await viewModel.loadSlideFeedback()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let deck = viewModel.deck {
                MarketDeckShareSheet(
                    deck: deck,
                    currentSlideIndex: viewModel.currentSlideIndex
                )
            }
        }
    }

    private func currentSlide(in deck: MarketUpdateDeck) -> DeckSlide? {
        guard viewModel.currentSlideIndex < deck.slides.count else { return nil }
        return deck.slides[viewModel.currentSlideIndex]
    }
}

// MARK: - Regeneratable Slide Types

extension DeckSlide.SlideType {
    var isRegeneratable: Bool {
        switch self {
        case .editorial, .weeklyOutlook, .cover, .sectionTitle:
            return true
        default:
            return false
        }
    }
}

// MARK: - Per-Slide Review Bar

struct SlideReviewBar: View {
    let slideType: DeckSlide.SlideType
    let existingFeedback: SlideFeedback?
    let isRegenerating: Bool
    let canRegenerate: Bool
    let onRate: (Bool, String?) -> Void
    let onRemove: () -> Void
    let onRegenerate: (String) -> Void

    @State private var selectedRating: Bool?
    @State private var showFeedbackInput = false
    @State private var feedbackText = ""
    @State private var hasSubmitted = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.xs) {
            if isRegenerating {
                // Regeneration in progress
                HStack(spacing: ArkSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.accent)
                    Text("Regenerating \(slideType.displayName)...")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.vertical, ArkSpacing.sm)
            } else if hasSubmitted && selectedRating == true {
                // Approved — tap to undo
                Button(action: { undoApprove() }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("Approved")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.success)
                        Text("(tap to undo)")
                            .font(AppFonts.footnote10)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                }
                .padding(.vertical, ArkSpacing.sm)
            } else if showFeedbackInput {
                // Feedback input + regenerate
                VStack(spacing: ArkSpacing.xs) {
                    Text("What should change?")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: ArkSpacing.xs) {
                        TextField("Your feedback...", text: $feedbackText)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, ArkSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                    .fill(AppColors.textPrimary(colorScheme).opacity(0.06))
                            )

                        if canRegenerate {
                            Button(action: submitAndRegenerate) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.accent)
                            }
                            .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    HStack(spacing: ArkSpacing.md) {
                        if canRegenerate {
                            Button("Regenerate") {
                                submitAndRegenerate()
                            }
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                            .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        Button("Save feedback only") {
                            submitFeedbackOnly()
                        }
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    }
                }
            } else {
                // Rating buttons
                HStack(spacing: ArkSpacing.md) {
                    Text(slideType.displayName)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: ArkSpacing.sm) {
                        Button(action: { tapApprove() }) {
                            HStack(spacing: 4) {
                                Image(systemName: currentRating == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.system(size: 16))
                                if currentRating == true {
                                    Text("Approved")
                                        .font(AppFonts.footnote10)
                                }
                            }
                            .foregroundColor(currentRating == true ? AppColors.success : AppColors.textSecondary.opacity(0.4))
                        }

                        Button(action: { tapNeedsWork() }) {
                            HStack(spacing: 4) {
                                Image(systemName: currentRating == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .font(.system(size: 16))
                                if currentRating == false {
                                    Text("Needs work")
                                        .font(AppFonts.footnote10)
                                }
                            }
                            .foregroundColor(currentRating == false ? AppColors.error : AppColors.textSecondary.opacity(0.4))
                        }
                    }
                }
            }
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.lg)
        .onAppear {
            if let existing = existingFeedback {
                selectedRating = existing.rating
                if existing.rating {
                    hasSubmitted = true
                }
            }
        }
    }

    private var currentRating: Bool? {
        selectedRating ?? existingFeedback?.rating
    }

    private func tapApprove() {
        selectedRating = true
        hasSubmitted = true
        onRate(true, nil)
    }

    private func undoApprove() {
        selectedRating = nil
        hasSubmitted = false
        onRemove()
    }

    private func tapNeedsWork() {
        selectedRating = false
        showFeedbackInput = true
    }

    private func submitAndRegenerate() {
        let text = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onRate(false, text)
        onRegenerate(text)
        showFeedbackInput = false
        hasSubmitted = true
    }

    private func submitFeedbackOnly() {
        let text = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        onRate(false, text.isEmpty ? nil : text)
        showFeedbackInput = false
        hasSubmitted = true
    }
}

// MARK: - Deck Feedback Bar (post-publish, whole deck)

struct DeckFeedbackBar: View {
    let rating: Bool?
    let onFeedback: (Bool, String?) -> Void

    @State private var selectedRating: Bool?
    @State private var showNoteField = false
    @State private var feedbackNote = ""
    @State private var feedbackSent = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.sm) {
            if feedbackSent {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                    Text("Feedback saved")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, ArkSpacing.sm)
            } else if showNoteField {
                VStack(spacing: ArkSpacing.xs) {
                    Text(selectedRating == true ? "What worked well?" : "What should improve?")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: ArkSpacing.xs) {
                        TextField("Optional note...", text: $feedbackNote)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, ArkSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: ArkSpacing.Radius.sm)
                                    .fill(AppColors.textPrimary(colorScheme).opacity(0.06))
                            )

                        Button(action: submitWithNote) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.accent)
                        }
                    }

                    Button("Skip — just rate") {
                        submitWithNote()
                    }
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
            } else {
                HStack(spacing: ArkSpacing.lg) {
                    Text("Rate this update")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: ArkSpacing.md) {
                        Button(action: { tapRating(true) }) {
                            Image(systemName: currentRating == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 18))
                                .foregroundColor(currentRating == true ? AppColors.success : AppColors.textSecondary.opacity(0.4))
                        }

                        Button(action: { tapRating(false) }) {
                            Image(systemName: currentRating == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.system(size: 18))
                                .foregroundColor(currentRating == false ? AppColors.error : AppColors.textSecondary.opacity(0.4))
                        }
                    }
                }
            }
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.lg)
        .onAppear {
            selectedRating = rating
            if rating != nil {
                feedbackSent = true
            }
        }
    }

    private var currentRating: Bool? {
        selectedRating ?? rating
    }

    private func tapRating(_ value: Bool) {
        selectedRating = value
        showNoteField = true
    }

    private func submitWithNote() {
        guard let rating = selectedRating else { return }
        let note = feedbackNote.trimmingCharacters(in: .whitespacesAndNewlines)
        onFeedback(rating, note.isEmpty ? nil : note)
        feedbackSent = true
    }
}
