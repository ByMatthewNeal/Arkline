import SwiftUI

// MARK: - API Health Dashboard

struct APIHealthView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var results: [APIHealthResult] = []
    @State private var isLoading = false
    @State private var lastChecked: Date?

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
                .padding(.horizontal, ArkSpacing.md)
            }
        }
        .navigationTitle("API Health")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
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
        case .down: return Color(hex: "EF4444")
        case .checking: return AppColors.textSecondary
        }
    }

    private func runChecks() async {
        isLoading = true
        results = await APIHealthService.shared.runAllChecks()
        lastChecked = Date()
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        APIHealthView()
    }
}
