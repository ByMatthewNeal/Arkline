import SwiftUI

// MARK: - Global Liquidity Section (Market Tab)
/// Displays composite central bank liquidity from BIS + FRED data
/// with per-country breakdown and trend indicators.
struct GlobalLiquiditySection: View {
    var refreshId: UUID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var liquidityIndex: GlobalLiquidityIndex?
    @State private var isLoading = true
    @State private var showInfo = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Central Bank Liquidity")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let gli = liquidityIndex {
                    signalBadge(gli.signal)
                }
            }

            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardBackground)
                    .frame(height: 200)
                    .redacted(reason: .placeholder)
            } else if let gli = liquidityIndex {
                // Composite headline
                VStack(spacing: 16) {
                    compositeRow(gli)

                    Divider()
                        .background(textPrimary.opacity(0.08))

                    // US Net Liquidity breakdown
                    usNetLiquidityRow(gli)

                    Divider()
                        .background(textPrimary.opacity(0.08))

                    // Per-country breakdown
                    countryBreakdown(gli)

                    // Changes
                    changesRow(gli)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                )
            } else {
                Text("Unable to load liquidity data")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal)
        .task(id: refreshId) {
            await loadData()
        }
        .sheet(isPresented: $showInfo) {
            LiquidityInfoSheet()
        }
    }

    // MARK: - Composite Row

    private func compositeRow(_ gli: GlobalLiquidityIndex) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("COMPOSITE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.4))
                    .tracking(1)

                Text(gli.formattedComposite)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Period: \(gli.period)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)

                if let annual = gli.changes.annual {
                    Text(String(format: "%+.1f%% YoY", annual))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(annual >= 0 ? AppColors.success : AppColors.error)
                }
            }
        }
    }

    // MARK: - US Net Liquidity

    private func usNetLiquidityRow(_ gli: GlobalLiquidityIndex) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("US NET LIQUIDITY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.4))
                .tracking(1)

            HStack(spacing: 16) {
                labeledValue("Fed Assets", String(format: "$%.2fT", gli.fedAssetsT))
                labeledValue("TGA", String(format: "-$%.2fT", gli.tgaT))
                labeledValue("RRP", String(format: "-$%.3fT", gli.rrpT))

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Net")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    Text(gli.formattedUSNetLiquidity)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(textPrimary)
                }
            }
        }
    }

    // MARK: - Country Breakdown

    private func countryBreakdown(_ gli: GlobalLiquidityIndex) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CENTRAL BANKS (BIS)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.4))
                .tracking(1)

            let banks = gli.topCentralBanks
            let maxValue = banks.first?.valueB ?? 1

            ForEach(banks, id: \.code) { bank in
                HStack(spacing: 8) {
                    Text(bank.code)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24, alignment: .leading)

                    Text(bank.name)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.7))
                        .lineLimit(1)
                        .frame(width: 110, alignment: .leading)

                    // Bar
                    GeometryReader { geo in
                        let width = geo.size.width * CGFloat(bank.valueB / maxValue)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent.opacity(0.3))
                            .frame(width: max(width, 4))
                    }
                    .frame(height: 12)

                    Text(formatBillions(bank.valueB))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(textPrimary.opacity(0.6))
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Changes Row

    private func changesRow(_ gli: GlobalLiquidityIndex) -> some View {
        HStack(spacing: 0) {
            if let monthly = gli.changes.monthly {
                changeChip("1M", monthly)
            }
            if let quarterly = gli.changes.quarterly {
                changeChip("3M", quarterly)
            }
            if let semiannual = gli.changes.semiannual {
                changeChip("6M", semiannual)
            }
            if let annual = gli.changes.annual {
                changeChip("1Y", annual)
            }
        }
    }

    // MARK: - Helpers

    private func signalBadge(_ signal: String) -> some View {
        let (label, color): (String, Color) = {
            switch signal {
            case "expanding": return ("Expanding", AppColors.success)
            case "contracting": return ("Contracting", AppColors.error)
            default: return ("Neutral", AppColors.warning)
            }
        }()

        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary.opacity(0.7))
        }
    }

    private func changeChip(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            Text(String(format: "%+.1f%%", value))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(value >= 0 ? AppColors.success : AppColors.error)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatBillions(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.1fT", value / 1000)
        }
        return String(format: "$%.0fB", value)
    }

    private func loadData() async {
        do {
            let service: GlobalLiquidityServiceProtocol = ServiceContainer.shared.globalLiquidityService
            liquidityIndex = try await service.fetchGlobalLiquidityIndex()
        } catch {
            logWarning("GlobalLiquiditySection: \(error.localizedDescription)", category: .network)
        }
        isLoading = false
    }
}

