import SwiftUI

// MARK: - Sentiment Regime Detail View
struct SentimentRegimeDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    @StateObject private var alertManager = SentimentRegimeAlertManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let data = viewModel.sentimentRegimeData {
                    // Current Regime Header
                    RegimeHeaderSection(data: data)

                    // Quadrant Chart
                    SentimentQuadrantChart(data: data)

                    // Milestones Legend
                    MilestonesSection(milestones: data.milestones)

                    // Regime Guide
                    RegimeGuideSection()

                    // Update Schedule Info
                    RegimeUpdateInfoSection(
                        lastUpdated: viewModel.regimeLastUpdated,
                        nextUpdate: viewModel.regimeNextUpdate
                    )

                    // Notification Toggle
                    RegimeNotificationToggle(alertManager: alertManager)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(.vertical, 16)
        }
        .background(
            colorScheme == .dark
                ? Color(hex: "0F0F0F")
                : Color(hex: "F5F5F7")
        )
        .navigationTitle("Sentiment Regime")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sentiment Regime Shifted", isPresented: $alertManager.showRegimeShiftAlert) {
            Button("OK") { alertManager.dismissAlert() }
        } message: {
            if let info = alertManager.regimeShiftInfo {
                Text("Market shifted from \(info.from.rawValue) to \(info.to.rawValue). \(info.to.description)")
            }
        }
    }
}

// MARK: - Regime Header Section
private struct RegimeHeaderSection: View {
    @Environment(\.colorScheme) var colorScheme
    let data: SentimentRegimeData

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Regime Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: data.currentRegime.colorHex).opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: data.currentRegime.icon)
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: data.currentRegime.colorHex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(data.currentRegime.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(data.currentRegime.description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Values
            HStack(spacing: 24) {
                ValuePill(label: "Emotion", value: String(format: "%.0f", data.currentPoint.emotionScore))
                ValuePill(label: "Engagement", value: String(format: "%.0f", data.currentPoint.engagementScore))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }
}

// MARK: - Value Pill
private struct ValuePill: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }
}

// MARK: - Sentiment Quadrant Chart
struct SentimentQuadrantChart: View {
    @Environment(\.colorScheme) var colorScheme
    let data: SentimentRegimeData
    @State private var showFullscreen = false

    private let chartPadding: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Regime Quadrant")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 20)

