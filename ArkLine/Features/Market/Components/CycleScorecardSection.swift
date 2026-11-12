import SwiftUI

// MARK: - Model

/// One asset's cycle read from the `cycle_scorecard` RPC. A confluence of the
/// signals Arkline already stores (risk band, BTC supply in profit, Fear & Greed,
/// market breadth), scored top vs bottom. A proxy scorecard until on-chain MVRV
/// and NUPL are added.
struct CycleScorecardEntry: Decodable, Identifiable {
    let asset: String
    let riskLevel: Double
    let riskCategory: String
    let fearGreed: Int
    let breadthPct: Double
    let supplyInProfit: Double?   // BTC only
    // On-chain cycle metrics from CryptoQuant. Optional so the app degrades
    // gracefully: until the cycle_scorecard RPC returns them, they decode to
    // nil and their chips simply don't render — no build change needed to turn
    // them on. Weighting into bottom_score/top_score is decided server-side.
    let mvrv: Double?             // market value / realized value (BTC-strongest)
    let nupl: Double?            // net unrealized profit/loss, fraction ~ -0.5..0.75
    let bottomScore: Int
    let topScore: Int
    let applicable: Int
    let cyclePosition: Double      // 0 capitulation .. 100 euphoria
    let verdict: String            // "bottom" | "top" | "neutral"
    let asOf: String

    var id: String { asset }

    enum CodingKeys: String, CodingKey {
        case asset
        case riskLevel = "risk_level"
        case riskCategory = "risk_category"
        case fearGreed = "fear_greed"
        case breadthPct = "breadth_pct"
        case supplyInProfit = "supply_in_profit"
        case mvrv
        case nupl
        case bottomScore = "bottom_score"
        case topScore = "top_score"
        case applicable
        case cyclePosition = "cycle_position"
        case verdict
        case asOf = "as_of"
    }
}

// MARK: - Service

enum CycleScorecardService {
    static func fetch() async throws -> [CycleScorecardEntry] {
        try await SupabaseManager.shared.database
            .rpc("cycle_scorecard")
            .execute()
            .value
    }
}

// MARK: - Cycle Scorecard Section (Market Tab)

/// Where are we in the cycle? A top/bottom confluence read for BTC, ETH and SOL
/// built from Arkline's existing signals. Proxy until on-chain MVRV/NUPL land.
struct CycleScorecardSection: View {
    var refreshId: UUID = UUID()
    @Environment(\.colorScheme) var colorScheme

