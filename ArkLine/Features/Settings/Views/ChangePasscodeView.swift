import SwiftUI

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
        // Verify current passcode if one is set
        if PasscodeManager.shared.hasPasscode {
            guard PasscodeManager.shared.verify(currentPasscode) else {
                errorMessage = "Current passcode is incorrect"
                showError = true
                return
            }
        }

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

        do {
            try PasscodeManager.shared.setPasscode(newPasscode)
            dismiss()
        } catch {
            errorMessage = "Failed to save passcode"
            showError = true
        }
    }
}
