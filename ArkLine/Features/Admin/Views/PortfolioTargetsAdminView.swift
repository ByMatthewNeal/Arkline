import SwiftUI

/// Admin-only editor for stock model portfolio target allocations.
///
/// Posting a new target here is the "position change" mechanism: the
/// compute-stock-portfolios edge function applies the newest effective target
/// on its next run (weekdays 22:05 UTC), rebalances at that day's closes,
/// logs the position change, and notifies followers.
struct PortfolioTargetsAdminView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var portfolios: [ModelPortfolio] = []
    @State private var selectedPortfolio: ModelPortfolio?
    @State private var weights: [TickerWeight] = []
    @State private var rationale = ""
    @State private var effectiveDate = Date()
    @State private var newTicker = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    struct TickerWeight: Identifiable {
        let id = UUID()
        var ticker: String
        var pct: Double
    }

    private var totalPct: Double {
        weights.reduce(0) { $0 + $1.pct }
    }

    private var isValid: Bool {
        abs(totalPct - 100) < 0.01 && !weights.isEmpty && weights.allSatisfy { $0.pct >= 0 }
    }

    /// Close a position: move its entire weight into CASH so the target stays at
    /// 100%. Posting the new target logs this as a "sold" position change.
    private func exitPosition(_ ticker: String) {
        guard let idx = weights.firstIndex(where: { $0.ticker == ticker }) else { return }
        let freed = weights[idx].pct
        weights.remove(at: idx)
        if let cashIdx = weights.firstIndex(where: { $0.ticker == "CASH" }) {
            weights[cashIdx].pct += freed
        } else {
            weights.append(TickerWeight(ticker: "CASH", pct: freed))
        }
        Haptics.selection()
    }

    var body: some View {
        List {
            // Portfolio picker
            Section {
                Picker("Portfolio", selection: $selectedPortfolio) {
                    Text("Select…").tag(ModelPortfolio?.none)
                    ForEach(portfolios) { p in
                        Text(p.name).tag(Optional(p))
                    }
                }
                .onChange(of: selectedPortfolio) { _, portfolio in
                    if let portfolio { Task { await loadCurrentTarget(portfolio) } }
                }
            } header: {
                Text("Equity Portfolio")
            } footer: {
                Text("Applied on the next market close after the effective date. Followers get a position-change notification.")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            if selectedPortfolio != nil {
                // Allocations
                Section {
                    ForEach($weights) { $w in
                        HStack {
                            Text(w.ticker)
                                .font(AppFonts.body14Medium)
                                .frame(width: 64, alignment: .leading)
                            Slider(value: $w.pct, in: 0...50, step: 0.5)
                            TextField("0", value: $w.pct, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 52)
                            Text("%")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                weights.removeAll { $0.id == w.id }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            // Exit closes the position by moving its whole weight
                            // into CASH, so the target stays balanced at 100%.
                            if w.ticker != "CASH" {
                                Button {
                                    exitPosition(w.ticker)
                                } label: {
                                    Label("Exit → Cash", systemImage: "arrow.uturn.backward")
                                }
                                .tint(AppColors.accent)
                            }
                        }
                    }

                    HStack {
                        TextField("Add ticker (e.g. AAPL)", text: $newTicker)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        Button("Add") {
                            let t = newTicker.trimmingCharacters(in: .whitespaces).uppercased()
                            guard !t.isEmpty, !weights.contains(where: { $0.ticker == t }) else { return }
                            weights.append(TickerWeight(ticker: t, pct: 0))
                            newTicker = ""
                        }
                        .disabled(newTicker.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    HStack {
                        Text("Total")
                            .font(AppFonts.body14Medium)
                        Spacer()
                        Text(String(format: "%.1f%%", totalPct))
                            .font(AppFonts.body14Bold)
                            .foregroundColor(abs(totalPct - 100) < 0.01 ? AppColors.success : AppColors.error)
                    }
                } header: {
                    Text("Target Allocation")
                } footer: {
                    Text("Must total 100%. CASH is the reserve sleeve. Swipe a position left to Exit it (moves its weight to CASH) or Remove it.")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Rationale + date
                Section {
                    TextField("Why this change? (shown in the position-change log)", text: $rationale, axis: .vertical)
                        .lineLimit(2...5)
                    DatePicker("Effective date", selection: $effectiveDate, displayedComponents: .date)
                } header: {
                    Text("Rationale")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Submit
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Post Position Change")
                                    .font(AppFonts.body14Bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSubmitting)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(AppFonts.caption12)
                            .foregroundColor(statusIsError ? AppColors.error : AppColors.success)
                    }
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background(colorScheme))
        // The app's floating tab bar is a bottom overlay that doesn't inset
        // content, so the last List row (the "Post Position Change" button) was
        // hidden underneath it. Reserve space so the button clears the tab bar.
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 88)
        }
        .navigationTitle("Portfolio Positions")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadPortfolios() }
        .overlay {
            if isLoading { ProgressView() }
        }
    }

    // MARK: - Data

    private func loadPortfolios() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await ServiceContainer.shared.modelPortfolioService.fetchPortfolios()
            // Only stock portfolios are curated; crypto is systematic
            portfolios = all.filter { $0.isStock }
        } catch {
            statusMessage = "Failed to load portfolios: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private struct TargetRow: Codable {
        let allocations: [String: Double]
        let rationale: String?
        let effective_date: String
    }

    private func loadCurrentTarget(_ portfolio: ModelPortfolio) async {
        isLoading = true
        defer { isLoading = false }
        statusMessage = nil
        do {
            let rows: [TargetRow] = try await SupabaseManager.shared.database
                .from("model_portfolio_targets")
                .select("allocations, rationale, effective_date")
                .eq("portfolio_id", value: portfolio.id.uuidString)
                .order("effective_date", ascending: false)
                .limit(1)
                .execute()
                .value
            if let latest = rows.first {
                weights = latest.allocations
                    .map { TickerWeight(ticker: $0.key, pct: $0.value * 100) }
                    .sorted { $0.pct > $1.pct }
            } else {
                weights = []
            }
            rationale = ""
        } catch {
            statusMessage = "Failed to load current target: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private struct NewTarget: Encodable {
        let portfolio_id: String
        let effective_date: String
        let allocations: [String: Double]
        let rationale: String?
    }

    private func submit() async {
        guard let portfolio = selectedPortfolio, isValid else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        var allocations: [String: Double] = [:]
        for w in weights where w.pct > 0 {
            allocations[w.ticker] = (w.pct / 100 * 10000).rounded() / 10000
        }

        do {
            try await SupabaseManager.shared.database
                .from("model_portfolio_targets")
                .upsert(NewTarget(
                    portfolio_id: portfolio.id.uuidString,
                    effective_date: formatter.string(from: effectiveDate),
                    allocations: allocations,
                    rationale: rationale.isEmpty ? nil : rationale
                ), onConflict: "portfolio_id,effective_date")
                .execute()
            statusMessage = "Posted. Applies at the next market close on/after \(formatter.string(from: effectiveDate))."
            statusIsError = false
            Haptics.success()
        } catch {
            statusMessage = "Failed to post: \(error.localizedDescription)"
            statusIsError = true
        }
    }
}
