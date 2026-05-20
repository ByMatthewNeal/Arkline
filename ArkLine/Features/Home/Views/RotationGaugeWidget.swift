import SwiftUI

// MARK: - Rotation Gauge Widget

struct RotationGaugeWidget: View {
    let signal: RotationSignal
    let topSectors: [SectorPerformance]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        NavigationLink {
            RotationDetailView(signal: signal)
        } label: {
            VStack(alignment: .leading, spacing: size == .compact ? 10 : 14) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: size == .compact ? 14 : 16))
                            .foregroundColor(regimeColor)

                        Text("Rotation Signal")
                            .font(size == .compact ? .subheadline : .headline)
                            .foregroundColor(textPrimary)
                    }

                    Spacer()

                    // Regime badge
                    Text(signal.regime.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(regimeColor))
                }

                if size == .compact {
                    compactBody
                } else {
                    standardBody
                }
            }
            .padding(size == .compact ? 14 : 18)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                    .fill(cardBackground)
            )
            .arkShadow(ArkSpacing.Shadow.card)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Body

    private var compactBody: some View {
        HStack(spacing: 16) {
            // Score
            VStack(spacing: 2) {
                Text(scoreText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(regimeColor)

                Text(scoreSuffix)
                    .font(.system(size: 10))
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            // Narrative
            if let narrative = signal.narrative {
                Text(narrative)
                    .font(.system(size: 11))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundColor(textPrimary.opacity(0.3))
        }
    }

    // MARK: - Standard Body

    private var standardBody: some View {
        VStack(spacing: 14) {
            // Gauge bar
            gaugeBar

            // Returns comparison
            HStack(spacing: 0) {
                returnPill(label: "BTC 30d", value: signal.btc30dReturn, isCrypto: true)
                Spacer()
                Text("vs")
                    .font(.system(size: 11))
                    .foregroundColor(textPrimary.opacity(0.4))
                Spacer()
                returnPill(label: "SPY 30d", value: signal.spy30dReturn, isCrypto: false)
            }

            // Narrative
            if let narrative = signal.narrative {
                Text(narrative)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.7))
                    .lineSpacing(2)
            }

            // Top sectors preview (standard/expanded)
            if !topSectors.isEmpty {
                Divider().opacity(0.2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Sectors")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textPrimary.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    let count = size == .expanded ? topSectors.count : min(3, topSectors.count)
                    ForEach(topSectors.prefix(count)) { sector in
                        sectorRow(sector)
                    }
                }
            }
        }
    }

    // MARK: - Gauge Bar

    private var gaugeBar: some View {
        VStack(spacing: 6) {
            // Labels
            HStack {
                Text("Crypto")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "F7931A"))
                Spacer()
                Text(scoreText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(regimeColor)
                Spacer()
                Text("Equities")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "3B82F6"))
            }

            // Bar
            GeometryReader { geo in
                let width = geo.size.width
                let center = width / 2
                let normalized = CGFloat(signal.rotationScore + 100) / 200.0
                let needleX = width * normalized

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "F7931A").opacity(0.3), Color(hex: "9CA3AF").opacity(0.15), Color(hex: "3B82F6").opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)

                    // Center marker
                    Rectangle()
                        .fill(textPrimary.opacity(0.2))
                        .frame(width: 1, height: 12)
                        .position(x: center, y: 4)

                    // Needle
                    Circle()
                        .fill(regimeColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: regimeColor.opacity(0.4), radius: 4)
                        .position(x: needleX, y: 4)
                }
            }
            .frame(height: 14)
        }
    }

    // MARK: - Helpers

    private func returnPill(label: String, value: Double?, isCrypto: Bool) -> some View {
        let ret = value ?? 0
        let isPositive = ret >= 0
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(String(format: "%+.1f%%", ret))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((isCrypto ? Color(hex: "F7931A") : Color(hex: "3B82F6")).opacity(0.08))
        )
    }

    private func sectorRow(_ sector: SectorPerformance) -> some View {
        HStack(spacing: 8) {
            Image(systemName: sector.icon)
                .font(.system(size: 10))
                .foregroundColor(AppColors.accent)
                .frame(width: 16)

            Text(sector.sectorName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textPrimary)
                .lineLimit(1)

            Spacer()

            if let rs = sector.relativeStrengthVsSpy {
                Text(String(format: "%+.1f%%", rs))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(rs >= 0 ? AppColors.success : AppColors.error)
            }

            if let top = sector.topPerformer {
                Text(top)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
    }

    private var regimeColor: Color {
        switch signal.regime {
        case .cryptoFavored: return Color(hex: "F7931A")
        case .equityFavored: return Color(hex: "3B82F6")
        case .neutral: return AppColors.textSecondary
        case .riskOff: return AppColors.error
        }
    }

    private var scoreText: String {
        let s = signal.rotationScore
        return s >= 0 ? "+\(s)" : "\(s)"
    }

    private var scoreSuffix: String {
        signal.rotationScore < 0 ? "→ Crypto" : signal.rotationScore > 0 ? "→ Equities" : "Neutral"
    }
}
