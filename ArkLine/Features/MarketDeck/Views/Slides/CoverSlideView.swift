import SwiftUI

struct CoverSlideView: View {
    let data: CoverSlideData
    let deck: MarketUpdateDeck
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo with glow — same style as SplashView/onboarding
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                AppColors.accent.opacity(0.25),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                Image("LaunchIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }

            Spacer().frame(height: ArkSpacing.lg)

            Text("WEEKLY MARKET UPDATE")
                .font(AppFonts.interFont(size: 11, weight: .semibold))
                .foregroundColor(AppColors.accent.opacity(0.6))
                .tracking(2)

            Spacer().frame(height: ArkSpacing.sm)

            Text(deck.weekLabel)
                .font(AppFonts.urbanistFont(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer().frame(height: ArkSpacing.md)

            Text(data.regime)
                .font(AppFonts.interFont(size: 12, weight: .semibold))
                .foregroundColor(regimeColor)
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(regimeColor.opacity(0.15))
                )

            Spacer().frame(height: ArkSpacing.xl)

            // BTC hero
            if data.btcPrice != nil || data.btcWeeklyChange != nil {
                VStack(spacing: ArkSpacing.xxs) {
                    Text("BTC")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1)

                    if let btcPrice = data.btcPrice {
                        Text(btcPrice.asCurrency)
                            .font(AppFonts.number44)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    if let btcChange = data.btcWeeklyChange {
                        Text(String(format: "%+.2f%%", btcChange))
                            .font(AppFonts.number20)
                            .foregroundColor(btcChange >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }

            Spacer().frame(height: ArkSpacing.lg)

            // Fear & Greed
            if let fgEnd = data.fearGreedEnd {
                VStack(spacing: ArkSpacing.xs) {
                    Text("FEAR & GREED INDEX")
                        .font(AppFonts.interFont(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1.5)

                    HStack(spacing: ArkSpacing.lg) {
                        if let fgStart = data.fearGreedStart {
                            fearGreedItem(value: fgStart, label: fearGreedLabel(fgStart), opacity: 0.5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        }
                        fearGreedItem(value: fgEnd, label: fearGreedLabel(fgEnd), opacity: 1.0)
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.vertical, ArkSpacing.md)
                .background(AppColors.textPrimary(colorScheme).opacity(0.06))
                .cornerRadius(ArkSpacing.Radius.lg)
            }

            Spacer()

            // Disclaimer
            Text("Arkline\u{2019}s Weekly Market Update is for informational and educational purposes only. It reflects publicly available data and pattern analysis \u{2014} not financial advice, or investment recommendations. Market conditions change rapidly. Nothing in this update should be the sole basis for any investment decision. You are solely responsible for your own research and any actions you take. Consult a licensed financial advisor before making investment decisions.")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.bottom, ArkSpacing.sm)
        }
    }

    @ViewBuilder
    private func fearGreedItem(value: Int, label: String, opacity: Double) -> some View {
        VStack(spacing: ArkSpacing.xxs) {
            Text("\(value)")
                .font(AppFonts.number24)
                .foregroundColor(fearGreedColor(value).opacity(opacity))
            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(fearGreedColor(value).opacity(opacity * 0.8))
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        switch value {
        case 0...24: return AppColors.error
        case 25...44: return Color(hex: "F97316")
        case 45...55: return AppColors.warning
        case 56...75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private func fearGreedLabel(_ value: Int) -> String {
        switch value {
        case 0...24: return "Extreme Fear"
        case 25...44: return "Fear"
        case 45...55: return "Neutral"
        case 56...75: return "Greed"
        default: return "Extreme Greed"
        }
    }

    private var regimeColor: Color {
        switch data.regime.lowercased() {
        case "risk-on": return AppColors.success
        case "risk-off": return AppColors.error
        default: return AppColors.warning
        }
    }
}