            chartContent(chartHeight: 260)
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)
                .onTapGesture { showFullscreen = true }
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenQuadrantView(data: data)
        }
    }

    @ViewBuilder
    func chartContent(chartHeight: CGFloat) -> some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width - chartPadding * 2

            ZStack(alignment: .topLeading) {
                quadrantBackgrounds(width: chartWidth, height: chartHeight)
                    .offset(x: chartPadding, y: 0)

                crosshairLines(width: chartWidth, height: chartHeight)
                    .offset(x: chartPadding, y: 0)

                quadrantLabels(width: chartWidth, height: chartHeight)
                    .offset(x: chartPadding, y: 0)

                trajectoryPath(width: chartWidth, height: chartHeight)
                    .offset(x: chartPadding, y: 0)

                milestoneDots(width: chartWidth, height: chartHeight)
                    .offset(x: chartPadding, y: 0)

                axisLabels(width: chartWidth, height: chartHeight)
            }
            .frame(height: chartHeight + 24)
        }
        .frame(height: chartHeight + 24)
    }

    // MARK: - Quadrant Backgrounds

    @ViewBuilder
    private func quadrantBackgrounds(width: CGFloat, height: CGFloat) -> some View {
        let halfW = width / 2
        let halfH = height / 2
        let opacity = colorScheme == .dark ? 0.12 : 0.10

        ZStack(alignment: .topLeading) {
            // Panic (top-left)
            Rectangle()
                .fill(Color(hex: SentimentRegime.panic.colorHex).opacity(opacity))
                .frame(width: halfW, height: halfH)

            // FOMO (top-right)
            Rectangle()
                .fill(Color(hex: SentimentRegime.fomo.colorHex).opacity(opacity))
                .frame(width: halfW, height: halfH)
                .offset(x: halfW)

            // Apathy (bottom-left)
            Rectangle()
                .fill(Color(hex: SentimentRegime.apathy.colorHex).opacity(opacity))
                .frame(width: halfW, height: halfH)
                .offset(y: halfH)

            // Complacency (bottom-right)
            Rectangle()
                .fill(Color(hex: SentimentRegime.complacency.colorHex).opacity(opacity))
                .frame(width: halfW, height: halfH)
                .offset(x: halfW, y: halfH)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Crosshair Lines

    @ViewBuilder
    private func crosshairLines(width: CGFloat, height: CGFloat) -> some View {
        let lineColor = colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)

        // Vertical line (x = 50)
        Path { path in
            path.move(to: CGPoint(x: width / 2, y: 0))
            path.addLine(to: CGPoint(x: width / 2, y: height))
        }
        .stroke(lineColor, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Horizontal line (y = 50)
        Path { path in
            path.move(to: CGPoint(x: 0, y: height / 2))
            path.addLine(to: CGPoint(x: width, y: height / 2))
        }
        .stroke(lineColor, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    // MARK: - Quadrant Labels

    @ViewBuilder
    private func quadrantLabels(width: CGFloat, height: CGFloat) -> some View {
        let labelOpacity = 0.55

        // Panic (top-left)
        Text("PANIC")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: SentimentRegime.panic.colorHex).opacity(labelOpacity))
            .position(x: width * 0.25, y: 16)

        // FOMO (top-right)
        Text("FOMO")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: SentimentRegime.fomo.colorHex).opacity(labelOpacity))
            .position(x: width * 0.75, y: 16)

        // Apathy (bottom-left)
        Text("APATHY")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: SentimentRegime.apathy.colorHex).opacity(labelOpacity))
            .position(x: width * 0.25, y: height - 16)

        // Complacency (bottom-right)
        Text("COMPLACENCY")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: SentimentRegime.complacency.colorHex).opacity(labelOpacity))
            .position(x: width * 0.75, y: height - 16)
    }

    // MARK: - Trajectory Path

    /// Ordered milestone points for the smooth curve (oldest → newest)
    private func milestonePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        var points: [(date: Date, cgPoint: CGPoint)] = []
        let m = data.milestones

        func toPoint(_ p: SentimentRegimePoint) -> CGPoint {
            CGPoint(
                x: p.emotionScore / 100.0 * width,
                y: (1.0 - CGFloat(p.engagementScore) / 100.0) * height
            )
        }

        if let p = m.threeMonthsAgo { points.append((p.date, toPoint(p))) }
        if let p = m.oneMonthAgo { points.append((p.date, toPoint(p))) }
        if let p = m.oneWeekAgo { points.append((p.date, toPoint(p))) }
        points.append((m.today.date, toPoint(m.today)))

        return points.map(\.cgPoint)
    }

    @ViewBuilder
    private func trajectoryPath(width: CGFloat, height: CGFloat) -> some View {
        // Subtle scatter dots for daily data points
        ForEach(data.trajectory) { point in
            Circle()
                .fill(AppColors.accent.opacity(0.22))
                .frame(width: 3, height: 3)
                .position(
                    x: point.emotionScore / 100.0 * width,
                    y: (1.0 - CGFloat(point.engagementScore) / 100.0) * height
                )
        }

        // Smooth curve connecting milestones only
        let pts = milestonePoints(width: width, height: height)
        if pts.count >= 2, let first = pts.first {
            Path { path in
                path.move(to: first)
                if pts.count == 2 {
                    path.addLine(to: pts[1])
                } else {
                    // Catmull-Rom to cubic bezier through milestone points
                    for i in 0..<(pts.count - 1) {
                        let p0 = i > 0 ? pts[i - 1] : pts[i]
                        let p1 = pts[i]
                        let p2 = pts[i + 1]
                        let p3 = i + 2 < pts.count ? pts[i + 2] : pts[i + 1]

                        let cp1 = CGPoint(
                            x: p1.x + (p2.x - p0.x) / 6,
                            y: p1.y + (p2.y - p0.y) / 6
                        )
                        let cp2 = CGPoint(
                            x: p2.x - (p3.x - p1.x) / 6,
                            y: p2.y - (p3.y - p1.y) / 6
                        )
                        path.addCurve(to: p2, control1: cp1, control2: cp2)
                    }
                }
            }
            .stroke(
                AppColors.accent.opacity(0.7),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Milestone Dots

    @ViewBuilder
    private func milestoneDots(width: CGFloat, height: CGFloat) -> some View {
        let milestones = data.milestones

        // 3 Months ago
        if let point = milestones.threeMonthsAgo {
            milestoneDot(point: point, width: width, height: height, size: 8, opacity: 0.4, label: "3M")
        }

        // 1 Month ago
        if let point = milestones.oneMonthAgo {
            milestoneDot(point: point, width: width, height: height, size: 8, opacity: 0.6, label: "1M")
        }

        // 1 Week ago
        if let point = milestones.oneWeekAgo {
            milestoneDot(point: point, width: width, height: height, size: 8, opacity: 0.8, label: "1W")
        }

        // Today (largest, with glow)
        todayDot(point: milestones.today, width: width, height: height)
    }

    @ViewBuilder
    private func milestoneDot(
        point: SentimentRegimePoint,
        width: CGFloat,
        height: CGFloat,
        size: CGFloat,
        opacity: Double,
        label: String
    ) -> some View {
        let x = point.emotionScore / 100.0 * width
        let y = (1.0 - CGFloat(point.engagementScore) / 100.0) * height

        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(opacity))
                .frame(width: size, height: size)

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .offset(y: -12)
        }
        .position(x: x, y: y)
    }

    @ViewBuilder
    private func todayDot(point: SentimentRegimePoint, width: CGFloat, height: CGFloat) -> some View {
        let x = point.emotionScore / 100.0 * width
        let y = (1.0 - CGFloat(point.engagementScore) / 100.0) * height

        ZStack {
            // Glow
            Circle()
                .fill(AppColors.accent.opacity(0.2))
                .frame(width: 20, height: 20)

            // Main dot
            Circle()
                .fill(AppColors.accent)
                .frame(width: 12, height: 12)

            // Inner dot
            Circle()
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                .frame(width: 4, height: 4)

            Text("Now")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(AppColors.accent)
                .offset(y: -16)
        }
        .position(x: x, y: y)
    }

    // MARK: - Axis Labels

    @ViewBuilder
    private func axisLabels(width: CGFloat, height: CGFloat) -> some View {
        // X-axis labels
        Text("Fear")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .position(x: chartPadding + 20, y: height + 14)

        Text("Greed")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .position(x: chartPadding + width - 20, y: height + 14)

        // Y-axis labels (rotated)
        Text("Low Vol")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .rotationEffect(.degrees(-90))
            .position(x: 12, y: height - 24)

        Text("High Vol")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(AppColors.textSecondary)
            .rotationEffect(.degrees(-90))
            .position(x: 12, y: 24)
    }
}

