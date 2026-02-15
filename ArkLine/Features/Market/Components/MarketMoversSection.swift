import SwiftUI

// MARK: - FMP Market Movers Section
/// Shows top gainers and losers from FMP API
struct FMPMarketMoversSection: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var gainers: [FMPMover] = []
    @State private var losers: [FMPMover] = []
    @State private var isLoading = true
    @State private var selectedTab = 0 // 0 = Gainers, 1 = Losers
    @State private var errorMessage: String?

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accent)
                Text("Market Movers")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Top Gainers").tag(0)
                Text("Top Losers").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            // Content
            if let error = errorMessage {
                ErrorCard(message: error)
                    .padding(.horizontal, 20)
            } else if isLoading {
                LoadingCard()
                    .padding(.horizontal, 20)
            } else {
                let movers = selectedTab == 0 ? gainers : losers

                if movers.isEmpty {
                    EmptyMoversCard()
                        .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(movers.prefix(5).enumerated()), id: \.element.id) { index, mover in
                            MoverRow(mover: mover, isGainer: selectedTab == 0)

                            if index < min(movers.count, 5) - 1 {
                                Divider()
                                    .background(AppColors.textSecondary.opacity(0.2))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 20)
                }
            }
        }
        .task {
            await loadMovers()
        }
    }

    private func loadMovers() async {
        guard FMPService.shared.isConfigured else {
            errorMessage = "FMP API key not configured"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let gTask = FMPService.shared.fetchBiggestGainers(limit: 10)
            async let lTask = FMPService.shared.fetchBiggestLosers(limit: 10)

            let (g, l) = try await (gTask, lTask)
            gainers = g
            losers = l
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Mover Row
struct MoverRow: View {
    @Environment(\.colorScheme) var colorScheme
    let mover: FMPMover
    let isGainer: Bool

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(mover.symbol)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(textPrimary)

                Text(mover.name)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Price
            Text(mover.priceFormatted)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .frame(width: 70, alignment: .trailing)

            // Change
            HStack(spacing: 4) {
                Image(systemName: isGainer ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(mover.changePercentFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(isGainer ? AppColors.success : AppColors.error)
            .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Loading Card (Skeleton)
private struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonListItem()
                if index < 4 {
                    Divider()
                        .background(AppColors.textSecondary.opacity(0.2))
                        .padding(.horizontal, 16)
                }
            }
        }
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Error Card
private struct ErrorCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(AppColors.warning)
            Text(message)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Empty Card
private struct EmptyMoversCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
            Text("No market data available")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Preview
#Preview {
    FMPMarketMoversSection()
        .padding(.vertical)
        .background(Color.black.opacity(0.9))
}
