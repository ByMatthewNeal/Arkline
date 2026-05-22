import SwiftUI
import Kingfisher

struct CryptoRiskLevelsScreen: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = CryptoRiskLevelsViewModel()
    @State private var selectedCoin: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading && viewModel.rows.isEmpty {
                    loadingState
                } else {
                    // Subtitle + toggles row
                    HStack {
                        Text("Regression model • \(viewModel.totalAssetCount) assets")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        sortToggle
                        trendToggle
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.top, ArkSpacing.sm)
                    .padding(.bottom, ArkSpacing.xs)

                    if viewModel.sortMode == .band {
                        ForEach(viewModel.bucketed, id: \.band) { section in
                            bandSection(band: section.band, items: section.items)
                        }
                    } else {
                        alphabeticalList
                    }

                    // Failed coins section
                    if !viewModel.failedCoins.isEmpty {
                        failedSection
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Crypto Risk Levels")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadAll() }
        .sheet(item: Binding(
            get: { selectedCoin.flatMap { RiskCoin(rawValue: $0) }.map { IdentifiableRiskCoin(coin: $0) } },
            set: { selectedCoin = $0?.coin.rawValue }
        )) { item in
            RiskLevelChartView(initialCoin: item.coin)
        }
    }

    // MARK: - Sort Toggle

    private var sortToggle: some View {
        HStack(spacing: 4) {
            ForEach(CryptoRiskLevelsViewModel.SortMode.allCases, id: \.self) { mode in
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.sortMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            viewModel.sortMode == mode
                                ? AppColors.accent.opacity(0.12)
                                : Color.clear
                        )
                        .foregroundColor(
                            viewModel.sortMode == mode
                                ? AppColors.accent
                                : AppColors.textSecondary
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Alphabetical List

    private var alphabeticalList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.alphabetical.enumerated()), id: \.element.config.assetId) { index, row in
                Button {
                    Haptics.light()
                    selectedCoin = row.config.assetId
                } label: {
                    coinRow(row: row)
                }
                .buttonStyle(.plain)

                if index < viewModel.alphabetical.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                        .padding(.horizontal, ArkSpacing.lg)
                }
            }
        }
        .padding(.vertical, ArkSpacing.sm)
        .padding(.horizontal, ArkSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, ArkSpacing.lg)
        .padding(.top, ArkSpacing.sm)
    }

    // MARK: - Trend Toggle

    private var trendToggle: some View {
        HStack(spacing: 4) {
            ForEach([CryptoRiskLevelsViewModel.TrendWindow.sevenDay, .thirtyDay], id: \.self) { window in
                Button {
                    Haptics.light()
                    viewModel.selectedTrendWindow = window
                } label: {
                    Text(window == .sevenDay ? "7D" : "30D")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            viewModel.selectedTrendWindow == window
                                ? AppColors.accent.opacity(0.12)
                                : Color.clear
                        )
                        .foregroundColor(
                            viewModel.selectedTrendWindow == window
                                ? AppColors.accent
                                : AppColors.textSecondary
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Band Section

    private func bandSection(band: String, items: [CryptoRiskLevelsViewModel.CoinRiskRow]) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Section header
            HStack(spacing: 6) {
                Circle()
                    .fill(bandColor(band))
                    .frame(width: 8, height: 8)

                Text(band)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(bandColor(band))

                Text("\(items.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bandColor(band))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(bandColor(band).opacity(0.12))
                    .cornerRadius(8)
            }
            .padding(.horizontal, ArkSpacing.lg)

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.config.assetId) { index, row in
                    Button { selectedCoin = row.config.assetId } label: {
                        coinRow(row: row)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                            .padding(.horizontal, ArkSpacing.lg)
                    }
                }
            }
            .padding(.vertical, ArkSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
            .padding(.horizontal, ArkSpacing.lg)
        }
        .padding(.top, ArkSpacing.lg)
    }

    // MARK: - Coin Row

    private func coinRow(row: CryptoRiskLevelsViewModel.CoinRiskRow) -> some View {
        HStack(spacing: 12) {
            // Logo
            if let logoURL = row.config.logoURL {
                KFImage(logoURL)
                    .resizable()
                    .placeholder { iconFallback(row.config.assetId) }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                iconFallback(row.config.assetId)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(row.config.assetId)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(row.config.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Score + trend
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.3f", row.current.riskLevel))
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(RiskColors.color(for: row.current.riskLevel))

                TrendIndicator(delta: viewModel.delta(for: row))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary.opacity(0.3))
        }
        .padding(.horizontal, ArkSpacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func iconFallback(_ symbol: String) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            Text(symbol.prefix(1))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func bandColor(_ band: String) -> Color {
        switch band {
        case "Very Low Risk": return RiskColors.color(for: 0.10)
        case "Low Risk": return RiskColors.color(for: 0.30)
        case "Neutral": return RiskColors.color(for: 0.47)
        case "Elevated Risk": return RiskColors.color(for: 0.62)
        case "High Risk": return RiskColors.color(for: 0.80)
        case "Extreme Risk": return RiskColors.color(for: 0.95)
        default: return AppColors.textSecondary
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading risk levels...")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var failedSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.textSecondary)
                    .frame(width: 8, height: 8)
                Text("Loading…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.lg)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.failedCoins.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }.enumerated()), id: \.element.assetId) { index, config in
                    HStack(spacing: 12) {
                        if let logoURL = config.logoURL {
                            KFImage(logoURL)
                                .resizable()
                                .placeholder { iconFallback(config.assetId) }
                                .fade(duration: 0.2)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        } else {
                            iconFallback(config.assetId)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.assetId)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Text(config.displayName)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("—")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.vertical, 10)

                    if index < viewModel.failedCoins.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                            .padding(.horizontal, ArkSpacing.lg)
                    }
                }
            }
            .padding(.vertical, ArkSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
            )
            .padding(.horizontal, ArkSpacing.lg)
        }
        .padding(.top, ArkSpacing.lg)
    }
}

// MARK: - Trend Indicator

private struct TrendIndicator: View {
    let delta: Double?
    private let threshold: Double = 0.02

    var body: some View {
        if let d = delta, abs(d) > threshold {
            let isUp = d > 0
            let color: Color = isUp ? AppColors.error : AppColors.success
            HStack(spacing: 2) {
                Image(systemName: isUp ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(String(format: "%+.3f", d))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
        } else {
            Text("—")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

/// Wrapper to make RiskCoin work with .sheet(item:)
private struct IdentifiableRiskCoin: Identifiable {
    let coin: RiskCoin
    var id: String { coin.rawValue }
}
