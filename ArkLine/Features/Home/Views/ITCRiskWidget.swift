import SwiftUI

// MARK: - ITC Risk Level Widget
/// Displays the Into The Cryptoverse Risk Level on the Home screen
struct ITCRiskWidget: View {
    let riskLevel: ITCRiskLevel?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    // MARK: - Sizing
    private var gaugeSize: CGFloat {
        switch size {
        case .compact: return 50
        case .standard: return 70
        case .expanded: return 90
        }
    }

    private var strokeWidth: CGFloat {
        switch size {
        case .compact: return 5
        case .standard: return 8
        case .expanded: return 10
        }
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            Group {
                if let risk = riskLevel {
                    contentView(risk: risk)
                } else {
                    placeholderView
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            if let risk = riskLevel {
                ITCRiskDetailView(riskLevel: risk)
            }
        }
    }

    // MARK: - Content View
    @ViewBuilder
    private func contentView(risk: ITCRiskLevel) -> some View {
        HStack(spacing: size == .compact ? 12 : 16) {
            // Risk Gauge
            ITCRiskGauge(
                riskLevel: risk.riskLevel,
                size: gaugeSize,
                strokeWidth: strokeWidth,
                colorScheme: colorScheme
            )

            // Risk Information
            VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                Text("ITC Risk Level")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                // Risk category badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(ITCRiskColors.color(for: risk.riskLevel, colorScheme: colorScheme))
                        .frame(width: 8, height: 8)

                    Text(risk.riskCategory)
                        .font(size == .compact ? .caption : .subheadline)
                        .foregroundColor(ITCRiskColors.color(for: risk.riskLevel, colorScheme: colorScheme))
                }

                if size != .compact {
                    Text("Powered by Into The Cryptoverse")
                        .font(.caption2)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                if size == .expanded {
                    Text("Updated: \(risk.date)")
                        .font(.caption2)
                        .foregroundColor(textPrimary.opacity(0.4))
                        .padding(.top, 2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.4))
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Placeholder View
    private var placeholderView: some View {
        HStack(spacing: 16) {
            // Skeleton gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08),
                        lineWidth: strokeWidth
                    )
                    .frame(width: gaugeSize, height: gaugeSize)

                Text("--")
                    .font(.system(size: size == .compact ? 14 : 18, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary.opacity(0.3))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ITC Risk Level")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            Spacer()
        }
        .padding(size == .compact ? 14 : 20)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - ITC Risk Gauge
/// Circular gauge showing the risk level with gradient coloring
struct ITCRiskGauge: View {
    let riskLevel: Double
    let size: CGFloat
    let strokeWidth: CGFloat
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        ITCRiskColors.color(for: riskLevel, colorScheme: colorScheme)
    }

    private var riskColorLight: Color {
        riskColor.opacity(0.6)
    }

    private var displayValue: String {
        String(format: "%.2f", riskLevel)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: strokeWidth
                )
                .frame(width: size, height: size)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    LinearGradient(
                        colors: [riskColorLight, riskColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Subtle glow effect
            Circle()
                .fill(riskColor.opacity(0.2))
                .blur(radius: size * 0.15)
                .frame(width: size * 0.6, height: size * 0.6)

            // Risk level value (0.00 - 1.00 format)
            Text(displayValue)
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - ITC Risk Colors
/// Provides colors based on risk level thresholds
struct ITCRiskColors {
    /// Returns the appropriate color for a given risk level (0.0 - 1.0)
    static func color(for level: Double, colorScheme: ColorScheme) -> Color {
        if level < 0.3 {
            return AppColors.success // Green for low risk
        } else if level < 0.7 {
            return AppColors.warning // Yellow/Orange for medium risk
        } else {
            return AppColors.error // Red for high risk
        }
    }

    /// Returns a gradient for the risk gauge
    static func gradient(for level: Double, colorScheme: ColorScheme) -> LinearGradient {
        let color = self.color(for: level, colorScheme: colorScheme)
        return LinearGradient(
            colors: [color.opacity(0.6), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - ITC Risk Detail View
struct ITCRiskDetailView: View {
    let riskLevel: ITCRiskLevel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                MeshGradientBackground()
                if isDarkMode { BrushEffectOverlay() }

                ScrollView {
                    VStack(spacing: 24) {
                        // Large Gauge
                        ITCRiskGauge(
                            riskLevel: riskLevel.riskLevel,
                            size: 180,
                            strokeWidth: 16,
                            colorScheme: colorScheme
                        )
                        .padding(.top, 20)

                        // Risk Info
                        VStack(spacing: 8) {
                            Text(riskLevel.riskCategory)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(ITCRiskColors.color(for: riskLevel.riskLevel, colorScheme: colorScheme))

                            Text(String(format: "%.3f", riskLevel.riskLevel))
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(textPrimary)

                            Text("As of \(riskLevel.date)")
                                .font(.caption)
                                .foregroundColor(textPrimary.opacity(0.5))
                        }

                        // Risk Level Explanation
                        riskExplanationCard

                        // Attribution
                        attributionCard

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("ITC Risk Level")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }

    private var riskExplanationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Understanding the Risk Level")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                RiskLevelRow(
                    category: "Low Risk",
                    range: "0.00 - 0.30",
                    description: "Historically good time to accumulate",
                    color: AppColors.success
                )

                RiskLevelRow(
                    category: "Medium Risk",
                    range: "0.30 - 0.70",
                    description: "Neutral market conditions",
                    color: AppColors.warning
                )

                RiskLevelRow(
                    category: "High Risk",
                    range: "0.70 - 1.00",
                    description: "Consider taking profits",
                    color: AppColors.error
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var attributionCard: some View {
        HStack {
            Image(systemName: "link")
                .foregroundColor(AppColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Powered by Into The Cryptoverse")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary)

                Text("intothecryptoverse.com")
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Risk Level Row
struct RiskLevelRow: View {
    let category: String
    let range: String
    let description: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(category)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)

                    Text("(\(range))")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()
        }
    }
}

// MARK: - Compact ITC Risk Card (for Market Sentiment Grid)
struct ITCRiskCard: View {
    let riskLevel: ITCRiskLevel
    let coinSymbol: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(coinSymbol) Risk (ITC)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.2f", riskLevel.riskLevel))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textPrimary)

                    Text(riskLevel.riskCategory)
                        .font(.caption2)
                        .foregroundColor(ITCRiskColors.color(for: riskLevel.riskLevel, colorScheme: colorScheme))
                }

                Spacer()

                // Mini gauge
                CompactITCGauge(riskLevel: riskLevel.riskLevel, colorScheme: colorScheme)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Compact ITC Gauge
struct CompactITCGauge: View {
    let riskLevel: Double
    let colorScheme: ColorScheme

    private var normalizedValue: Double {
        min(max(riskLevel, 0), 1)
    }

    private var riskColor: Color {
        ITCRiskColors.color(for: riskLevel, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: 6
                )
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(riskColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Previews
#Preview("ITC Risk Widget - Standard") {
    VStack(spacing: 20) {
        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.42
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.15
            ),
            size: .standard
        )

        ITCRiskWidget(
            riskLevel: ITCRiskLevel(
                date: "2025-01-15",
                riskLevel: 0.85
            ),
            size: .standard
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Widget - Compact") {
    ITCRiskWidget(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.42
        ),
        size: .compact
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}

#Preview("ITC Risk Card") {
    ITCRiskCard(
        riskLevel: ITCRiskLevel(
            date: "2025-01-15",
            riskLevel: 0.42
        ),
        coinSymbol: "BTC"
    )
    .frame(width: 180)
    .padding()
    .background(Color(hex: "0F0F0F"))
}
