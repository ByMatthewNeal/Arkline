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

    // Number formatter for comma display
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    // Get numeric value from string (removing commas)
    private var numericValue: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    // Check if a preset matches current amount
    private func isPresetSelected(_ preset: Double) -> Bool {
        return numericValue == preset
    }

    // Format amount with commas
    private func formatWithCommas(_ value: String) -> String {
        // Remove existing commas and non-numeric characters
        let cleanedString = value.replacingOccurrences(of: ",", with: "")
            .filter { $0.isNumber }

        // Convert to number and format
        guard let number = Double(cleanedString) else { return cleanedString }
        return Self.numberFormatter.string(from: NSNumber(value: number)) ?? cleanedString
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
                    .onChange(of: amount) { oldValue, newValue in
                        let formatted = formatWithCommas(newValue)
                        if formatted != newValue {
                            amount = formatted
                        }
                    }
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
                        amount = formatWithCommas(String(Int(preset)))
                        isFocused = false
                    }) {
                        Text(DCACalculatorService.formatQuickAmount(preset))
                            .font(AppFonts.body14Medium)
                            .foregroundColor(isPresetSelected(preset) ? .white : textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isPresetSelected(preset) ? AppColors.accent : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
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
    @State private var searchedAssets: [DCAAsset] = []
    @State private var topCryptoAssets: [DCAAsset] = []
    @State private var searchedStockAssets: [DCAAsset] = []
    @State private var isSearching = false
    @State private var isLoadingTopCrypto = false
    @State private var searchTask: Task<Void, Never>?

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var displayAssets: [DCAAsset] {
        // If we have search results, show them
        if !searchText.isEmpty && !searchedAssets.isEmpty {
            return searchedAssets
        }

        // For crypto, show top 100 if loaded, otherwise fallback to local list
        if selectedType == .crypto {
            if !topCryptoAssets.isEmpty && searchText.isEmpty {
                return topCryptoAssets
            }
        }

        // Fallback to local list with filtering
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
                    Button(action: {
                        selectedType = type
                        searchText = ""
                        searchedAssets = []
                    }) {
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
                    .onChange(of: searchText) { _, newValue in
                        performSearch(query: newValue)
                    }

                if isSearching || isLoadingTopCrypto {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
            )

            // Asset list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(displayAssets) { asset in
                        DCAAssetRowView(
                            asset: asset,
                            isSelected: selectedAsset?.symbol == asset.symbol,
                            onSelect: { selectedAsset = asset }
                        )
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
        .onAppear {
            loadTopCryptoAssets()
        }
    }

    private func loadTopCryptoAssets() {
        guard topCryptoAssets.isEmpty else { return }
        isLoadingTopCrypto = true

        Task {
            do {
                let marketService = ServiceContainer.shared.marketService
                let cryptoAssets = try await marketService.fetchCryptoAssets(page: 1, perPage: 100)

                await MainActor.run {
                    topCryptoAssets = cryptoAssets.map { crypto in
                        DCAAsset(
                            symbol: crypto.symbol.uppercased(),
                            name: crypto.name,
                            type: .crypto
                        )
                    }
                    isLoadingTopCrypto = false
                }
            } catch {
                await MainActor.run {
                    isLoadingTopCrypto = false
                }
            }
        }
    }

    private func performSearch(query: String) {
        // Cancel previous search
        searchTask?.cancel()

        guard query.count >= 2 else {
            searchedAssets = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            do {
                let marketService = ServiceContainer.shared.marketService

                switch selectedType {
                case .crypto:
                    let results = try await marketService.searchCrypto(query: query)
                    await MainActor.run {
                        if !Task.isCancelled {
                            searchedAssets = results.map { crypto in
                                DCAAsset(
                                    symbol: crypto.symbol.uppercased(),
                                    name: crypto.name,
                                    type: .crypto
                                )
                            }
                            isSearching = false
                        }
                    }

                case .stock:
                    let results = try await marketService.searchStocks(query: query)
                    await MainActor.run {
                        if !Task.isCancelled {
                            searchedAssets = results.map { stock in
                                DCAAsset(
                                    symbol: stock.symbol,
                                    name: stock.name,
                                    type: .stock
                                )
                            }
                            isSearching = false
                        }
                    }

                case .commodity:
                    // Commodities use local filtering only
                    await MainActor.run {
                        isSearching = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
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
        VStack(spacing: 0) {
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
                    } else {
                        Circle()
                            .stroke(AppColors.textSecondary.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)
        }
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

                // Strategy badge
                HStack(spacing: 6) {
                    Image(systemName: calculation.strategyType.icon)
                        .font(.system(size: 12))
                    Text(calculation.strategyType.rawValue)
                        .font(AppFonts.caption12Medium)
                }
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.accent.opacity(0.15))
                )

                // Asset info
                HStack(spacing: 8) {
                    DCAAssetIconView(asset: calculation.asset, size: 24)
                    Text(calculation.asset.symbol)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }
            }

            Divider()

            if calculation.strategyType == .timeBased {
                timeBasedSummary
            } else {
                riskBasedSummary
            }

            // Portfolio info
            if let portfolioName = calculation.targetPortfolioName {
                Divider()

                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)

                    Text("Target Portfolio")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(portfolioName)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Time-Based Summary

    @ViewBuilder
    private var timeBasedSummary: some View {
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

    // MARK: - Risk-Based Summary

    @ViewBuilder
    private var riskBasedSummary: some View {
        // Plan details
        VStack(spacing: 12) {
            SummaryRow(label: "Total Investment", value: calculation.formattedTotalAmount)
            SummaryRow(label: "Risk Levels", value: calculation.riskBandDescription)
            SummaryRow(label: "Risk Range", value: calculation.riskRangeDescription)
        }

        Divider()

        // Risk meter visualization
        VStack(spacing: 16) {
            Text("Active Risk Zones")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            DCABTCRiskMeter(selectedBands: calculation.riskBands)

            // Investment explanation
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)

                    Text("You'll receive a notification when BTC risk enters your selected zones")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }

                // List selected bands with investment amounts
                VStack(spacing: 6) {
                    let sortedBands = calculation.riskBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
                    let amountPerBand = calculation.totalAmount / Double(sortedBands.count)

                    ForEach(sortedBands) { band in
                        HStack {
                            Circle()
                                .fill(Color(hex: band.color))
                                .frame(width: 8, height: 8)

                            Text(band.rawValue)
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(textPrimary)

                            Text("(\(Int(band.riskRange.lowerBound))-\(Int(band.riskRange.upperBound)))")
                                .font(AppFonts.footnote10)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text(amountPerBand.asCurrency)
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7"))
                )
            }
        }

        // How it works
        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text("How It Works")
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                RiskBasedStepRow(number: 1, text: "BTC risk indicator updates based on market conditions")
                RiskBasedStepRow(number: 2, text: "When risk enters your selected zone, you get notified")
                RiskBasedStepRow(number: 3, text: "Execute your DCA purchase at optimal risk levels")
            }
        }
    }
}

struct RiskBasedStepRow: View {
    let number: Int
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 20, height: 20)

                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.accent)
            }

            Text(text)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
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

