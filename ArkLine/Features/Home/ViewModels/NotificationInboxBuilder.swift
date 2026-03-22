import SwiftUI

/// Builds a unified notification inbox from existing data sources.
/// No new Supabase tables — assembles from trade_signals, DCA reminders,
/// market summary, and extreme move history.
struct NotificationInboxBuilder {

    private static let inboxWindow: TimeInterval = 48 * 3600  // 48 hours

    @MainActor static func build(
        todayReminders: [DCAReminder],
        recentSignals: [TradeSignal],
        marketSummary: MarketSummary?,
        extremeMoveHistory: [ExtremeMove],
        qpsSignals: [DailyPositioningSignal] = [],
        readIds: Set<String>
    ) -> [AppNotification] {
        let cutoff = Date().addingTimeInterval(-inboxWindow)
        var notifications: [AppNotification] = []

        // 1. Signal generated (active/triggered signals)
        for signal in recentSignals where signal.status.isLive {
            let triggeredAt = signal.triggeredAt ?? signal.generatedAt
            guard triggeredAt > cutoff else { continue }

            let isBuy = signal.signalType == .buy || signal.signalType == .strongBuy
            let direction = isBuy ? "Long" : "Short"
            let isStrong = signal.signalType == .strongBuy || signal.signalType == .strongSell
            let strength = isStrong ? "Strong " : ""

            let id = "signal_new_\(signal.id.uuidString)"
            notifications.append(AppNotification(
                id: id,
                type: .signalGenerated,
                icon: isBuy ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                iconColor: isBuy ? AppColors.success : AppColors.error,
                title: "\(signal.asset) \(strength)\(direction)",
                subtitle: "Entry \(signal.entryPriceMid.asSignalPrice) | R:R \(String(format: "%.1f", signal.riskRewardRatio))x",
                time: triggeredAt,
                isRead: readIds.contains(id)
            ))
        }

        // 2. Signal outcomes (closed signals)
        for signal in recentSignals {
            guard let closedAt = signal.closedAt, closedAt > cutoff else { continue }
            guard let outcome = signal.outcome else { continue }

            let id = "signal_outcome_\(signal.id.uuidString)"
            let (icon, color, outcomeText) = outcomeDisplay(signal)

            let pctStr = signal.outcomePct.map { String(format: "%+.1f%%", $0) } ?? ""
            let durationStr = signal.durationHours.map { "\($0)h" } ?? ""
            let subtitle = [pctStr, durationStr].filter { !$0.isEmpty }.joined(separator: " in ")

            notifications.append(AppNotification(
                id: id,
                type: .signalOutcome,
                icon: icon,
                iconColor: color,
                title: "\(signal.asset) \(outcomeText)",
                subtitle: subtitle,
                time: closedAt,
                isRead: readIds.contains(id)
            ))
        }

        // 3. T1 hits on still-active signals
        for signal in recentSignals where signal.status.isLive {
            guard let t1HitAt = signal.t1HitAt, t1HitAt > cutoff else { continue }

            let id = "signal_t1_\(signal.id.uuidString)"
            let t1Pnl = signal.t1PnlPct.map { String(format: "%+.1f%%", $0) } ?? ""

            notifications.append(AppNotification(
                id: id,
                type: .signalT1Hit,
                icon: "target",
                iconColor: AppColors.success,
                title: "\(signal.asset) T1 Hit",
                subtitle: "50% closed at \(t1Pnl). Runner trailing...",
                time: t1HitAt,
                isRead: readIds.contains(id)
            ))
        }

        // 4. Daily briefing
        if let summary = marketSummary, summary.generatedAt > cutoff {
            let id = "briefing_\(summary.briefingKey)"
            // Strip markdown headers (## Posture, etc.) from the preview
            let cleanedSummary = summary.summary
                .components(separatedBy: .newlines)
                .drop { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") || $0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: " ")
            let preview = String(cleanedSummary.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
            notifications.append(AppNotification(
                id: id,
                type: .dailyBriefing,
                icon: "newspaper.fill",
                iconColor: AppColors.accent,
                title: "Daily Briefing",
                subtitle: preview,
                time: summary.generatedAt,
                isRead: readIds.contains(id)
            ))
        }

        // 5. Extreme macro moves
        for move in extremeMoveHistory where move.detectedAt > cutoff {
            let id = "macro_\(move.id.uuidString)"
            notifications.append(AppNotification(
                id: id,
                type: .extremeMacroMove,
                icon: "exclamationmark.triangle.fill",
                iconColor: move.severity == .extreme ? AppColors.error : AppColors.warning,
                title: move.notificationTitle,
                subtitle: move.interpretation,
                time: move.detectedAt,
                isRead: readIds.contains(id)
            ))
        }

        // 6. DCA reminders (today only)
        let calendar = Calendar.current
        let today = Date()
        for reminder in todayReminders {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.notificationTime)
            let notifTime = calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0, of: today
            ) ?? today

            let dateStr = calendar.startOfDay(for: today).timeIntervalSince1970
            let id = "dca_\(reminder.id.uuidString)_\(Int(dateStr))"

            notifications.append(AppNotification(
                id: id,
                type: .dcaReminder,
                icon: "dollarsign.arrow.circlepath",
                iconColor: AppColors.accent,
                title: "DCA Reminder: \(reminder.name)",
                subtitle: "Time to invest \(reminder.amount.asCurrency) in \(reminder.symbol)",
                time: notifTime,
                isRead: readIds.contains(id)
            ))
        }

        // 7. QPS signal changes
        for signal in qpsSignals where signal.hasChanged {
            let time = signal.createdAt ?? signal.signalDate
            guard time > cutoff else { continue }

            let id = "qps_\(signal.asset)_\(signal.signal)_\(Int(signal.signalDate.timeIntervalSince1970))"
            let prev = signal.prevPositioningSignal?.label ?? "Unknown"
            let current = signal.positioningSignal.label
            // Color by direction of change: upgrade = green, downgrade = red, lateral = yellow
            let order: [PositioningSignal] = [.bearish, .neutral, .bullish]
            let prevIdx = signal.prevPositioningSignal.flatMap { order.firstIndex(of: $0) } ?? 1
            let newIdx = order.firstIndex(of: signal.positioningSignal) ?? 1
            let color: Color = newIdx > prevIdx ? AppColors.success
                : newIdx < prevIdx ? AppColors.error : AppColors.warning

            notifications.append(AppNotification(
                id: id,
                type: .qpsSignalChange,
                icon: "waveform.path.ecg",
                iconColor: color,
                title: "\(signal.asset) Signal Changed",
                subtitle: "\(prev) → \(current)",
                time: time,
                isRead: readIds.contains(id)
            ))
        }

        // 8. Market regime change
        if let regime = RegimeChangeManager.shared.lastKnownRegime,
           regime != .noData,
           let changeDate = RegimeChangeManager.shared.lastRegimeChange,
           changeDate > cutoff {
            let id = "regime_\(regime.rawValue)_\(Int(changeDate.timeIntervalSince1970))"
            notifications.append(AppNotification(
                id: id,
                type: .marketRegimeChange,
                icon: "globe.americas.fill",
                iconColor: regime.color,
                title: regime.notificationTitle,
                subtitle: regime.description,
                time: changeDate,
                isRead: readIds.contains(id)
            ))
        }

        // 9. Sentiment regime shift
        if let regime = SentimentRegimeAlertManager.shared.lastKnownRegime,
           let changeDate = SentimentRegimeAlertManager.shared.lastRegimeChange,
           changeDate > cutoff {
            let id = "sentiment_\(regime.rawValue)_\(Int(changeDate.timeIntervalSince1970))"
            notifications.append(AppNotification(
                id: id,
                type: .sentimentRegimeShift,
                icon: regime.icon,
                iconColor: Color(hex: regime.colorHex),
                title: "Sentiment Shift: \(regime.rawValue)",
                subtitle: regime.description,
                time: changeDate,
                isRead: readIds.contains(id)
            ))
        }

        // Sort by time descending
        notifications.sort { $0.time > $1.time }
        return notifications
    }

    // MARK: - Helpers

    private static func outcomeDisplay(_ signal: TradeSignal) -> (icon: String, color: Color, text: String) {
        switch signal.outcome {
        case .win:
            return ("checkmark.circle.fill", AppColors.success, "Target Hit")
        case .loss:
            if signal.status == .expired {
                return ("clock.badge.xmark", AppColors.textSecondary, "Expired")
            }
            return ("xmark.circle.fill", AppColors.error, "Stopped Out")
        case .partial:
            return ("minus.circle.fill", AppColors.warning, "Partial Win")
        case .none:
            return ("questionmark.circle", AppColors.textSecondary, "Closed")
        }
    }
}