    @State private var entries: [CycleScorecardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showInfo = false
    @State private var lastLoaded: UUID?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    /// True once any asset is returning on-chain MVRV/NUPL from the RPC. Drives
    /// the on-chain chip row, the info-sheet rows, and the footer copy so the
    /// card reads correctly whether or not CryptoQuant is live yet.
    private var hasOnChain: Bool {
        entries.contains { $0.mvrv != nil || $0.nupl != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading && entries.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            } else if entries.isEmpty {
                Text(errorMessage ?? "No cycle data yet.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(entries) { entry in
                    assetCard(entry)
                }
                mindsetCallout
                footerNote
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        .task(id: refreshId) { await load() }
        .sheet(isPresented: $showInfo) { infoSheet }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Cycle Scorecard")
                    .font(.headline)
                    .foregroundColor(textPrimary)
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if let asOf = entries.first?.asOf {
                    Text("Updated \(formattedAsOf(asOf))")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Text("Where are we in the cycle? A top vs bottom read from your risk bands, sentiment, breadth, and BTC supply in profit.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: Asset Card

    private func assetCard(_ e: CycleScorecardEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(e.asset)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)
                verdictChip(e.verdict)
                Spacer()
                signalTally(bottom: e.bottomScore, top: e.topScore)
            }

            cycleGauge(e.cyclePosition, verdict: e.verdict)

            // Component readings — each chip colored by the state it is flashing:
            // green near a bottom, amber near a top, neutral in the middle.
            HStack(spacing: 6) {
                metricChip("Risk", e.riskCategory, riskState(e.riskLevel))
                metricChip("F&G", "\(e.fearGreed)", fearGreedState(e.fearGreed))
                metricChip("Breadth", "\(Int(e.breadthPct.rounded()))%", breadthState(e.breadthPct))
                if let sip = e.supplyInProfit {
                    metricChip("Supply", "\(Int(sip.rounded()))%", supplyState(sip))
                }
            }

            // On-chain metrics land on their own row so the proxy row above never
            // gets crowded. Renders only for assets the RPC is feeding.
            if e.mvrv != nil || e.nupl != nil {
                HStack(spacing: 6) {
                    if let mvrv = e.mvrv {
                        metricChip("MVRV", formatMVRV(mvrv), mvrvState(mvrv))
                    }
                    if let nupl = e.nupl {
                        metricChip("NUPL", formatNUPL(nupl), nuplState(nupl))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func cycleGauge(_ position: Double, verdict: String) -> some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let x = geo.size.width * CGFloat(min(max(position, 0), 100)) / 100.0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [AppColors.success.opacity(0.55), AppColors.textTertiary.opacity(0.35), AppColors.error.opacity(0.55)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                    Circle()
                        .fill(zoneColor(verdict))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(cardBackground, lineWidth: 2))
                        .position(x: min(max(x, 6), geo.size.width - 6), y: 3)
                }
            }
            .frame(height: 12)
            HStack {
                Text("Capitulation").font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("Euphoria").font(.system(size: 9)).foregroundColor(AppColors.textTertiary)
            }
        }
    }

    /// Whether a single signal is flashing a bottom, a top, or nothing.
    private enum SignalState { case bottom, top, neutral }

    // Thresholds mirror the cycle_scorecard RPC exactly.
    private func riskState(_ v: Double) -> SignalState {
        if v < 0.40 { return .bottom }
        if v >= 0.70 { return .top }
        return .neutral
    }
    private func fearGreedState(_ v: Int) -> SignalState {
        if v <= 25 { return .bottom }
        if v >= 75 { return .top }
        return .neutral
    }
    private func breadthState(_ v: Double) -> SignalState {
        if v <= 25 { return .bottom }
        if v >= 80 { return .top }
        return .neutral
    }
    private func supplyState(_ v: Double) -> SignalState {
        if v <= 50 { return .bottom }
        if v >= 90 { return .top }
        return .neutral
    }

    // On-chain thresholds (CryptoQuant). Kept here as the single place to align
    // with the RPC on Oct 5 — if NUPL arrives as a percent rather than a
    // fraction, or CryptoQuant's MVRV bands differ, adjust only these two.
    //
    // MVRV = market value / realized value. Below 1.0 the average holder is
    // underwater (historic bottom zone); stretched high marks euphoric tops.
    private func mvrvState(_ v: Double) -> SignalState {
        if v < 1.0 { return .bottom }
        if v >= 3.2 { return .top }
        return .neutral
    }
    // NUPL as a fraction (~ -0.5 capitulation .. 0.75 euphoria). At/below 0 the
    // network is in aggregate loss (bottom); 0.5+ is the belief/euphoria band.
    private func nuplState(_ v: Double) -> SignalState {
        if v <= 0 { return .bottom }
        if v >= 0.5 { return .top }
        return .neutral
    }

    private func formatMVRV(_ v: Double) -> String { String(format: "%.1f", v) }
    private func formatNUPL(_ v: Double) -> String { String(format: "%.2f", v) }

    /// Two colored dots: how many signals lean bottom vs top right now.
    private func signalTally(bottom: Int, top: Int) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(AppColors.success).frame(width: 6, height: 6)
                Text("\(bottom) bottom")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            HStack(spacing: 4) {
                Circle().fill(AppColors.warning).frame(width: 6, height: 6)
                Text("\(top) top")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func metricChip(_ label: String, _ value: String, _ state: SignalState) -> some View {
        let tint: Color
        let bgOpacity: Double
        let neutral: Bool
        switch state {
        case .bottom: tint = AppColors.success; bgOpacity = 0.14; neutral = false
        case .top:    tint = AppColors.warning; bgOpacity = 0.14; neutral = false
        case .neutral: tint = AppColors.textTertiary; bgOpacity = 0.10; neutral = true
        }
        return HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(neutral ? AppColors.textTertiary : tint)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(neutral ? AppColors.textSecondary : tint)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(bgOpacity)))
    }

    private func verdictChip(_ verdict: String) -> some View {
        let (label, color): (String, Color)
        switch verdict {
        case "bottom": (label, color) = ("Bottom forming", AppColors.success)
        case "top":    (label, color) = ("Top risk", AppColors.warning)
        default:       (label, color) = ("Mid-cycle", AppColors.textSecondary)
        }
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.3)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.14)))
    }

    /// Turns the RPC's "yyyy-MM-dd" as-of date into US long format,
    /// e.g. "September 21, 2026". Falls back to the raw string if parsing fails.
    private func formattedAsOf(_ raw: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: String(raw.prefix(10))) else { return raw }

        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US")
        out.dateFormat = "MMMM d, yyyy"
        return out.string(from: date)
    }

    private func zoneColor(_ verdict: String) -> Color {
        switch verdict {
        case "bottom": return AppColors.success
        case "top": return AppColors.warning
        default: return AppColors.textSecondary
        }
    }

    /// A calm psychology line matched to where the weight of evidence sits, so
    /// the cycle read comes with the mindset it asks for.
    private var mindsetLine: String {
        if entries.contains(where: { $0.verdict == "bottom" }) {
            return "Bottoms are an act of courage. They arrive wrapped in bad news, which is exactly what makes them bottoms."
        }
        if entries.contains(where: { $0.verdict == "top" }) {
            return "Tops are an act of discipline. They feel like the start of something greater, which is what makes them tops."
        }
        return "The edges are where the asymmetry lives. The middle is noise, and patience is a position."
    }

    private var mindsetCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(AppColors.accent.opacity(0.55))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("MINDSET")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(AppColors.accent)
                Text(mindsetLine)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var footerNote: some View {
        Text(hasOnChain
             ? "Reads on-chain MVRV and NUPL alongside your risk, sentiment and breadth signals. On-chain leans BTC-strongest; the confluence is the point."
             : "Proxy signals from data you already have. On-chain MVRV and NUPL can be added for a deeper read.")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textTertiary)
            .padding(.top, 2)
    }

    private var infoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A cycle is an emotional round trip from capitulation to euphoria. No single metric marks a top or bottom, so this scores several at once and shows where the weight of evidence sits.")
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary)
                    infoRow("Risk band", "Price versus its long-run fair value. Low is undervalued (bottom), high is stretched (top).")
                    infoRow("Supply in Profit", "Share of BTC held in profit. Near 50% marks a bottom; 90%+ marks a euphoric top. BTC only for now.")
                    infoRow("Fear & Greed", "Crowd sentiment. Extreme fear at bottoms, extreme greed at tops.")
                    infoRow("Market breadth", "How broad the uptrend is. A washout at bottoms, froth at tops.")
                    if hasOnChain {
                        infoRow("MVRV", "On-chain: market value versus what coins last moved at. Below 1 the average holder is underwater (bottom); stretched high marks a top. Strongest on BTC.")
                        infoRow("NUPL", "On-chain: net unrealized profit or loss across the network. In the red at capitulation, deep in the green at euphoria.")
                    }
                    Text("Each signal chip is colored by what it is saying: green when it is near a bottom, amber when it is near a top, gray when it is mid-range. The more chips that agree, the stronger the read.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                    Text("Read the confluence, not one line. The edges (capitulation and euphoria) are where the asymmetry lives; the middle is noise.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
            }
            .navigationTitle("Reading the cycle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showInfo = false }
                }
            }
        }
    }

    private func infoRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.accent)
            Text(body).font(.system(size: 12)).foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: Load

    private func load() async {
        if lastLoaded == refreshId, !entries.isEmpty { return }
        isLoading = true
        errorMessage = nil
        do {
            entries = try await CycleScorecardService.fetch()
            lastLoaded = refreshId
            if entries.isEmpty { errorMessage = "No cycle data yet." }
        } catch {
            logWarning("CycleScorecard: \(error.localizedDescription)", category: .network)
            if entries.isEmpty { errorMessage = "Couldn't load the cycle scorecard." }
        }
        isLoading = false
    }
}
