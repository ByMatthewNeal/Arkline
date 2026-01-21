import SwiftUI

// MARK: - DCA List View
struct DCAListView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var viewModel = DCAViewModel()
    @State private var showCreateSheet = false

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
                Button(action: { showCreateSheet = true }) {
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

// MARK: - Empty State
struct EmptyDCAState: View {
    let onCreateTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundColor(AppColors.accent.opacity(0.6))

            VStack(spacing: 8) {
                Text("No DCA Reminders")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("Create your first DCA reminder to start\nbuilding your investment strategy")
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button(action: onCreateTap) {
                Text("Create Reminder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(AppColors.accent)
                    .cornerRadius(12)
            }
        }
        .padding(40)
    }
}

// MARK: - Unified DCA Card
struct DCAUnifiedCard: View {
    let reminder: DCAReminder
    let riskLevel: AssetRiskLevel?
    let onEdit: () -> Void
    let onViewHistory: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with coin icon and info
            HStack(spacing: 14) {
                // Coin icon
                DCACoinIconView(symbol: reminder.symbol, size: 48)

                // Title and details
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reminder.symbol) DCA Reminder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)

                    // Subtitle: "$1000 • Tue, Fri • <0.5 Risk Level"
                    HStack(spacing: 4) {
                        Text(reminder.amount.asCurrency)
                            .foregroundColor(textPrimary.opacity(0.6))

                        Text("•")
                            .foregroundColor(textPrimary.opacity(0.4))

                        Text(reminder.frequency.shortDisplayName)
                            .foregroundColor(textPrimary.opacity(0.6))

                        if let risk = riskLevel {
                            Text("•")
                                .foregroundColor(textPrimary.opacity(0.4))

                            Text("<\(String(format: "%.1f", risk.riskScore / 100)) Risk")
                                .foregroundColor(riskColorFor(risk.riskCategory))
                        }
                    }
                    .font(.system(size: 14))
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                // Edit Reminder button
                Button(action: onEdit) {
                    Text("Edit Reminder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                        )
                }

                // View History button
                Button(action: onViewHistory) {
                    Text("View History")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.accent.opacity(0.15))
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func riskColorFor(_ category: RiskCategory) -> Color {
        switch category {
        case .veryLow, .low: return AppColors.success
        case .moderate: return AppColors.warning
        case .high, .veryHigh: return AppColors.error
        }
    }
}

// MARK: - DCA Coin Icon View
struct DCACoinIconView: View {
    let symbol: String
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(coinColor.opacity(0.15))
                .frame(width: size, height: size)

            if let iconName = coinSystemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(coinColor)
            } else {
                Text(String(symbol.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(coinColor)
            }
        }
    }

    private var coinColor: Color {
        switch symbol.uppercased() {
        case "BTC": return Color(hex: "F7931A")
        case "ETH": return Color(hex: "627EEA")
        case "SOL": return Color(hex: "00FFA3")
        case "ADA": return Color(hex: "0033AD")
        case "DOT": return Color(hex: "E6007A")
        case "AVAX": return Color(hex: "E84142")
        case "LINK": return Color(hex: "2A5ADA")
        case "DOGE": return Color(hex: "C2A633")
        case "XRP": return Color(hex: "23292F")
        case "SHIB": return Color(hex: "F4A422")
        default: return AppColors.accent
        }
    }

    private var coinSystemIcon: String? {
        switch symbol.uppercased() {
        case "BTC": return "bitcoinsign"
        case "ETH": return "diamond.fill"
        default: return nil
        }
    }
}

