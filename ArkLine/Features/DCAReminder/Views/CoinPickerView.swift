import SwiftUI

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

// MARK: - Coin Row View
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
