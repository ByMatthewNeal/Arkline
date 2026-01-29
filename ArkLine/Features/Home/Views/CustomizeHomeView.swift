import SwiftUI

// MARK: - Customize Home View
/// Allows users to select which widgets appear on their home screen
struct CustomizeHomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var expandedWidget: HomeWidgetType? = nil

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var sheetBackground: Color {
        colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7")
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

                        Text("Customize Your Home")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(textPrimary)

                        Text("Toggle widgets on/off and adjust their size. Tap an enabled widget to change its display size.")
                            .font(.system(size: 14))
                            .foregroundColor(textPrimary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 10)

                    // Core Assets section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Core Assets")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(CoreAsset.allCases.enumerated()), id: \.element.id) { index, asset in
                                CoreAssetToggleRow(
                                    asset: asset,
                                    isEnabled: appState.isCoreAssetEnabled(asset),
                                    isLast: index == CoreAsset.allCases.count - 1,
                                    onToggle: {
                                        withAnimation(.spring(response: 0.3)) {
                                            appState.toggleCoreAsset(asset)
                                        }
                                    }
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBackground)
                        )
                    }
                    .padding(.horizontal, 16)

                    // Widget toggles
                    VStack(spacing: 12) {
                        ForEach(HomeWidgetType.allCases) { widget in
                            WidgetConfigRow(
                                widget: widget,
                                isEnabled: appState.isWidgetEnabled(widget),
                                currentSize: appState.widgetSize(widget),
                                isExpanded: expandedWidget == widget,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.toggleWidget(widget)
                                        if !appState.isWidgetEnabled(widget) {
                                            expandedWidget = nil
                                        }
                                    }
                                },
                                onExpand: {
                                    withAnimation(.spring(response: 0.3)) {
                                        if expandedWidget == widget {
                                            expandedWidget = nil
                                        } else if appState.isWidgetEnabled(widget) {
                                            expandedWidget = widget
                                        }
                                    }
                                },
                                onSizeChange: { size in
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.setWidgetSize(size, for: widget)
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

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .background(sheetBackground)
            .navigationTitle("Customize Home")
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
            appState.setWidgetConfiguration(WidgetConfiguration())
            appState.setCoreAssets(CoreAsset.defaultEnabled)
            expandedWidget = nil
        }
    }
}

// MARK: - Widget Config Row
struct WidgetConfigRow: View {
    let widget: HomeWidgetType
    let isEnabled: Bool
    let currentSize: WidgetSize
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void
    let onSizeChange: (WidgetSize) -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 14) {
                // Widget icon
                ZStack {
                    Circle()
                        .fill(widget.accentColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: widget.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(widget.accentColor)
                }

                // Widget info
                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)

                    HStack(spacing: 6) {
                        if isEnabled {
                            // Size indicator
                            HStack(spacing: 4) {
                                Image(systemName: currentSize.icon)
                                    .font(.system(size: 10))
                                Text(currentSize.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(widget.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(widget.accentColor.opacity(0.15))
                            )
                        } else {
                            Text(widget.description)
                                .font(.system(size: 12))
                                .foregroundColor(textPrimary.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                }
                .onTapGesture {
                    if isEnabled {
                        onExpand()
                    }
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
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled {
                    onExpand()
                }
            }

            // Size picker (shown when expanded)
            if isExpanded && isEnabled {
                VStack(spacing: 12) {
                    Divider()
                        .background(AppColors.divider(colorScheme))
                        .padding(.horizontal, 14)

                    // Size options
                    HStack(spacing: 10) {
                        ForEach(WidgetSize.allCases) { size in
                            SizeOptionButton(
                                size: size,
                                isSelected: currentSize == size,
                                accentColor: widget.accentColor,
                                onSelect: { onSizeChange(size) }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

// MARK: - Size Option Button
struct SizeOptionButton: View {
    let size: WidgetSize
    let isSelected: Bool
    let accentColor: Color
    let onSelect: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Size preview icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(height: sizePreviewHeight)

                    Image(systemName: size.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? accentColor : textPrimary.opacity(0.5))
                }

                Text(size.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? accentColor : textPrimary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var sizePreviewHeight: CGFloat {
        switch size {
        case .compact: return 32
        case .standard: return 44
        case .expanded: return 56
        }
    }
}

// MARK: - Core Asset Toggle Row
struct CoreAssetToggleRow: View {
    let asset: CoreAsset
    let isEnabled: Bool
    let isLast: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Asset icon
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: asset.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.accent)
                }

                // Asset info
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textPrimary)

                    Text(asset.name)
                        .font(.system(size: 12))
                        .foregroundColor(textPrimary.opacity(0.6))
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
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .background(AppColors.divider(colorScheme))
                    .padding(.leading, 68)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CustomizeHomeView()
        .environmentObject(AppState())
}

#Preview("Light") {
    CustomizeHomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
