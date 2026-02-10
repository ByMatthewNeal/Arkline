import SwiftUI

// MARK: - Settings Row
struct SettingsRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    var value: String? = nil
    var isDestructive = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .font(AppFonts.body14Medium)
                .foregroundColor(isDestructive ? AppColors.error : AppColors.textPrimary(colorScheme))

            Spacer()

            if let value = value {
                Text(value)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Currency Select View
struct CurrencySelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SettingsViewModel

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            List {
            ForEach(viewModel.currencyOptions, id: \.0) { code, name in
                Button(action: {
                    viewModel.saveCurrency(code)
                    appState.setPreferredCurrency(code)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(code)
                                .font(AppFonts.body14Bold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Text(name)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        if viewModel.preferredCurrency == code {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Currency")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Mode Settings View
struct ModeSettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: SettingsViewModel
    var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            List {
            ForEach(Constants.DarkModePreference.allCases, id: \.self) { mode in
                Button(action: {
                    viewModel.saveDarkMode(mode)
                    appState.setDarkModePreference(mode)
                    dismiss()
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.accent)

                            Text(mode.displayName)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Spacer()

                        if viewModel.darkModePreference == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Risk Level Select View
struct RiskLevelSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SettingsViewModel
    @State private var showPaywall = false

    let availableCoins = AssetRiskConfig.allConfigs.map(\.assetId)

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            List {
            Section {
                ForEach(availableCoins, id: \.self) { coin in
                    if coin == "BTC" {
                        // BTC always available
                        Button(action: { toggleCoin(coin) }) {
                            riskCoinRow(coin: coin, isSelected: viewModel.riskCoins.contains(coin))
                        }
                    } else if appState.isPro {
                        // Pro users can toggle any coin
                        Button(action: { toggleCoin(coin) }) {
                            riskCoinRow(coin: coin, isSelected: viewModel.riskCoins.contains(coin))
                        }
                    } else {
                        // Free users see locked coins
                        Button(action: { showPaywall = true }) {
                            HStack {
                                CoinIconView(symbol: coin, size: 36)
                                    .opacity(0.4)

                                Text(coin)
                                    .font(AppFonts.body14Medium)
                                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.4))

                                Spacer()

                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color(hex: "F59E0B")))
                            }
                        }
                    }
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            } header: {
                Text("Select coins to track for risk analysis")
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Risk Coins")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .allCoinRisk)
        }
    }

    private func riskCoinRow(coin: String, isSelected: Bool) -> some View {
        HStack {
            CoinIconView(symbol: coin, size: 36)

            Text(coin)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.accent)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func toggleCoin(_ coin: String) {
        viewModel.toggleRiskCoin(coin)
    }
}

// MARK: - Dark Mode Preference Extension
extension Constants.DarkModePreference {
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .automatic: return "iphone"
        }
    }
}
