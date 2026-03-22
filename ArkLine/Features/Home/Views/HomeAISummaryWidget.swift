import SwiftUI

// MARK: - AI Daily Market Summary Widget
struct HomeAISummaryWidget: View {
    let summary: MarketSummary?
    let isLoading: Bool
    let userName: String
    var size: WidgetSize = .standard
    var isAdmin: Bool = false
    var liveRegime: MacroRegimeResult? = nil
    var onFeedback: ((Bool, String?) -> Void)? = nil
    var audioService: BriefingAudioService = .shared
    var forceExpand: Binding<Bool>? = nil
    @State private var showNoteField = false
    @State private var selectedRating: Bool?
    @State private var feedbackNote = ""
    @State private var feedbackSent = false
    @State private var feedbackSentWithNote = false
    @State private var regenerationStart: Date?
    @AppStorage(Constants.UserDefaults.lastReadBriefingKey) private var lastReadBriefingKey = ""
    @State private var isExpanded = true
    @State private var hasBeenExpandedThisSession = false
    @State private var showUnavailable = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    // MARK: - Expand / Collapse Helpers

    private var currentBriefingKey: String {
        summary?.briefingKey ?? ""
    }

    private var isNewBriefing: Bool {
        !currentBriefingKey.isEmpty && currentBriefingKey != lastReadBriefingKey
    }

    private var showUnreadDot: Bool {
        isNewBriefing && !hasBeenExpandedThisSession
    }

