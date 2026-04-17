import SwiftUI

struct BriefingArchiveView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var briefings: [MarketSummary] = []
    @State private var isLoading = true
    @State private var expandedKey: String?

    private var grouped: [(String, [MarketSummary])] {
        let dict = Dictionary(grouping: briefings) { $0.summaryDate }
        return dict.sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if briefings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textTertiary)
                    Text("No past briefings")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(grouped, id: \.0) { date, items in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(formatDate(date))
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                    .padding(.horizontal, 4)

                                ForEach(items, id: \.briefingKey) { briefing in
                                    briefingCard(briefing)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .refreshable {
            await loadArchive()
        }
        .navigationTitle("Past Briefings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await loadArchive()
        }
    }

    @ViewBuilder
    private func briefingCard(_ briefing: MarketSummary) -> some View {
        let isExpanded = expandedKey == briefing.briefingKey

        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.arkSpring) {
                    expandedKey = isExpanded ? nil : briefing.briefingKey
                }
            } label: {
                HStack {
                    slotBadge(briefing.slot)

                    Text(timeString(briefing.generatedAt))
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    // Preview posture from first line
                    if let posture = extractPosture(briefing.summary) {
                        Text(posture)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(AppColors.divider(colorScheme))

                briefingContent(briefing.summary)
            }
        }
        .padding(14)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func slotBadge(_ slot: String) -> some View {
        let (label, color): (String, Color) = switch slot {
        case "morning": ("Morning", AppColors.warning)
        case "evening": ("Evening", Color(hex: "8B5CF6"))
        case "weekend": ("Weekend", AppColors.accent)
        default: (slot.capitalized, AppColors.textSecondary)
        }

        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    @ViewBuilder
    private func briefingContent(_ markdown: String) -> some View {
        let sections = parseSections(markdown)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections, id: \.header) { section in
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.header)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                    Text(section.body)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadArchive() async {
        do {
            briefings = try await MarketSummaryService.shared.fetchBriefingArchive(limit: 30)
        } catch {
            logError("Failed to load briefing archive: \(error)", category: .network)
        }
        isLoading = false
    }

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    private func formatDate(_ dateString: String) -> String {
        guard let date = Self.dateParser.date(from: dateString) else { return dateString }
        return Self.displayFormatter.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        Self.timeFormatter.string(from: date) + " ET"
    }

    private func extractPosture(_ summary: String) -> String? {
        guard let range = summary.range(of: "## Posture") else { return nil }
        let after = summary[range.upperBound...]
        let line = after.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .first?
            .trimmingCharacters(in: .whitespaces)
        guard let line, !line.isEmpty, !line.hasPrefix("##") else { return nil }
        return line.count > 60 ? String(line.prefix(57)) + "..." : line
    }

    private struct BriefingSection: Hashable {
        let header: String
        let body: String
    }

    private func parseSections(_ markdown: String) -> [BriefingSection] {
        let parts = markdown.components(separatedBy: "## ")
        return parts.compactMap { part in
            let lines = part.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")
            guard let header = lines.first?.trimmingCharacters(in: .whitespaces),
                  !header.isEmpty else { return nil }
            let body = lines.dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { return nil }
            return BriefingSection(header: header, body: body)
        }
    }
}
