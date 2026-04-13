import SwiftUI

// MARK: - Leverage Calculator View

struct LeverageCalculatorView: View {
    let signal: TradeSignal
    var startExpanded: Bool = true
    var onCalculationChange: ((LeverageCalculation?) -> Void)? = nil

    @State private var leverage: Double = 1
    @State private var marginText: String = ""
    @State private var marginMode: MarginMode = .isolated
    @State private var entryStrategy: EntryStrategy = .optimal
    @State private var isExpanded: Bool = false
    @State private var showTooltip: Bool = false
    @State private var showRLadder: Bool = false
    @State private var walletText: String = ""
    @State private var riskPercent: Double = 0
    @State private var riskSize: RiskSize = .oneR
    @State private var riskTolerance: RiskTolerance = .moderate
    @Environment(\.colorScheme) private var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : .white }
    private var subtleBg: Color { colorScheme == .dark ? Color(hex: "2A2A2E") : Color(hex: "F5F5F7") }

    private var walletAmount: Double {
        walletText.asLocalizedDouble ?? 0
    }

    private var isWalletMode: Bool {
        walletAmount > 0 && riskPercent > 0
    }

    private var marginAmount: Double {
        if isWalletMode {
            return walletAmount * (riskPercent / 100) * riskSize.multiplier
        }
        return marginText.asLocalizedDouble ?? 0
    }

    private var leverageInt: Int { max(1, Int(leverage.rounded())) }

    private var calculation: LeverageCalculation? {
        guard leverageInt > 1, marginAmount > 0 else { return nil }
        return LeverageCalculation(signal: signal, leverage: leverageInt, margin: marginAmount, strategy: entryStrategy, riskTolerance: riskTolerance)
    }

    private var hasEntryZone: Bool {
        guard signal.entryPriceMid > 0 else { return false }
        return abs(signal.entryZoneHigh - signal.entryZoneLow) / signal.entryPriceMid * 100 > 0.1
    }

    private var maxSafe: Int {
        let entry = entryStrategy.effectiveEntryPrice(
            zoneLow: signal.entryZoneLow,
            zoneHigh: signal.entryZoneHigh,
            isLong: signal.signalType.isBuy
        )
        guard entry > 0 else { return 200 }
        let stopPct = abs(signal.stopLoss - entry) / entry * 100
        guard stopPct > 0 else { return 200 }
        return max(1, Int(floor((100.0 / stopPct) * riskTolerance.safetyFactor)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Text("Your Setup")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 16) {
                    if showTooltip {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.accent)
                            Text("These calculations are estimates. Always verify with your exchange.")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Button { withAnimation { showTooltip = false } } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(subtleBg))
                        .transition(.opacity)
                    }

                    inputSection

                    if hasEntryZone && leverageInt > 1 {
                        EntryStrategySectionView(
                            signal: signal,
                            strategy: $entryStrategy,
                            calculation: calculation
                        )
                    }

                    resultsSection
                    maxSafeBadge
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
        )
        .onAppear {
            isExpanded = startExpanded
            // Auto-scale down to 0.5R for counter-trend or scalp signals
            if signal.isCounterTrend || signal.isScalp {
                riskSize = .halfR
            }
            // Restore saved risk tolerance
            if let savedTolerance = UserDefaults.standard.string(forKey: Constants.UserDefaults.leverageRiskTolerance),
               let tolerance = RiskTolerance(rawValue: savedTolerance) {
                riskTolerance = tolerance
            }
            // Restore saved wallet size
            let savedWallet = UserDefaults.standard.string(forKey: Constants.UserDefaults.leverageWalletSize) ?? ""
            if !savedWallet.isEmpty && walletText.isEmpty {
                walletText = savedWallet
            }
            let key = "arkline_leverage_tooltip_shown"
            if !UserDefaults.standard.bool(forKey: key) {
                showTooltip = true
                UserDefaults.standard.set(true, forKey: key)
            }
        }
        .onChange(of: leverage) { _, _ in onCalculationChange?(calculation) }
        .onChange(of: marginText) { _, _ in onCalculationChange?(calculation) }
        .onChange(of: entryStrategy) { _, _ in onCalculationChange?(calculation) }
        .onChange(of: walletText) { _, newValue in
            onCalculationChange?(calculation)
            // Persist wallet size for next visit
            if !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.leverageWalletSize)
            }
        }
        .onChange(of: riskPercent) { _, _ in onCalculationChange?(calculation) }
        .onChange(of: riskSize) { _, _ in onCalculationChange?(calculation) }
        .onChange(of: riskTolerance) { _, _ in onCalculationChange?(calculation) }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            // Leverage
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Leverage")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(leverageInt)x")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(leverageInt > maxSafe ? AppColors.error : AppColors.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: leverageInt)
                }

                Slider(value: $leverage, in: 1...150, step: 1) {
                    EmptyView()
                }
                .tint(leverageInt > maxSafe ? AppColors.error : AppColors.accent)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([1, 5, 10, 25, 50, 75, 100, 125], id: \.self) { val in
                            quickButton("\(val)x", isActive: leverageInt == val) {
                                leverage = Double(val)
                            }
                        }
                    }
                }
            }

            // Wallet Size
            VStack(alignment: .leading, spacing: 6) {
                Text("Wallet Size")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Text("$")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0", text: $walletText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(subtleBg)
                    .cornerRadius(8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["1000", "5000", "10000", "25000"], id: \.self) { val in
                                let display: String = {
                                    switch val {
                                    case "1000": return "$1K"
                                    case "5000": return "$5K"
                                    case "10000": return "$10K"
                                    case "25000": return "$25K"
                                    default: return "$\(val)"
                                    }
                                }()
                                quickButton(display, isActive: walletText == val) {
                                    walletText = val
                                }
                            }
                        }
                    }
                }
            }

            // Risk Per Trade + R-Size
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Risk Per Trade")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    if isWalletMode {
                        Text("Margin: \(formatDollar(marginAmount))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }

                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach([1.0, 2.0, 5.0, 7.0, 10.0, 15.0, 25.0], id: \.self) { pct in
                                quickButton("\(Int(pct))%", isActive: riskPercent == pct) {
                                    riskPercent = pct
                                }
                            }
                        }
                    }

                    // R-Size toggle
                    HStack(spacing: 0) {
                        ForEach(RiskSize.allCases, id: \.self) { size in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { riskSize = size }
                            } label: {
                                Text(size.label)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(riskSize == size ? .white : AppColors.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(riskSize == size ? AppColors.accent : AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .cornerRadius(14)
                }

                if signal.isCounterTrend && riskSize == .halfR {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.warning)
                        Text("Counter-trend signal — auto-scaled to 0.5R")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.warning)
                    }
                }

                if !isWalletMode && walletAmount <= 0 {
                    Text("Enter wallet size to auto-calculate margin")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Manual margin override
            if !isWalletMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Margin (manual)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("$")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            TextField("0", text: $marginText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(textPrimary)
                                .frame(width: 80)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(subtleBg)
                        .cornerRadius(8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["100", "250", "500", "1000"], id: \.self) { val in
                                    let display = val == "1000" ? "$1K" : "$\(val)"
                                    quickButton(display, isActive: marginText == val) {
                                        marginText = val
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Risk Tolerance
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Risk Tolerance")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("Max loss per trade: \(riskTolerance.maxMarginLoss)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(riskTolerance == .aggressive ? AppColors.error : riskTolerance == .moderate ? AppColors.warning : AppColors.success)
                }

                HStack(spacing: 0) {
                    ForEach(RiskTolerance.allCases, id: \.self) { tolerance in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                riskTolerance = tolerance
                                UserDefaults.standard.set(tolerance.rawValue, forKey: Constants.UserDefaults.leverageRiskTolerance)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tolerance.icon)
                                    .font(.system(size: 10))
                                Text(tolerance.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(riskTolerance == tolerance ? .white : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(riskTolerance == tolerance ? toleranceColor(tolerance) : toleranceColor(tolerance).opacity(colorScheme == .dark ? 0.12 : 0.06))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .cornerRadius(10)

                Text(riskTolerance.description)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }

            // Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Mode")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)

                Picker("Mode", selection: $marginMode) {
                    ForEach(MarginMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if marginMode == .cross {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.warning)
                        Text("Cross margin uses full account balance. Shown as isolated.")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if leverageInt == 1 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(AppColors.success)
                    Text("Spot trade — no leverage risk")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                if marginAmount > 0 {
                    let entry = entryStrategy.effectiveEntryPrice(
                        zoneLow: signal.entryZoneLow,
                        zoneHigh: signal.entryZoneHigh,
                        isLong: signal.signalType.isBuy
                    )
                    let qty = entry > 0 ? marginAmount / entry : 0
                    Divider().opacity(0.3)
                    resultRow("Position Size", value: formatDollar(marginAmount))
                    resultRow("Quantity (\(signal.asset))", value: formatQuantity(qty))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(subtleBg))
        } else if marginAmount <= 0 {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(AppColors.textSecondary)
                Text(walletAmount > 0 ? "Select risk % to calculate" : "Enter wallet size or margin to calculate risk")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(subtleBg))
        } else if let calc = calculation {
            if calc.isSignalViableAtLeverage {
                viableResults(calc)
            } else {
                notViableBanner(calc)
            }
        }
    }

    // MARK: - Viable Results

    private func viableResults(_ calc: LeverageCalculation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RISK ANALYSIS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            resultRow("Notional Position", value: formatDollar(calc.notionalPosition))
            resultRow("Quantity (\(signal.asset))", value: formatQuantity(calc.assetQuantity))
            resultRow("Stop Loss Price", value: "$\(calc.stopLossPrice.asSignalPrice)", valueColor: AppColors.error)
            resultRow("Stop Loss Distance", value: String(format: "%.1f%%", calc.stopLossPercent), valueColor: AppColors.error)
            resultRow("Liquidation Price", value: "$\(calc.entryPrice > 1000 ? String(format: "%.0f", calc.liquidationPrice) : calc.liquidationPrice.asSignalPrice)")
            resultRow("Liquidation Distance", value: String(format: "%.2f%%", calc.liquidationPercent))

            // Stop adjusted warning
            if calc.stopLossWasAdjusted {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stop Adjusted: \(String(format: "%.2f%%", calc.adjustedStopLossPercent)) → $\(calc.adjustedStopLossPrice.asSignalPrice)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.warning)
                        Text("Original \(String(format: "%.1f%%", calc.stopLossPercent)) stop exceeds safe range")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.warning.opacity(colorScheme == .dark ? 0.12 : 0.08)))
            }

            Divider().padding(.vertical, 4)

            resultRow("Dollar Risk / Trade", value: "-\(formatDollar(calc.dollarRiskPerTrade))", valueColor: AppColors.error)
            if isWalletMode {
                let walletRiskPct = walletAmount > 0 ? (calc.dollarRiskPerTrade / walletAmount) * 100 : 0
                resultRow("Wallet Risk / Trade", value: String(format: "%.2f%%", walletRiskPct), valueColor: walletRiskPct > 5 ? AppColors.error : AppColors.textSecondary)
            }
            resultRow("Margin Loss / Trade", value: String(format: "%.1f%%", calc.marginLossPercent), valueColor: calc.marginLossPercent >= 100 ? AppColors.error : AppColors.textSecondary)
            resultRow("Max Consecutive Losses", value: "\(calc.maxConsecutiveLosses)")

            if calc.maxConsecutiveLosses == 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.error)
                    Text("A single stop loss wipes this margin allocation")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.error)
                }
            }

            // Payouts
            Divider().padding(.vertical, 4)

            Text("PAYOUTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            if let t1 = signal.target1, let payout = calc.target1DollarPayout, let returnPct = calc.target1ReturnOnMargin {
                VStack(spacing: 2) {
                    resultRow("Target 1 ($\(t1.asSignalPrice))", value: "+\(formatDollar(payout))", valueColor: AppColors.success)
                    HStack {
                        Spacer()
                        Text(String(format: "+%.1f%% on margin", returnPct))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.success.opacity(0.8))
                    }
                }
            }

            if let t2 = signal.target2, let payout = calc.target2DollarPayout, let returnPct = calc.target2ReturnOnMargin {
                VStack(spacing: 2) {
                    resultRow("Target 2 ($\(t2.asSignalPrice))", value: "+\(formatDollar(payout))", valueColor: AppColors.success)
                    HStack {
                        Spacer()
                        Text(String(format: "+%.1f%% on margin", returnPct))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.success.opacity(0.8))
                    }
                }
            }

            if let adjRR = calc.adjustedRiskReward {
                Divider().padding(.vertical, 4)
                resultRow("Risk / Reward", value: String(format: "1 : %.1f", adjRR),
                          valueColor: AppColors.accent,
                          badge: calc.stopLossWasAdjusted ? "(adjusted)" : nil)
            }

            // R-Target Ladder (collapsible)
            if !calc.rTargetLadder.isEmpty {
                Divider().padding(.vertical, 4)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showRLadder.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("R-TARGET LADDER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(1)
                        Text("·")
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(formatQuantity(calc.assetQuantity)) \(signal.asset)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .rotationEffect(.degrees(showRLadder ? 90 : 0))
                    }
                }
                .buttonStyle(PlainButtonStyle())

                if showRLadder {
                    VStack(spacing: 6) {
                        // Header row
                        HStack(spacing: 0) {
                            Text("R")
                                .frame(width: 36, alignment: .leading)
                            Text("Price")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text("P&L")
                                .frame(width: 70, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                        ForEach(calc.rTargetLadder) { target in
                            HStack(spacing: 0) {
                                Text(target.id)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 36, alignment: .leading)
                                Text("$\(target.targetPrice.asSignalPrice)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(textPrimary)
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("+\(formatDollar(target.pnl))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.success)
                                    .monospacedDigit()
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }

                        // 1R reference
                        HStack(spacing: 4) {
                            Text("1R = $\(calc.stopDistanceDollar.asSignalPrice) move")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Extreme leverage warning
            if leverageInt > 125 {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.error)
                    Text("Extreme leverage. Liquidation within \(String(format: "%.2f%%", calc.liquidationPercent)) of entry.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.error)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.error.opacity(colorScheme == .dark ? 0.12 : 0.08)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(subtleBg))
    }

    // MARK: - Not Viable

    private func notViableBanner(_ calc: LeverageCalculation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.error)
                    .frame(width: 8, height: 8)
                Text("SIGNAL NOT VIABLE AT \(leverageInt)x")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.error)
            }

            Text("Stop loss (\(String(format: "%.1f%%", calc.stopLossPercent))) exceeds liquidation distance (\(String(format: "%.2f%%", calc.liquidationPercent))). You will be liquidated before your stop triggers.")
                .font(.system(size: 12))
                .foregroundColor(textPrimary.opacity(0.8))

            HStack {
                Text("Max Safe Leverage:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text("\(calc.maxSafeLeverage)x")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(textPrimary)
            }

            Button {
                withAnimation { leverage = Double(calc.maxSafeLeverage) }
            } label: {
                Text("Adjust to \(calc.maxSafeLeverage)x")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.error.opacity(colorScheme == .dark ? 0.12 : 0.08)))
    }

    // MARK: - Max Safe Badge

    private var maxSafeBadge: some View {
        Button {
            withAnimation { leverage = Double(maxSafe) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.accent)
                Text("Max Safe Leverage for This Signal:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text("\(maxSafe)x")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.accent.opacity(colorScheme == .dark ? 0.1 : 0.06)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Helpers

    private func toleranceColor(_ tolerance: RiskTolerance) -> Color {
        switch tolerance {
        case .conservative: return AppColors.success
        case .moderate: return AppColors.warning
        case .aggressive: return AppColors.error
        }
    }

    private func quickButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActive ? .white : AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? AppColors.accent : AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func resultRow(_ label: String, value: String, valueColor: Color? = nil, badge: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(valueColor ?? textPrimary)
                .monospacedDigit()
            if let badge {
                Text(badge)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func formatQuantity(_ qty: Double) -> String {
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

    private func formatDollar(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 10_000 {
            return String(format: "$%.1fK", value / 1_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }
}
