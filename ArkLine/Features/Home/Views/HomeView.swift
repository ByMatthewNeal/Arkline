import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
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
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        GlassHeader(
                            greeting: viewModel.greeting,
                            userName: viewModel.userName,
                            avatarUrl: viewModel.userAvatar,
                            appState: appState
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Portfolio Value Card (Hero)
                        PortfolioHeroCard(
                            totalValue: viewModel.portfolioValue,
                            change24h: viewModel.portfolioChange24h,
                            changePercent: viewModel.portfolioChangePercent
                        )
                        .padding(.horizontal, 20)

                        // Quick Actions
                        GlassQuickActions()
                            .padding(.horizontal, 20)

                        // ArkLine Risk Score (Composite)
                        if let riskScore = viewModel.compositeRiskScore {
                            RiskScoreCard(score: riskScore)
                                .padding(.horizontal, 20)
                        }

                        // Fear & Greed Widget
                        if let fearGreed = viewModel.fearGreedIndex {
                            GlassFearGreedCard(index: fearGreed)
                                .padding(.horizontal, 20)
                        }

                        // Market Movers
                        MarketMoversSection(
                            btcPrice: viewModel.btcPrice,
                            ethPrice: viewModel.ethPrice,
                            btcChange: viewModel.btcChange24h,
                            ethChange: viewModel.ethChange24h
                        )
                        .padding(.horizontal, 20)

                        // Today's DCA Reminders
                        if viewModel.hasTodayReminders {
                            DCARemindersSection(
                                reminders: viewModel.todayReminders,
                                onComplete: { reminder in Task { await viewModel.markReminderComplete(reminder) } }
                            )
                            .padding(.horizontal, 20)
                        }

                        // Favorites
                        if !viewModel.favoriteAssets.isEmpty {
                            FavoritesSection(assets: viewModel.favoriteAssets)
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 120)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
    }
}

// MARK: - Glass Header
struct GlassHeader: View {
    let greeting: String
    let userName: String
    let avatarUrl: URL?
    @ObservedObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundColor(textPrimary.opacity(0.6))

                Text(userName.isEmpty ? "Welcome" : userName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }

            Spacer()

            HStack(spacing: 12) {
                // Dark/Light Mode Toggle
                GlassThemeToggleButton(appState: appState)

                // Notification Bell with glow
                GlassIconButton(icon: "bell.fill", hasNotification: true)

                // Profile Avatar
                GlassAvatar(imageUrl: avatarUrl, name: userName, size: 44)
            }
        }
    }
}

// MARK: - Glass Theme Toggle Button
struct GlassThemeToggleButton: View {
    @ObservedObject var appState: AppState
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                // Toggle between light and dark
                if appState.darkModePreference == .dark {
                    appState.setDarkModePreference(.light)
                } else {
                    appState.setDarkModePreference(.dark)
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDarkMode ? Color(hex: "A78BFA") : Color(hex: "F59E0B"))
                    .rotationEffect(.degrees(isDarkMode ? 0 : 360))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Glass Icon Button
struct GlassIconButton: View {
    let icon: String
    var hasNotification: Bool = false
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textPrimary)

                // Notification dot
                if hasNotification {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .fill(AppColors.error)
                                .blur(radius: 4)
                        )
                        .offset(x: 12, y: -12)
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
}

// MARK: - Glass Avatar
struct GlassAvatar: View {
    let imageUrl: URL?
    let name: String
    let size: CGFloat
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(AppColors.accent.opacity(0.3))
                .blur(radius: 8)
                .frame(width: size + 8, height: size + 8)

            // Avatar container
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.accent, AppColors.meshPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .frame(width: size, height: size)

            // Avatar content
            if let url = imageUrl {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(textPrimary)
                }
                .frame(width: size - 4, height: size - 4)
                .clipShape(Circle())
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(textPrimary)
            }
        }
    }
}

// MARK: - Portfolio Hero Card
struct PortfolioHeroCard: View {
    let totalValue: Double
    let change24h: Double
    let changePercent: Double
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change24h >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Total Value
            VStack(spacing: 8) {
                Text("Portfolio Value")
                    .font(.subheadline)
                    .foregroundColor(textPrimary.opacity(0.6))

                Text(totalValue.asCurrency)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)

                // Change indicator
                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(isPositive ? "+" : "")\(change24h.asCurrency)")
                        .font(.system(size: 16, weight: .semibold))

                    Text("(\(isPositive ? "+" : "")\(changePercent, specifier: "%.2f")%)")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((isPositive ? AppColors.success : AppColors.error).opacity(0.2))
                )
            }

            // Mini chart placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(height: 60)
                .overlay(
                    // Fake sparkline
                    Path { path in
                        let points: [CGFloat] = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.75, 0.9]
                        let width: CGFloat = 280
                        let height: CGFloat = 50
                        path.move(to: CGPoint(x: 0, y: height * (1 - points[0])))
                        for (index, point) in points.enumerated() {
                            path.addLine(to: CGPoint(x: width * CGFloat(index) / CGFloat(points.count - 1), y: height * (1 - point)))
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.meshCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .padding(8)
                )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 24)
        .overlay(
            // Accent glow at top
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Glass Quick Actions
struct GlassQuickActions: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            GlassQuickActionButton(icon: "plus", label: "Buy", color: AppColors.success)
            GlassQuickActionButton(icon: "arrow.up.right", label: "Send", color: AppColors.accent)
            GlassQuickActionButton(icon: "arrow.down.left", label: "Receive", color: AppColors.meshPurple)
            GlassQuickActionButton(icon: "chart.bar.fill", label: "Trade", color: AppColors.meshCyan)
        }
    }
}