    private func resolveInitialExpandState() {
        if isNewBriefing {
            isExpanded = true
            hasBeenExpandedThisSession = false
        } else {
            isExpanded = false
            hasBeenExpandedThisSession = true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header — tappable to toggle expand/collapse
            headerRow

            // Audio progress bar
            if audioService.playbackState == .playing || audioService.playbackState == .paused {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(textPrimary.opacity(0.08))
                            .frame(height: 3)
                        Capsule()
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * audioService.playbackProgress, height: 3)
                            .animation(.linear(duration: 0.25), value: audioService.playbackProgress)
                    }
                }
                .frame(height: 3)
            }

            // Audio error message
            if let error = audioService.lastError {
                Text(error)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }

            // Greeting with market posture
            Text(enhancedGreeting)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.85))

            // Sentiment pill — prefer live regime over stale briefing text
            if let posture = livePosture ?? parsedPosture {
                sentimentPill(posture)
            }

            // Body
            if summary == nil && isLoading {
                if feedbackSentWithNote {
                    regeneratingBanner
                }
                shimmerPlaceholder
            } else if let summary {
                if isExpanded {
                    structuredSummary(summary.summary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    collapsedPreview(summary.summary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else if showUnavailable {
                Text("Market briefing unavailable")
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.3))
            } else {
                // Summary is nil and not loading — show shimmer briefly,
                // then "unavailable" after the fetch has had time to complete
                shimmerPlaceholder
                    .task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if summary == nil && !isLoading {
                            showUnavailable = true
                        }
                    }
            }

            // Next update indicator
            if let summary, !isLoading {
                nextUpdateLabel(for: summary)
            }

            // Admin feedback row — only when expanded
            if isAdmin, summary != nil, isExpanded {
                feedbackRow
            }
        }
        .padding(size == .compact ? 14 : 18)
        .glassCard(cornerRadius: 16)
        .onAppear {
            if summary != nil {
                resolveInitialExpandState()
            }
        }
        .onChange(of: summary?.generatedAt) {
            // New briefing arrived — reset all feedback state + re-resolve expand
            if summary != nil {
                showUnavailable = false
                feedbackSentWithNote = false
                feedbackSent = false
                selectedRating = nil
                feedbackNote = ""
                showNoteField = false
                regenerationStart = nil
                resolveInitialExpandState()
            }
        }
        .onChange(of: isExpanded) {
            if isExpanded {
                hasBeenExpandedThisSession = true
                if !currentBriefingKey.isEmpty {
                    lastReadBriefingKey = currentBriefingKey
                }
            }
        }
        .onChange(of: forceExpand?.wrappedValue) { _, shouldExpand in
            if shouldExpand == true {
                withAnimation(.arkSpring) { isExpanded = true }
                forceExpand?.wrappedValue = false
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Button {
                withAnimation(.arkSpring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(AppColors.accent)

                    Text("Daily Briefing")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)

                    if showUnreadDot {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if let summary {
                Text(relativeTime(from: summary.generatedAt))
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.4))

                // Audio play/pause button
                audioButton(for: summary)

                // Speed button (visible during playback)
                if audioService.playbackState == .playing || audioService.playbackState == .paused {
                    Button {
                        audioService.cycleSpeed()
                    } label: {
                        Text(audioService.playbackSpeed == 1.0 ? "1x" : String(format: "%.2gx", audioService.playbackSpeed))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.accent.opacity(0.12))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            if summary != nil {
                Button {
                    withAnimation(.arkSpring) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Audio Button

    private func audioButton(for summary: MarketSummary) -> some View {
        Button {
            switch audioService.playbackState {
            case .idle:
                Task { await audioService.play(summary: summary) }
            case .loading:
                break
            case .playing, .paused:
                audioService.togglePlayPause()
            }
        } label: {
            Group {
                switch audioService.playbackState {
                case .idle:
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(AppColors.accent)
                case .loading:
                    ProgressView()
                        .scaleEffect(0.6)
                case .playing:
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(AppColors.accent)
                case .paused:
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
            .font(.system(size: 18))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Collapsed Preview

    @ViewBuilder
    private func collapsedPreview(_ text: String) -> some View {
        let sections = parseSections(text).filter { $0.header.lowercased() != "posture" }
        if let first = sections.first {
            VStack(alignment: .leading, spacing: 4) {
                Text(first.header)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(first.body)
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineSpacing(3)
                    .lineLimit(2)
                    .mask(
                        VStack(spacing: 0) {
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                                .frame(height: 12)
                        }
                    )
            }
        }
    }

    // MARK: - Regeneration Banner

    private var regeneratingBanner: some View {
        TimelineView(.periodic(from: regenerationStart ?? .now, by: 1)) { context in
            let elapsed = Int(context.date.timeIntervalSince(regenerationStart ?? context.date))
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Regenerating briefing... \(elapsed)s")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
    }

    // MARK: - Admin Feedback

    /// The effective rating: session selection overrides DB value.
    private var effectiveRating: Bool? {
        selectedRating ?? summary?.feedbackRating
    }

    private var notePlaceholder: String {
        selectedRating == true ? "What did you like?" : "What could be better?"
    }

    @ViewBuilder
    private var feedbackRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().opacity(0.2)

            HStack(spacing: 12) {
                Text("Rate this briefing")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.5))

                Spacer()

                // Thumbs up
                Button {
                    selectedRating = true
                    showNoteField = true
                    feedbackNote = ""
                    feedbackSent = false
                    feedbackSentWithNote = false
                } label: {
                    Image(systemName: effectiveRating == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 16))
                        .foregroundColor(effectiveRating == true ? AppColors.success : textPrimary.opacity(0.4))
                }

                // Thumbs down
                Button {
                    selectedRating = false
                    showNoteField = true
                    feedbackNote = ""
                    feedbackSent = false
                    feedbackSentWithNote = false
                } label: {
                    Image(systemName: effectiveRating == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: 16))
                        .foregroundColor(effectiveRating == false ? AppColors.error : textPrimary.opacity(0.4))
                }
            }

            // Confirmation text
            if feedbackSent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.success)
                    Text(feedbackSentWithNote ? "Feedback sent — regenerating briefing..." : "Feedback sent")
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }

            // Note field (shown after either thumb)
            if showNoteField && !feedbackSent {
                HStack(spacing: 8) {
                    TextField(notePlaceholder, text: $feedbackNote)
                        .font(AppFonts.caption12)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )

                    LiveDictationButton(text: $feedbackNote)

                    Button {
                        let note = feedbackNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        let rating = selectedRating ?? false
                        let hasNote = !note.isEmpty
                        onFeedback?(rating, hasNote ? note : nil)
                        // Only show regeneration banner for negative feedback with a note
                        let willRegenerate = !rating && hasNote
                        feedbackSentWithNote = willRegenerate
                        regenerationStart = willRegenerate ? .now : nil
                        feedbackNote = ""
                        showNoteField = false
                        feedbackSent = true
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accent)
                    }
                }
                // Skip button — submit bare rating without a note
                Button {
                    let rating = selectedRating ?? false
                    onFeedback?(rating, nil)
                    feedbackSentWithNote = false
                    feedbackNote = ""
                    showNoteField = false
                    feedbackSent = true
                } label: {
                    Text("Skip — just rate")
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.35))
                }
            }
        }
    }

    // MARK: - Parsed Posture

    private struct MarketPosture {
        let label: String
        let color: Color
        let icon: String
        let detail: String

        static func riskOn(_ detail: String, _ label: String, color: Color = AppColors.success) -> MarketPosture {
            MarketPosture(label: label, color: color, icon: "arrow.up.right", detail: detail)
        }

        static func riskOff(_ detail: String, _ label: String, color: Color = AppColors.error) -> MarketPosture {
            MarketPosture(label: label, color: color, icon: "arrow.down.right", detail: detail)
        }
    }

    /// Extract the regime quadrant label from the posture text (e.g. "Risk-On Disinflation")
    private static let quadrantLabels = [
        "risk-on disinflation", "risk-on inflation",
        "risk-off inflation", "risk-off disinflation"
    ]

    /// Live regime from the ViewModel — uses quadrant color directly.
    private var livePosture: MarketPosture? {
        guard let regime = liveRegime else { return nil }
        let q = regime.quadrant
        if q.rawValue.lowercased().contains("risk-on") {
            return .riskOn("", q.rawValue, color: q.color)
        } else {
            return .riskOff("", q.rawValue, color: q.color)
        }
    }

    private var parsedPosture: MarketPosture? {
        guard let text = summary?.summary else { return nil }
        let sections = parseSections(text)
        guard let postureSection = sections.first(where: { $0.header.lowercased() == "posture" }) else { return nil }
        let body = postureSection.body.lowercased()

        // Match against the 4 quadrants for exact label + color
        for q in MacroRegimeQuadrant.allCases {
            if body.contains(q.rawValue.lowercased()) {
                if q.rawValue.lowercased().contains("risk-on") {
                    return .riskOn(postureSection.body, q.rawValue, color: q.color)
                } else {
                    return .riskOff(postureSection.body, q.rawValue, color: q.color)
                }
            }
        }

        // Fallback: broad match
        if body.contains("risk-on") || body.contains("risk on") {
            return .riskOn(postureSection.body, "Risk-On")
        } else if body.contains("risk-off") || body.contains("risk off") {
            return .riskOff(postureSection.body, "Risk-Off")
        }
        return nil
    }

    // MARK: - Enhanced Greeting

    private var enhancedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }

        return "\(timeGreeting), \(userName). Here's your daily briefing."
    }

    // MARK: - Sentiment Pill

    private func sentimentPill(_ posture: MarketPosture) -> some View {
        HStack(spacing: 6) {
            Image(systemName: posture.icon)
                .font(.system(size: 10, weight: .bold))

            Text(posture.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(posture.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(posture.color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Structured Summary

    @ViewBuilder
    private func structuredSummary(_ text: String) -> some View {
        let sections = parseSections(text).filter { $0.header.lowercased() != "posture" }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections, id: \.header) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.header)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text(section.body)
                        .font(AppFonts.body14)
                        .foregroundColor(textPrimary.opacity(0.7))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct SummarySection: Hashable {
        let header: String
        let body: String
    }

    private func parseSections(_ text: String) -> [SummarySection] {
        let lines = text.components(separatedBy: "\n")
        var sections: [SummarySection] = []
        var currentHeader: String?
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                // Save previous section
                if let header = currentHeader {
                    let body = currentLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if !body.isEmpty {
                        sections.append(SummarySection(header: String(header.dropFirst(3)), body: body))
                    }
                }
                currentHeader = trimmed
                currentLines = []
            } else if !trimmed.isEmpty {
                currentLines.append(trimmed)
            }
        }

        // Save last section
        if let header = currentHeader {
            let body = currentLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !body.isEmpty {
                sections.append(SummarySection(header: String(header.dropFirst(3)), body: body))
            }
        }

        // Fallback: if no sections parsed, show as single block
        if sections.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(SummarySection(header: "Overview", body: text.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return sections
    }

    // MARK: - Shimmer Placeholder

    private var shimmerPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Reassuring loading message
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Preparing your briefing...")
                    .font(AppFonts.caption12)
                    .foregroundColor(textPrimary.opacity(0.4))
            }

            // Posture pill shimmer
            RoundedRectangle(cornerRadius: 10)
                .fill(shimmerFill)
                .frame(width: 80, height: 24)

            // Section shimmer
            shimmerSection()
            // Section shimmer
            shimmerSection()
        }
    }

    private var shimmerFill: some ShapeStyle {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    private func shimmerSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            shimmerLine(maxWidth: 120)
            shimmerLine(maxWidth: .infinity)
            shimmerLine(maxWidth: 200)
        }
    }

    private func shimmerLine(maxWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                colorScheme == .dark
                    ? Color.white.opacity(0.06)
                    : Color.black.opacity(0.06)
            )
            .frame(maxWidth: maxWidth, minHeight: 14, maxHeight: 14)
    }

    // MARK: - Next Update Label

    private func nextUpdateLabel(for summary: MarketSummary) -> some View {
        let text = nextUpdateText(slot: summary.slot)
        return HStack(spacing: 4) {
            Circle()
                .fill(AppColors.accent.opacity(0.5))
                .frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func nextUpdateText(slot: String) -> String {
        let now = Date()
        var estCal = Calendar(identifier: .gregorian)
        estCal.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        let weekday = estCal.component(.weekday, from: now) // 1=Sun, 7=Sat

        // Use current day to determine the next update, not just the slot
        // (the slot may be stale from a previous day's briefing)
        let isWeekend = weekday == 1 || weekday == 7 // Sun or Sat
        let estHour = estCal.component(.hour, from: now)

        if isWeekend {
            if weekday == 7 { // Saturday
                if estHour < 12 {
                    return "Next update at 12:00 PM ET"
                } else {
                    return "Next update Sunday 12:00 PM ET"
                }
            } else { // Sunday
                if estHour < 12 {
                    return "Next update at 12:00 PM ET"
                } else {
                    return "Next update Monday 10:00 AM ET"
                }
            }
        } else { // Weekday
            switch slot {
            case "morning":
                return "Next update at 5:00 PM ET"
            case "evening":
                if weekday == 6 { // Friday evening
                    return "Next update Saturday 12:00 PM ET"
                } else {
                    return "Next update at 10:00 AM ET"
                }
            default:
                if estHour < 10 {
                    return "Next update at 10:00 AM ET"
                } else if estHour < 17 {
                    return "Next update at 5:00 PM ET"
                } else {
                    return "Next update at 10:00 AM ET"
                }
            }
        }
    }

    // MARK: - Relative Time

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}
