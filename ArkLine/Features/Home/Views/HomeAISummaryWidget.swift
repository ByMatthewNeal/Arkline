import SwiftUI

// MARK: - AI Daily Market Summary Widget
struct HomeAISummaryWidget: View {
    let summary: MarketSummary?
    let isLoading: Bool
    let userName: String
    var size: WidgetSize = .standard
    var isAdmin: Bool = false
    var onFeedback: ((Bool, String?) -> Void)? = nil
    @State private var showNoteField = false
    @State private var selectedRating: Bool?
    @State private var feedbackNote = ""
    @State private var feedbackSent = false
    @State private var feedbackSentWithNote = false
    @State private var regenerationStart: Date?
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(AppColors.accent)

                    Text("Daily Briefing")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                if let summary {
                    Text(relativeTime(from: summary.generatedAt))
                        .font(AppFonts.caption12)
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            // Greeting with market posture
            Text(enhancedGreeting)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.85))

            // Sentiment pill
            if let posture = parsedPosture {
                sentimentPill(posture)
            }

            // Body
            if summary == nil && isLoading {
                if feedbackSentWithNote {
                    regeneratingBanner
                }
                shimmerPlaceholder
            } else if let summary {
                structuredSummary(summary.summary)
            } else {
                Text("Market briefing unavailable")
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary.opacity(0.3))
            }

            // Admin feedback row
            if isAdmin, summary != nil {
                feedbackRow
            }
        }
        .padding(size == .compact ? 14 : 18)
        .glassCard(cornerRadius: 16)
        .onChange(of: summary?.generatedAt) {
            // New briefing arrived — reset regeneration state
            if summary != nil, feedbackSentWithNote {
                feedbackSentWithNote = false
                feedbackSent = false
                selectedRating = nil
                regenerationStart = nil
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

    private var currentRating: Bool? {
        summary?.feedbackRating
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
                    Image(systemName: (currentRating == true || selectedRating == true) ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 16))
                        .foregroundColor((currentRating == true || selectedRating == true) ? AppColors.success : textPrimary.opacity(0.4))
                }

                // Thumbs down
                Button {
                    selectedRating = false
                    showNoteField = true
                    feedbackNote = ""
                    feedbackSent = false
                    feedbackSentWithNote = false
                } label: {
                    Image(systemName: (currentRating == false || selectedRating == false) ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: 16))
                        .foregroundColor((currentRating == false || selectedRating == false) ? AppColors.error : textPrimary.opacity(0.4))
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
                        feedbackSentWithNote = hasNote
                        regenerationStart = hasNote ? .now : nil
                        feedbackNote = ""
                        showNoteField = false
                        feedbackSent = true
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.accent)
                    }
                }
                .onAppear {
                    if let existingNote = summary?.feedbackNote, feedbackNote.isEmpty {
                        feedbackNote = existingNote
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

    private enum MarketPosture {
        case riskOn(String, String) // (detail, quadrant label)
        case riskOff(String, String)
        case neutral(String, String)

        var label: String {
            switch self {
            case .riskOn(_, let q), .riskOff(_, let q), .neutral(_, let q): return q
            }
        }

        var color: Color {
            switch self {
            case .riskOn: return AppColors.success
            case .riskOff: return AppColors.error
            case .neutral: return AppColors.warning
            }
        }

        var icon: String {
            switch self {
            case .riskOn: return "arrow.up.right"
            case .riskOff: return "arrow.down.right"
            case .neutral: return "arrow.right"
            }
        }

        var detail: String {
            switch self {
            case .riskOn(let d, _), .riskOff(let d, _), .neutral(let d, _): return d
            }
        }
    }

    /// Extract the regime quadrant label from the posture text (e.g. "Risk-On Disinflation")
    private static let quadrantLabels = [
        "risk-on disinflation", "risk-on inflation",
        "risk-off inflation", "risk-off disinflation"
    ]

    private var parsedPosture: MarketPosture? {
        guard let text = summary?.summary else { return nil }
        let sections = parseSections(text)
        guard let postureSection = sections.first(where: { $0.header.lowercased() == "posture" }) else { return nil }
        let body = postureSection.body.lowercased()

        // Try to extract the full quadrant name (e.g. "Risk-On Disinflation")
        let quadrantLabel: String = {
            for q in Self.quadrantLabels {
                if body.contains(q) {
                    // Title-case it back from the original text
                    if let range = body.range(of: q) {
                        return String(postureSection.body[range])
                    }
                }
            }
            // Fallback to simple labels
            if body.contains("risk-on") || body.contains("risk on") { return "Risk-On" }
            if body.contains("risk-off") || body.contains("risk off") { return "Risk-Off" }
            return "Neutral"
        }()

        if body.contains("risk-on") || body.contains("risk on") {
            return .riskOn(postureSection.body, quadrantLabel)
        } else if body.contains("risk-off") || body.contains("risk off") {
            return .riskOff(postureSection.body, quadrantLabel)
        } else {
            return .neutral(postureSection.body, quadrantLabel)
        }
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