struct GlassQuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: { }) {
            VStack(spacing: 8) {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(color.opacity(0.4))
                        .blur(radius: 10)
                        .frame(width: 50, height: 50)

                    // Icon container
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.5), lineWidth: 1)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(textPrimary.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Risk Score Card
struct RiskScoreCard: View {
    let score: Int
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var riskColor: Color {
        switch score {
        case 0..<30: return AppColors.error
        case 30..<70: return AppColors.warning
        default: return AppColors.success
        }
    }

    var riskLabel: String {
        switch score {
        case 0..<30: return "High Risk"
        case 30..<70: return "Moderate"
        default: return "Low Risk"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Score circle
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 70, height: 70)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [riskColor, riskColor.opacity(0.5)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                // Glow
                Circle()
                    .fill(riskColor.opacity(0.3))
                    .blur(radius: 15)
                    .frame(width: 50, height: 50)

                // Score text
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ArkLine Risk Score")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Text(riskLabel)
                    .font(.subheadline)
                    .foregroundColor(riskColor)

                Text("Based on 10 indicators")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.4))
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Glass Fear & Greed Card
struct GlassFearGreedCard: View {
    let index: FearGreedIndex
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Fear & Greed Index")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text(index.level.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: index.level.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: index.level.color).opacity(0.2))
                    )
            }

            // Gauge
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(0))

                // Gradient arc
                Circle()
                    .trim(from: 0.25, to: 0.25 + (0.5 * Double(index.value) / 100))
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.error, AppColors.warning, AppColors.success],
                            center: .center,
                            startAngle: .degrees(90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(0))

                // Center value
                VStack(spacing: 4) {
                    Text("\(index.value)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)

                    Text("/ 100")
                        .font(.caption)
                        .foregroundColor(textPrimary.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
        }
        .padding(20)
        .glassCard(cornerRadius: 20)
    }
}

// MARK: - Market Movers Section
struct MarketMoversSection: View {
    let btcPrice: Double
    let ethPrice: Double
    let btcChange: Double
    let ethChange: Double
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Movers")
                .font(.headline)
                .foregroundColor(textPrimary)

            HStack(spacing: 12) {
                GlassCoinCard(
                    symbol: "BTC",
                    name: "Bitcoin",
                    price: btcPrice,
                    change: btcChange,
                    icon: "bitcoinsign.circle.fill",
                    accentColor: Color(hex: "F7931A")
                )

                GlassCoinCard(
                    symbol: "ETH",
                    name: "Ethereum",
                    price: ethPrice,
                    change: ethChange,
                    icon: "diamond.fill",
                    accentColor: AppColors.meshPurple
                )
            }
        }
    }
}

struct GlassCoinCard: View {
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let icon: String
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { change >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Coin icon with glow
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.3))
                        .blur(radius: 8)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }

                Spacer()

                // Change badge
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(abs(change), specifier: "%.1f")%")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textPrimary)

                Text(price.asCurrency)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - DCA Reminders Section
struct DCARemindersSection: View {
    let reminders: [DCAReminder]
    let onComplete: (DCAReminder) -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's DCA")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text("\(reminders.count) reminder\(reminders.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(textPrimary.opacity(0.5))
            }

            ForEach(reminders) { reminder in
                GlassDCACard(reminder: reminder, onComplete: { onComplete(reminder) })
            }
        }
    }
}

struct GlassDCACard: View {
    let reminder: DCAReminder
    let onComplete: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Coin icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.3))
                    .blur(radius: 8)
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)

                Text(reminder.symbol.prefix(1))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(reminder.amount.asCurrency)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Spacer()

            // Complete button with glow
            Button(action: onComplete) {
                Text("Invest")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(AppColors.success)
                                .blur(radius: 8)
                                .opacity(0.5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.success, AppColors.success.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Favorites Section
struct FavoritesSection: View {
    let assets: [CryptoAsset]
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Favorites")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Button(action: { }) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(assets) { asset in
                        GlassFavoriteCard(asset: asset)
                    }
                }
            }
        }
    }
}

struct GlassFavoriteCard: View {
    let asset: CryptoAsset
    @Environment(\.colorScheme) var colorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(asset.symbol.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textPrimary)

                Spacer()

                Text("\(isPositive ? "+" : "")\(asset.priceChangePercentage24h, specifier: "%.1f")%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }

            Text(asset.currentPrice.asCurrency)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.8))
        }
        .padding(14)
        .frame(width: 120)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
}
