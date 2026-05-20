import SwiftUI
import Kingfisher

struct StockRiskLevelsScreen: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = StockRiskLevelsViewModel()
    @State private var selectedSymbol: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isLoading && viewModel.rows.isEmpty {
                    loadingState
                } else {
                    // Subtitle + toggle row
                    HStack {
                        Text("Trend & momentum • \(viewModel.totalAssetCount) stocks bucketed")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        trendToggle
                    }
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.top, ArkSpacing.sm)
                    .padding(.bottom, ArkSpacing.xs)

                    ForEach(viewModel.bucketed, id: \.band) { section in
                        bandSection(band: section.band, items: section.items)
                    }

                    // Failed stocks section
                    if !viewModel.failedStocks.isEmpty {
                        failedSection
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Stock Risk Levels")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadAll() }
        .sheet(item: Binding(
            get: { selectedSymbol.map { IdentifiableStockSymbol(symbol: $0) } },
            set: { selectedSymbol = $0?.symbol }
        )) { item in
            StockRiskDetailSheet(symbol: item.symbol)
                .presentationDetents([.large])
        }
    }

    // MARK: - Trend Toggle

    private var trendToggle: some View {
        HStack(spacing: 4) {
            ForEach([StockRiskLevelsViewModel.TrendWindow.sevenDay, .thirtyDay], id: \.self) { window in
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

    private func bandSection(band: String, items: [StockRiskLevelsViewModel.StockRiskRow]) -> some View {
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
                    Button { selectedSymbol = row.config.assetId } label: {
                        stockRow(row: row)
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

    // MARK: - Stock Row

    private func stockRow(row: StockRiskLevelsViewModel.StockRiskRow) -> some View {
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

                StockTrendIndicator(delta: viewModel.delta(for: row))
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
                        colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            Text(symbol.prefix(2))
                .font(.system(size: 12, weight: .bold))
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
            Text("Loading stock risk levels...")
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
                Text("Loading\u{2026}")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, ArkSpacing.lg)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.failedStocks.enumerated()), id: \.element.assetId) { index, config in
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

                        Text("\u{2014}")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.vertical, 10)

                    if index < viewModel.failedStocks.count - 1 {
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

// MARK: - Stock Trend Indicator

private struct StockTrendIndicator: View {
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
            Text("\u{2014}")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

/// Wrapper to make stock symbol work with .sheet(item:)
private struct IdentifiableStockSymbol: Identifiable {
    let symbol: String
    var id: String { symbol }
}
