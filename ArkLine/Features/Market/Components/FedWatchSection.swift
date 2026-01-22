import SwiftUI

// MARK: - Fed Watch Section
struct FedWatchSection: View {
    @Environment(\.colorScheme) var colorScheme
    let meetings: [FedWatchData]
    @State private var selectedMeetingIndex: Int = 0
    @State private var showInfoSheet = false

    private var selectedMeeting: FedWatchData? {
        guard selectedMeetingIndex < meetings.count else { return nil }
        return meetings[selectedMeetingIndex]
    }

    // Computed probabilities for selected meeting
    private var easeProbability: Double {
        selectedMeeting?.probabilities.filter { $0.change < 0 }.reduce(0) { $0 + $1.probability } ?? 0
    }

    private var noChangeProbability: Double {
        selectedMeeting?.probabilities.filter { $0.change == 0 }.reduce(0) { $0 + $1.probability } ?? 0
    }

    private var hikeProbability: Double {
        selectedMeeting?.probabilities.filter { $0.change > 0 }.reduce(0) { $0 + $1.probability } ?? 0
    }

    private var marketSentiment: FedSentiment {
        if easeProbability > 0.5 {
            return .bullish
        } else if hikeProbability > 0.3 {
            return .bearish
        } else {
            return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "3B82F6"))

                    Text("Fed Watch")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                Spacer()

                Button(action: { showInfoSheet = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)

            // Meeting Selector (horizontal scroll)
            if meetings.count > 1 {
                MeetingSelector(
                    meetings: meetings,
                    selectedIndex: $selectedMeetingIndex
                )
            }

            // Content Card
            if let data = selectedMeeting {
                FedWatchCard(
                    data: data,
                    easeProbability: easeProbability,
                    noChangeProbability: noChangeProbability,
                    hikeProbability: hikeProbability,
                    sentiment: marketSentiment
                )
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.2), value: selectedMeetingIndex)
            } else if meetings.isEmpty {
                PlaceholderCard(title: "Fed Rate Probabilities", icon: "building.columns")
                    .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            FedWatchInfoSheet()
        }
    }
}

