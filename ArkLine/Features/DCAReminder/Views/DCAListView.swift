import SwiftUI

// MARK: - DCA List View
struct DCAListView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = DCAViewModel()
    @State private var showCreateSheet = false
    @State private var showPaywall = false

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
                    // All reminders (unified list)
                    ForEach(viewModel.reminders) { reminder in
                        DCAUnifiedCard(
                            reminder: reminder,
                            riskLevel: viewModel.riskLevel(for: reminder.symbol),
                            onEdit: { viewModel.editingReminder = reminder },
                            onViewHistory: { viewModel.selectedReminder = reminder }
                        )
                    }

                    // Empty state
                    if viewModel.reminders.isEmpty && viewModel.riskBasedReminders.isEmpty {
                        EmptyDCAState(onCreateTap: { showCreateSheet = true })
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
        .sheet(item: $viewModel.selectedReminder) { reminder in
            InvestmentHistorySheetView(reminder: reminder, viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        DCAListView()
    }
}
