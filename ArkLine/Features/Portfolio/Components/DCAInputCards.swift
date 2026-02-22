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
    var isRiskBased: Bool = false
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
        // Risk-based mode: only show supported crypto assets
        if isRiskBased {
            let assets = DCAAsset.riskSupportedCryptoAssets
            if searchText.isEmpty { return assets }
            return assets.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

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

            if isRiskBased {
                // Info banner for risk-based mode
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)

                    Text("Risk-based DCA is only available for crypto assets with risk-level data.")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.accent.opacity(0.08))
                )
            } else {
                // Category tabs (only for time-based)
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
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)

                TextField(isRiskBased ? "Search supported assets..." : "Search \(selectedType.displayName.lowercased())...", text: $searchText)
                    .font(AppFonts.body14)
                    .foregroundColor(textPrimary)
                    .onChange(of: searchText) { _, newValue in
                        if !isRiskBased {
                            performSearch(query: newValue)
                        }
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
            if !isRiskBased {
                loadTopCryptoAssets()
            }
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

// MARK: - Asset Row
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

// MARK: - Asset Icon
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

// MARK: - Frequency Option Row
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

// MARK: - Weekday Picker
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

// MARK: - Duration Button
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