// MARK: - Milestones Section
private struct MilestonesSection: View {
    @Environment(\.colorScheme) var colorScheme
    let milestones: RegimeMilestones

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trajectory")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 8) {
                milestoneRow(label: "Now", point: milestones.today, isCurrent: true)

                if let point = milestones.oneWeekAgo {
                    milestoneRow(label: "1 Week Ago", point: point)
                }
                if let point = milestones.oneMonthAgo {
                    milestoneRow(label: "1 Month Ago", point: point)
                }
                if let point = milestones.threeMonthsAgo {
                    milestoneRow(label: "3 Months Ago", point: point)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func milestoneRow(label: String, point: SentimentRegimePoint, isCurrent: Bool = false) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: point.regime.colorHex))
                .frame(width: isCurrent ? 10 : 8, height: isCurrent ? 10 : 8)

            Text(label)
                .font(.subheadline)
                .fontWeight(isCurrent ? .semibold : .regular)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            Text(point.regime.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(hex: point.regime.colorHex))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(hex: point.regime.colorHex).opacity(0.12))
                )

            Text(dateFormatter.string(from: point.date))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - Regime Guide Section
private struct RegimeGuideSection: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regime Guide")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 8) {
                ForEach(SentimentRegime.allCases, id: \.rawValue) { regime in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: regime.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: regime.colorHex))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(regime.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text(regime.description)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }
}

// MARK: - Regime Update Info Section
private struct RegimeUpdateInfoSection: View {
    @Environment(\.colorScheme) var colorScheme
    let lastUpdated: Date?
    let nextUpdate: Date

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d 'at' HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)

                Text("Updated twice weekly")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Text("Sundays & Wednesdays at 00:15 UTC")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Divider()
                .opacity(0.4)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last updated")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(lastUpdatedText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next update")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(Self.dateFormatter.string(from: nextUpdate) + " UTC")
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }

    private var lastUpdatedText: String {
        guard let date = lastUpdated else { return "—" }
        return Self.dateFormatter.string(from: date) + " UTC"
    }
}

// MARK: - Regime Notification Toggle
private struct RegimeNotificationToggle: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var alertManager: SentimentRegimeAlertManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)
                .frame(width: 32, height: 32)
                .background(AppColors.accent.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Regime Shift Alerts")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Get notified when the quadrant changes")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { alertManager.notificationsEnabled },
                set: { newValue in
                    alertManager.notificationsEnabled = newValue
                    if newValue {
                        alertManager.requestNotificationPermissions()
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 20)
    }
}

// MARK: - Fullscreen Quadrant View
private struct FullscreenQuadrantView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    let data: SentimentRegimeData

    var body: some View {
        ZStack(alignment: .topTrailing) {
            (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Regime Quadrant")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .padding(.top, 60)

                SentimentQuadrantChart(data: data)
                    .chartContent(chartHeight: UIScreen.main.bounds.height * 0.55)
                    .padding(16)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 16)

                Spacer()
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(20)
            }
            .padding(.top, 44)
        }
    }
}
