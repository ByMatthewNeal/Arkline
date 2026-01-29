import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SettingsViewModel()

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var chartIconColor: Color {
        appState.chartColorPalette.previewColors.first ?? AppColors.accent
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated mesh gradient background
                MeshGradientBackground()

                // Brush effect overlay for dark mode
                if isDarkMode {
                    BrushEffectOverlay()
                }

                // Content
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

                    NavigationLink(destination: AvatarColorSelectView(appState: appState)) {
                        SettingsRow(
                            icon: "person.crop.circle.fill",
                            iconColor: appState.avatarColorTheme.gradientColors.light,
                            title: "Avatar Color",
                            value: appState.avatarColorTheme.displayName
                        )
                    }

                    NavigationLink(destination: ChartColorSelectView(appState: appState)) {
                        SettingsRow(
                            icon: "chart.pie.fill",
                            iconColor: chartIconColor,
                            title: "Chart Colors",
                            value: appState.chartColorPalette.displayName
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

                    NavigationLink(destination: NewsTopicsSettingsView(viewModel: viewModel)) {
                        SettingsRow(
                            icon: "newspaper.fill",
                            iconColor: AppColors.info,
                            title: "News Topics",
                            value: "\(viewModel.selectedNewsTopics.count) topics" + (viewModel.customNewsTopics.isEmpty ? "" : " + \(viewModel.customNewsTopics.count) custom")
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
            }
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

// MARK: - Avatar Color Select View
struct AvatarColorSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Avatar
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            appState.avatarColorTheme.gradientColors.light,
                                            appState.avatarColorTheme.gradientColors.dark
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)

                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: 100, height: 100)

                            Text("M")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)

                        Text("Preview")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 24)

                    // Color Options Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Constants.AvatarColorTheme.allCases, id: \.self) { theme in
                            AvatarColorOption(
                                theme: theme,
                                isSelected: appState.avatarColorTheme == theme,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        appState.setAvatarColorTheme(theme)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("Avatar Color")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Chart Color Select View
struct ChartColorSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Chart
                    VStack(spacing: 12) {
                        // Mini pie chart preview
                        ChartPalettePreview(palette: appState.chartColorPalette)

                        Text("Preview")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 24)

                    // Palette Options
                    VStack(spacing: 12) {
                        ForEach(Constants.ChartColorPalette.allCases, id: \.self) { palette in
                            ChartPaletteOption(
                                palette: palette,
                                isSelected: appState.chartColorPalette == palette,
                                action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        appState.setChartColorPalette(palette)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("Chart Colors")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Chart Palette Preview
struct ChartPalettePreview: View {
    let palette: Constants.ChartColorPalette

    var body: some View {
        ZStack {
            // Donut chart preview
            ForEach(Array(allocations.enumerated()), id: \.offset) { index, allocation in
                Circle()
                    .trim(from: startAngle(for: index), to: endAngle(for: index))
                    .stroke(allocation.color, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            // Center label
            VStack(spacing: 2) {
                Text("4")
                    .font(.system(size: 24, weight: .bold))
                Text("Assets")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 120)
    }

    private var allocations: [(color: Color, percentage: Double)] {
        let colors = palette.colors
        return [
            (Color(hex: colors.crypto), 45),
            (Color(hex: colors.stock), 30),
            (Color(hex: colors.metal), 15),
            (Color(hex: colors.realEstate), 10)
        ]
    }

    private func startAngle(for index: Int) -> CGFloat {
        let preceding = allocations.prefix(index).reduce(0) { $0 + $1.percentage }
        return preceding / 100
    }

    private func endAngle(for index: Int) -> CGFloat {
        let including = allocations.prefix(index + 1).reduce(0) { $0 + $1.percentage }
        return including / 100
    }
}

// MARK: - Chart Palette Option
struct ChartPaletteOption: View {
    let palette: Constants.ChartColorPalette
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var primaryColor: Color {
        palette.previewColors.first ?? AppColors.accent
    }

    private var iconColor: Color {
        isSelected ? primaryColor : AppColors.textSecondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02)
        }
    }

    private var borderColor: Color {
        isSelected ? primaryColor : Color.clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Color swatches
                HStack(spacing: 4) {
                    ForEach(palette.previewColors.indices, id: \.self) { index in
                        Circle()
                            .fill(palette.previewColors[index])
                            .frame(width: 20, height: 20)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: palette.icon)
                            .font(.system(size: 12))
                            .foregroundColor(iconColor)

                        Text(palette.displayName)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(isSelected ? AppColors.textPrimary(colorScheme) : AppColors.textSecondary)
                    }

                    Text(palette.description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar Color Option
struct AvatarColorOption: View {
    let theme: Constants.AvatarColorTheme
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Color preview circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.gradientColors.light, theme.gradientColors.dark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 56, height: 56)

                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Theme name and icon
                HStack(spacing: 6) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? theme.gradientColors.light : AppColors.textSecondary)

                    Text(theme.displayName)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(isSelected ? AppColors.textPrimary(colorScheme) : AppColors.textSecondary)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                            ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.02))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? theme.gradientColors.light : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Risk Level Select View
struct RiskLevelSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Bindable var viewModel: SettingsViewModel

    let availableCoins = ["BTC", "ETH", "SOL"]

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
        }
        .navigationTitle("Risk Coins")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleCoin(_ coin: String) {
        viewModel.toggleRiskCoin(coin)
    }
}

// MARK: - Notifications Detail View
struct NotificationsDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var dcaReminders = true
    @State private var priceAlerts = true
    @State private var marketNews = true
    @State private var communityUpdates = false
    @State private var emailNotifications = true

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
                Toggle(isOn: $dcaReminders) {
                    NotificationRow(
                        icon: "calendar.badge.clock",
                        iconColor: AppColors.accent,
                        title: "DCA Reminders",
                        description: "Get reminded about your scheduled purchases"
                    )
                }

                Toggle(isOn: $priceAlerts) {
                    NotificationRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: AppColors.success,
                        title: "Price Alerts",
                        description: "Notifications when prices hit your targets"
                    )
                }

                Toggle(isOn: $marketNews) {
                    NotificationRow(
                        icon: "newspaper",
                        iconColor: AppColors.warning,
                        title: "Market News",
                        description: "Breaking news and market updates"
                    )
                }

                Toggle(isOn: $communityUpdates) {
                    NotificationRow(
                        icon: "person.3",
                        iconColor: AppColors.info,
                        title: "Community Updates",
                        description: "Posts and discussions from the community"
                    )
                }
            } header: {
                Text("Push Notifications")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            Section {
                Toggle(isOn: $emailNotifications) {
                    NotificationRow(
                        icon: "envelope",
                        iconColor: AppColors.accent,
                        title: "Email Notifications",
                        description: "Receive important updates via email"
                    )
                }
            } header: {
                Text("Email")
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
        .navigationTitle("Notifications")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct NotificationRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(description)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Change Passcode View
struct ChangePasscodeView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var showError = false
    @State private var errorMessage = ""

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
                SecureField("Current Passcode", text: $currentPasscode)
                    .keyboardType(.numberPad)
            } header: {
                Text("Current")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            Section {
                SecureField("New Passcode", text: $newPasscode)
                    .keyboardType(.numberPad)

                SecureField("Confirm Passcode", text: $confirmPasscode)
                    .keyboardType(.numberPad)
            } header: {
                Text("New Passcode")
            } footer: {
                Text("Use a 6-digit passcode for better security")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            Section {
                Button(action: changePasscode) {
                    Text("Update Passcode")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.accent)
                        .cornerRadius(8)
                }
                .listRowBackground(Color.clear)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.sidebar)
        #endif
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("Change Passcode")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func changePasscode() {
        guard newPasscode == confirmPasscode else {
            errorMessage = "Passcodes don't match"
            showError = true
            return
        }

        guard newPasscode.count >= 4 else {
            errorMessage = "Passcode must be at least 4 digits"
            showError = true
            return
        }

        // TODO: Implement actual passcode change logic
        dismiss()
    }
}

// MARK: - Devices View
struct DevicesView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    let devices = [
        DeviceInfo(name: "iPhone 15 Pro", lastActive: "Now", isCurrent: true),
        DeviceInfo(name: "iPad Pro", lastActive: "2 hours ago", isCurrent: false),
        DeviceInfo(name: "MacBook Pro", lastActive: "Yesterday", isCurrent: false)
    ]

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
                ForEach(devices) { device in
                    DeviceRow(device: device)
                }
            } header: {
                Text("Active Devices")
            } footer: {
                Text("These devices have access to your ArkLine account")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            Section {
                Button(action: signOutAllDevices) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(AppColors.error)
                        Text("Sign Out All Other Devices")
                            .foregroundColor(AppColors.error)
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
        .navigationTitle("Devices")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func signOutAllDevices() {
        // TODO: Implement sign out all devices
    }
}

struct DeviceInfo: Identifiable {
    let id = UUID()
    let name: String
    let lastActive: String
    let isCurrent: Bool
}

struct DeviceRow: View {
    @Environment(\.colorScheme) var colorScheme
    let device: DeviceInfo

    var deviceIcon: String {
        if device.name.contains("iPhone") { return "iphone" }
        if device.name.contains("iPad") { return "ipad" }
        if device.name.contains("Mac") { return "laptopcomputer" }
        return "desktopcomputer"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(device.name)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if device.isCurrent {
                        Text("This device")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Text("Last active: \(device.lastActive)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - FAQ View
struct FAQView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    let faqs = [
        FAQItem(question: "What is ArkLine?", answer: "ArkLine is a crypto sentiment tracking app that helps you understand market trends, track your portfolio, and make informed investment decisions."),
        FAQItem(question: "How does the sentiment analysis work?", answer: "We aggregate data from multiple sources including social media, news, and market data to calculate real-time sentiment scores for cryptocurrencies."),
        FAQItem(question: "What is DCA?", answer: "DCA (Dollar-Cost Averaging) is an investment strategy where you invest a fixed amount at regular intervals, regardless of the asset's price."),
        FAQItem(question: "How do I set up price alerts?", answer: "Go to your Profile > Alerts and tap 'Add Alert'. Select the cryptocurrency, set your target price, and choose whether to be notified when the price goes above or below your target."),
        FAQItem(question: "Is my data secure?", answer: "Yes, we use industry-standard encryption and security practices. Your data is stored securely and we never share your personal information with third parties."),
        FAQItem(question: "How do I delete my account?", answer: "Go to Settings > Account > Delete Account. Please note that this action is irreversible and all your data will be permanently deleted.")
    ]

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
            List {
                ForEach(faqs) { faq in
                    FAQRow(faq: faq)
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
        .navigationTitle("FAQ")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQRow: View {
    @Environment(\.colorScheme) var colorScheme
    let faq: FAQItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(faq.question)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 14))
                }
            }

            if isExpanded {
                Text(faq.answer)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()
            if isDarkMode { BrushEffectOverlay() }
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
        }
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
