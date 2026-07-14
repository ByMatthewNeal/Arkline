import SwiftUI

/// Full-screen research note: the published thesis behind a model portfolio
/// position. Shows the valuation frozen at publication next to the live
/// position price, the bull/bear debate, KPIs to watch, and the explicit
/// invalidation criteria ("what changes our mind").
struct ResearchNoteView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let note: ResearchNote
    /// Live price derived from the latest NAV snapshot (value/qty), if held.
    let currentPrice: Double?

    private var priceChangeSincePublish: Double? {
        guard let entry = note.valuationAtPublish?.price, entry > 0,
              let current = currentPrice else { return nil }
        return ((current - entry) / entry) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.ticker)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Text(note.title)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                        if let date = note.publishedAt {
                            Text("Published \(date.formatted(date: .abbreviated, time: .omitted)) · v\(note.version)")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Positioning block
                    HStack(spacing: ArkSpacing.sm) {
                        if let classification = note.classification {
                            tag(classification.capitalized,
                                color: classification == "core" ? AppColors.accent : AppColors.warning)
                        }
                        if let stage = note.stage {
                            tag(stage, color: AppColors.info)
                        }
                        if let weight = note.targetWeight {
                            tag(String(format: "Target %.0f%%", weight * 100), color: AppColors.success)
                        }
                    }

                    // Thesis
                    section("Why We Own It") {
                        Text(note.thesis)
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Valuation: frozen at publish vs now
                    if let val = note.valuationAtPublish {
                        section("The Numbers When We Called It") {
                            VStack(spacing: ArkSpacing.xs) {
                                if let price = val.price {
                                    valuationRow("Price at publication", String(format: "$%.2f", price))
                                }
                                if let current = currentPrice {
                                    HStack {
                                        Text("Price now")
                                            .font(AppFonts.body14)
                                            .foregroundColor(AppColors.textSecondary)
                                        Spacer()
                                        Text(String(format: "$%.2f", current))
                                            .font(AppFonts.body14Medium)
                                            .foregroundColor(AppColors.textPrimary(colorScheme))
                                        if let change = priceChangeSincePublish {
                                            Text(String(format: "%@%.1f%%", change >= 0 ? "+" : "", change))
                                                .font(AppFonts.caption12Medium)
                                                .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                                        }
                                    }
                                }
                                if let mcap = val.marketCap { valuationRow("Market cap", mcap) }
                                if let pe = val.pe { valuationRow("PE (trailing)", String(format: "%.1fx", pe)) }
                                if let fpe = val.forwardPe { valuationRow("Forward PE", String(format: "%.1fx", fpe)) }
                                if let peg = val.peg { valuationRow("PEG", String(format: "%.2f", peg)) }
                                if let ev = val.evFwdRevenue { valuationRow("EV / Fwd Revenue", String(format: "%.1fx", ev)) }
                                if let risk = val.riskLevel {
                                    valuationRow("Arkline Risk Level",
                                                 String(format: "%.2f%@", risk, val.riskCategory.map { " (\($0))" } ?? ""))
                                }
                                if let fair = val.fairValue { valuationRow("Model Fair Value", String(format: "$%.0f", fair)) }
                                if let asOf = val.asOf {
                                    Text("Snapshot as of \(asOf) — frozen so you can judge the call, not a moving target.")
                                        .font(AppFonts.caption12)
                                        .foregroundColor(AppColors.textTertiary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    // Bull vs Bear
                    if note.bullCase != nil || note.bearCase != nil {
                        section("The Debate") {
                            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                                if let bull = note.bullCase {
                                    debateBlock(label: "Bull case", text: bull, color: AppColors.success)
                                }
                                if let bear = note.bearCase {
                                    debateBlock(label: "Bear case", text: bear, color: AppColors.error)
                                }
                            }
                        }
                    }

                    // Drivers
                    if note.upsideDriver != nil || note.downsideRisk != nil {
                        section("What Moves It") {
                            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                                if let up = note.upsideDriver {
                                    labeledRow(icon: "arrow.up.right.circle.fill", color: AppColors.success,
                                               label: "Primary upside driver", text: up)
                                }
                                if let down = note.downsideRisk {
                                    labeledRow(icon: "arrow.down.right.circle.fill", color: AppColors.error,
                                               label: "Primary risk", text: down)
                                }
                            }
                        }
                    }

                    // Invalidation criteria — the accountability section
                    if !note.invalidation.isEmpty {
                        section("What Changes Our Mind") {
                            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                                Text("If these happen, the thesis is wrong — and we act, not rationalize.")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textTertiary)
                                ForEach(note.invalidation, id: \.criterion) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: item.triggered == true
                                              ? "exclamationmark.triangle.fill" : "circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(item.triggered == true ? AppColors.error : AppColors.textTertiary)
                                            .padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.criterion)
                                                .font(AppFonts.body14)
                                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                                .fixedSize(horizontal: false, vertical: true)
                                            if item.triggered == true, let at = item.triggeredAt {
                                                Text("Triggered \(at)")
                                                    .font(AppFonts.caption12Medium)
                                                    .foregroundColor(AppColors.error)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // KPIs
                    if !note.kpis.isEmpty {
                        section("KPIs We're Watching") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(note.kpis, id: \.self) { kpi in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .font(.system(size: 10))
                                            .foregroundColor(AppColors.accent)
                                            .padding(.top, 3)
                                        Text(kpi)
                                            .font(AppFonts.body14)
                                            .foregroundColor(AppColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    // Full report body
                    if let body = note.bodyMarkdown, !body.isEmpty {
                        section("Full Report") {
                            Text(LocalizedStringKey(body))
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    // Disclaimer
                    Text("Research notes explain the reasoning behind Arkline model portfolio positions. Educational and informational only — not investment advice. Do your own research and consult a licensed financial advisor before investing.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textTertiary)
                        .padding(ArkSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                                .fill(AppColors.warning.opacity(0.08))
                        )

                    Spacer(minLength: 32)
                }
                .padding(ArkSpacing.lg)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Research")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text(title)
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            content()
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.cardBorder(colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    @ViewBuilder
    private func valuationRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }

    @ViewBuilder
    private func debateBlock(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ArkSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func labeledRow(icon: String, color: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textTertiary)
                Text(text)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
