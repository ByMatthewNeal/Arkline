import SwiftUI

struct DCAListView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = DCAViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                DCATabSelector(selectedTab: $viewModel.selectedTab, colorScheme: colorScheme)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        switch viewModel.selectedTab {
                        case .timeBased:
                            timeBasedContent
                        case .riskBased:
                            riskBasedContent
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("DCA Reminders")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if viewModel.selectedTab == .timeBased {
                            viewModel.showCreateSheet = true
                        } else {
                            viewModel.showCreateRiskBasedSheet = true
                        }
                    }) {
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
            .sheet(isPresented: $viewModel.showCreateRiskBasedSheet) {
                CreateRiskBasedDCAView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Time-Based Content

    @ViewBuilder
    private var timeBasedContent: some View {
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

        // Empty State
        if viewModel.todayReminders.isEmpty && viewModel.activeReminders.isEmpty {
            emptyStateView(
                icon: "calendar.badge.clock",
                title: "No Time-Based Reminders",
                subtitle: "Create a recurring DCA reminder to invest on a schedule"
            )
        }
    }

    // MARK: - Risk-Based Content

    @ViewBuilder
    private var riskBasedContent: some View {
        // Triggered Reminders (Action Required)
        if !viewModel.triggeredReminders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Action Required")
                        .font(AppFonts.title18SemiBold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    Text("\(viewModel.triggeredReminders.count)")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.error)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(viewModel.triggeredReminders) { reminder in
                        RiskBasedDCACardTriggered(
                            reminder: reminder,
                            riskLevel: viewModel.riskLevel(for: reminder.symbol),
                            onInvest: { Task { await viewModel.markRiskBasedAsInvested(reminder) } },
                            onDismiss: { Task { await viewModel.dismissRiskTrigger(reminder) } }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // Active Risk-Based Reminders
        if !viewModel.pendingRiskReminders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Monitoring")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    ForEach(viewModel.pendingRiskReminders) { reminder in
                        NavigationLink(destination: RiskBasedDCADetailView(reminder: reminder, viewModel: viewModel)) {
                            RiskBasedDCACard(
                                reminder: reminder,
                                riskLevel: viewModel.riskLevel(for: reminder.symbol)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        // Empty State
        if viewModel.triggeredReminders.isEmpty && viewModel.pendingRiskReminders.isEmpty {
            emptyStateView(
                icon: "chart.line.downtrend.xyaxis",
                title: "No Risk-Based Reminders",
                subtitle: "Create a risk-based DCA rule to invest when risk levels change"
            )
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)

            Text(title)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(subtitle)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tab Selector

struct DCATabSelector: View {
    @Binding var selectedTab: DCAViewTab
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DCAViewTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(selectedTab == tab ? AppColors.accent : AppColors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? AppColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 8)
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

// MARK: - Risk-Based DCA Card (Standard)

struct RiskBasedDCACard: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: RiskBasedDCAReminder
    let riskLevel: AssetRiskLevel?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            CoinIconView(symbol: reminder.symbol, size: 44)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(reminder.name)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Risk")
                        .font(AppFonts.footnote10Bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.warning)
                        .cornerRadius(4)
                }

                Text(reminder.triggerDescription)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Current Risk Level
            if let riskLevel = riskLevel {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Current Risk")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)

                    RiskLevelBadge(riskLevel: riskLevel)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Risk-Based DCA Card (Triggered)

struct RiskBasedDCACardTriggered: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: RiskBasedDCAReminder
    let riskLevel: AssetRiskLevel?
    let onInvest: () -> Void
    let onDismiss: () -> Void

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

                        Text("Triggered")
                            .font(AppFonts.footnote10Bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.error)
                            .cornerRadius(8)
                    }

                    if let triggeredLevel = reminder.lastTriggeredRiskLevel {
                        Text("Risk level reached \(Int(triggeredLevel))%")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Investment Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Amount")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                    Text(reminder.formattedAmount)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.accent)
                }
            }

            // Risk Info
            if let riskLevel = riskLevel {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger Condition")
                            .font(AppFonts.footnote10)
                            .foregroundColor(AppColors.textSecondary)
                        Text(reminder.triggerDescription)
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Risk")
                            .font(AppFonts.footnote10)
                            .foregroundColor(AppColors.textSecondary)
                        RiskLevelBadge(riskLevel: riskLevel)
                    }
                }
                .padding(12)
                .background(AppColors.divider(colorScheme).opacity(0.5))
                .cornerRadius(8)
            }

            // Actions
            HStack(spacing: 12) {
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.divider(colorScheme), lineWidth: 1)
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

// MARK: - Risk Level Badge

struct RiskLevelBadge: View {
    let riskLevel: AssetRiskLevel

    var backgroundColor: Color {
        switch riskLevel.riskCategory {
        case .veryLow, .low:
            return AppColors.success.opacity(0.15)
        case .moderate:
            return AppColors.warning.opacity(0.15)
        case .high, .veryHigh:
            return AppColors.error.opacity(0.15)
        }
    }

    var textColor: Color {
        switch riskLevel.riskCategory {
        case .veryLow, .low:
            return AppColors.success
        case .moderate:
            return AppColors.warning
        case .high, .veryHigh:
            return AppColors.error
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(textColor)
                .frame(width: 6, height: 6)

            Text("\(riskLevel.formattedScore)%")
                .font(AppFonts.caption12Medium)
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Risk-Based DCA Detail View

struct RiskBasedDCADetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let reminder: RiskBasedDCAReminder
    @Bindable var viewModel: DCAViewModel
    @State private var investmentHistory: [RiskDCAInvestment] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    CoinIconView(symbol: reminder.symbol, size: 64)

                    HStack(spacing: 8) {
                        Text(reminder.name)
                            .font(AppFonts.title24)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("Risk-Based")
                            .font(AppFonts.footnote10Bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.warning)
                            .cornerRadius(8)
                    }

                    Text(reminder.triggerDescription)
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 20)

                // Risk Status Card
                VStack(spacing: 16) {
                    HStack {
                        Text("Risk Status")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Spacer()
                        if reminder.isTriggered {
                            Text("TRIGGERED")
                                .font(AppFonts.footnote10Bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.error)
                                .cornerRadius(8)
                        } else {
                            Text("MONITORING")
                                .font(AppFonts.footnote10Bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppColors.success)
                                .cornerRadius(8)
                        }
                    }

                    // Risk Gauge
                    if let riskLevel = viewModel.riskLevel(for: reminder.symbol) {
                        RiskGaugeView(
                            currentRisk: riskLevel.riskScore,
                            threshold: reminder.riskThreshold,
                            condition: reminder.riskCondition
                        )
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Investment Amount")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                            Text(reminder.formattedAmount)
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Threshold")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(Int(reminder.riskThreshold))% (\(reminder.riskCondition.displayName))")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
                .padding(.horizontal, 20)

                // Investment History
                if !investmentHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Investment History")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            ForEach(investmentHistory) { investment in
                                RiskInvestmentRow(investment: investment)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Actions
                VStack(spacing: 12) {
                    Button(action: { Task { await viewModel.toggleRiskBasedReminder(reminder) } }) {
                        HStack {
                            Image(systemName: reminder.isActive ? "pause.fill" : "play.fill")
                            Text(reminder.isActive ? "Pause Monitoring" : "Resume Monitoring")
                        }
                        .font(AppFonts.body14Medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                    }

                    Button(action: { Task { await viewModel.deleteRiskBasedReminder(reminder) } }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Rule")
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
        .navigationTitle("Risk DCA Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            investmentHistory = await viewModel.fetchRiskBasedInvestmentHistory(reminderId: reminder.id)
        }
    }
}

// MARK: - Risk Gauge View

struct RiskGaugeView: View {
    let currentRisk: Double
    let threshold: Double
    let condition: RiskCondition

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.success, AppColors.warning, AppColors.error],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 12)
                        .opacity(0.3)

                    // Threshold Marker
                    Rectangle()
                        .fill(AppColors.textSecondary)
                        .frame(width: 2, height: 20)
                        .offset(x: geometry.size.width * (threshold / 100))

                    // Current Risk Indicator
                    Circle()
                        .fill(riskColor)
                        .frame(width: 16, height: 16)
                        .offset(x: geometry.size.width * (currentRisk / 100) - 8)
                }
            }
            .frame(height: 20)

            // Labels
            HStack {
                Text("0%")
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Current: \(Int(currentRisk))%")
                    .font(AppFonts.footnote10Bold)
                    .foregroundColor(riskColor)
                Spacer()
                Text("100%")
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    var riskColor: Color {
        let category = RiskCategory.from(score: currentRisk)
        switch category {
        case .veryLow, .low: return AppColors.success
        case .moderate: return AppColors.warning
        case .high, .veryHigh: return AppColors.error
        }
    }
}

// MARK: - Risk Investment Row

struct RiskInvestmentRow: View {
    @Environment(\.colorScheme) var colorScheme
    let investment: RiskDCAInvestment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.purchaseDate.displayDate)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Risk at \(investment.formattedRiskLevel)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.formattedAmount)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.accent)

                Text("@ \(investment.priceAtPurchase.asCryptoPrice)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 8)
    }
}

// MARK: - Create Risk-Based DCA View

struct CreateRiskBasedDCAView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var symbol = ""
    @State private var name = ""
    @State private var amount: Double = 100
    @State private var riskThreshold: Double = 50
    @State private var riskCondition: RiskCondition = .below
    @State private var currentRiskLevel: AssetRiskLevel?
    @State private var isLoadingRisk = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Symbol (e.g., BTC)", text: $symbol)
                        .onChange(of: symbol) { _, newValue in
                            if newValue.count >= 2 {
                                fetchRiskLevel()
                            }
                        }
                    TextField("Name (e.g., Bitcoin)", text: $name)
                } header: {
                    Text("Asset")
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
                } header: {
                    Text("Investment")
                }

                Section {
                    Picker("Trigger When Risk", selection: $riskCondition) {
                        ForEach(RiskCondition.allCases, id: \.self) { condition in
                            Text(condition.description).tag(condition)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Risk Threshold")
                            Spacer()
                            Text("\(Int(riskThreshold))%")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.accent)
                        }

                        Slider(value: $riskThreshold, in: 0...100, step: 5)
                            .tint(AppColors.accent)
                    }

                    if let risk = currentRiskLevel {
                        HStack {
                            Text("Current Risk Level")
                            Spacer()
                            RiskLevelBadge(riskLevel: risk)
                        }
                    } else if isLoadingRisk {
                        HStack {
                            Text("Fetching Risk Level")
                            Spacer()
                            ProgressView()
                        }
                    }
                } header: {
                    Text("Risk Trigger")
                } footer: {
                    Text("You'll be notified when \(symbol.isEmpty ? "the asset" : symbol.uppercased()) risk \(riskCondition == .above ? "rises above" : "falls below") \(Int(riskThreshold))%")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("New Risk-Based DCA")
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

    private func fetchRiskLevel() {
        guard !symbol.isEmpty else { return }
        isLoadingRisk = true

        Task {
            let level = await viewModel.fetchRiskLevel(for: symbol)
            await MainActor.run {
                currentRiskLevel = level
                isLoadingRisk = false
            }
        }
    }

    private func createReminder() {
        Task {
            await viewModel.createRiskBasedReminder(
                symbol: symbol,
                name: name,
                amount: amount,
                riskThreshold: riskThreshold,
                riskCondition: riskCondition
            )
        }
    }
}

#Preview {
    DCAListView()
}
