import SwiftUI

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

// MARK: - Device Info
struct DeviceInfo: Identifiable {
    let id = UUID()
    let name: String
    let lastActive: String
    let isCurrent: Bool
}

// MARK: - Device Row
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
