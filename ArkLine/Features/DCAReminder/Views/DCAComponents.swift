import SwiftUI

// MARK: - Empty State
struct EmptyDCAState: View {
    let onCreateTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(AppColors.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No DCA Reminders")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("Create your first DCA reminder to start\nbuilding your investment strategy")
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button(action: onCreateTap) {
                Text("Create Reminder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.accent)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
}

// MARK: - Unified DCA Card
struct DCAUnifiedCard: View {
    let reminder: DCAReminder
    let riskLevel: AssetRiskLevel?
    let onEdit: () -> Void
    let onViewHistory: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
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
                // Edit Reminder button
                Button(action: onEdit) {
                    Text("Edit Reminder")
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
                    Text("View History")
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
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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

    var body: some View {
        ZStack {
            Circle()
                .fill(coinColor.opacity(0.15))
                .frame(width: size, height: size)

            if let iconName = coinSystemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(coinColor)
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

    private var coinSystemIcon: String? {
        switch symbol.uppercased() {
        case "BTC": return "bitcoinsign"
        case "ETH": return "diamond.fill"
        default: return nil
        }
    }
}
