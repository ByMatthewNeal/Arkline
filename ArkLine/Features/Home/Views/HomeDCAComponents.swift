import SwiftUI

// MARK: - DCA Reminders Section
struct DCARemindersSection: View {
    let reminders: [DCAReminder]
    let onComplete: (DCAReminder) -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's DCA")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            ForEach(reminders) { reminder in
                GlassDCACard(reminder: reminder, onComplete: { onComplete(reminder) })
            }
        }
    }
}

// MARK: - Glass DCA Card
struct GlassDCACard: View {
    let reminder: DCAReminder
    let onComplete: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Coin icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.3))
                    .blur(radius: 8)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)

                Text(reminder.symbol.prefix(1))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(reminder.amount.asCurrency)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            // Complete button with glow
            Button(action: onComplete) {
                Text("Invest")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(AppColors.success)
                                .blur(radius: 8)
                                .opacity(0.5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.success, AppColors.success.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
            }
            .accessibilityLabel("Mark \(reminder.name) as invested")
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }
}

// MARK: - DCA Reminders Entry Section (Always Visible)
struct DCARemindersEntrySection: View {
    let todayReminders: [DCAReminder]
    let onComplete: (DCAReminder) -> Void
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var maxReminders: Int {
        switch size {
        case .compact: return 1
        case .standard: return 3
        case .expanded: return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header with bell icon
            HStack {
                Text("DCA Reminders")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(textPrimary)

                Spacer()

                NavigationLink(destination: DCAListView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }
            }

            // Show today's reminders if any, otherwise show entry card
            if todayReminders.isEmpty {
                // Entry card when no reminders today
                NavigationLink(destination: DCAListView()) {
                    HStack(spacing: size == .compact ? 12 : 16) {
                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: size == .compact ? 36 : 48, height: size == .compact ? 36 : 48)

                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: size == .compact ? 16 : 20))
                                .foregroundColor(AppColors.accent)
                        }

                        VStack(alignment: .leading, spacing: size == .compact ? 2 : 4) {
                            Text("Manage DCA Strategies")
                                .font(.system(size: size == .compact ? 14 : 16, weight: .semibold))
                                .foregroundColor(textPrimary)

                            if size != .compact {
                                Text("Time-based & Risk-based reminders")
                                    .font(.caption)
                                    .foregroundColor(textPrimary.opacity(0.6))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: size == .compact ? 12 : 14, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                    .padding(size == .compact ? 12 : 16)
                    .background(
                        RoundedRectangle(cornerRadius: size == .compact ? 12 : 16)
                            .fill(cardBackground)
                    )
                    .arkShadow(ArkSpacing.Shadow.card)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Manage DCA strategies")
            } else {
                if size != .compact {
                    // Today's Reminders header
                    Text("Today's Reminders")
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary.opacity(0.6))
                        .padding(.top, 4)
                }

                // Show today's reminders with new design
                ForEach(Array(todayReminders.prefix(maxReminders))) { reminder in
                    HomeDCACard(reminder: reminder, onInvest: { onComplete(reminder) }, isCompact: size == .compact)
                }
            }
        }
    }
}

// MARK: - Home DCA Card (Today's reminder with actions)
struct HomeDCACard: View {
    let reminder: DCAReminder
    let onInvest: () -> Void
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showHistory = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            // Header row
            HStack(spacing: isCompact ? 10 : 12) {
                // Coin icon
                HomeCoinIcon(symbol: reminder.symbol, size: isCompact ? 36 : 44)

                // Info
                VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                    HStack(spacing: 8) {
                        Text(reminder.name)
                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                            .foregroundColor(textPrimary)

                        if !isCompact {
                            // Today badge
                            Text(todayDateBadge)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColors.accent.opacity(0.15))
                                )
                        }
                    }

                    Text(isCompact ? reminder.amount.asCurrency : "Purchase Amount: \(reminder.amount.asCurrency)")
                        .font(.system(size: isCompact ? 11 : 13))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Spacer()

                if isCompact {
                    // Simple invest button for compact
                    Button(action: onInvest) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Mark \(reminder.name) as invested")
                }
            }

            // Action buttons (only for non-compact)
            if !isCompact {
                HStack(spacing: 10) {
                    // History button
                    Button(action: { showHistory = true }) {
                        Text("History")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                            )
                    }
                    .accessibilityLabel("View \(reminder.name) investment history")

                    // Mark as Invested button
                    Button(action: onInvest) {
                        Text("Mark as Invested")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                    }
                    .accessibilityLabel("Mark \(reminder.name) as invested")
                }
            }
        }
        .padding(isCompact ? 10 : 14)
        .background(
            RoundedRectangle(cornerRadius: isCompact ? 12 : 16)
                .fill(cardBackground)
        )
        .arkShadow(ArkSpacing.Shadow.card)
    }

    private var todayDateBadge: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Home Coin Icon
struct HomeCoinIcon: View {
    let symbol: String
    let size: CGFloat

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
        AppColors.accent
    }

    private var coinSystemIcon: String? {
        switch symbol.uppercased() {
        case "BTC": return "bitcoinsign"
        case "ETH": return "diamond.fill"
        default: return nil
        }
    }
}
