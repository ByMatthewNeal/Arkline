import SwiftUI
import Kingfisher

// MARK: - Signal Detail View

struct SignalDetailView: View {
    let signalId: UUID
    private let initialSignal: TradeSignal?
    @State private var signal: TradeSignal?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showMethodology = false
    @State private var showEducationalModal = false
    @State private var showShareSheet = false
    @State private var currentLeverageCalc: LeverageCalculation?
    @State private var currentPrice: Double?
    @State private var customEntryText: String = ""
    @State private var showCustomEntry = false
    @State private var refreshTimer: Timer?
    @State private var manualExitText: String = ""
    @State private var showManualResolve = false
    @State private var isResolving = false
    @State private var resolveError: String?
    @State private var resolveSuccess = false
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    private let service = SwingSetupService()
    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    init(signalId: UUID, signal: TradeSignal? = nil) {
        self.signalId = signalId
        self.initialSignal = signal
        // If we have the signal upfront, skip the loading skeleton
        self._signal = State(initialValue: signal)
        self._isLoading = State(initialValue: signal == nil)
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 16) {
                    SkeletonCard()
                    SkeletonCard()
                    SkeletonCard()
                }
                .padding()
            } else if let loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.warning)
                    Text("Failed to load signal")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                    Text(loadError)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await loadData() }
                    } label: {
                        Text("Retry")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppColors.accent)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let signal {
                VStack(spacing: 20) {
                    headerSection(signal)
                    statusBanner(signal)
                    TradeStructureChart(signal: signal)

                    if let pattern = signal.chartPattern {
                        chartPatternCard(pattern, signal: signal)
                    }

                    if let briefing = signal.briefingText, !briefing.isEmpty {
                        aiAnalysisCard(briefing)
                    }

                    tradeParametersCard(signal)

                    if signal.status.isLive {
                        customEntryCard(signal)
                    }

                    LeverageCalculatorView(signal: signal, startExpanded: true) { calc in
                        currentLeverageCalc = calc
                    }

                    if signal.isT1Hit || signal.isRunnerPhase {
                        runnerTrackingCard(signal)
                    }

                    // Admin: Manual Resolution
                    if appState.currentUser?.isAdmin == true && signal.status.isLive {
                        adminManualResolveCard(signal)
                    }

                    // Show badge if signal was manually resolved
                    if signal.isManuallyResolved {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 11))
                            Text("Manually resolved by admin")
                                .font(AppFonts.caption12)
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppColors.textSecondary.opacity(0.08))
                        .cornerRadius(8)
                    }

                    statusTimeline(signal)
                    disclaimerSection

                    NavigationLink {
                        SwingSetupsDetailView()
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View All Setups & History")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(12)
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .refreshable {
            await loadData()
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Signal Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if signal != nil, appState.currentUser?.isAdmin == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMethodology = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(isPresented: $showMethodology) {
            SignalMethodologySheet()
        }
        .sheet(isPresented: $showShareSheet) {
            if let signal {
                TradeSignalShareSheet(
                    signal: signal,
                    leverageInfo: currentLeverageCalc.map { ShareLeverageInfo(from: $0) },
                    currentPrice: currentPrice
                )
            }
        }
        .alert("Educational Tool", isPresented: $showEducationalModal) {
            Button("Got It", role: .cancel) { }
        } message: {
            Text("Arkline identifies technical pattern conditions across timeframes. These signals are educational tools, not financial or investment advice. Always do your own research.")
        }
        .task {
            await loadData()
            startRefreshTimerIfNeeded()
        }
        .onAppear {
            let key = "arkline_signal_detail_education_shown"
            if !UserDefaults.standard.bool(forKey: key) {
                showEducationalModal = true
                UserDefaults.standard.set(true, forKey: key)
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func loadData() async {
        // Pre-populate from cache if available (avoids stuck skeleton)
        if signal == nil, let cached = SwingSetupService.cachedActiveSignals?.first(where: { $0.id == signalId }) {
            signal = cached
        }

        // Only show skeleton if we have no cached data
        if signal == nil {
            isLoading = true
        }
        loadError = nil
        defer { isLoading = false }

        do {
            let fetched = try await withTimeout(seconds: 5) { [service, signalId] in
                try await service.fetchSignal(id: signalId)
            }
            signal = fetched
            await fetchCurrentPrice(asset: fetched.asset)
        } catch {
            logError("Signal detail load failed for \(signalId): \(error)", category: .network)
            // If we already have data (from init or cache), just log — don't overwrite
            if signal == nil {
                loadError = "Unable to load signal. Please try again."
            }
        }
    }

    /// Polls signal + price every 30s while the signal is live
    private func startRefreshTimerIfNeeded() {
        guard signal?.status.isLive == true else { return }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                do {
                    let updated = try await service.fetchSignal(id: signalId)
                    signal = updated
                    await fetchCurrentPrice(asset: updated.asset)
                    // Stop polling once resolved
                    if !updated.status.isLive {
                        refreshTimer?.invalidate()
                        refreshTimer = nil
                    }
                } catch {
                    logDebug("Signal refresh failed: \(error)", category: .network)
                }
            }
        }
    }

    private func fetchCurrentPrice(asset: String) async {
        do {
            let pair = "\(asset.uppercased())-USD"
            guard let url = URL(string: "https://api.coinbase.com/api/v3/brokerage/market/products/\(pair)/candles?granularity=ONE_HOUR&limit=1") else {
                logDebug("Invalid URL for price fetch: \(pair)", category: .network)
                return
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candles = json["candles"] as? [[String: Any]],
               let latest = candles.first,
               let closeStr = latest["close"] as? String,
               let price = Double(closeStr) {
                currentPrice = price
            }
        } catch {
            logDebug("Failed to fetch current price: \(error)", category: .network)
        }
    }

    // MARK: - 1. Header

    private func headerSection(_ signal: TradeSignal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    if let logoURL = AssetRiskConfig.forCoin(signal.asset)?.logoURL
                        ?? RiskCoin(rawValue: signal.asset)?.iconURL {
                        KFImage(logoURL)
                            .resizable()
                            .placeholder {
                                Circle()
                                    .fill(AppColors.accent.opacity(0.2))
                                    .frame(width: 32, height: 32)
                            }
                            .fade(duration: 0.2)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }

                    Text(signal.asset)
                        .font(.title.bold())
                        .foregroundColor(textPrimary)
                }

                Text(signal.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(signal.signalType.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(signal.signalType.isBuy ? AppColors.success : AppColors.error)
                    .cornerRadius(10)

                HStack(spacing: 6) {
                    let confColor: Color = {
                        switch signal.confidence {
                        case .high: return AppColors.success
                        case .medium: return AppColors.warning
                        case .low: return AppColors.error
                        }
                    }()
                    Text(signal.confidence.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(confColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(confColor.opacity(0.12))
                        .cornerRadius(4)

                    if signal.isWeakDirection {
                        Text("Off-trend")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.textSecondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    Text(signal.timeframeBadge)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(signal.isScalp ? AppColors.accent : AppColors.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background((signal.isScalp ? AppColors.accent : AppColors.textSecondary).opacity(0.12))
                        .cornerRadius(4)

                    if signal.isCounterTrend {
                        Text("Counter-Trend")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.warning.opacity(0.12))
                            .cornerRadius(4)
                    }
                    if signal.isRangeCompressed {
                        Text("Compressed")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.warning.opacity(0.12))
                            .cornerRadius(4)
                    }
                    if signal.isLowConviction {
                        Text("Low Conviction")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.warning)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.warning.opacity(0.12))
                            .cornerRadius(4)
                    }
                    if let volLabel = signal.volatilityRegimeLabel {
                        Text(volLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.error.opacity(0.12))
                            .cornerRadius(4)
                    }
                    if signal.hasVolumeConfluence {
                        Text("Vol Shelf")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(AppColors.textSecondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private func statusBanner(_ signal: TradeSignal) -> some View {
        let bannerConfig = statusBannerConfig(signal)
        if let config = bannerConfig {
            HStack(spacing: 10) {
                Image(systemName: config.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(config.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(config.color)
                    if let subtitle = config.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.7))
                    }
                }

                Spacer()

                if let badge = config.badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(config.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(config.color.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(config.color.opacity(colorScheme == .dark ? 0.1 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(config.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    private struct BannerConfig {
        let icon: String
        let title: String
        let subtitle: String?
        let badge: String?
        let color: Color
    }

    private func statusBannerConfig(_ signal: TradeSignal) -> BannerConfig? {
        if signal.isRunnerPhase {
            return BannerConfig(
                icon: "arrow.up.right.circle.fill",
                title: "Runner Trailing",
                subtitle: "T1 hit — 50% closed, remaining position trailing",
                badge: signal.t1PnlPct.map { String(format: "%+.1f%%", $0) },
                color: AppColors.accent
            )
        }

        switch signal.status {
        case .active:
            let countdown: String? = signal.expiresAt.flatMap { expires in
                let remaining = expires.timeIntervalSince(Date())
                guard remaining > 0 else { return nil }
                let hours = Int(remaining / 3600)
                return hours >= 24 ? "\(hours / 24)d \(hours % 24)h" : "\(hours)h"
            }
            return BannerConfig(
                icon: "eye.fill",
                title: "Watching",
                subtitle: "Waiting for price to enter the zone",
                badge: countdown.map { "\($0) left" },
                color: AppColors.warning
            )
        case .triggered:
            let unrealizedPnl: Double? = currentPrice.map { price in
                let entryMid = signal.entryPriceMid
                return signal.signalType.isBuy
                    ? ((price - entryMid) / entryMid) * 100
                    : ((entryMid - price) / entryMid) * 100
            }
            let pnlSubtitle: String = {
                if let pnl = unrealizedPnl {
                    let prefix = pnl >= 0 ? "Currently" : "Currently"
                    return "\(prefix) \(String(format: "%+.2f%%", pnl)) — watching T1"
                }
                return "Price confirmed in zone — watching T1"
            }()
            let pnlColor: Color = {
                guard let pnl = unrealizedPnl else { return AppColors.accent }
                return pnl >= 0 ? AppColors.success : AppColors.error
            }()
            return BannerConfig(
                icon: pnlColor == AppColors.success ? "arrow.up.right.circle.fill" : (pnlColor == AppColors.error ? "arrow.down.right.circle.fill" : "bolt.fill"),
                title: "In Play",
                subtitle: pnlSubtitle,
                badge: unrealizedPnl.map { String(format: "%+.2f%%", $0) },
                color: pnlColor
            )
        case .targetHit:
            return BannerConfig(
                icon: "checkmark.circle.fill",
                title: "Target Hit",
                subtitle: signal.outcomePct.map { String(format: "Closed at %+.2f%%", $0) },
                badge: signal.rMultiple.map { String(format: "%+.1fR", $0) },
                color: AppColors.success
            )
        case .invalidated:
            let subtitle: String? = {
                var parts: [String] = []
                if let pnl = signal.outcomePct {
                    parts.append(String(format: "Closed at %+.2f%%", pnl))
                }
                if let bestPct = signal.bestPricePct, bestPct > 0 {
                    parts.append(String(format: "Reached %+.1f%% before reversing", bestPct))
                }
                return parts.isEmpty ? nil : parts.joined(separator: " · ")
            }()
            return BannerConfig(
                icon: "xmark.circle.fill",
                title: "Stopped Out",
                subtitle: subtitle,
                badge: signal.rMultiple.map { String(format: "%+.1fR", $0) },
                color: AppColors.error
            )
        case .expired:
            let subtitle: String = {
                if signal.triggeredAt != nil, let bestPct = signal.bestPricePct, bestPct > 0 {
                    return String(format: "Reached %+.1f%% before expiring", bestPct)
                }
                return "Price never reached the entry zone"
            }()
            return BannerConfig(
                icon: "clock.badge.xmark",
                title: "Expired",
                subtitle: subtitle,
                badge: nil,
                color: AppColors.textSecondary
            )
        }
    }

    // MARK: - Chart Pattern

    private func chartPatternCard(_ pattern: ChartPattern, signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accent)
                Text("Chart Pattern")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                // Type badge: Reversal or Continuation
                let typeColor = pattern.type.lowercased() == "reversal" ? AppColors.warning : AppColors.accent
                Text(pattern.type.capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(typeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(typeColor.opacity(0.12))
                    .cornerRadius(6)
            }

            // Pattern name + confidence
            HStack {
                Text(pattern.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 10))
                    Text("\(pattern.confidenceInt)%")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(patternConfidenceColor(pattern.confidenceInt))
            }

            // Description
            Text(pattern.description)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.8))
                .lineSpacing(3)

            // Neckline + Target levels
            if pattern.neckline != nil || pattern.target != nil {
                Divider()

                VStack(spacing: 8) {
                    if let neckline = pattern.neckline {
                        paramRow(label: "Neckline",
                                 value: "$\(formatSignalPrice(neckline))",
                                 valueColor: AppColors.accent)
                    }
                    if let target = pattern.target {
                        paramRow(label: "Pattern Target",
                                 value: "$\(formatSignalPrice(target))",
                                 valueColor: AppColors.success)
                    }
                }
            }

            // Timeframe + bias footer
            HStack(spacing: 8) {
                chipBadge(pattern.timeframe.uppercased())

                let biasColor = pattern.bias.lowercased() == "bullish" ? AppColors.success : AppColors.error
                chipBadge(pattern.bias.capitalized, color: biasColor)
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func patternConfidenceColor(_ confidence: Int) -> Color {
        if confidence >= 70 { return AppColors.success }
        if confidence >= 50 { return AppColors.warning }
        return AppColors.error
    }

    private func chipBadge(_ text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color ?? AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((color ?? AppColors.textSecondary).opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - 2. Trade Parameters

    private func tradeParametersCard(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Signal Parameters")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Text("Pattern detected — not financial advice")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }

            VStack(spacing: 10) {
                if let price = currentPrice {
                    let entryMid = (signal.entryZoneLow + signal.entryZoneHigh) / 2
                    let distPct = ((price - entryMid) / entryMid) * 100
                    let isInZone = price >= signal.entryZoneLow && price <= signal.entryZoneHigh
                    let badge = isInZone ? "IN ZONE" : String(format: "%+.1f%%", distPct)
                    let badgeColor = isInZone ? AppColors.success : AppColors.textSecondary

                    paramRow(label: "Current Price",
                             value: "$\(formatSignalPrice(price))",
                             badge: badge,
                             badgeColor: badgeColor,
                             valueColor: AppColors.accent)
                }

                paramRow(label: "Entry Zone",
                         value: "$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")

                if signal.status.isLive, let zone = signal.considerProfitZone {
                    let low = min(zone.low, zone.high)
                    let high = max(zone.low, zone.high)
                    paramRow(label: "Consider Profit",
                             value: "$\(formatSignalPrice(low)) – $\(formatSignalPrice(high))",
                             badge: "30–75%",
                             badgeColor: AppColors.warning)
                }

                if let t1 = signal.target1, let pct = signal.entryPctFromTarget1 {
                    paramRow(label: "Target 1",
                             value: "$\(formatSignalPrice(t1))",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                }

                if let t2 = signal.target2, let pct = signal.entryPctFromTarget2 {
                    paramRow(label: "Target 2",
                             value: "$\(formatSignalPrice(t2))",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                }

                paramRow(label: "Stop Loss",
                         value: "$\(formatSignalPrice(signal.stopLoss))",
                         badge: String(format: "%.1f%%", signal.stopLossPct),
                         badgeColor: AppColors.error)

                Divider()

                paramRow(label: "Risk / Reward",
                         value: String(format: "%.1fx", signal.riskRewardRatio),
                         valueColor: AppColors.accent)
            }
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - Custom Entry Card

    private func customEntryCard(_ signal: TradeSignal) -> some View {
        let customEntry = customEntryText.asLocalizedDouble
        let isBuy = signal.signalType.isBuy

        // Original risk distance as a percentage of entry mid
        let originalRiskPct = abs(signal.stopLoss - signal.entryPriceMid) / signal.entryPriceMid

        // Adjusted stop loss: same % distance from user's entry
        let adjustedSL: Double? = {
            guard let entry = customEntry, entry > 0 else { return nil }
            return isBuy ? entry * (1 - originalRiskPct) : entry * (1 + originalRiskPct)
        }()

        // Adjusted R:R
        let adjustedRR: Double? = {
            guard let entry = customEntry, let sl = adjustedSL, let t1 = signal.target1 else { return nil }
            let risk = abs(entry - sl)
            guard risk > 0 else { return nil }
            let reward = abs(t1 - entry)
            return reward / risk
        }()

        return VStack(alignment: .leading, spacing: 12) {
            // Header with toggle
            Button {
                withAnimation(.arkSpring) {
                    showCustomEntry.toggle()
                    if !showCustomEntry { customEntryText = "" }
                }
            } label: {
                HStack {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Text("Adjust My Entry")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                    Spacer()
                    Image(systemName: showCustomEntry ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if showCustomEntry {
                VStack(spacing: 12) {
                    // Entry price input
                    HStack {
                        Text("$")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Your entry price", text: $customEntryText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                            .keyboardType(.decimalPad)
                            .focused($isTextFieldFocused)
                            .transaction { $0.animation = nil }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(customEntry != nil ? AppColors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                    .transaction { $0.animation = nil }

                    if let entry = customEntry, let sl = adjustedSL {
                        VStack(spacing: 8) {
                            // Entry vs original
                            let entryDiff = ((entry - signal.entryPriceMid) / signal.entryPriceMid) * 100
                            paramRow(
                                label: "Your Entry",
                                value: "$\(formatSignalPrice(entry))",
                                badge: String(format: "%+.1f%% from signal", entryDiff),
                                badgeColor: AppColors.textSecondary,
                                valueColor: AppColors.accent
                            )

                            paramRow(
                                label: "Adjusted Stop Loss",
                                value: "$\(formatSignalPrice(sl))",
                                badge: String(format: "%.1f%%", -originalRiskPct * 100),
                                badgeColor: AppColors.error
                            )

                            if let t1 = signal.target1 {
                                let rawPct = ((t1 - entry) / entry) * 100
                                let t1Pct = isBuy ? rawPct : -rawPct
                                paramRow(
                                    label: "Target 1",
                                    value: "$\(formatSignalPrice(t1))",
                                    badge: String(format: "%+.1f%%", t1Pct),
                                    badgeColor: AppColors.success
                                )
                            }

                            if let t2 = signal.target2 {
                                let rawPct = ((t2 - entry) / entry) * 100
                                let t2Pct = isBuy ? rawPct : -rawPct
                                paramRow(
                                    label: "Target 2",
                                    value: "$\(formatSignalPrice(t2))",
                                    badge: String(format: "%+.1f%%", t2Pct),
                                    badgeColor: AppColors.success
                                )
                            }

                            Divider()

                            if let rr = adjustedRR {
                                paramRow(
                                    label: "Adjusted R:R",
                                    value: String(format: "%.1fx", rr),
                                    valueColor: rr >= 2.0 ? AppColors.success : (rr >= 1.5 ? AppColors.warning : AppColors.error)
                                )
                            }

                            if let calc = currentLeverageCalc, calc.marginAmount > 0 {
                                let notional = calc.marginAmount * Double(calc.leverageMultiplier)
                                let qty = entry > 0 ? notional / entry : 0
                                if qty > 0 {
                                    paramRow(
                                        label: "Quantity (\(signal.asset))",
                                        value: formatSignalQuantity(qty),
                                        valueColor: AppColors.accent
                                    )
                                }
                            }
                        }

                        // Warning if SL is far from original
                        let slDiffPct = ((sl - signal.stopLoss) / signal.stopLoss) * 100
                        if abs(slDiffPct) > 2 {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                Text("Stop loss adjusted \(String(format: "%+.1f%%", slDiffPct)) from signal's original to maintain the same risk %")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.warning)
                            .padding(.top, 4)
                        }
                    }
                }
                .transaction { $0.animation = nil }
            }
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - Runner Tracking Card

    private func runnerTrackingCard(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Split Exit Tracking")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(spacing: 10) {
                // T1 half
                HStack {
                    Text("50% closed at T1")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    if let t1Pnl = signal.t1PnlPct {
                        Text(String(format: "%+.2f%%", t1Pnl))
                            .font(AppFonts.body14Bold)
                            .foregroundColor(t1Pnl >= 0 ? AppColors.success : AppColors.error)
                    }
                }

                Divider()

                // Runner half
                if signal.isRunnerPhase {
                    HStack {
                        Text("50% runner")
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("Trailing")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.accent)
                    }

                    if let best = signal.bestPrice {
                        paramRow(label: "Best Price",
                                 value: "$\(formatSignalPrice(best))",
                                 valueColor: AppColors.success)
                    }
                    if let trail = signal.runnerStop {
                        paramRow(label: "Trail Stop",
                                 value: "$\(formatSignalPrice(trail))",
                                 valueColor: AppColors.warning)
                    }
                } else if let runnerPnl = signal.runnerPnlPct {
                    HStack {
                        Text("50% runner closed")
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(String(format: "%+.2f%%", runnerPnl))
                            .font(AppFonts.body14Bold)
                            .foregroundColor(runnerPnl >= 0 ? AppColors.success : AppColors.error)
                    }

                    if let exitPrice = signal.runnerExitPrice {
                        paramRow(label: "Runner Exit",
                                 value: "$\(formatSignalPrice(exitPrice))")
                    }
                }

                Divider()

                // Combined result
                if let totalPnl = signal.outcomePct {
                    HStack {
                        Text("Combined P&L")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text(String(format: "%+.2f%%", totalPnl))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(totalPnl >= 0 ? AppColors.success : AppColors.error)
                        if let rMult = signal.rMultiple {
                            Text(String(format: "(%+.1fR)", rMult))
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(rMult >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                } else if signal.isRunnerPhase, let t1Pnl = signal.t1PnlPct {
                    HStack {
                        Text("Locked P&L (T1 half)")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text(String(format: "%+.2f%%", t1Pnl / 2))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.success)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - 3. AI Analysis

    private func aiAnalysisCard(_ briefing: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Analysis")
                .font(.headline)
                .foregroundColor(textPrimary)

            Text(briefing)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.9))
                .lineSpacing(4)
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - 6. Status Timeline

    private func statusTimeline(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .foregroundColor(textPrimary)

            let events = buildTimelineEvents(signal)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    timelineRow(event: event, isLast: index == events.count - 1)
                }

                if let pct = signal.outcomePct {
                    HStack(spacing: 6) {
                        Text("Result:")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%+.1f%%", pct))
                            .font(AppFonts.body14Bold)
                            .foregroundColor(pct >= 0 ? AppColors.success : AppColors.error)
                        if let rMult = signal.rMultiple {
                            Text(String(format: "(%+.1fR)", rMult))
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(rMult >= 0 ? AppColors.success : AppColors.error)
                        }
                        if let hours = signal.durationHours {
                            Text("(\(hours >= 24 ? "\(hours / 24)d \(hours % 24)h" : "\(hours)h"))")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.leading, 30)
                    .padding(.top, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    private struct TimelineEvent {
        let label: String
        let time: String
        let isCompleted: Bool
        let color: Color?
    }

    private func buildTimelineEvents(_ signal: TradeSignal) -> [TimelineEvent] {
        var events: [TimelineEvent] = []

        events.append(TimelineEvent(
            label: "Signal Generated",
            time: signal.generatedAt.formatted(date: .abbreviated, time: .shortened),
            isCompleted: true, color: nil))

        events.append(TimelineEvent(
            label: "Price Entered Zone",
            time: signal.triggeredAt?.formatted(date: .abbreviated, time: .shortened) ?? "Pending",
            isCompleted: signal.triggeredAt != nil, color: nil))

        if let t1Time = signal.t1HitAt {
            let t1Label = if let t1Pnl = signal.t1PnlPct {
                "T1 Hit — 50% closed at \(String(format: "%+.1f%%", t1Pnl))"
            } else {
                "T1 Hit — 50% closed"
            }
            events.append(TimelineEvent(label: t1Label,
                time: t1Time.formatted(date: .abbreviated, time: .shortened),
                isCompleted: true, color: AppColors.success))
        }

        if signal.isRunnerPhase {
            events.append(TimelineEvent(label: "Runner trailing (50% remaining)",
                time: "In progress", isCompleted: false, color: AppColors.accent))
        } else if signal.outcome == .win {
            let label = signal.isT1Hit ? "Runner closed — Win" : "Target Hit"
            events.append(TimelineEvent(label: label,
                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                isCompleted: true, color: AppColors.success))
        } else if signal.outcome == .loss {
            let label = signal.isT1Hit ? "Runner stopped at breakeven" : "Stopped Out"
            events.append(TimelineEvent(label: label,
                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                isCompleted: true, color: signal.isT1Hit ? AppColors.warning : AppColors.error))
        } else if signal.status == .expired {
            events.append(TimelineEvent(label: "Expired",
                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                isCompleted: true, color: AppColors.textSecondary))
        } else if let expires = signal.expiresAt {
            let remaining = expires.timeIntervalSince(Date())
            let hoursLeft = max(0, Int(remaining / 3600))
            events.append(TimelineEvent(label: "Expires in \(hoursLeft)h",
                time: expires.formatted(date: .abbreviated, time: .shortened),
                isCompleted: false, color: nil))
        } else {
            events.append(TimelineEvent(label: "Outcome",
                time: "Pending", isCompleted: false, color: nil))
        }

        return events
    }

    private func timelineRow(event: TimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Dot + connecting line
            VStack(spacing: 0) {
                Circle()
                    .fill(event.isCompleted ? (event.color ?? AppColors.accent) : AppColors.textSecondary.opacity(0.3))
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(event.isCompleted ? (event.color ?? AppColors.accent).opacity(0.3) : AppColors.textSecondary.opacity(0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
                Text(event.time)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    // MARK: - Admin Manual Resolution

    private func adminManualResolveCard(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.arkSpring) {
                    showManualResolve.toggle()
                    if !showManualResolve {
                        manualExitText = ""
                        resolveError = nil
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.warning)
                    Text("Manual Resolution")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)
                    Spacer()
                    Text("ADMIN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.warning.opacity(0.12))
                        .cornerRadius(4)
                    Image(systemName: showManualResolve ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if showManualResolve {
                VStack(spacing: 12) {
                    Text("Enter the actual exit price to resolve this signal. The system will auto-determine outcome and P&L.")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    // Price input
                    HStack {
                        Text("$")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Exit price", text: $manualExitText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(textPrimary)
                            .keyboardType(.decimalPad)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Double(manualExitText) != nil ? AppColors.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                    )

                    // Preview what will happen
                    if let exitPrice = Double(manualExitText), exitPrice > 0 {
                        manualResolvePreview(signal, exitPrice: exitPrice)
                    }

                    if let error = resolveError {
                        Text(error)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.error)
                    }

                    if resolveSuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Signal resolved successfully")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.success)
                    }

                    // Resolve button
                    if let exitPrice = Double(manualExitText), exitPrice > 0, !resolveSuccess {
                        Button {
                            Task { await performManualResolve(signal: signal, exitPrice: exitPrice) }
                        } label: {
                            HStack {
                                if isResolving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle")
                                    Text("Resolve Signal")
                                }
                            }
                            .font(AppFonts.body14Bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.warning)
                            .cornerRadius(10)
                        }
                        .disabled(isResolving)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.warning.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func manualResolvePreview(_ signal: TradeSignal, exitPrice: Double) -> some View {
        let isBuy = signal.signalType.isBuy
        let entry = signal.entryPriceMid

        let exitPnlPct = isBuy
            ? ((exitPrice - entry) / entry) * 100
            : ((entry - exitPrice) / entry) * 100

        let t1Hit: Bool = {
            guard let t1 = signal.target1 else { return false }
            return isBuy ? exitPrice >= t1 : exitPrice <= t1
        }()
        let slHit = isBuy ? exitPrice <= signal.stopLoss : exitPrice >= signal.stopLoss

        let outcomeLabel: String
        let outcomeColor: Color
        let finalPnl: Double

        if signal.isT1Hit {
            let t1Pnl = signal.t1PnlPct ?? 0
            finalPnl = (t1Pnl + exitPnlPct) / 2
            outcomeLabel = finalPnl > 0 ? "Win (runner close)" : "Loss (runner close)"
            outcomeColor = finalPnl > 0 ? AppColors.success : AppColors.error
        } else if t1Hit {
            let t1Pnl: Double = {
                guard let t1 = signal.target1 else { return exitPnlPct }
                return isBuy ? ((t1 - entry) / entry) * 100 : ((entry - t1) / entry) * 100
            }()
            finalPnl = (t1Pnl + exitPnlPct) / 2
            outcomeLabel = "Win (T1 + runner at exit)"
            outcomeColor = AppColors.success
        } else if slHit {
            finalPnl = exitPnlPct
            outcomeLabel = "Loss (stop loss)"
            outcomeColor = AppColors.error
        } else {
            finalPnl = exitPnlPct
            outcomeLabel = exitPnlPct > 0 ? "Win (early exit)" : "Loss (early exit)"
            outcomeColor = exitPnlPct > 0 ? AppColors.success : AppColors.error
        }

        return VStack(spacing: 8) {
            Divider()

            HStack {
                Text("Projected Outcome")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(outcomeLabel)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(outcomeColor)
            }

            HStack {
                Text("Projected P&L")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(String(format: "%+.2f%%", finalPnl))
                    .font(AppFonts.body14Bold)
                    .foregroundColor(outcomeColor)

                if let r1r = signal.risk1r, r1r > 0 {
                    let rPct = (r1r / entry) * 100
                    let rMult = rPct > 0 ? finalPnl / rPct : 0
                    Text(String(format: "(%+.1fR)", rMult))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(outcomeColor)
                }
            }

            // Reference levels
            HStack {
                Text("Entry: $\(formatSignalPrice(entry))")
                Spacer()
                Text("SL: $\(formatSignalPrice(signal.stopLoss))")
                if let t1 = signal.target1 {
                    Text("T1: $\(formatSignalPrice(t1))")
                }
            }
            .font(.system(size: 10))
            .foregroundColor(AppColors.textSecondary.opacity(0.6))
        }
    }

    private func performManualResolve(signal: TradeSignal, exitPrice: Double) async {
        isResolving = true
        resolveError = nil
        defer { isResolving = false }

        do {
            let updated = try await service.resolveSignalManually(signal: signal, exitPrice: exitPrice)
            self.signal = updated
            resolveSuccess = true
            refreshTimer?.invalidate()
            refreshTimer = nil
            NotificationCenter.default.post(name: Constants.Notifications.signalManuallyResolved, object: nil)
        } catch {
            resolveError = error.localizedDescription
        }
    }

    // MARK: - 7. Disclaimer

    private var disclaimerSection: some View {
        Text("This is not financial advice. Always do your own research and consult a licensed advisor before making crypto-related decisions.")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textSecondary.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
    }

    private func paramRow(label: String, value: String, badge: String? = nil, badgeColor: Color? = nil, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFonts.body14Medium)
                .foregroundColor(valueColor ?? textPrimary)
                .monospacedDigit()

            if let badge, let color = badgeColor {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }

    private func formatSignalQuantity(_ qty: Double) -> String {
        if qty >= 1000 {
            return String(format: "%.1f", qty)
        } else if qty >= 1 {
            return String(format: "%.4f", qty)
        } else if qty >= 0.001 {
            return String(format: "%.6f", qty)
        } else {
            return String(format: "%.8f", qty)
        }
    }

}
