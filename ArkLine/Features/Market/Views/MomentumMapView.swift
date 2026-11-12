import SwiftUI

// MARK: - Momentum Map View

/// Dual-confirmation momentum board. Surfaces assets where the USD pair and the
/// BTC pair agree: both bullish = true momentum, while the off-diagonal quadrants
/// surface relative-strength leaders (gaining on BTC) and laggards. Reads the
/// already-cached daily positioning signals — no extra pipeline.
struct MomentumMapView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var groups: [(MomentumQuadrant, [MomentumPair])] = []
    @State private var asOf: Date?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var streakByAsset: [String: Int] = [:]

    private let service = PositioningSignalService()

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading && groups.isEmpty {
                    loadingState
                } else if groups.isEmpty {
                    errorState
                } else {
                    if let asOf {
                        asOfHeader(asOf)
                    }
                    leaderboardLink
                    ForEach(groups, id: \.0) { quadrant, pairs in
                        quadrantSection(quadrant, pairs: pairs)
                    }
                }

                howItWorks
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .navigationTitle("Momentum Map")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(AppColors.background(colorScheme))
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let signals = try await service.fetchLatestSignals()
            groups = MomentumPair.grouped(from: signals)
            await loadStreaks()
            // Header date = the freshest signal in the set. `signals` is sorted by
            // asset name, so `.first` was showing whichever asset sorts first
            // alphabetically (often a lagging stock/index dated a few days back),
            // making fresh data look stale. Use the max date instead.
            asOf = signals.map(\.signalDate).max()
            if groups.isEmpty {
                errorMessage = "No paired positioning data available yet."
            }
        } catch {
            // One quick retry to absorb transient network/session failures.
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                let signals = try await service.fetchLatestSignals(forceRefresh: true)
                groups = MomentumPair.grouped(from: signals)
                asOf = signals.map(\.signalDate).max()
            } catch {
                logWarning("MomentumMap: \(error.localizedDescription)", category: .network)
                if groups.isEmpty {
                    errorMessage = "Couldn't load the momentum map. Check your connection and tap retry."
                }
            }
        }
        isLoading = false
    }

    /// Best-effort: pull current momentum streaks so each row can show how many
    /// days straight it has been in true momentum. Never blocks the map.
    private func loadStreaks() async {
        if let entries = try? await service.fetchMomentumLeaderboard(days: 90) {
            streakByAsset = Dictionary(entries.map { ($0.asset, $0.currentStreak) },
                                       uniquingKeysWith: { a, _ in a })
        }
    }

    // MARK: - Header

    private func asOfHeader(_ date: Date) -> some View {
        HStack {
            Text("Where the USD and BTC pair agree")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal)
    }

    // MARK: - Quadrant Section

    private func quadrantSection(_ quadrant: MomentumQuadrant, pairs: [MomentumPair]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(quadrant.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quadrant.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Text(quadrant.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text("\(pairs.count)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(quadrant.accent)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(pairs.enumerated()), id: \.element.id) { index, pair in
                    pairRow(pair, isTop: quadrant == .momentum && index == 0, streak: streakByAsset[pair.asset])
                    if index < pairs.count - 1 {
                        Divider().background(textPrimary.opacity(0.06))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(quadrant.accent.opacity(0.22), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private func pairRow(_ pair: MomentumPair, isTop: Bool, streak: Int?) -> some View {
        NavigationLink {
            AssetMomentumHistoryView(asset: pair.asset, displayName: pair.displayName)
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(pair.asset)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(textPrimary)
                            if isTop { strongestBadge }
                            if let streak, streak >= 2 { StreakChip(days: streak) }
                        }
                        Text(pair.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    signalPill(label: "USD", signal: pair.usdSignal)
                    signalPill(label: "BTC", signal: pair.btcSignal)
                }

                // Momentum strength meter (0-100 combined USD + BTC score).
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(textPrimary.opacity(0.06))
                                .frame(height: 4)
                            Capsule().fill(strengthColor(pair.combinedScore))
                                .frame(width: max(4, geo.size.width * CGFloat(pair.combinedScore) / 100.0), height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(pair.combinedScore)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 24, alignment: .trailing)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppColors.textTertiary.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var strongestBadge: some View {
        Text("STRONGEST")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundColor(AppColors.success)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(AppColors.success.opacity(0.12)))
    }

    private func strengthColor(_ score: Int) -> Color {
        switch score {
        case 80...: return AppColors.success
        case 65..<80: return AppColors.success.opacity(0.7)
        case 50..<65: return AppColors.warning
        default: return AppColors.error.opacity(0.7)
        }
    }

    private var leaderboardLink: some View {
        NavigationLink {
            MomentumLeaderboardView()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppColors.textSecondary)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Momentum over time")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                    Text("Who held the most momentum over 7, 30, or 90 days")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func signalPill(label: String, signal: PositioningSignal) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(signal.color.opacity(0.7))
            Text(signal.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(signal.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(signal.color.opacity(0.12)))
    }

    // MARK: - Loading / Error States

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding(.vertical, 60)
            Spacer()
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textTertiary)
            Text(errorMessage ?? "No momentum data available yet.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
            Button {
                Task { await loadData() }
            } label: {
                Text("Retry")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.accent))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - How It Works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How the Momentum Map Works")
                .font(.headline)
                .foregroundColor(textPrimary)

            bulletPoint("Each asset is read on two pairs: its USD pair (e.g. SOL/USD) and its BTC pair (e.g. SOL/BTC), each scored 0–100 and classified bullish, neutral, or bearish.")
            bulletPoint("True momentum = both pairs bullish. Historically the strongest, most durable moves happen when an asset is rising in dollars AND gaining on Bitcoin at the same time.")
            bulletPoint("Outperforming BTC = the BTC pair is bullish while USD lags. These are relative-strength leaders that often move first when risk turns back on.")
            bulletPoint("Leading in USD = strong in dollar terms but not yet beating Bitcoin. Both bearish = no momentum.")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .padding(.horizontal)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Momentum Leaderboard (over time)

/// Ranks crypto assets by how much momentum they held over a chosen window
/// (7 / 30 / 90 days): days spent in true momentum, then average strength.
struct MomentumLeaderboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var window = 30
    @State private var sort: LeaderboardSort = .consistency
    @State private var entries: [MomentumLeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = PositioningSignalService()
    private let windows = [7, 30, 90]

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    enum LeaderboardSort: String, CaseIterable, Identifiable {
        case consistency = "Days in momentum"
        case strength = "Avg strength"
        case streak = "Current streak"
        var id: String { rawValue }
    }

    private var sortedEntries: [MomentumLeaderboardEntry] {
        // Every sort ends with the ticker as a deterministic tiebreak so equal
        // metrics never reshuffle between opens.
        switch sort {
        case .consistency:
            return entries.sorted {
                ($0.daysTrueMomentum, $0.avgStrength, $1.asset) > ($1.daysTrueMomentum, $1.avgStrength, $0.asset)
            }
        case .strength:
            return entries.sorted {
                ($0.avgStrength, Double($0.daysTrueMomentum), $1.asset) > ($1.avgStrength, Double($1.daysTrueMomentum), $0.asset)
            }
        case .streak:
            return entries.sorted {
                ($0.currentStreak, $0.avgStrength, $1.asset) > ($1.currentStreak, $1.avgStrength, $0.asset)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Window", selection: $window) {
                    ForEach(windows, id: \.self) { d in Text("\(d)d").tag(d) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                HStack(spacing: 6) {
                    Text("Sort by")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Menu {
                        ForEach(LeaderboardSort.allCases) { option in
                            Button(option.rawValue) { sort = option }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sort.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                if isLoading && entries.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if entries.isEmpty {
                    Text(errorMessage ?? "No data yet.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            leaderboardRow(rank: index + 1, entry: entry)
                            if index < sortedEntries.count - 1 {
                                Divider().background(textPrimary.opacity(0.06))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .navigationTitle("Momentum Leaderboard")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(AppColors.background(colorScheme))
        .task(id: window) { await load() }
    }

    private func leaderboardRow(rank: Int, entry: MomentumLeaderboardEntry) -> some View {
        NavigationLink {
            AssetMomentumHistoryView(asset: entry.asset, displayName: entry.displayName)
        } label: {
            HStack(spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(rank <= 3 ? textPrimary : AppColors.textTertiary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(entry.asset)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textPrimary)
                        if entry.latestTrue, entry.currentStreak >= 2 {
                            StreakChip(days: entry.currentStreak)
                        } else if !entry.latestTrue {
                            Text("FADED")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(AppColors.textTertiary)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(AppColors.textTertiary.opacity(0.15)))
                        }
                    }
                    Text(entry.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Sparkline(values: entry.spark, color: entry.latestTrue ? AppColors.success : AppColors.textTertiary)
                    .frame(width: 46, height: 22)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.momentumPct)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(entry.latestTrue ? AppColors.success : AppColors.textSecondary)
                    Text("\(entry.daysTrueMomentum)/\(entry.daysTracked)d · \(Int(entry.avgStrength.rounded()))")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textTertiary)
                }
                .frame(width: 72, alignment: .trailing)
            }
            .padding(.vertical, 8)
            .opacity(entry.latestTrue ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await service.fetchMomentumLeaderboard(days: window)
            if entries.isEmpty { errorMessage = "No momentum data for this window yet." }
        } catch {
            logWarning("MomentumLeaderboard: \(error.localizedDescription)", category: .network)
            errorMessage = "Couldn't load the leaderboard."
        }
        isLoading = false
    }
}

// MARK: - Per-Asset Momentum History

/// One asset's momentum over time: a summary, a daily strength strip, and the
/// share of days spent in true momentum, across a 7 / 30 / 90 day window.
struct AssetMomentumHistoryView: View {
    let asset: String
    let displayName: String

    @Environment(\.colorScheme) var colorScheme
    @State private var window = 30
    @State private var days: [AssetMomentumDay] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = PositioningSignalService()
    private let windows = [7, 30, 90]

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var trueDays: Int { days.filter(\.bothBull).count }
    private var avgStrength: Int {
        guard !days.isEmpty else { return 0 }
        return Int((days.map(\.strength).reduce(0, +) / Double(days.count)).rounded())
    }
    /// Consecutive most-recent days in true momentum (days is oldest-first).
    private var currentStreak: Int {
        var c = 0
        for day in days.reversed() {
            if day.bothBull { c += 1 } else { break }
        }
        return c
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Window", selection: $window) {
                    ForEach(windows, id: \.self) { d in Text("\(d)d").tag(d) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal)

                if isLoading && days.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if days.isEmpty {
                    Text(errorMessage ?? "No history yet.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    HStack(spacing: 10) {
                        stat("\(currentStreak)d", "current streak")
                        stat("\(trueDays)/\(days.count)", "days in momentum")
                        stat("\(avgStrength)", "avg strength")
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily momentum")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                        strengthChart
                        Text("Bar height = combined strength. Green = true momentum (both bullish). Oldest on the left, newest on the right.")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
                    .padding(.horizontal)
                }
            }
            .padding(.top)
            .padding(.bottom, 100)
        }
        .navigationTitle(asset)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .background(AppColors.background(colorScheme))
        .task(id: window) { await load() }
    }

    private var strengthChart: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(day))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, CGFloat(day.strength) / 100.0 * 64))
            }
        }
        .frame(height: 64, alignment: .bottom)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
    }

    private func barColor(_ day: AssetMomentumDay) -> Color {
        if day.bothBull { return AppColors.success }
        return day.strength >= 50 ? AppColors.warning : AppColors.error.opacity(0.7)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            days = try await service.fetchAssetMomentumHistory(asset: asset, days: window)
            if days.isEmpty { errorMessage = "No history for \(asset) yet." }
        } catch {
            logWarning("AssetMomentumHistory: \(error.localizedDescription)", category: .network)
            errorMessage = "Couldn't load history."
        }
        isLoading = false
    }
}

// MARK: - Shared components

/// A restrained streak tag: consecutive true-momentum days as a thin, monochrome
/// outlined pill (e.g. "31D"). Deliberately understated to keep an institutional feel.
struct StreakChip: View {
    let days: Int
    var body: some View {
        Text("\(days)D")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .tracking(0.5)
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                Capsule().stroke(AppColors.textTertiary.opacity(0.35), lineWidth: 0.8)
            )
    }
}

/// A tiny line chart of recent strength values (0-100), oldest first. Self-scales
/// to its own min/max so the shape (building vs fading) reads at a glance.
struct Sparkline: View {
    let values: [Double]
    var color: Color
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count >= 2 {
                Path { path in
                    path.move(to: pts[0])
                    for pt in pts.dropFirst() { path.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            } else if let only = pts.first {
                Circle().fill(color)
                    .frame(width: lineWidth * 2, height: lineWidth * 2)
                    .position(only)
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 1)
        let n = values.count
        return values.enumerated().map { i, v in
            let x = n == 1 ? size.width / 2 : size.width * CGFloat(i) / CGFloat(n - 1)
            let y = size.height * (1 - CGFloat((v - minV) / range))
            return CGPoint(x: x, y: y)
        }
    }
}
