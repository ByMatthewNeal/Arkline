import SwiftUI

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
            .navigationTitle(selectedCoin.map { "\($0.symbol) DCA Reminder" } ?? "New Reminder")
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
        guard let userId = SupabaseAuthManager.shared.currentUserId else {
            viewModel.error = .custom(message: "You must be signed in to create a reminder")
            return
        }

        let frequency: DCAFrequency = selectedFrequency.toDCAFrequency

        let reminder = DCAReminder(
            userId: userId,
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
            if viewModel.error == nil {
                dismiss()
            }
        }
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
