import SwiftUI

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
        if let _ = Double(amount) {
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
