import SwiftUI

/// Bridge view for the Portfolio DCA tab.
/// Shows the DCA Tracker dashboard if the user has an active plan,
/// otherwise falls back to the DCA Calculator wizard.
struct DCAPortfolioTabView: View {
    @Bindable var portfolioViewModel: PortfolioViewModel
    @State private var trackerViewModel = DCATrackerViewModel()
    @State private var hasLoaded = false
    @State private var showCreatePlan = false

    var body: some View {
        Group {
            if !hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if trackerViewModel.selectedPlan != nil {
                // Has an active plan — show tracker dashboard
                DCATrackerView(viewModel: trackerViewModel)
            } else if !trackerViewModel.plans.isEmpty {
                // Has plans but none selected — show plan list
                planListView
            } else {
                // No plans — show create plan prompt
                ScrollView {
                    VStack(spacing: ArkSpacing.xl) {
                        Spacer().frame(height: ArkSpacing.xxxl)

                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(AppColors.accent.opacity(0.3))

                        VStack(spacing: ArkSpacing.sm) {
                            Text("Start a DCA Plan")
                                .font(AppFonts.title20)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Text("Set a target allocation, track your buys, monitor P&L, and build a streak — all in one place.")
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        Button { showCreatePlan = true } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Create DCA Plan")
                            }
                            .font(AppFonts.body14Bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ArkSpacing.md)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
                        }
                        .padding(.horizontal, 20)

                        Spacer()
                    }
                }
            }
        }
        .task {
            await trackerViewModel.loadPlans()
            // Auto-select first active plan
            if trackerViewModel.selectedPlan == nil,
               let firstActive = trackerViewModel.plans.first(where: { $0.isActive }) {
                trackerViewModel.selectedPlan = firstActive
                await trackerViewModel.loadEntries(planId: firstActive.id)
                await trackerViewModel.fetchLivePrice(symbol: firstActive.assetSymbol)
            }
            hasLoaded = true
        }
        .sheet(isPresented: $showCreatePlan) {
            NavigationStack {
                CreateDCAPlanSheet(viewModel: trackerViewModel)
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    private var createPlanBanner: some View {
        Button { showCreatePlan = true } label: {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a DCA Plan")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("Track allocation, P&L, and streaks")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.accent)
            }
            .padding(ArkSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.accent.opacity(colorScheme == .dark ? 0.1 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.vertical, ArkSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var planListView: some View {
        ScrollView {
            VStack(spacing: ArkSpacing.md) {
                ForEach(trackerViewModel.plans) { plan in
                    Button {
                        trackerViewModel.selectedPlan = plan
                        Task {
                            await trackerViewModel.loadEntries(planId: plan.id)
                            await trackerViewModel.fetchLivePrice(symbol: plan.assetSymbol)
                        }
                    } label: {
                        HStack(spacing: ArkSpacing.sm) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(plan.assetSymbol) DCA Plan")
                                    .font(AppFonts.body14Bold)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Text("\(plan.totalWeeks) weeks · \(plan.frequency)")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(plan.status.capitalized)
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(plan.isActive ? AppColors.success : AppColors.textSecondary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        }
                        .padding(ArkSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.cardBackground(colorScheme))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button { showCreatePlan = true } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("New DCA Plan")
                    }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, ArkSpacing.md)
        }
    }
}
