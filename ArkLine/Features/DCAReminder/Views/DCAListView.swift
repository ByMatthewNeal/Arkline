import SwiftUI

// MARK: - DCA List View
struct DCAListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = DCAViewModel()
    @State private var showCreateSheet = false
    @State private var showPaywall = false
    @State private var showCompleted = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Upcoming section
                    let upcoming = viewModel.activeReminders.sorted {
                        ($0.nextReminderDate ?? .distantFuture) < ($1.nextReminderDate ?? .distantFuture)
                    }

                    if !upcoming.isEmpty {
                        sectionHeader("Upcoming", count: upcoming.count)

                        ForEach(upcoming) { reminder in
                            DCAUnifiedCard(
                                reminder: reminder,
                                riskLevel: viewModel.riskLevel(for: reminder.symbol),
                                onEdit: { viewModel.editingReminder = reminder },
                                onMarkInvested: {
                                    Task { await viewModel.markAsInvested(reminder) }
                                }
                            )
                        }
                    }

                    // Completed section
                    let completed = viewModel.completedReminders
                    if !completed.isEmpty {
                        Button {
                            withAnimation(.arkSpring) { showCompleted.toggle() }
                        } label: {
                            HStack {
                                Text("Completed")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(textPrimary.opacity(0.6))

                                Text("\(completed.count)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(textPrimary.opacity(0.4))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E8E8EA"))
                                    )

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textPrimary.opacity(0.3))
                                    .rotationEffect(.degrees(showCompleted ? 90 : 0))
                            }
                            .padding(.top, 8)
                        }
                        .buttonStyle(.plain)

                        if showCompleted {
                            ForEach(completed) { reminder in
                                DCAUnifiedCard(
                                    reminder: reminder,
                                    riskLevel: viewModel.riskLevel(for: reminder.symbol),
                                    onEdit: { viewModel.editingReminder = reminder }
                                )
                                .opacity(0.7)
                            }
                        }
                    }

                    // Loading state
                    if viewModel.isLoading && viewModel.reminders.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(AppColors.accent)
                            Text("Loading reminders...")
                                .font(.system(size: 14))
                                .foregroundColor(textPrimary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    // Empty state (only show after loading completes)
                    if !viewModel.isLoading && viewModel.reminders.isEmpty && viewModel.riskBasedReminders.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No DCA Reminders",
                            message: "Create your first DCA reminder to start building your investment strategy",
                            actionTitle: "Create Reminder",
                            action: { showCreateSheet = true }
                        )
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .navigationTitle("DCA Reminders")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if !appState.isPro && viewModel.reminders.count >= 3 {
                        showPaywall = true
                    } else {
                        showCreateSheet = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "EAEAEA"))
                            .frame(width: 36, height: 36)

                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
            }
        }
        #endif
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .unlimitedDCA)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateDCASheetView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.editingReminder) { reminder in
            EditDCASheetView(reminder: reminder, viewModel: viewModel)
        }
        .onAppear {
            Task { await viewModel.refresh() }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.6))

            Text("\(count)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "E8E8EA"))
                )

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        DCAListView()
    }
}
