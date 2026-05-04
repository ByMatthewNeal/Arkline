import SwiftUI

// MARK: - API Health Dashboard

struct APIHealthView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var results: [APIHealthResult] = []
    @State private var isLoading = false
    @State private var lastChecked: Date?
    @State private var showShareSheet = false
    @State private var checkProgress: Int = 0
    @State private var scanTimer: Timer?

    private var healthyCount: Int { results.filter { $0.status == .healthy }.count }
    private var degradedCount: Int { results.filter { $0.status == .degraded }.count }
    private var downCount: Int { results.filter { $0.status == .down }.count }

    private var overallStatus: APIHealthResult.APIStatus {
        if results.isEmpty { return .checking }
        if downCount > 0 { return .down }
        if degradedCount > 0 { return .degraded }
        return .healthy
    }

    private var resultsByCategory: [(category: APIHealthResult.APICategory, items: [APIHealthResult])] {
        APIHealthResult.APICategory.allCases.compactMap { category in
            let items = results.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    if isLoading && results.isEmpty {
                        scanningView
                            .padding(.top, ArkSpacing.xl)
                    } else {
                        // Overall Status Card
                        overallStatusCard
                            .padding(.top, ArkSpacing.sm)

                        // Summary Bar
                        if !results.isEmpty {
                            summaryBar
                        }

                        // Results by Category
                        ForEach(resultsByCategory, id: \.category) { group in
                            categorySection(group.category, items: group.items)
                        }

                        // Last checked timestamp
                        if let lastChecked {
                            Text("Last checked: \(lastChecked.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.bottom, ArkSpacing.xl)
                        }
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
            }
        }
        .navigationTitle("System Health")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !results.isEmpty {
                    ShareLink(item: exportReport()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await runChecks() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColors.accent)
                    }
                }
                .disabled(isLoading)
            }
        }
        .task {
            await runChecks()
        }
    }

    // MARK: - Overall Status Card

    private var overallStatusCard: some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: overallStatus.icon)
                .font(.system(size: 40))
                .foregroundColor(statusColor(overallStatus))
                .symbolEffect(.pulse, isActive: isLoading)

            Text(isLoading ? "Checking Services..." : overallStatusLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if !isLoading && !results.isEmpty {
                Text("\(healthyCount)/\(results.count) services operational")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.lg)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.Radius.card)
    }

    private var overallStatusLabel: String {
        switch overallStatus {
        case .healthy: return "All Systems Operational"
        case .degraded: return "Some Services Degraded"
        case .down: return "Service Issues Detected"
        case .checking: return "Checking..."
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: ArkSpacing.sm) {
            summaryChip(count: healthyCount, label: "Healthy", status: .healthy)
            if degradedCount > 0 {
                summaryChip(count: degradedCount, label: "Degraded", status: .degraded)
            }
            if downCount > 0 {
                summaryChip(count: downCount, label: "Down", status: .down)
            }
            Spacer()
        }
    }

    private func summaryChip(count: Int, label: String, status: APIHealthResult.APIStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor(status).opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Category Section

    private func categorySection(_ category: APIHealthResult.APICategory, items: [APIHealthResult]) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text(category.rawValue.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, result in
                    apiRow(result)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.Radius.card)
        }
    }

    // MARK: - API Row

    private func apiRow(_ result: APIHealthResult) -> some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: result.status.icon)
                .font(.system(size: 16))
                .foregroundColor(statusColor(result.status))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let detail = result.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(result.status == .down ? statusColor(.down) : AppColors.textSecondary)
                }

                if let explanation = result.explanation, result.status != .healthy {
                    Text(explanation)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .lineLimit(3)
                }
            }

            Spacer()

            if let latency = result.latencyMs {
                Text("\(latency)ms")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(latency > 3000 ? statusColor(.degraded) : AppColors.textSecondary)
            }
        }
        .padding(.horizontal, ArkSpacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func statusColor(_ status: APIHealthResult.APIStatus) -> Color {
        switch status {
        case .healthy: return AppColors.success
        case .degraded: return AppColors.warning
        case .down: return AppColors.error
        case .checking: return AppColors.textSecondary
        }
    }

    // MARK: - Scanning View

    private let scanLabels = [
        "Checking Coinbase...",
        "Pinging CoinGecko...",
        "Testing Claude API...",
        "Verifying FMP connection...",
        "Checking crypto cache freshness...",
        "Inspecting signal pipeline...",
        "Validating curated news...",
        "Checking daily briefing...",
        "Scanning economic events...",
        "Verifying model portfolios...",
        "Almost done...",
    ]

    private var scanningView: some View {
        VStack(spacing: ArkSpacing.xl) {
            // Animated radar icon
            ZStack {
                Circle()
                    .stroke(AppColors.accent.opacity(0.1), lineWidth: 2)
                    .frame(width: 100, height: 100)

                Circle()
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)

                Circle()
                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .symbolEffect(.variableColor.iterative, isActive: isLoading)
            }

            VStack(spacing: ArkSpacing.sm) {
                Text("Scanning Systems")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(scanLabels[checkProgress % scanLabels.count])
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: checkProgress)
            }

            // Progress bar
            VStack(spacing: ArkSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * min(CGFloat(checkProgress + 1) / CGFloat(scanLabels.count), 1.0), height: 6)
                            .animation(.easeInOut(duration: 0.4), value: checkProgress)
                    }
                }
                .frame(height: 6)

                Text("\(min(checkProgress + 1, scanLabels.count))/\(scanLabels.count) checks")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, ArkSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.xl)
        .onAppear { startScanAnimation() }
        .onDisappear { scanTimer?.invalidate() }
    }

    private func startScanAnimation() {
        checkProgress = 0
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            Task { @MainActor in
                if checkProgress < scanLabels.count - 1 {
                    checkProgress += 1
                }
            }
        }
    }

    private func runChecks() async {
        isLoading = true
        checkProgress = 0
        startScanAnimation()
        results = await APIHealthService.shared.runAllChecks()
        scanTimer?.invalidate()
        lastChecked = Date()
        isLoading = false
    }

    private func exportReport() -> String {
        var lines: [String] = []
        lines.append("Arkline System Health Report")
        if let lastChecked {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
            formatter.timeZone = TimeZone(identifier: "America/New_York")
            lines.append("Checked: \(formatter.string(from: lastChecked))")
        }
        lines.append("Status: \(healthyCount) healthy, \(degradedCount) degraded, \(downCount) down out of \(results.count) checks")
        lines.append("")

        for group in resultsByCategory {
            lines.append("## \(group.category.rawValue)")
            for result in group.items {
                let icon: String
                switch result.status {
                case .healthy: icon = "[OK]"
                case .degraded: icon = "[DEGRADED]"
                case .down: icon = "[DOWN]"
                case .checking: icon = "[...]"
                }
                var line = "\(icon) \(result.name)"
                if let detail = result.detail {
                    line += " — \(detail)"
                }
                if let latency = result.latencyMs {
                    line += " (\(latency)ms)"
                }
                lines.append(line)
                if let explanation = result.explanation, result.status != .healthy {
                    lines.append("  → \(explanation)")
                }
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        APIHealthView()
    }
}