// MARK: - Create DCA Sheet
struct CreateDCASheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var selectedCoin: CoinOption?
    @State private var showCoinPicker = false
    @State private var amount: String = "1000"
    @State private var attachRiskLevel = false
    @State private var riskThreshold: Double = 0.5
    @State private var selectedFrequency: DCAFrequencyOption = .daily
    @State private var customInterval: Int = 1
    @State private var customPeriod: CustomPeriod = .month
    @State private var selectedDays: Set<Int> = [1]
    @State private var notificationTime = Date()

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sectionBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Coin selection
                        if let coin = selectedCoin {
                            coinSelectedSection(coin)
                        } else {
                            coinSelectionButton
                        }

                        if selectedCoin != nil {
                            // Purchase Amount
                            purchaseAmountSection

                            // Risk Level
                            riskLevelSection

                            // Frequency
                            frequencySection

                            // Notification Time
                            notificationTimeSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(selectedCoin != nil ? "\(selectedCoin!.symbol) DCA Reminder" : "New Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            #endif
            .safeAreaInset(edge: .bottom) {
                if selectedCoin != nil {
                    bottomButtons
                }
            }
            .sheet(isPresented: $showCoinPicker) {
                CoinPickerView(selectedCoin: $selectedCoin, viewModel: viewModel)
            }
        }
    }

    // MARK: - Sections

    private var coinSelectionButton: some View {
        Button(action: { showCoinPicker = true }) {
            HStack {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Coin")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text("Select a cryptocurrency to set up DCA")
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(sectionBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private func coinSelectedSection(_ coin: CoinOption) -> some View {
        Button(action: { showCoinPicker = true }) {
            HStack {
                DCACoinIconView(symbol: coin.symbol, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(coin.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(coin.symbol)
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Spacer()

                Text("Change")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(sectionBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseAmountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Purchase Amount")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Enter amount of money you want to invest")
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.6))

            HStack {
                Text("$")
                    .font(.system(size: 17))
                    .foregroundColor(textPrimary.opacity(0.6))

                TextField("1000", text: $amount)
                    .font(.system(size: 17))
                    .foregroundColor(textPrimary)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var riskLevelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Risk Level")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text("Attach the risk level to your reminder")
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $attachRiskLevel)
                    .labelsHidden()
                    .tint(AppColors.accent)
            }

            if attachRiskLevel {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Trigger when risk below")
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary.opacity(0.7))

                        Spacer()

                        Text(String(format: "%.1f", riskThreshold))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }

                    Slider(value: $riskThreshold, in: 0...1, step: 0.1)
                        .tint(AppColors.accent)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequency")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Select a frequency for this DCA reminder")
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.6))

            // Frequency picker
            Menu {
                ForEach(DCAFrequencyOption.allCases, id: \.self) { option in
                    Button(action: { selectedFrequency = option }) {
                        HStack {
                            Text(option.displayName)
                            if selectedFrequency == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedFrequency.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
            }

            // Custom settings
            if selectedFrequency == .custom {
                customFrequencySettings
            }

            // Description
            Text(frequencyDescription)
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent)
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var customFrequencySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
                .padding(.top, 8)

            // Every X Day/Week/Month
            HStack(spacing: 12) {
                Text("Every")
                    .font(.system(size: 15))
                    .foregroundColor(textPrimary)

                Menu {
                    ForEach(1...12, id: \.self) { num in
                        Button(action: { customInterval = num }) {
                            Text("\(num)")
                        }
                    }
                } label: {
                    HStack {
                        Text("\(customInterval)")
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                    )
                }

                Menu {
                    ForEach(CustomPeriod.allCases, id: \.self) { period in
                        Button(action: { customPeriod = period }) {
                            Text(period.displayName)
                        }
                    }
                } label: {
                    HStack {
                        Text(customPeriod.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                    )
                }
            }

            // Day picker grid
            if customPeriod == .month {
                DayPickerGrid(selectedDays: $selectedDays)
            } else if customPeriod == .week {
                WeekDayPicker(selectedDays: $selectedDays)
            }
        }
    }

    private var notificationTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notification Time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Select a time to be notified")
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.6))

            DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                    )
            }

            Button(action: createReminder) {
                Text("Create Reminder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accent)
                    )
            }
            .disabled(selectedCoin == nil || amount.isEmpty)
            .opacity(selectedCoin == nil || amount.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }

    private var frequencyDescription: String {
        switch selectedFrequency {
        case .daily:
            return "You will receive a notification every day"
        case .weekly:
            return "You will receive a notification every week"
        case .monthly:
            return "You will receive a notification every month"
        case .custom:
            if customPeriod == .month {
                let dayText = selectedDays.sorted().map { ordinal($0) }.joined(separator: ", ")
                return "You will receive a notification every \(ordinal(customInterval)) month on \(dayText)"
            } else {
                return "You will receive a notification every \(customInterval) \(customPeriod.displayName.lowercased())"
            }
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    private func createReminder() {
        guard let coin = selectedCoin, let amountValue = Double(amount) else { return }

        let frequency: DCAFrequency = selectedFrequency.toDCAFrequency

        let reminder = DCAReminder(
            userId: UUID(),
            symbol: coin.symbol,
            name: coin.name,
            amount: amountValue,
            frequency: frequency,
            totalPurchases: nil,
            completedPurchases: 0,
            notificationTime: notificationTime,
            startDate: Date(),
            nextReminderDate: Date(),
            isActive: true
        )

        Task {
            await viewModel.createReminder(reminder)
        }

        dismiss()
    }
}

// MARK: - Day Picker Grid (for monthly)
struct DayPickerGrid: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.colorScheme) var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                Button(action: { toggleDay(day) }) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: selectedDays.contains(day) ? .semibold : .regular))
                        .foregroundColor(selectedDays.contains(day) ? .white : AppColors.textPrimary(colorScheme))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(day) ? AppColors.accent : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.textPrimary(colorScheme).opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - Week Day Picker
