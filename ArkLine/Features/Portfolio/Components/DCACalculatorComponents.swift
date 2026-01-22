import SwiftUI

// MARK: - Amount Input Card
struct DCAAmountInputCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var amount: String
    @FocusState private var isFocused: Bool

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sectionBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much do you want to invest?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Enter the total amount you want to invest over time")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            // Amount input
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(textPrimary)

                TextField("0", text: $amount)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(textPrimary)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($isFocused)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
            )

            // Quick select
            Text("Quick select")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(DCACalculatorService.quickAmountPresets, id: \.self) { preset in
                    Button(action: {
                        amount = String(Int(preset))
                        isFocused = false
                    }) {
                        Text(DCACalculatorService.formatQuickAmount(preset))
                            .font(AppFonts.body14Medium)
                            .foregroundColor(amount == String(Int(preset)) ? .white : textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(amount == String(Int(preset)) ? AppColors.accent : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                            )
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Asset Picker Card
struct DCAAssetPickerCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedAsset: DCAAsset?
    @Binding var selectedType: DCAAssetType
    @State private var searchText = ""

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var filteredAssets: [DCAAsset] {
        let assets = DCAAsset.assets(for: selectedType)
        if searchText.isEmpty {
            return assets
        }
        return assets.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What asset are you investing in?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            // Category tabs
            HStack(spacing: 8) {
                ForEach(DCAAssetType.allCases) { type in
                    Button(action: { selectedType = type }) {
                        Text(type.displayName)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(selectedType == type ? .white : textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedType == type ? AppColors.accent : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(AppColors.textSecondary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)

                TextField("Search \(selectedType.displayName.lowercased())...", text: $searchText)
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
            )

            // Asset list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredAssets) { asset in
                        DCAAssetRowView(
                            asset: asset,
                            isSelected: selectedAsset?.id == asset.id,
                            onSelect: { selectedAsset = asset }
                        )
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct DCAAssetRowView: View {
    let asset: DCAAsset
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Icon
                DCAAssetIconView(asset: asset, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.symbol)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text(asset.name)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }

        Divider()
            .padding(.leading, 58)
    }
}

struct DCAAssetIconView: View {
    let asset: DCAAsset
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Circle()
                .fill(assetColor.opacity(0.15))
                .frame(width: size, height: size)

            if let iconName = systemIcon {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(assetColor)
            } else {
                Text(String(asset.symbol.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(assetColor)
            }
        }
    }

    private var assetColor: Color {
        switch asset.symbol.uppercased() {
        case "BTC": return Color(hex: "F7931A")
        case "ETH": return Color(hex: "627EEA")
        case "SOL": return Color(hex: "00FFA3")
        case "NVDA": return Color(hex: "76B900")
        case "AAPL": return Color(hex: "555555")
        case "GOLD": return Color(hex: "FFD700")
        default: return AppColors.accent
        }
    }

    private var systemIcon: String? {
        switch asset.symbol.uppercased() {
        case "BTC": return "bitcoinsign"
        case "ETH": return "diamond.fill"
        case "GOLD", "SILVER", "PLAT": return "cube.box.fill"
        default: return nil
        }
    }
}

// MARK: - Frequency Card
struct DCAFrequencyCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedFrequency: DCAFrequency
    @Binding var selectedDays: Set<Weekday>

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How often will you invest?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            // Frequency options
            VStack(spacing: 8) {
                ForEach([DCAFrequency.daily, .weekly, .biweekly, .monthly], id: \.self) { frequency in
                    DCAFrequencyOptionRow(
                        frequency: frequency,
                        isSelected: selectedFrequency == frequency,
                        onSelect: {
                            selectedFrequency = frequency
                            // Reset days for non-weekly frequencies
                            if frequency != .weekly {
                                selectedDays = []
                            }
                        }
                    )
                }
            }

            // Day picker for weekly
            if selectedFrequency == .weekly {
                VStack(alignment: .leading, spacing: 12) {
                    Text("On which days?")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)

                    DCAWeekdayPicker(selectedDays: $selectedDays)
                }
                .padding(.top, 8)
            }

            // Description
            Text(DCACalculatorService.frequencyDescription(
                frequency: selectedFrequency,
                selectedDays: selectedDays
            ))
            .font(AppFonts.body14)
            .foregroundColor(AppColors.accent)
            .padding(.top, 4)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct DCAFrequencyOptionRow: View {
    let frequency: DCAFrequency
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                Text(frequency.displayName)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.accent.opacity(0.1) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
            )
        }
    }
}

struct DCAWeekdayPicker: View {
    @Binding var selectedDays: Set<Weekday>
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                Button(action: { toggleDay(day) }) {
                    Text(day.shortName)
                        .font(.system(size: 12, weight: selectedDays.contains(day) ? .semibold : .regular))
                        .foregroundColor(selectedDays.contains(day) ? .white : textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDays.contains(day) ? AppColors.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    private func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - Duration Card
struct DCADurationCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedDuration: DCADuration?
    @State private var showCustomPicker = false
    @State private var customMonths: Int = 9

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Over what time period?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Choose how long you want to spread your investment")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            // Duration presets
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DCADuration.presets, id: \.months) { duration in
                    DCADurationButton(
                        duration: duration,
                        isSelected: selectedDuration == duration,
                        onSelect: {
                            selectedDuration = duration
                            showCustomPicker = false
                        }
                    )
                }

                // Custom option
                Button(action: {
                    showCustomPicker = true
                    selectedDuration = .custom(months: customMonths)
                }) {
                    HStack {
                        Text("Custom")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(showCustomPicker ? .white : textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(showCustomPicker ? AppColors.accent : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                    )
                }
            }

            // Custom picker
            if showCustomPicker {
                HStack {
                    Text("Duration:")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Menu {
                        ForEach(1...36, id: \.self) { months in
                            Button(action: {
                                customMonths = months
                                selectedDuration = .custom(months: months)
                            }) {
                                Text("\(months) month\(months == 1 ? "" : "s")")
                            }
                        }
                    } label: {
                        HStack {
                            Text("\(customMonths) month\(customMonths == 1 ? "" : "s")")
                                .font(AppFonts.body14Bold)
                                .foregroundColor(textPrimary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct DCADurationButton: View {
    let duration: DCADuration
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            Text(duration.displayName)
                .font(AppFonts.body14Medium)
                .foregroundColor(isSelected ? .white : textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppColors.accent : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                )
        }
    }
}

// MARK: - Calculation Summary Card
struct DCACalculationSummaryCard: View {
    @Environment(\.colorScheme) var colorScheme
    let calculation: DCACalculation

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Your DCA Plan")
                    .font(AppFonts.title24)
                    .foregroundColor(textPrimary)

                // Asset info
                HStack(spacing: 8) {
                    DCAAssetIconView(asset: calculation.asset, size: 24)
                    Text(calculation.asset.symbol)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }
            }

            Divider()

            // Plan details
            VStack(spacing: 12) {
                SummaryRow(label: "Total Investment", value: calculation.formattedTotalAmount)
                SummaryRow(label: "Frequency", value: DCACalculatorService.frequencyDescription(
                    frequency: calculation.frequency,
                    selectedDays: calculation.selectedDays
                ))
                SummaryRow(label: "Duration", value: calculation.duration.displayName)
            }

            Divider()

            // Key metrics
            VStack(spacing: 16) {
                // Per purchase amount - highlighted
                VStack(spacing: 4) {
                    Text("Per Purchase")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    Text(calculation.formattedAmountPerPurchase)
                        .font(AppFonts.number36)
                        .foregroundColor(AppColors.accent)
                }

                HStack(spacing: 20) {
                    MetricItem(
                        icon: "calendar",
                        value: "\(calculation.numberOfPurchases)",
                        label: "Purchases"
                    )

                    MetricItem(
                        icon: "play.circle",
                        value: dateFormatter.string(from: calculation.startDate),
                        label: "First"
                    )

                    if let endDate = calculation.endDate {
                        MetricItem(
                            icon: "flag.checkered",
                            value: dateFormatter.string(from: endDate),
                            label: "Last"
                        )
                    }
                }
            }

            // Upcoming schedule preview
            if !calculation.purchaseDates.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Schedule")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    VStack(spacing: 8) {
                        ForEach(Array(calculation.purchaseDates.prefix(5).enumerated()), id: \.offset) { _, date in
                            HStack {
                                Text(shortDateFormatter.string(from: date))
                                    .font(AppFonts.body14)
                                    .foregroundColor(AppColors.textSecondary)

                                Spacer()

                                Text(calculation.formattedAmountPerPurchase)
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(textPrimary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                            )
                        }

                        if calculation.purchaseDates.count > 5 {
                            Text("+ \(calculation.purchaseDates.count - 5) more purchases")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)
        }
    }
}

struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.accent)

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Step Indicator
struct DCAStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}
