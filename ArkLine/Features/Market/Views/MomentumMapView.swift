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
                    ForEach(groups, id: \.0) { quadrant, pairs in
                        quadrantSection(quadrant, pairs: pairs)
                    }
                }

                howItWorks
            }
            .padding(.vertical)
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
            asOf = signals.first?.signalDate
            if groups.isEmpty {
                errorMessage = "No paired positioning data available yet."
            }
        } catch {
            // One quick retry to absorb transient network/session failures.
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
                let signals = try await service.fetchLatestSignals(forceRefresh: true)
                groups = MomentumPair.grouped(from: signals)
                asOf = signals.first?.signalDate
            } catch {
                logWarning("MomentumMap: \(error.localizedDescription)", category: .network)
                if groups.isEmpty {
                    errorMessage = "Couldn't load the momentum map. Check your connection and tap retry."
                }
            }
        }
        isLoading = false
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
                Image(systemName: quadrant.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(quadrant.accent)
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
                    pairRow(pair)
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

    private func pairRow(_ pair: MomentumPair) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(pair.asset)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)
                    if !pair.isRealBTCPair {
                        Text("synthetic")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(textPrimary.opacity(0.06)))
                    }
                }
                Text(pair.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            signalPill(label: "USD", signal: pair.usdSignal, score: pair.usdScore)
            signalPill(label: "BTC", signal: pair.btcSignal, score: pair.btcScore)
        }
        .padding(.vertical, 8)
    }

    private func signalPill(label: String, signal: PositioningSignal, score: Int) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(signal.color.opacity(0.7))
            Text(signal.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(signal.color)
            Text("\(score)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(signal.color.opacity(0.65))
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
            bulletPoint("Synthetic pairs are derived as USD ÷ BTC price; when Bitcoin itself is falling they can read bullish simply because the asset is dropping slower. Treat the real Coinbase pairs as the cleaner read.")
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
