import SwiftUI
import StoreKit
import RevenueCat

struct PaywallView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let feature: PremiumFeature?

    // MARK: - Purchase State

    @State private var offerings: Offerings?
    @State private var selectedPackage: Package?
    @State private var storeProducts: [Product] = []
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var purchaseSuccess = false

    // MARK: - Animation State

    @State private var showHeader = false
    @State private var showMetrics = false
    @State private var showComparison = false
    @State private var showSocialProof = false
    @State private var showPlans = false
    @State private var showTrust = false
    @State private var showCTA = false
    @State private var showFooter = false
    @State private var glowPulse = false

    init(feature: PremiumFeature? = nil) {
        self.feature = feature
    }

    // MARK: - Gold Gradient

    private var goldGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: ArkSpacing.xl) {
                        premiumHeader

                        if let feature {
                            featureContextBadge(feature)
                        }

                        keyMetricsBar
                        featureComparisonTable
                        socialProofSection
                        planSelectionCards
                        trustGuaranteeSection
                        purchaseCTA
                        restoreAndTerms
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
            .task {
                await loadOfferings()
                await triggerStaggeredAppearance()
            }
            .overlay {
                if purchaseSuccess {
                    enhancedSuccessOverlay
                }
            }
        }
    }

    // MARK: - Staggered Appearance

    private func triggerStaggeredAppearance() async {
        let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
        let delay: UInt64 = 100_000_000 // 100ms

        withAnimation(spring) { showHeader = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showMetrics = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showComparison = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showSocialProof = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showPlans = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showTrust = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showCTA = true }
        try? await Task.sleep(nanoseconds: delay)
        withAnimation(spring) { showFooter = true }
    }

    // MARK: - Section 1: Premium Header

    private var premiumHeader: some View {
        VStack(spacing: ArkSpacing.sm) {
            ZStack {
                // Outer glow pulse
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "F59E0B").opacity(0.4),
                                Color(hex: "F59E0B").opacity(0)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(glowPulse ? 1.2 : 0.9)
                    .opacity(glowPulse ? 0.8 : 0.4)

                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(goldGradient)
            }

            Text("ArkLine Pro")
                .font(AppFonts.title32)
                .foregroundStyle(goldGradient)

            Text("Institutional-Grade Intelligence")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.top, ArkSpacing.lg)
        .opacity(showHeader ? 1 : 0)
        .offset(y: showHeader ? 0 : 20)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                glowPulse = true
            }
        }
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

    // MARK: - Section 2: Key Metrics Bar

    private var keyMetricsBar: some View {
        HStack(spacing: 0) {
            metricItem(icon: "chart.bar.fill", value: "12+", label: "Risk Models")

            Rectangle()
                .fill(AppColors.divider(colorScheme))
                .frame(width: 1, height: 32)

            metricItem(icon: "square.grid.2x2.fill", value: "6", label: "Asset Classes")

            Rectangle()
                .fill(AppColors.divider(colorScheme))
                .frame(width: 1, height: 32)

            metricItem(icon: "bell.badge.fill", value: "24/7", label: "Real-Time")
        }
        .padding(.vertical, ArkSpacing.sm)
        .glassCard(cornerRadius: ArkSpacing.Radius.card)
        .opacity(showMetrics ? 1 : 0)
        .offset(y: showMetrics ? 0 : 20)
    }

    private func metricItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: ArkSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppColors.accent)
            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 3: Feature Comparison Table

    private var featureComparisonTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("Features")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Free")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textTertiary)
                    .frame(width: 56)

                Text("Pro")
                    .font(AppFonts.caption12Medium)
                    .foregroundStyle(goldGradient)
                    .frame(width: 56)
            }
            .padding(.bottom, ArkSpacing.sm)

            Rectangle()
                .fill(AppColors.divider(colorScheme))
                .frame(height: 1)

            ForEach(comparisonRows) { row in
                comparisonRow(row)
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.card)
        .opacity(showComparison ? 1 : 0)
        .offset(y: showComparison ? 0 : 20)
    }

    private struct ComparisonRow: Identifiable {
        let id = UUID()
        let feature: String
        let icon: String
        let freeValue: ComparisonValue
        let proValue: ComparisonValue
    }

    private enum ComparisonValue {
        case check
        case dash
        case limited(String)
    }

    private var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(feature: "Risk Levels", icon: "chart.bar.fill",
                          freeValue: .limited("BTC Only"), proValue: .check),
            ComparisonRow(feature: "Technical Analysis", icon: "waveform.path.ecg",
                          freeValue: .dash, proValue: .check),
            ComparisonRow(feature: "DCA Reminders", icon: "calendar.badge.plus",
                          freeValue: .limited("3 Max"), proValue: .check),
            ComparisonRow(feature: "Market Broadcasts", icon: "megaphone.fill",
                          freeValue: .dash, proValue: .check),
            ComparisonRow(feature: "Macro Dashboard", icon: "globe.americas.fill",
                          freeValue: .limited("Summary"), proValue: .check),
            ComparisonRow(feature: "Portfolio Analytics", icon: "chart.line.uptrend.xyaxis",
                          freeValue: .limited("Basic"), proValue: .check),
            ComparisonRow(feature: "Data Export", icon: "square.and.arrow.up.fill",
                          freeValue: .dash, proValue: .check),
        ]
    }

    private func comparisonRow(_ row: ComparisonRow) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: row.icon)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 16)
                    Text(row.feature)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                comparisonValueView(row.freeValue, isPro: false)
                    .frame(width: 56)

                comparisonValueView(row.proValue, isPro: true)
                    .frame(width: 56)
            }
            .padding(.vertical, ArkSpacing.xs)

            Rectangle()
                .fill(AppColors.divider(colorScheme).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func comparisonValueView(_ value: ComparisonValue, isPro: Bool) -> some View {
        switch value {
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isPro ? AppColors.success : AppColors.textSecondary)
        case .dash:
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textTertiary)
        case .limited(let text):
            Text(text)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textTertiary)
        }
    }

    // MARK: - Section 4: Social Proof

    private var socialProofSection: some View {
        HStack(spacing: ArkSpacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(AppColors.accent)
            Text("Join founding members managing institutional-level portfolios")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .opacity(showSocialProof ? 1 : 0)
        .offset(y: showSocialProof ? 0 : 20)
    }

    // MARK: - Section 5: Plan Selection Cards

    private var planSelectionCards: some View {
        VStack(spacing: ArkSpacing.sm) {
            // RevenueCat plans
            if let annual = offerings?.current?.annual {
                annualPlanCard(
                    title: "Annual",
                    price: annual.storeProduct.localizedPriceString,
                    subtitle: monthlyEquivalent(for: annual),
                    isSelected: selectedPackage?.identifier == annual.identifier
                ) {
                    Haptics.medium()
                    selectedPackage = annual
                    selectedProduct = nil
                }
            }

            if let monthly = offerings?.current?.monthly {
                monthlyPlanCard(
                    title: "Monthly",
                    price: monthly.storeProduct.localizedPriceString + "/mo",
                    isSelected: selectedPackage?.identifier == monthly.identifier
                ) {
                    Haptics.medium()
                    selectedPackage = monthly
                    selectedProduct = nil
                }
            }

            // StoreKit 2 fallback
            if offerings == nil && !storeProducts.isEmpty {
                if let yearly = storeProducts.first(where: { $0.id == "yearly" }) {
                    annualPlanCard(
                        title: "Annual",
                        price: yearly.displayPrice,
                        subtitle: storeMonthlyEquivalent(for: yearly),
                        isSelected: selectedProduct?.id == yearly.id
                    ) {
                        selectedProduct = yearly
                        selectedPackage = nil
                    }
                }
                if let monthly = storeProducts.first(where: { $0.id == "monthly" }) {
                    monthlyPlanCard(
                        title: "Monthly",
                        price: monthly.displayPrice + "/mo",
                        isSelected: selectedProduct?.id == monthly.id
                    ) {
                        selectedProduct = monthly
                        selectedPackage = nil
                    }
                }
            }

            // Loading skeleton
            if offerings == nil && storeProducts.isEmpty {
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .fill(AppColors.cardBackground(colorScheme).opacity(0.5))
                    .frame(height: 100)
                    .overlay {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                    }
            }
        }
        .opacity(showPlans ? 1 : 0)
        .offset(y: showPlans ? 0 : 20)
    }

    private func annualPlanCard(title: String, price: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: ArkSpacing.sm) {
                HStack {
                    Text(title)
                        .font(AppFonts.title18Bold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("RECOMMENDED")
                        .font(AppFonts.footnote10Bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ArkSpacing.xs)
                        .padding(.vertical, ArkSpacing.xxxs)
                        .background(AppColors.accent)
                        .cornerRadius(ArkSpacing.Radius.xs)

                    Spacer()

                    Text("Save 37%")
                        .font(AppFonts.footnote10Bold)
                        .foregroundColor(AppColors.success)
                        .padding(.horizontal, ArkSpacing.xs)
                        .padding(.vertical, ArkSpacing.xxxs)
                        .background(AppColors.success.opacity(0.15))
                        .cornerRadius(ArkSpacing.Radius.xs)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(subtitle)
                        .font(AppFonts.title24)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    Text(price + "/yr")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme).opacity(0.8))
            .cornerRadius(ArkSpacing.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.divider(colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? AppColors.accent.opacity(0.25) : Color.clear,
                radius: isSelected ? 8 : 0,
                y: 0
            )
        }
    }

    private func monthlyPlanCard(title: String, price: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppFonts.title16)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text(price)
                    .font(AppFonts.title16)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme).opacity(0.6))
            .cornerRadius(ArkSpacing.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.divider(colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }

    // MARK: - Section 6: Trust & Guarantee

    private var trustGuaranteeSection: some View {
        HStack(spacing: 0) {
            trustBadge(icon: "shield.checkmark.fill", text: "Cancel Anytime")
            trustBadge(icon: "clock.fill", text: "No Lock-In")
            trustBadge(icon: "bolt.fill", text: "Instant Access")
        }
        .padding(.vertical, ArkSpacing.sm)
        .glassCard(cornerRadius: ArkSpacing.Radius.card)
        .opacity(showTrust ? 1 : 0)
        .offset(y: showTrust ? 0 : 20)
    }

    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: ArkSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(AppColors.success)
            Text(text)
                .font(AppFonts.footnote10Bold)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 7: Purchase CTA

    private var purchaseCTA: some View {
        Button(action: { Task { await purchase() } }) {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Start Your Membership")
                            .font(AppFonts.title16)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(ArkSpacing.Radius.md)
            .shadow(
                color: AppColors.accent.opacity(0.4),
                radius: 12,
                y: 4
            )
        }
        .disabled((selectedPackage == nil && selectedProduct == nil) || isPurchasing)
        .opacity((selectedPackage == nil && selectedProduct == nil) ? 0.6 : 1)
        .opacity(showCTA ? 1 : 0)
        .offset(y: showCTA ? 0 : 20)
    }

    // MARK: - Section 8: Restore + Terms

    private var restoreAndTerms: some View {
        VStack(spacing: ArkSpacing.sm) {
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

            Text("Recurring billing. Cancel anytime in Settings.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .opacity(showFooter ? 1 : 0)
        .offset(y: showFooter ? 0 : 20)
    }

    // MARK: - Section 9: Enhanced Success Overlay

    private var enhancedSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            ParticleBurstView()

            VStack(spacing: ArkSpacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(goldGradient)
                    .scaleEffect(purchaseSuccess ? 1 : 0.3)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.6),
                        value: purchaseSuccess
                    )

                Text("Welcome to ArkLine Pro")
                    .font(AppFonts.title24)
                    .foregroundStyle(goldGradient)

                Text("Your premium access is now active")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
            }
            .scaleEffect(purchaseSuccess ? 1 : 0.8)
            .opacity(purchaseSuccess ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.7),
                value: purchaseSuccess
            )
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
                    Haptics.success()
                    withAnimation { purchaseSuccess = true }
                    try? await Task.sleep(for: .seconds(1.5))
                    dismiss()
                }
            } catch {
                errorMessage = AppError.from(error).userMessage
            }
        } else if let product = selectedProduct {
            // StoreKit 2 direct purchase fallback
            do {
                let result = try await product.purchase()
                switch result {
                case .success:
                    // Sync with RevenueCat if available
                    await SubscriptionService.shared.refreshStatus()
                    Haptics.success()
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
                errorMessage = AppError.from(error).userMessage
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
            errorMessage = AppError.from(error).userMessage
        }
    }

    // MARK: - Helpers

    private func monthlyEquivalent(for package: Package) -> String {
        let price = package.storeProduct.price as Decimal
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatter?.locale ?? .current
        let monthlyString = formatter.string(from: monthly as NSDecimalNumber) ?? ""
        return "\(monthlyString)/mo"
    }

    private func storeMonthlyEquivalent(for product: Product) -> String {
        let monthly = product.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        let monthlyString = formatter.string(from: monthly as NSDecimalNumber) ?? ""
        return "\(monthlyString)/mo"
    }
}

// MARK: - Particle Burst View

private struct ParticleBurstView: View {
    @State private var animate = false

    private let particles: [(angle: Double, radius: CGFloat, size: CGFloat, colorIndex: Int)] = {
        (0..<20).map { index in
            let angle = (Double(index) / 20.0) * 2 * .pi + Double.random(in: -0.2...0.2)
            let radius = CGFloat.random(in: 100...200)
            let size = CGFloat.random(in: 3...7)
            let colorIndex = index % 4
            return (angle, radius, size, colorIndex)
        }
    }()

    private let colors: [Color] = [
        Color(hex: "F59E0B"),
        Color(hex: "FBBF24"),
        Color(hex: "3B82F6"),
        Color(hex: "22C55E"),
    ]

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { index in
                let particle = particles[index]
                Circle()
                    .fill(colors[particle.colorIndex])
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: animate ? cos(particle.angle) * particle.radius : 0,
                        y: animate ? sin(particle.angle) * particle.radius : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 0.8...1.4))
                        .delay(Double.random(in: 0...0.2)),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