// MARK: - Liquidity Info Sheet
/// Explains what data sources power the Global Liquidity Index
private struct LiquidityInfoSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // What is this?
                    section("What is Central Bank Liquidity?") {
                        Text("This index tracks the total assets held by the world's largest central banks, converted to USD. When central banks expand their balance sheets (print money, buy bonds), liquidity increases and risk assets like crypto tend to benefit.")
                    }

                    // Data sources
                    section("Data Sources") {
                        VStack(alignment: .leading, spacing: 12) {
                            sourceRow("BIS (Bank for International Settlements)", "Balance sheets for ECB, PBOC, BOJ, BOE, SNB, RBA, BOC, RBI, BOK, and BCB. Monthly data, converted to USD at market exchange rates.")
                            sourceRow("FRED (Federal Reserve)", "US Net Liquidity = Fed Balance Sheet (WALCL) minus Treasury General Account (TGA) minus Reverse Repo (RRP). Weekly data.")
                        }
                    }

                    // Central banks tracked
                    section("Central Banks Tracked") {
                        VStack(alignment: .leading, spacing: 6) {
                            bankRow("US", "Federal Reserve (Fed)")
                            bankRow("XM", "European Central Bank (ECB)")
                            bankRow("CN", "People's Bank of China (PBOC)")
                            bankRow("JP", "Bank of Japan (BOJ)")
                            bankRow("GB", "Bank of England (BOE)")
                            bankRow("CH", "Swiss National Bank (SNB)")
                            bankRow("IN", "Reserve Bank of India (RBI)")
                            bankRow("BR", "Central Bank of Brazil (BCB)")
                            bankRow("KR", "Bank of Korea (BOK)")
                            bankRow("AU", "Reserve Bank of Australia (RBA)")
                            bankRow("CA", "Bank of Canada (BOC)")
                        }
                    }

                    // How to read
                    section("How to Read the Signal") {
                        VStack(alignment: .leading, spacing: 8) {
                            signalExplanation("Expanding", AppColors.success, "Monthly change > +0.3%. Central banks are adding liquidity. Historically bullish for crypto.")
                            signalExplanation("Neutral", AppColors.warning, "Monthly change between -0.3% and +0.3%. Stable conditions.")
                            signalExplanation("Contracting", AppColors.error, "Monthly change < -0.3%. Central banks are tightening. Historically bearish for risk assets.")
                        }
                    }

                    section("Update Frequency") {
                        Text("BIS data updates monthly (10 business days after month-end). US Net Liquidity updates weekly. The index refreshes daily at 08:00 UTC.")
                    }
                }
                .padding(20)
            }
            .background(colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
            .navigationTitle("About Global Liquidity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)
            content()
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.7))
        }
    }

    private func sourceRow(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.accent)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(textPrimary.opacity(0.6))
        }
    }

    private func bankRow(_ code: String, _ name: String) -> some View {
        HStack(spacing: 8) {
            Text(code)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.accent)
                .frame(width: 24, alignment: .leading)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.7))
        }
    }

    private func signalExplanation(_ label: String, _ color: Color, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
            }
        }
    }
}
