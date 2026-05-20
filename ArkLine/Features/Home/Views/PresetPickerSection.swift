import SwiftUI

/// Preset management section for CustomizeHomeView.
/// Shows a pill row to switch between Default and user presets,
/// plus save/rename/delete actions.
struct PresetPickerSection: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var showSaveAlert = false
    @State private var showRenameAlert = false
    @State private var showDeleteConfirmation = false
    @State private var presetNameInput = ""
    @State private var targetPresetId: UUID?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBackground: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Dashboard Presets")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(textPrimary.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                // Preset pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Default pill
                        presetPill(
                            name: "Default",
                            isActive: appState.activePresetId == nil,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    appState.switchToPreset(id: nil)
                                }
                            }
                        )

                        // User presets
                        ForEach(appState.dashboardPresets) { preset in
                            presetPill(
                                name: preset.name,
                                isActive: appState.activePresetId == preset.id,
                                onTap: {
                                    withAnimation(.spring(response: 0.3)) {
                                        appState.switchToPreset(id: preset.id)
                                    }
                                }
                            )
                            .contextMenu {
                                Button {
                                    targetPresetId = preset.id
                                    presetNameInput = preset.name
                                    showRenameAlert = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    targetPresetId = preset.id
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                // Save / limit indicator
                if appState.dashboardPresets.count < DashboardPreset.maxPresets {
                    Button {
                        presetNameInput = ""
                        showSaveAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Save Current as Preset")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                        Text("\(DashboardPreset.maxPresets)/\(DashboardPreset.maxPresets) presets used — delete one to save a new layout")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBackground)
            )
        }
        .padding(.horizontal, 16)
        .alert("Save Preset", isPresented: $showSaveAlert) {
            TextField("Preset name", text: $presetNameInput)
            Button("Save") {
                let name = presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                withAnimation(.spring(response: 0.3)) {
                    appState.savePreset(name: name)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save your current layout so you can switch back to it later.")
        }
        .alert("Rename Preset", isPresented: $showRenameAlert) {
            TextField("New name", text: $presetNameInput)
            Button("Rename") {
                let name = presetNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, let id = targetPresetId else { return }
                appState.renamePreset(id: id, newName: name)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Preset?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                guard let id = targetPresetId else { return }
                withAnimation(.spring(response: 0.3)) {
                    appState.deletePreset(id: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This preset will be permanently removed.")
        }
    }

    // MARK: - Pill

    private func presetPill(name: String, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(name)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .white : textPrimary.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? AppColors.accent : AppColors.textSecondary.opacity(colorScheme == .dark ? 0.15 : 0.1))
                )
        }
        .buttonStyle(.plain)
    }
}