// MARK: - Meeting Selector
struct MeetingSelector: View {
    @Environment(\.colorScheme) var colorScheme
    let meetings: [FedWatchData]
    @Binding var selectedIndex: Int

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(meetings.enumerated()), id: \.offset) { index, meeting in
                    MeetingDateChip(
                        date: meeting.meetingDate,
                        isSelected: index == selectedIndex,
                        isNext: index == 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIndex = index
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Meeting Date Chip
struct MeetingDateChip: View {
    @Environment(\.colorScheme) var colorScheme
    let date: Date
    let isSelected: Bool
    let isNext: Bool
    let action: () -> Void

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if isNext {
                    Text("NEXT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isSelected ? .white : Color(hex: "3B82F6"))
                }

                Text(monthString)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)

                Text(dayString)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary(colorScheme))
            }
            .frame(width: 52, height: isNext ? 58 : 48)
            .background(
                isSelected
                    ? Color(hex: "3B82F6")
                    : (colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "F0F0F0"))
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(hex: "2A2A2A").opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Fed Sentiment
enum FedSentiment {
    case bullish
    case neutral
    case bearish

    var label: String {
        switch self {
        case .bullish: return "Bullish for Risk Assets"
        case .neutral: return "Neutral Outlook"
        case .bearish: return "Bearish for Risk Assets"
        }
    }

    // Simplified: only use green/red for clear directional signals
    var color: Color {
        switch self {
        case .bullish: return AppColors.success
        case .neutral: return AppColors.textSecondary  // Neutral = gray, not yellow
        case .bearish: return AppColors.error
        }
    }

    var icon: String {
        switch self {
        case .bullish: return "arrow.up.right"
        case .neutral: return "minus"
        case .bearish: return "arrow.down.right"
        }
    }
}

// MARK: - Fed Watch Card
struct FedWatchCard: View {
    @Environment(\.colorScheme) var colorScheme
    let data: FedWatchData
    let easeProbability: Double
    let noChangeProbability: Double
    let hikeProbability: Double
    let sentiment: FedSentiment

    var body: some View {
        VStack(spacing: 16) {
            // Meeting Info Row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next FOMC Meeting")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text(data.meetingDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Rate")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Text(formatRateRange(data.currentRate))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }

            Divider()
                .background(Color(hex: "2A2A2A"))

            // Probabilities - simplified with accent blue for all
            HStack(spacing: 12) {
                ProbabilityPill(
                    label: "Cut",
                    probability: easeProbability,
                    isHighlighted: easeProbability > noChangeProbability && easeProbability > hikeProbability
                )

                ProbabilityPill(
                    label: "Hold",
                    probability: noChangeProbability,
                    isHighlighted: noChangeProbability >= easeProbability && noChangeProbability >= hikeProbability
                )

                ProbabilityPill(
                    label: "Hike",
                    probability: hikeProbability,
                    isHighlighted: hikeProbability > noChangeProbability && hikeProbability > easeProbability
                )
            }

            // Market Sentiment Badge
            HStack(spacing: 6) {
                Image(systemName: sentiment.icon)
                    .font(.system(size: 12))

                Text(sentiment.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(sentiment.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(sentiment.color.opacity(0.15))
            .cornerRadius(20)

            // Last Updated
            Text("Data from CME FedWatch • \(data.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func formatRateRange(_ midpoint: Double) -> String {
        let lower = midpoint - 0.125
        let upper = midpoint + 0.125
        return String(format: "%.2f-%.2f%%", lower, upper)
    }
}

// MARK: - Probability Pill
struct ProbabilityPill: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let probability: Double
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)

            Text("\(Int(probability * 100))%")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(isHighlighted ? AppColors.accent : AppColors.textPrimary(colorScheme))

            // Mini progress bar - simplified monochrome
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08)
                        )
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(isHighlighted ? AppColors.accent : AppColors.textSecondary.opacity(0.5))
                        .frame(width: geometry.size.width * probability, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            isHighlighted
                ? AppColors.accent.opacity(0.1)
                : Color.clear
        )
        .cornerRadius(12)
    }
}

// MARK: - Fed Watch Info Sheet
struct FedWatchInfoSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Understanding Fed Watch")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("How Federal Reserve interest rate decisions impact your investments")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    // What is it section
                    InfoSection(
                        icon: "building.columns.fill",
                        iconColor: AppColors.accent,
                        title: "What is the Fed Watch Tool?",
                        content: "The CME FedWatch Tool shows the market's expectations for upcoming Federal Reserve interest rate decisions. These probabilities are derived from Fed Funds futures prices traded on the CME."
                    )

                    // Why it matters
                    InfoSection(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppColors.accent,
                        title: "Why It Matters for Crypto & Stocks",
                        content: "Interest rates affect all risk assets including crypto and stocks. When the Fed cuts rates, borrowing becomes cheaper, liquidity increases, and investors tend to move into riskier assets seeking higher returns."
                    )

                    // Rate Cut Impact
                    ImpactCard(
                        title: "Rate Cut (Easing)",
                        subtitle: "Generally Bullish",
                        icon: "arrow.down.circle.fill",
                        iconColor: AppColors.success,
                        impacts: [
                            "Lower borrowing costs increase investment",
                            "Weaker dollar can boost Bitcoin prices",
                            "More liquidity flows into risk assets",
                            "Tech stocks and crypto typically rally"
                        ]
                    )

                    // Rate Hike Impact
                    ImpactCard(
                        title: "Rate Hike (Tightening)",
                        subtitle: "Generally Bearish",
                        icon: "arrow.up.circle.fill",
                        iconColor: AppColors.error,
                        impacts: [
                            "Higher borrowing costs reduce spending",
                            "Stronger dollar can pressure Bitcoin",
                            "Investors move to safer assets (bonds)",
                            "Growth stocks and crypto often decline"
                        ]
                    )

                    // Hold Impact
                    ImpactCard(
                        title: "No Change (Hold)",
                        subtitle: "Neutral / Mixed",
                        icon: "minus.circle.fill",
                        iconColor: AppColors.textSecondary,
                        impacts: [
                            "Market reaction depends on expectations",
                            "If hold was expected: minimal impact",
                            "Focus shifts to Fed's forward guidance",
                            "Watch for hints about future decisions"
                        ]
                    )

                    // Pro Tip
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(AppColors.accent)
                            Text("Pro Tip")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Text("Markets often \"price in\" expected rate decisions ahead of time. The biggest moves happen when the Fed surprises the market with an unexpected decision or changes their forward guidance.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(16)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(12)

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(AppColors.background(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Info Section
struct InfoSection: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Text(content)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Impact Card
struct ImpactCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let impacts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(iconColor)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(impacts, id: \.self) { impact in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 6, height: 6)
                            .offset(y: 6)

                        Text(impact)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: colorScheme == .dark ? "1F1F1F" : "F5F5F5"))
        .cornerRadius(12)
    }
}

#Preview {
    ScrollView {
        FedWatchSection(
            meetings: [
                FedWatchData(
                    meetingDate: Date().addingTimeInterval(7 * 24 * 3600),
                    currentRate: 3.625,
                    probabilities: [
                        RateProbability(targetRate: 3.375, change: -25, probability: 0.05),
                        RateProbability(targetRate: 3.625, change: 0, probability: 0.95),
                        RateProbability(targetRate: 3.875, change: 25, probability: 0.00)
                    ],
                    lastUpdated: Date()
                ),
                FedWatchData(
                    meetingDate: Date().addingTimeInterval(60 * 24 * 3600),
                    currentRate: 3.625,
                    probabilities: [
                        RateProbability(targetRate: 3.375, change: -25, probability: 0.20),
                        RateProbability(targetRate: 3.625, change: 0, probability: 0.75),
                        RateProbability(targetRate: 3.875, change: 25, probability: 0.05)
                    ],
                    lastUpdated: Date()
                )
            ]
        )
    }
    .background(Color(hex: "0F0F0F"))
}
