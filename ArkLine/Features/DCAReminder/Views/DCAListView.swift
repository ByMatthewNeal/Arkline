import SwiftUI

struct DCAListView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = DCAViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's Reminders
                    if !viewModel.todayReminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today")
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ForEach(viewModel.todayReminders) { reminder in
                                    DCACardToday(
                                        reminder: reminder,
                                        onInvest: { Task { await viewModel.markAsInvested(reminder) } },
                                        onSkip: { Task { await viewModel.skipReminder(reminder) } }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Active Reminders
                    if !viewModel.activeReminders.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Reminders")
                                .font(AppFonts.title18SemiBold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .padding(.horizontal, 20)

                            VStack(spacing: 12) {
                                ForEach(viewModel.activeReminders) { reminder in
                                    NavigationLink(destination: DCADetailView(reminder: reminder, viewModel: viewModel)) {
                                        DCACard(reminder: reminder)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("DCA Reminders")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showCreateSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $viewModel.showCreateSheet) {
                CreateDCAView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - DCA Card (Standard)
struct DCACard: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: DCAReminder

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            CoinIconView(symbol: reminder.symbol, size: 44)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.name)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(reminder.amount.asCurrency) • \(reminder.frequency.displayName)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Progress
            VStack(alignment: .trailing, spacing: 4) {
                if let nextDate = reminder.nextReminderDate {
                    Text(nextDate.displayDate)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("\(reminder.completedPurchases)/\(reminder.totalPurchases ?? 0)")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - DCA Card (Today)
struct DCACardToday: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: DCAReminder
    let onInvest: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                CoinIconView(symbol: reminder.symbol, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(reminder.name)
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("Today")
                            .font(AppFonts.footnote10Bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accent)
                            .cornerRadius(8)
                    }

                    Text("Investment amount: \(reminder.amount.asCurrency)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.error, lineWidth: 1)
                        )
                }

                Button(action: onInvest) {
                    Text("Mark as Invested")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - DCA Detail View
struct DCADetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: DCAReminder
    @Bindable var viewModel: DCAViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    CoinIconView(symbol: reminder.symbol, size: 64)

                    Text(reminder.name)
                        .font(AppFonts.title24)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("\(reminder.amount.asCurrency) • \(reminder.frequency.displayName)")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 20)

                // Progress Card
                VStack(spacing: 16) {
                    HStack {
                        Text("Progress")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Spacer()
                        Text("\(reminder.completedPurchases)/\(reminder.totalPurchases ?? 0)")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(AppColors.accent)
                    }

                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.divider(colorScheme))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.accent)
                                .frame(width: geometry.size.width * reminder.progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Invested")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                            Text(reminder.totalInvested.asCurrency)
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Next Purchase")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                            if let nextDate = reminder.nextReminderDate {
                                Text(nextDate.displayDate)
                                    .font(AppFonts.body14Bold)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                            }
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)

                // Actions
                VStack(spacing: 12) {
                    Button(action: { Task { await viewModel.toggleReminder(reminder) } }) {
                        HStack {
                            Image(systemName: reminder.isActive ? "pause.fill" : "play.fill")
                            Text(reminder.isActive ? "Pause Reminder" : "Resume Reminder")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                    }

                    Button(action: { Task { await viewModel.deleteReminder(reminder) } }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Reminder")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.error, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("DCA Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Create DCA View
struct CreateDCAView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var symbol = ""
    @State private var name = ""
    @State private var amount: Double = 100
    @State private var frequency: DCAFrequency = .weekly
    @State private var totalPurchases: Int? = nil
    @State private var notificationTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Symbol (e.g., BTC)", text: $symbol)
                    TextField("Name (e.g., Bitcoin)", text: $name)
                }

                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("100", value: $amount, format: .currency(code: "USD"))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(DCAFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }

                    DatePicker("Notification Time", selection: $notificationTime, displayedComponents: .hourAndMinute)
                }

                Section {
                    Stepper("Total Purchases: \(totalPurchases ?? 0)", value: Binding(
                        get: { totalPurchases ?? 0 },
                        set: { totalPurchases = $0 == 0 ? nil : $0 }
                    ), in: 0...520)
                } footer: {
                    Text("Leave at 0 for unlimited purchases")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("New DCA Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createReminder()
                        dismiss()
                    }
                    .disabled(symbol.isEmpty || name.isEmpty)
                }
            }
            #endif
        }
    }

    private func createReminder() {
        let reminder = DCAReminder(
            userId: UUID(),
            symbol: symbol.uppercased(),
            name: name,
            amount: amount,
            frequency: frequency,
            totalPurchases: totalPurchases,
            completedPurchases: 0,
            notificationTime: notificationTime,
            startDate: Date(),
            nextReminderDate: Date(),
            isActive: true
        )
        Task { await viewModel.createReminder(reminder) }
    }
}

#Preview {
    DCAListView()
}
