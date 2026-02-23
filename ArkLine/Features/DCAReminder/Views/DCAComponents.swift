import SwiftUI
import Kingfisher

// MARK: - Unified DCA Card
struct DCAUnifiedCard: View {
    let reminder: DCAReminder
    let riskLevel: AssetRiskLevel?
    let onEdit: () -> Void
    let onViewHistory: () -> Void
    var onMarkInvested: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var isDue: Bool {
        guard let nextDate = reminder.nextReminderDate else { return false }
        return nextDate <= Date()
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with coin icon and info
            HStack(spacing: 14) {
                // Coin icon
                DCACoinIconView(symbol: reminder.symbol, size: 48)

                // Title and details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reminder.symbol) DCA Reminder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)

                    // Subtitle: "$1000 • Tue, Fri • <0.5 Risk Level"
                    HStack(spacing: 4) {
                        Text(reminder.amount.asCurrency)
                            .foregroundColor(textPrimary.opacity(0.6))

                        Text("•")
                            .foregroundColor(textPrimary.opacity(0.4))

                        Text(reminder.frequency.shortDisplayName)
                            .foregroundColor(textPrimary.opacity(0.6))

                        if let risk = riskLevel {
                            Text("•")
                                .foregroundColor(textPrimary.opacity(0.4))

                            Text("<\(String(format: "%.1f", risk.riskScore / 100)) Risk")
                                .foregroundColor(riskColorFor(risk.riskCategory))
                        }
                    }
                    .font(.system(size: 14))
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Mark Invested button (only for due reminders)
                if let onMarkInvested, isDue {
                    Button(action: onMarkInvested) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                            Text("Invested")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.success)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.success.opacity(0.15))
                        )
                    }
                }

                // Edit Reminder button
                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                        )
                }

                // View History button
                Button(action: onViewHistory) {
                    Text("History")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.accent.opacity(0.15))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    private func riskColorFor(_ category: RiskCategory) -> Color {
        switch category {
        case .veryLow, .low: return AppColors.success
        case .moderate: return AppColors.warning
        case .high, .veryHigh: return AppColors.error
        }
    }
}

// MARK: - DCA Coin Icon View
struct DCACoinIconView: View {
    let symbol: String
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme

    private static let coinGeckoImageUrls: [String: String] = [
        "BTC": "https://assets.coingecko.com/coins/images/1/large/bitcoin.png",
        "ETH": "https://assets.coingecko.com/coins/images/279/large/ethereum.png",
        "SOL": "https://assets.coingecko.com/coins/images/4128/large/solana.png",
        "BNB": "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png",
        "UNI": "https://assets.coingecko.com/coins/images/12504/large/uniswap-logo.png",
        "RENDER": "https://assets.coingecko.com/coins/images/11636/large/rndr.png",
        "SUI": "https://assets.coingecko.com/coins/images/26375/large/sui_asset.jpeg",
        "ONDO": "https://assets.coingecko.com/coins/images/26580/large/ONDO.png",
        "ADA": "https://assets.coingecko.com/coins/images/975/large/cardano.png",
        "DOT": "https://assets.coingecko.com/coins/images/12171/large/polkadot.png",
        "AVAX": "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png",
        "LINK": "https://assets.coingecko.com/coins/images/877/large/chainlink-new-logo.png",
        "DOGE": "https://assets.coingecko.com/coins/images/5/large/dogecoin.png",
        "TRX": "https://assets.coingecko.com/coins/images/1094/large/tron-logo.png",
        "SHIB": "https://assets.coingecko.com/coins/images/11939/large/shiba.png",
        "XRP": "https://assets.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png",
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(coinColor.opacity(0.15))
                .frame(width: size, height: size)

            if let urlString = Self.coinGeckoImageUrls[symbol.uppercased()],
               let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        Text(String(symbol.prefix(1)))
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(coinColor)
                    }
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.65, height: size * 0.65)
                    .clipShape(Circle())
            } else {
                Text(String(symbol.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(coinColor)
            }
        }
    }

    private var coinColor: Color {
        switch symbol.uppercased() {
        case "BTC": return Color(hex: "F7931A")
        case "ETH": return Color(hex: "627EEA")
        case "SOL": return Color(hex: "00FFA3")
        case "ADA": return Color(hex: "0033AD")
        case "DOT": return Color(hex: "E6007A")
        case "AVAX": return Color(hex: "E84142")
        case "LINK": return Color(hex: "2A5ADA")
        case "DOGE": return Color(hex: "C2A633")
        case "XRP": return Color(hex: "23292F")
        case "SHIB": return Color(hex: "F4A422")
        default: return AppColors.accent
        }
    }
}
