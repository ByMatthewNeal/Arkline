import SwiftUI
import StoreKit
import RevenueCat

struct PaywallView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let feature: PremiumFeature?

    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var storeProducts: [Product] = []
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var purchaseSuccess = false

    init(feature: PremiumFeature? = nil) {
        self.feature = feature
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                ScrollView {
                    VStack(spacing: ArkSpacing.xl) {
                        headerSection
                        if let feature {
                            featureContextBadge(feature)
                        }
                        benefitsList
                        planCards
                        purchaseButton
                        restoreLink
                        termsSection
                    }
                    .padding(.horizontal, ArkSpacing.Layout.screenPadding)
                    .padding(.top, ArkSpacing.lg)
                    .padding(.bottom, ArkSpacing.xxxxl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .task { await loadOfferings() }
            .overlay {
                if purchaseSuccess {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("ArkLine Pro")
                .font(AppFonts.title32)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Unlock the full power of ArkLine")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, ArkSpacing.lg)
    }

    // MARK: - Feature Context Badge

    private func featureContextBadge(_ feature: PremiumFeature) -> some View {
        HStack(spacing: ArkSpacing.xs) {
            Image(systemName: feature.icon)
                .font(.system(size: 14))
            Text(feature.title)
                .font(AppFonts.caption12Medium)
        }
        .foregroundColor(AppColors.accent)
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xxs)
        .background(AppColors.accent.opacity(0.12))
        .cornerRadius(ArkSpacing.Radius.full)
    }

    // MARK: - Benefits List

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            benefitRow(icon: "chart.bar.fill", text: "Risk levels for all coins")
            benefitRow(icon: "waveform.path.ecg", text: "Full technical analysis")
            benefitRow(icon: "megaphone.fill", text: "Market broadcasts")
            benefitRow(icon: "calendar.badge.plus", text: "Unlimited DCA reminders")
            benefitRow(icon: "globe.americas.fill", text: "Macro dashboard deep dives")
            benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced portfolio analytics")
            benefitRow(icon: "square.and.arrow.up.fill", text: "Export to PDF, CSV, JSON")
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme).opacity(0.8))
        .cornerRadius(ArkSpacing.Radius.card)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)
            Text(text)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.success)
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: ArkSpacing.sm) {
            if let annual = offerings?.current?.annual {
                planCard(
                    package: annual,
                    title: "Yearly",
                    price: annual.storeProduct.localizedPriceString,
                    subtitle: monthlyEquivalent(for: annual),
                    badge: "Save 30%"
                )
            }

            if let monthly = offerings?.current?.monthly {
                planCard(
                    package: monthly,
                    title: "Monthly",
                    price: monthly.storeProduct.localizedPriceString,
                    subtitle: "per month",
                    badge: nil
                )
            }

            // StoreKit 2 fallback when RevenueCat offerings unavailable
            if offerings == nil && !storeProducts.isEmpty {
                if let yearly = storeProducts.first(where: { $0.id == "yearly" }) {
                    storeProductCard(
                        product: yearly,
                        title: "Yearly",
                        subtitle: storeMonthlyEquivalent(for: yearly),
                        badge: "Save 30%"
                    )
                }
                if let monthly = storeProducts.first(where: { $0.id == "monthly" }) {
                    storeProductCard(
                        product: monthly,
                        title: "Monthly",
                        subtitle: "per month",
                        badge: nil
                    )
                }
            }

            if offerings == nil && storeProducts.isEmpty {
                // Loading skeleton
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .fill(AppColors.cardBackground(colorScheme).opacity(0.5))
                    .frame(height: 80)
                    .overlay {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                    }
            }
        }
    }

    private func planCard(package: Package, title: String, price: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier

        return Button(action: {
            selectedPackage = package
            selectedProduct = nil
        }) {
            HStack {
                VStack(alignment: .leading, spacing: ArkSpacing.xxxs) {
                    HStack(spacing: ArkSpacing.xs) {
                        Text(title)
                            .font(AppFonts.title16)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        if let badge {
                            Text(badge)
                                .font(AppFonts.footnote10Bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .cornerRadius(ArkSpacing.Radius.xs)
                        }
                    }
                    Text(subtitle)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(price)
                    .font(AppFonts.title18Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme).opacity(0.8))
            .cornerRadius(ArkSpacing.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .stroke(isSelected ? AppColors.accent : AppColors.divider(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func monthlyEquivalent(for package: Package) -> String {
        let price = package.storeProduct.price as Decimal
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? .current
        let monthlyString = formatter.string(from: monthly as NSDecimalNumber) ?? ""
        return "\(monthlyString)/mo"
    }

    private func storeProductCard(product: Product, title: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button(action: {
            selectedProduct = product
            selectedPackage = nil
        }) {
            HStack {
                VStack(alignment: .leading, spacing: ArkSpacing.xxxs) {
                    HStack(spacing: ArkSpacing.xs) {
                        Text(title)
                            .font(AppFonts.title16)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        if let badge {
                            Text(badge)
                                .font(AppFonts.footnote10Bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.success)
                                .cornerRadius(ArkSpacing.Radius.xs)
                        }
                    }
                    Text(subtitle)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(AppFonts.title18Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme).opacity(0.8))
            .cornerRadius(ArkSpacing.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .stroke(isSelected ? AppColors.accent : AppColors.divider(colorScheme), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func storeMonthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        let monthlyString = formatter.string(from: monthly as NSDecimalNumber) ?? ""
        return "\(monthlyString)/mo"
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        Button(action: { Task { await purchase() } }) {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                        .font(AppFonts.title16)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ArkSpacing.ButtonHeight.large)
            .background(
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(ArkSpacing.Radius.sm)
        }
        .disabled((selectedPackage == nil && selectedProduct == nil) || isPurchasing)
        .opacity((selectedPackage == nil && selectedProduct == nil) ? 0.6 : 1)
    }

    // MARK: - Restore

    private var restoreLink: some View {
        VStack(spacing: ArkSpacing.xs) {
            if let errorMessage {
                Text(errorMessage)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
            }

            Button(action: { Task { await restore() } }) {
                Group {
                    if isRestoring {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                    } else {
                        Text("Restore Purchases")
                            .font(AppFonts.body14)
                    }
                }
                .foregroundColor(AppColors.textSecondary)
            }
            .disabled(isRestoring)
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        Text("Recurring billing. Cancel anytime in Settings.")
            .font(AppFonts.caption12)
            .foregroundColor(AppColors.textTertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: ArkSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.success)

                Text("Welcome to Pro!")
                    .font(AppFonts.title24)
                    .foregroundColor(.white)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func loadOfferings() async {
        // Load products from StoreKit 2 (respects local .storekit config for pricing)
        do {
            let products = try await Product.products(for: ["monthly", "yearly"])
            if !products.isEmpty {
                storeProducts = products
                selectedProduct = products.first(where: { $0.id == "yearly" }) ?? products.first
                return
            }
        } catch {
            AppLogger.shared.error("StoreKit product loading error: \(error)")
        }

        // Fall back to RevenueCat offerings
        do {
            let result = try await SubscriptionService.shared.getOfferings()
            offerings = result
            selectedPackage = result.current?.annual ?? result.current?.monthly
            if result.current == nil {
                errorMessage = "Unable to load subscription options."
            }
        } catch {
            errorMessage = "Unable to load subscription options."
            AppLogger.shared.error("PaywallView offerings error: \(error)")
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        if let package = selectedPackage {
            // RevenueCat purchase path
            do {
                let success = try await SubscriptionService.shared.purchase(package: package)
                if success {
                    withAnimation { purchaseSuccess = true }
                    try? await Task.sleep(for: .seconds(1.5))
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else if let product = selectedProduct {
            // StoreKit 2 direct purchase fallback
            do {
                let result = try await product.purchase()
                switch result {
                case .success:
                    // Sync with RevenueCat if available
                    await SubscriptionService.shared.refreshStatus()
                    withAnimation { purchaseSuccess = true }
                    try? await Task.sleep(for: .seconds(1.5))
                    dismiss()
                case .userCancelled:
                    break
                case .pending:
                    errorMessage = "Purchase is pending approval."
                @unknown default:
                    break
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        defer { isRestoring = false }

        do {
            let restored = try await SubscriptionService.shared.restorePurchases()
            if restored {
                withAnimation { purchaseSuccess = true }
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            } else {
                errorMessage = "No active subscription found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
