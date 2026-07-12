import SwiftUI

// MARK: - Customize Market View
/// Lets users choose which widget sections appear on the Market Overview tab.
/// Mirrors `CustomizeHomeView`; Market widgets have no size options, so rows are toggle-only.
/// Backed by the pre-existing `MarketWidgetConfiguration` + `AppState.toggleMarketWidget`.
struct CustomizeMarketView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
    }

    /// Rows follow the user's current on-screen order so the sheet matches the tab.
    private var orderedWidgets: [MarketWidgetType] {
        let order = appState.marketWidgetConfiguration.widgetOrder
        let missing = MarketWidgetType.allCases.filter { !order.contains($0) }
        return order + missing
    }

    private var enabledCount: Int {
        MarketWidgetType.allCases.filter { appState.isMarketWidgetEnabled($0) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header info
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.accent)

                        Text("Customize Market")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textPrimary)

                        Text("Choose which sections appear on your Market tab. Nothing is deleted — hidden sections stay one toggle away.")
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 10)

                    // Section count
                    Text("\(enabledCount) of \(MarketWidgetType.allCases.count) sections shown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.5))

                    // Widget toggles
                    VStack(spacing: 12) {
                        ForEach(orderedWidgets) { widget in
                            MarketWidgetConfigRow(
                                widget: widget,
                                isEnabled: appState.isMarketWidgetEnabled(widget),
                                onToggle: {
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.toggleMarketWidget(widget)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)

                    // Reset to defaults
                    Button(action: resetToDefaults) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .medium))
                            Text("Reset to Defaults")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .accessibilityLabel("Reset Market sections to defaults")

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Customize Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private func resetToDefaults() {
        withAnimation(.spring(response: 0.3)) {
            appState.setMarketWidgetConfiguration(MarketWidgetConfiguration())
        }
    }
}

// MARK: - Market Widget Config Row
/// Toggle-only row (Market sections have no size variants).
struct MarketWidgetConfigRow: View {
    let widget: MarketWidgetType
    let isEnabled: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        HStack(spacing: 14) {
            // Widget icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: widget.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColors.accent)
            }

            // Widget info
            VStack(alignment: .leading, spacing: 4) {
                Text(widget.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textPrimary)

                Text(widget.description)
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Toggle
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEnabled ? AppColors.accent : Color.gray.opacity(0.3))
                        .frame(width: 52, height: 32)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: isEnabled ? 10 : -10)
                }
                .animation(.spring(response: 0.3), value: isEnabled)
            }
            .accessibilityLabel("Toggle \(widget.displayName), currently \(isEnabled ? "on" : "off")")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled ? AppColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    CustomizeMarketView()
        .environmentObject(AppState())
}

#Preview("Light") {
    CustomizeMarketView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