// MARK: - Strategy Type Card
struct DCAStrategyTypeCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedStrategy: DCAStrategyType

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your DCA strategy")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select how you want to trigger your investments")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                ForEach(DCAStrategyType.allCases) { strategy in
                    DCAStrategyOptionCard(
                        strategy: strategy,
                        isSelected: selectedStrategy == strategy,
                        onSelect: { selectedStrategy = strategy }
                    )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct DCAStrategyOptionCard: View {
    let strategy: DCAStrategyType
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.15) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")))
                        .frame(width: 48, height: 48)

                    Image(systemName: strategy.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(strategy.rawValue)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text(strategy.description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

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
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk Band Card
struct DCARiskBandCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedBands: Set<DCABTCRiskBand>

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When should you buy?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select the BTC risk levels that will trigger your DCA purchases. Lower risk levels are typically better for accumulation.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            // Risk meter visualization
            DCABTCRiskMeter(selectedBands: selectedBands)
                .padding(.vertical, 8)

            // Risk band options
            VStack(spacing: 10) {
                ForEach(DCABTCRiskBand.allCases) { band in
                    DCARiskBandOptionRow(
                        band: band,
                        isSelected: selectedBands.contains(band),
                        isRecommended: DCABTCRiskBand.recommendedForDCA.contains(band),
                        onToggle: { toggleBand(band) }
                    )
                }
            }

            // Selected bands summary
            if !selectedBands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You'll be notified when BTC risk is:")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)

                    let sortedBands = selectedBands.sorted { $0.riskRange.lowerBound < $1.riskRange.lowerBound }
                    let rangeText = "\(Int(sortedBands.first!.riskRange.lowerBound)) - \(Int(sortedBands.last!.riskRange.upperBound))"

                    Text("\(sortedBands.map { $0.rawValue }.joined(separator: ", ")) (\(rangeText))")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }

    private func toggleBand(_ band: DCABTCRiskBand) {
        if selectedBands.contains(band) {
            selectedBands.remove(band)
        } else {
            selectedBands.insert(band)
        }
    }
}

struct DCABTCRiskMeter: View {
    let selectedBands: Set<DCABTCRiskBand>
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Risk meter bar
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(DCABTCRiskBand.allCases) { band in
                        Rectangle()
                            .fill(Color(hex: band.color).opacity(selectedBands.contains(band) ? 1.0 : 0.3))
                            .frame(width: (geometry.size.width - CGFloat(DCABTCRiskBand.allCases.count - 1) * 2) / CGFloat(DCABTCRiskBand.allCases.count))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            // Labels
            HStack {
                Text("Low Risk")
                    .font(AppFonts.footnote10)
                    .foregroundColor(Color(hex: DCABTCRiskBand.veryLow.color))

                Spacer()

                Text("High Risk")
                    .font(AppFonts.footnote10)
                    .foregroundColor(Color(hex: DCABTCRiskBand.veryHigh.color))
            }
        }
    }
}

