import SwiftUI

// MARK: - Avatar Color Select View
struct AvatarColorSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var appState: AppState
    @State private var previewTheme: Constants.AvatarColorTheme?

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    // Use preview theme if set, otherwise use saved theme
    private var displayTheme: Constants.AvatarColorTheme {
        previewTheme ?? appState.avatarColorTheme
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Avatar - updates when tapping options
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            displayTheme.gradientColors.light,
                                            displayTheme.gradientColors.dark
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
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayTheme)

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
                                isSelected: displayTheme == theme,
                                action: {
                                    // Update preview immediately
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        previewTheme = theme
                                    }
                                    // Save to AppState
                                    appState.setAvatarColorTheme(theme)
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
        .onAppear {
            previewTheme = appState.avatarColorTheme
        }
    }
}

// MARK: - Chart Color Select View
struct ChartColorSelectView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @ObservedObject var appState: AppState
    @State private var previewPalette: Constants.ChartColorPalette?

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    // Use preview palette if set, otherwise use saved palette
    private var displayPalette: Constants.ChartColorPalette {
        previewPalette ?? appState.chartColorPalette
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Chart - updates when tapping options
                    VStack(spacing: 12) {
                        // Mini pie chart preview
                        ChartPalettePreview(palette: displayPalette)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayPalette)

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
                                isSelected: displayPalette == palette,
                                action: {
                                    // Update preview immediately
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        previewPalette = palette
                                    }
                                    // Save to AppState
                                    appState.setChartColorPalette(palette)
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
        .onAppear {
            previewPalette = appState.chartColorPalette
        }
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
