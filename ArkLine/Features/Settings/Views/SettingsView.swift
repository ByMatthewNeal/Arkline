import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // General Section
                Section {
                    NavigationLink(destination: CurrencySelectView(viewModel: viewModel)) {
                        SettingsRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: AppColors.success,
                            title: "Currency",
                            value: viewModel.preferredCurrency
                        )
                    }

                    NavigationLink(destination: ModeSettingsView(viewModel: viewModel, appState: appState)) {
                        SettingsRow(
                            icon: "moon.fill",
                            iconColor: AppColors.accent,
                            title: "Appearance",
                            value: viewModel.darkModePreference.displayName
                        )
                    }

                    NavigationLink(destination: RiskLevelSelectView(viewModel: viewModel)) {
                        SettingsRow(
                            icon: "chart.bar.fill",
                            iconColor: AppColors.warning,
                            title: "Risk Coins",
                            value: viewModel.riskCoins.joined(separator: ", ")
                        )
                    }
                } header: {
                    Text("General")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Notifications Section
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { viewModel.toggleNotifications($0) }
                    )) {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: AppColors.error,
                            title: "Push Notifications"
                        )
                    }

                    NavigationLink(destination: NotificationsDetailView()) {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            iconColor: AppColors.info,
                            title: "Notification Settings"
                        )
                    }
                } header: {
                    Text("Notifications")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Security Section
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.biometricEnabled },
                        set: { viewModel.toggleBiometric($0) }
                    )) {
                        SettingsRow(
                            icon: "faceid",
                            iconColor: AppColors.accent,
                            title: "Face ID"
                        )
                    }

                    NavigationLink(destination: ChangePasscodeView()) {
                        SettingsRow(
                            icon: "lock.fill",
                            iconColor: AppColors.warning,
                            title: "Change Passcode"
                        )
                    }

                    NavigationLink(destination: DevicesView()) {
                        SettingsRow(
                            icon: "iphone",
                            iconColor: AppColors.textSecondary,
                            title: "Devices"
                        )
                    }
                } header: {
                    Text("Security")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Support Section
                Section {
                    NavigationLink(destination: FAQView()) {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            iconColor: AppColors.info,
                            title: "FAQ"
                        )
                    }

                    Button(action: openSupportEmail) {
                        SettingsRow(
                            icon: "envelope.fill",
                            iconColor: AppColors.accent,
                            title: "Contact Support"
                        )
                    }

                    NavigationLink(destination: AboutView()) {
                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: AppColors.textSecondary,
                            title: "About",
                            value: "v1.0.0"
                        )
                    }
                } header: {
                    Text("Support")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Account Section
                Section {
                    Button(action: { viewModel.showSignOutAlert = true }) {
                        SettingsRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconColor: AppColors.warning,
                            title: "Sign Out"
                        )
                    }

                    Button(action: { viewModel.showDeleteAccountAlert = true }) {
                        SettingsRow(
                            icon: "trash.fill",
                            iconColor: AppColors.error,
                            title: "Delete Account",
                            isDestructive: true
                        )
                    }
                } header: {
                    Text("Account")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .alert("Sign Out", isPresented: $viewModel.showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await viewModel.signOut()
                        appState.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $viewModel.showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                        appState.signOut()
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }

    private func openSupportEmail() {
        #if canImport(UIKit)
        if let url = URL(string: "mailto:support@arkline.app") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

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
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.currencyOptions, id: \.0) { code, name in
                Button(action: {
                    viewModel.saveCurrency(code)
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
        .background(AppColors.background(colorScheme))
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

    var body: some View {
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
        .background(AppColors.background(colorScheme))
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Risk Level Select View
struct RiskLevelSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SettingsViewModel

    let availableCoins = ["BTC", "ETH", "SOL", "BNB", "XRP", "ADA", "DOGE", "AVAX"]

    var body: some View {
        List {
            Section {
                ForEach(availableCoins, id: \.self) { coin in
                    Button(action: { toggleCoin(coin) }) {
                        HStack {
                            CoinIconView(symbol: coin, size: 36)

                            Text(coin)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            Spacer()

                            if viewModel.riskCoins.contains(coin) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.accent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(AppColors.textSecondary)
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
        .background(AppColors.background(colorScheme))
        .navigationTitle("Risk Coins")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleCoin(_ coin: String) {
        if viewModel.riskCoins.contains(coin) {
            viewModel.riskCoins.removeAll { $0 == coin }
        } else {
            viewModel.riskCoins.append(coin)
        }
    }
}

// MARK: - Placeholder Views
struct NotificationsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Text("Notification Settings")
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Notifications")
    }
}

struct ChangePasscodeView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Text("Change Passcode")
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Change Passcode")
    }
}

struct DevicesView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Text("Devices")
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("Devices")
    }
}

struct FAQView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Text("FAQ")
            .foregroundColor(AppColors.textPrimary(colorScheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.background(colorScheme))
            .navigationTitle("FAQ")
    }
}

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(AppColors.accent)

            Text("ArkLine")
                .font(AppFonts.title30)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Version 1.0.0")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)

            Text("Crypto & Finance Sentiment Tracker")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(colorScheme))
        .navigationTitle("About")
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