struct DCARiskBandOptionRow: View {
    let band: DCABTCRiskBand
    let isSelected: Bool
    let isRecommended: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Color indicator
                Circle()
                    .fill(Color(hex: band.color))
                    .frame(width: 12, height: 12)

                // Band info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(band.rawValue)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(textPrimary)

                        if isRecommended {
                            Text("Recommended")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "00C853"))
                                )
                        }
                    }

                    Text("\(Int(band.riskRange.lowerBound))-\(Int(band.riskRange.upperBound))% • \(band.investmentAdvice)")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: 22, height: 22)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Portfolio Picker Card
struct DCAPortfolioPickerCard: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedPortfolioId: UUID?
    @Binding var selectedPortfolioName: String?
    let availablePortfolios: [Portfolio]

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which portfolio?")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(textPrimary)

            Text("Select the portfolio where DCA transactions will be added")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            if availablePortfolios.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))

                    Text("No portfolios available")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)

                    Text("Create a portfolio first to link your DCA plan")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                // Portfolio list
                VStack(spacing: 10) {
                    ForEach(availablePortfolios) { portfolio in
                        DCAPortfolioOptionRow(
                            portfolio: portfolio,
                            isSelected: selectedPortfolioId == portfolio.id,
                            onSelect: {
                                selectedPortfolioId = portfolio.id
                                selectedPortfolioName = portfolio.name
                            }
                        )
                    }
                }
            }

            // Info note
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)

                Text("DCA transactions will be automatically added to this portfolio when you complete each purchase.")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.accent.opacity(0.08))
            )
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

struct DCAPortfolioOptionRow: View {
    let portfolio: Portfolio
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Portfolio icon
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(portfolio.name)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)

                    Text("\(portfolio.holdings?.count ?? 0) holdings • \((portfolio.totalValue ?? 0).asCurrency)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Selection indicator
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
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : (colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F5F5F7")))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
