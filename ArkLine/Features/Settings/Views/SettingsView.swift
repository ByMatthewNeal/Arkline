import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = SettingsViewModel()
    @State private var analyticsEnabled = UserDefaults.standard.bool(forKey: "analyticsConsentGranted")

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
                            title: "Risk Assets",
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
                        set: {
                            Haptics.selection()
                            viewModel.toggleNotifications($0)
                        }
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
                        set: {
                            Haptics.selection()
                            viewModel.toggleBiometric($0)
                        }
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

                } header: {
                    Text("Security")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Privacy Section
                Section {
                    Toggle(isOn: $analyticsEnabled) {
                        SettingsRow(
                            icon: "chart.bar.fill",
                            iconColor: AppColors.info,
                            title: "Usage Analytics"
                        )
                    }
                    .onChange(of: analyticsEnabled) { _, newValue in
                        Haptics.selection()
                        Task { await AnalyticsService.shared.setConsent(newValue) }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Help improve Arkline by sharing anonymous usage data. No personal or financial data is collected.")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Subscription Section
                // Always shown — Apple guideline 3.1.1 requires Restore
                // Purchases to be discoverable even for non-subscribers.
                // Manage Subscription routes based on subscription source:
                // - Apple IAP customer (RevenueCat entitlement active) → iOS Settings
                // - Stripe customer (active/past_due/trialing from Supabase) → billing portal
                Section {
                    // Manage Subscription
                    // Apple IAP path takes precedence — if RC sees an active
                    // Apple entitlement, route the user to iOS Settings (per
                    // Apple anti-steering rules, we cannot send them to our
                    // Stripe portal instead).
                    if RevenueCatService.shared.isPro {
                        Button {
                            Haptics.selection()
                            viewModel.openAppleSubscriptions()
                        } label: {
                            SettingsRow(
                                icon: "creditcard.fill",
                                iconColor: AppColors.accent,
                                title: "Manage Subscription"
                            )
                        }
                    } else if let status = appState.currentUser?.subscriptionStatus,
                              status == .active || status == .pastDue || status == .trialing {
                        // Stripe customer — keep existing billing portal path
                        Button {
                            Task { await viewModel.openBillingPortal(email: appState.currentUser?.email) }
                        } label: {
                            HStack {
                                SettingsRow(
                                    icon: "creditcard.fill",
                                    iconColor: AppColors.accent,
                                    title: "Manage Subscription"
                                )
                                if viewModel.isLoadingBillingPortal {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(viewModel.isLoadingBillingPortal)

                        if let error = viewModel.billingPortalError {
                            Text(error)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.error)
                        }
                    }

                    // Restore Purchases — Apple 3.1.1 requirement.
                    // Visible to ALL users so anyone with a prior App Store
                    // purchase can recover entitlement on a new device.
                    Button {
                        Haptics.selection()
                        Task { await viewModel.restorePurchases() }
                    } label: {
                        HStack {
                            SettingsRow(
                                icon: "arrow.clockwise.circle.fill",
                                iconColor: AppColors.info,
                                title: "Restore Purchases"
                            )
                            if viewModel.isRestoringPurchases {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(viewModel.isRestoringPurchases)

                    if let error = viewModel.restorePurchasesError {
                        Text(error)
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.error)
                    }

                    // Trial badge (Stripe trials only — Apple handles its own
                    // trial display via iOS Settings)
                    if let status = appState.currentUser?.subscriptionStatus,
                       status == .trialing,
                       !RevenueCatService.shared.isPro {
                        HStack(spacing: ArkSpacing.xs) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12))
                            if let days = appState.currentUser?.trialDaysRemaining {
                                Text(days <= 1 ? "Trial ends today" : "\(days) days left in trial")
                                    .font(AppFonts.caption12)
                            } else {
                                Text("Free trial active")
                                    .font(AppFonts.caption12)
                            }
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, ArkSpacing.md)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(ArkSpacing.Radius.sm)
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    // Auto-renewal disclosure — required adjacent to any
                    // subscription management surface. Generic wording covers
                    // both Apple-IAP and Stripe billing flows.
                    Text("Subscriptions renew automatically until canceled. Manage or cancel anytime through your account.")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Support Section
                Section {
                    NavigationLink(destination: DictionaryView()) {
                        SettingsRow(
                            icon: "character.book.closed",
                            iconColor: .purple,
                            title: "Dictionary"
                        )
                    }

                    NavigationLink(destination: FAQView()) {
                        SettingsRow(
                            icon: "questionmark.circle.fill",
                            iconColor: AppColors.info,
                            title: "FAQ"
                        )
                    }

                    NavigationLink(destination: FeatureRequestFormView()) {
                        SettingsRow(
                            icon: "lightbulb.fill",
                            iconColor: AppColors.warning,
                            title: "Request a Feature"
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
            .contentMargins(.bottom, 80, for: .scrollContent)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .alert("Sign Out", isPresented: $viewModel.showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    // Don't sign out of Supabase — keep session active so
                    // refreshUserProfile() works after passcode re-login.
                    // The passcode/FaceID lock screen protects app access.
                    appState.signOut()
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
            .alert("Purchases Restored", isPresented: $viewModel.showRestoreSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your subscription has been restored to this device.")
            }
            .alert("No Purchases Found", isPresented: $viewModel.showRestoreNothingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We couldn't find an active subscription tied to your Apple ID. If you believe this is a mistake, make sure you're signed in to the App Store with the Apple ID that made the purchase.")
            }
        }
    }

    private func openSupportEmail() {
        #if canImport(UIKit)
        if let url = URL(string: "mailto:support@arkline.io") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