struct WeekDayPicker: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.colorScheme) var colorScheme

    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                Button(action: { toggleDay(index + 1) }) {
                    Text(day)
                        .font(.system(size: 12, weight: selectedDays.contains(index + 1) ? .semibold : .regular))
                        .foregroundColor(selectedDays.contains(index + 1) ? .white : AppColors.textPrimary(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDays.contains(index + 1) ? AppColors.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.textPrimary(colorScheme).opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - Coin Picker View
struct CoinPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedCoin: CoinOption?
    @Bindable var viewModel: DCAViewModel

    @State private var searchText = ""
    @State private var selectedCategory: DCAAssetCategory = .crypto

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var filteredCoins: [CoinOption] {
        let coins = CoinOption.cryptoCoins
        if searchText.isEmpty {
            return coins
        }
        return coins.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Category tabs
                    HStack(spacing: 8) {
                        ForEach(DCAAssetCategory.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Text(category.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedCategory == category ? .white : textPrimary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedCategory == category ? AppColors.accent : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(textPrimary.opacity(0.5))

                        TextField("Search", text: $searchText)
                            .font(.system(size: 16))
                            .foregroundColor(textPrimary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color.white)
                    )
                    .padding(.horizontal, 20)

                    // Risk level note
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.accent)

                        Text("Risk Level can be attached to your DCA Reminder")
                            .font(.system(size: 13))
                            .foregroundColor(textPrimary.opacity(0.6))

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Coin list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(filteredCoins) { coin in
                                CoinRowView(
                                    coin: coin,
                                    hasRiskData: coin.hasRiskData,
                                    onSelect: {
                                        selectedCoin = coin
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 16)
            }
            .navigationTitle("Choose Coin")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            #endif
        }
    }
}

struct CoinRowView: View {
    let coin: CoinOption
    let hasRiskData: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                DCACoinIconView(symbol: coin.symbol, size: 40)

                Text(coin.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textPrimary)

                Spacer()

                if hasRiskData {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }

        Divider()
            .padding(.leading, 70)
    }
}

// MARK: - Edit DCA Sheet
struct EditDCASheetView: View {
    let reminder: DCAReminder
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var amount: String
    @State private var selectedFrequency: DCAFrequencyOption
    @State private var customInterval: Int = 1
    @State private var customPeriod: CustomPeriod = .month
    @State private var selectedDays: Set<Int> = [1]
    @State private var notificationTime: Date
    @State private var isActive: Bool

    init(reminder: DCAReminder, viewModel: DCAViewModel) {
        self.reminder = reminder
        self.viewModel = viewModel
        _amount = State(initialValue: String(format: "%.0f", reminder.amount))
        _selectedFrequency = State(initialValue: DCAFrequencyOption.from(reminder.frequency))
        _notificationTime = State(initialValue: reminder.notificationTime)
        _isActive = State(initialValue: reminder.isActive)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sectionBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Frequency section
                        frequencySection

                        // Notification Time
                        notificationTimeSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Edit \(reminder.symbol) DCA Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: deleteReminder) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.error)
                    }
                }
            }
            #endif
            .safeAreaInset(edge: .bottom) {
                bottomButtons
            }
        }
    }

    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select a frequency for this DCA reminder")
                .font(.system(size: 14))
                .foregroundColor(textPrimary.opacity(0.6))

            Menu {
                ForEach(DCAFrequencyOption.allCases, id: \.self) { option in
                    Button(action: { selectedFrequency = option }) {
                        HStack {
                            Text(option.displayName)
                            if selectedFrequency == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedFrequency.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
            }

            if selectedFrequency == .custom {
                customFrequencySettings
            }

            Text(frequencyDescription)
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent)
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var customFrequencySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Settings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
                .padding(.top, 8)

            HStack(spacing: 12) {
                Text("Every")
                    .font(.system(size: 15))
                    .foregroundColor(textPrimary)

                Menu {
                    ForEach(1...12, id: \.self) { num in
                        Button(action: { customInterval = num }) {
                            Text("\(num)")
                        }
                    }
                } label: {
                    HStack {
                        Text("\(customInterval)")
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                    )
                }

                Menu {
                    ForEach(CustomPeriod.allCases, id: \.self) { period in
                        Button(action: { customPeriod = period }) {
                            Text(period.displayName)
                        }
                    }
                } label: {
                    HStack {
                        Text(customPeriod.displayName)
                            .font(.system(size: 15))
                            .foregroundColor(textPrimary)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                    )
                }
            }

            if customPeriod == .month {
                DayPickerGrid(selectedDays: $selectedDays)
            } else if customPeriod == .week {
                WeekDayPicker(selectedDays: $selectedDays)
            }
        }
    }

    private var notificationTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notification Time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Select a time to be notified")
                .font(.system(size: 13))
                .foregroundColor(textPrimary.opacity(0.6))

            DatePicker("", selection: $notificationTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionBackground)
        )
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: togglePause) {
                Text(isActive ? "Pause Reminder" : "Resume Reminder")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
                    )
            }

            Button(action: saveChanges) {
                Text("Save Changes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accent)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }

    private var frequencyDescription: String {
        switch selectedFrequency {
        case .daily:
            return "You will receive a notification every day"
        case .weekly:
            return "You will receive a notification every week"
        case .monthly:
            return "You will receive a notification every month"
        case .custom:
            if customPeriod == .month {
                let dayText = selectedDays.sorted().map { ordinal($0) }.joined(separator: ", ")
                return "You will receive a notification every \(ordinal(customInterval)) month on \(dayText)"
            } else {
                return "You will receive a notification every \(customInterval) \(customPeriod.displayName.lowercased())"
            }
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    private func togglePause() {
        isActive.toggle()
    }

    private func saveChanges() {
        var updated = reminder
        updated.isActive = isActive
        updated.notificationTime = notificationTime
        if let amountValue = Double(amount) {
            // Note: amount is not mutable in the current model, this would need model update
        }
        updated.frequency = selectedFrequency.toDCAFrequency

        Task {
            await viewModel.updateReminder(updated)
        }
        dismiss()
    }

    private func deleteReminder() {
        Task {
            await viewModel.deleteReminder(reminder)
        }
        dismiss()
    }
}

// MARK: - Investment History Sheet
struct InvestmentHistorySheetView: View {
    let reminder: DCAReminder
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: DCAViewModel

    @State private var investments: [DCAInvestment] = []
    @State private var isLoading = true

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(hex: "0F0F0F") : Color(hex: "F5F5F7"))
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if investments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(investments) { investment in
                                InvestmentHistoryRow(investment: investment, symbol: reminder.symbol)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Investment History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                }
            }
            #endif
            .task {
                // In a real app, fetch from service
                // For now, simulate with mock data
                try? await Task.sleep(nanoseconds: 500_000_000)
                isLoading = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(textPrimary.opacity(0.3))

            Text("No Investment History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(textPrimary)

            Text("Your investment history will appear here\nonce you start investing")
                .font(.system(size: 14))
                .foregroundColor(textPrimary.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

struct InvestmentHistoryRow: View {
    let investment: DCAInvestment
    let symbol: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            // Coin icon
            DCACoinIconView(symbol: symbol, size: 44)

            // Date and details
            VStack(alignment: .leading, spacing: 4) {
                Text(investment.purchaseDate.displayDate)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(textPrimary)

                Text("@ \(investment.priceAtPurchase.asCryptoPrice)")
                    .font(.system(size: 13))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                Text(investment.amount.asCurrency)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text("Invested")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.success.opacity(0.15))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Supporting Types

enum DCAFrequencyOption: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"

    var displayName: String { rawValue }

    var toDCAFrequency: DCAFrequency {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .custom: return .weekly // Default for custom
        }
    }

    static func from(_ frequency: DCAFrequency) -> DCAFrequencyOption {
        switch frequency {
        case .daily: return .daily
        case .weekly, .twiceWeekly, .biweekly: return .weekly
        case .monthly: return .monthly
        }
    }
}

enum CustomPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var displayName: String { rawValue }
}

enum DCAAssetCategory: String, CaseIterable {
    case crypto = "Crypto"
    case stocks = "Stocks"
    case commodities = "Commodities"

    var displayName: String { rawValue }
}

struct CoinOption: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let name: String
    let hasRiskData: Bool

    static let cryptoCoins: [CoinOption] = [
        CoinOption(symbol: "BTC", name: "Bitcoin", hasRiskData: true),
        CoinOption(symbol: "ETH", name: "Ethereum", hasRiskData: true),
        CoinOption(symbol: "ADA", name: "Cardano", hasRiskData: false),
        CoinOption(symbol: "DOT", name: "Polkadot", hasRiskData: false),
        CoinOption(symbol: "AVAX", name: "Avalanche", hasRiskData: false),
        CoinOption(symbol: "LINK", name: "Chainlink", hasRiskData: false),
        CoinOption(symbol: "SOL", name: "Solana", hasRiskData: true),
        CoinOption(symbol: "DOGE", name: "Dogecoin", hasRiskData: false),
        CoinOption(symbol: "TRX", name: "TRON", hasRiskData: false),
        CoinOption(symbol: "SHIB", name: "Shiba Inu", hasRiskData: false),
        CoinOption(symbol: "XRP", name: "XRP", hasRiskData: false),
    ]
}

// MARK: - DCA Frequency Extension
extension DCAFrequency {
    var shortDisplayName: String {
        switch self {
        case .daily: return "Daily"
        case .twiceWeekly: return "Tue, Fri"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }
}

#Preview {
    NavigationStack {
        DCAListView()
    }
}
